package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gorilla/websocket"
)

var (
	truenasURL    = getEnv("TRUENAS_URL", "https://truenas.local")
	truenasAPIKey = os.Getenv("TRUENAS_API_KEY")
	truenasName   = getEnv("TRUENAS_NAME", strings.Split(strings.TrimPrefix(strings.TrimPrefix(truenasURL, "https://"), "http://"), ":")[0])
	s3Endpoint    = os.Getenv("S3_ENDPOINT")
	s3AccessKey   = os.Getenv("S3_ACCESS_KEY")
	s3SecretKey   = os.Getenv("S3_SECRET_KEY")
	s3Bucket      = os.Getenv("S3_BUCKET")
	s3Prefix      = getEnv("S3_PREFIX", "truenas-backups")
	s3Region      = getEnv("S3_REGION", "us-east-1")
	verifySSL     = getEnv("VERIFY_SSL", "true") == "true"
	retentionDays = getEnvInt("BACKUP_RETENTION_DAYS", 30)
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}

func tlsConfig() *tls.Config {
	if !verifySSL {
		return &tls.Config{InsecureSkipVerify: true}
	}
	return nil
}

// TrueNAS WebSocket client
type wsClient struct {
	conn *websocket.Conn
	id   atomic.Int64
}

func (c *wsClient) call(method string, params any) (json.RawMessage, error) {
	id := c.id.Add(1)
	if err := c.conn.WriteJSON(map[string]any{"jsonrpc": "2.0", "method": method, "id": id, "params": params}); err != nil {
		return nil, err
	}
	var resp struct {
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := c.conn.ReadJSON(&resp); err != nil {
		return nil, err
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("RPC error %d: %s", resp.Error.Code, resp.Error.Message)
	}
	return resp.Result, nil
}

func generateBackup() ([]byte, error) {
	wsURL := strings.Replace(strings.Replace(truenasURL, "https://", "wss://", 1), "http://", "ws://", 1) + "/api/current"
	conn, _, err := (&websocket.Dialer{HandshakeTimeout: 10 * time.Second, TLSClientConfig: tlsConfig()}).Dial(wsURL, nil)
	if err != nil {
		return nil, fmt.Errorf("websocket: %w", err)
	}
	defer conn.Close()

	client := &wsClient{conn: conn}

	// Authenticate
	var ok bool
	result, err := client.call("auth.login_with_api_key", []string{truenasAPIKey})
	if err != nil {
		return nil, fmt.Errorf("auth: %w", err)
	}
	json.Unmarshal(result, &ok)
	if !ok {
		return nil, fmt.Errorf("auth failed")
	}

	// Get download URL
	fmt.Printf("Requesting config backup from %s\n", truenasURL)
	result, err = client.call("core.download", []any{"config.save", []map[string]bool{{"secretseed": true}}, "config.tar"})
	if err != nil {
		return nil, fmt.Errorf("core.download: %w", err)
	}
	var dlResult []any
	json.Unmarshal(result, &dlResult)
	if len(dlResult) < 2 {
		return nil, fmt.Errorf("unexpected download response")
	}

	// Download file
	req, _ := http.NewRequest("GET", truenasURL+dlResult[1].(string), nil)
	req.Header.Set("Authorization", "Bearer "+truenasAPIKey)
	httpClient := &http.Client{Timeout: 120 * time.Second, Transport: &http.Transport{TLSClientConfig: tlsConfig()}}
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("download: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("download returned %d: %s", resp.StatusCode, body)
	}

	data, _ := io.ReadAll(resp.Body)
	fmt.Printf("Config backup generated: %d bytes\n", len(data))
	return data, nil
}

func newS3Client() (*s3.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(s3AccessKey, s3SecretKey, "")),
		config.WithRegion(s3Region),
	)
	if err != nil {
		return nil, err
	}
	return s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(s3Endpoint)
		o.UsePathStyle = true
	}), nil
}

func upload(ctx context.Context, client *s3.Client, data []byte, filename string) error {
	key := s3Prefix + "/" + filename
	fmt.Printf("Uploading to s3://%s/%s\n", s3Bucket, key)
	_, err := client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s3Bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/x-tar"),
	})
	return err
}

func cleanup(ctx context.Context, client *s3.Client) error {
	if retentionDays <= 0 {
		return nil
	}
	prefix := s3Prefix + "/"
	cutoff := time.Now().UTC().AddDate(0, 0, -retentionDays)
	paginator := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{Bucket: aws.String(s3Bucket), Prefix: aws.String(prefix)})

	deleted := 0
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return err
		}
		for _, obj := range page.Contents {
			if obj.LastModified.Before(cutoff) {
				client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: aws.String(s3Bucket), Key: obj.Key})
				deleted++
			}
		}
	}
	fmt.Printf("Cleanup: removed %d old backup(s)\n", deleted)
	return nil
}

func main() {
	if truenasAPIKey == "" || s3Endpoint == "" || s3AccessKey == "" || s3SecretKey == "" || s3Bucket == "" {
		fmt.Fprintln(os.Stderr, "Error: missing required env vars (TRUENAS_API_KEY, S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET)")
		os.Exit(1)
	}

	data, err := generateBackup()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()
	s3Client, err := newS3Client()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	filename := fmt.Sprintf("%s-config-%s.tar", truenasName, time.Now().UTC().Format("2006-01-02_15-04-05"))
	if err := upload(ctx, s3Client, data, filename); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if err := cleanup(ctx, s3Client); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Backup successful: %s\n", filename)
}