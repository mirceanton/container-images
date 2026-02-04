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

type Config struct {
	TrueNASURL          string
	TrueNASAPIKey       string
	TrueNASName         string
	S3Endpoint          string
	S3AccessKey         string
	S3SecretKey         string
	S3Bucket            string
	S3Prefix            string
	S3Region            string
	VerifySSL           bool
	BackupRetentionDays int
}

func loadConfig() (*Config, error) {
	truenasURL := getEnv("TRUENAS_URL", "https://truenas.local")
	cfg := &Config{
		TrueNASURL:          truenasURL,
		TrueNASAPIKey:       os.Getenv("TRUENAS_API_KEY"),
		TrueNASName:         getEnv("TRUENAS_NAME", deriveTrueNASName(truenasURL)),
		S3Endpoint:          os.Getenv("S3_ENDPOINT"),
		S3AccessKey:         os.Getenv("S3_ACCESS_KEY"),
		S3SecretKey:         os.Getenv("S3_SECRET_KEY"),
		S3Bucket:            os.Getenv("S3_BUCKET"),
		S3Prefix:            getEnv("S3_PREFIX", "truenas-backups"),
		S3Region:            getEnv("S3_REGION", "us-east-1"),
		VerifySSL:           getEnv("VERIFY_SSL", "true") == "true",
		BackupRetentionDays: getEnvInt("BACKUP_RETENTION_DAYS", 30),
	}

	if cfg.TrueNASAPIKey == "" {
		return nil, fmt.Errorf("TRUENAS_API_KEY is required")
	}
	if cfg.S3Endpoint == "" || cfg.S3AccessKey == "" || cfg.S3SecretKey == "" || cfg.S3Bucket == "" {
		return nil, fmt.Errorf("S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, and S3_BUCKET are required")
	}
	return cfg, nil
}

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

func deriveTrueNASName(url string) string {
	name := strings.TrimPrefix(url, "https://")
	name = strings.TrimPrefix(name, "http://")
	name = strings.Split(name, ":")[0]
	return name
}

// TrueNAS WebSocket JSON-RPC client
type TrueNASClient struct {
	conn   *websocket.Conn
	nextID atomic.Int64
}

type jsonRPCRequest struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	ID      int64  `json:"id"`
	Params  any    `json:"params,omitempty"`
}

type jsonRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int64           `json:"id"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *jsonRPCError   `json:"error,omitempty"`
}

type jsonRPCError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data,omitempty"`
}

func newTrueNASClient(cfg *Config) (*TrueNASClient, error) {
	wsURL := strings.Replace(cfg.TrueNASURL, "https://", "wss://", 1)
	wsURL = strings.Replace(wsURL, "http://", "ws://", 1)
	wsURL += "/api/current"

	dialer := websocket.Dialer{
		HandshakeTimeout: 10 * time.Second,
	}
	if !cfg.VerifySSL {
		dialer.TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	}

	conn, _, err := dialer.Dial(wsURL, nil)
	if err != nil {
		return nil, fmt.Errorf("websocket dial failed: %w", err)
	}

	client := &TrueNASClient{conn: conn}

	if err := client.authenticate(cfg.TrueNASAPIKey); err != nil {
		conn.Close()
		return nil, fmt.Errorf("authentication failed: %w", err)
	}

	return client, nil
}

func (c *TrueNASClient) call(method string, params any) (json.RawMessage, error) {
	id := c.nextID.Add(1)
	req := jsonRPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		ID:      id,
		Params:  params,
	}

	if err := c.conn.WriteJSON(req); err != nil {
		return nil, fmt.Errorf("write failed: %w", err)
	}

	var resp jsonRPCResponse
	if err := c.conn.ReadJSON(&resp); err != nil {
		return nil, fmt.Errorf("read failed: %w", err)
	}

	if resp.Error != nil {
		return nil, fmt.Errorf("RPC error %d: %s", resp.Error.Code, resp.Error.Message)
	}

	return resp.Result, nil
}

func (c *TrueNASClient) authenticate(apiKey string) error {
	result, err := c.call("auth.login_with_api_key", []string{apiKey})
	if err != nil {
		return err
	}

	var success bool
	if err := json.Unmarshal(result, &success); err != nil {
		return fmt.Errorf("parsing auth response: %w", err)
	}
	if !success {
		return fmt.Errorf("authentication returned false")
	}

	return nil
}

func (c *TrueNASClient) Close() error {
	return c.conn.Close()
}

func generateConfigBackup(cfg *Config) ([]byte, error) {
	client, err := newTrueNASClient(cfg)
	if err != nil {
		return nil, err
	}
	defer client.Close()

	fmt.Printf("Requesting config backup from %s\n", cfg.TrueNASURL)

	downloadParams := []any{
		"config.save",
		[]map[string]bool{{"secretseed": true}},
		"config.tar",
	}

	result, err := client.call("core.download", downloadParams)
	if err != nil {
		return nil, fmt.Errorf("core.download failed: %w", err)
	}

	var downloadResult []any
	if err := json.Unmarshal(result, &downloadResult); err != nil {
		return nil, fmt.Errorf("parsing download response: %w", err)
	}

	if len(downloadResult) < 2 {
		return nil, fmt.Errorf("unexpected download response format")
	}

	downloadURL, ok := downloadResult[1].(string)
	if !ok {
		return nil, fmt.Errorf("download URL not a string")
	}

	fullURL := cfg.TrueNASURL + downloadURL

	httpClient := &http.Client{Timeout: 120 * time.Second}
	if !cfg.VerifySSL {
		httpClient.Transport = &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
	}

	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return nil, fmt.Errorf("creating download request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+cfg.TrueNASAPIKey)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("download request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("download returned %d: %s", resp.StatusCode, string(body))
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading backup data: %w", err)
	}

	fmt.Printf("Config backup generated: %d bytes\n", len(data))
	return data, nil
}

func createS3Client(cfg *Config) (*s3.Client, error) {
	awsCfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			cfg.S3AccessKey, cfg.S3SecretKey, "",
		)),
		config.WithRegion(cfg.S3Region),
	)
	if err != nil {
		return nil, err
	}

	return s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(cfg.S3Endpoint)
		o.UsePathStyle = true
	}), nil
}

func uploadToS3(ctx context.Context, client *s3.Client, cfg *Config, data []byte, filename string) (string, error) {
	key := filename
	if cfg.S3Prefix != "" {
		key = cfg.S3Prefix + "/" + filename
	}

	fmt.Printf("Uploading to s3://%s/%s\n", cfg.S3Bucket, key)

	_, err := client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(cfg.S3Bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/x-tar"),
	})
	if err != nil {
		return "", fmt.Errorf("upload failed: %w", err)
	}

	return key, nil
}

func cleanupOldBackups(ctx context.Context, client *s3.Client, cfg *Config) error {
	if cfg.BackupRetentionDays <= 0 {
		return nil
	}

	prefix := cfg.S3Prefix
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}

	cutoff := time.Now().UTC().AddDate(0, 0, -cfg.BackupRetentionDays)

	paginator := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{
		Bucket: aws.String(cfg.S3Bucket),
		Prefix: aws.String(prefix),
	})

	deleted := 0
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("listing objects: %w", err)
		}

		for _, obj := range page.Contents {
			if obj.LastModified.Before(cutoff) {
				_, err := client.DeleteObject(ctx, &s3.DeleteObjectInput{
					Bucket: aws.String(cfg.S3Bucket),
					Key:    obj.Key,
				})
				if err != nil {
					fmt.Printf("Warning: failed to delete %s: %v\n", *obj.Key, err)
					continue
				}
				fmt.Printf("Deleted old backup: %s\n", *obj.Key)
				deleted++
			}
		}
	}

	fmt.Printf("Cleanup: removed %d old backup(s)\n", deleted)
	return nil
}

func run() error {
	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	ctx := context.Background()

	backupData, err := generateConfigBackup(cfg)
	if err != nil {
		return fmt.Errorf("generating backup: %w", err)
	}

	timestamp := time.Now().UTC().Format("20060102-150405")
	filename := fmt.Sprintf("%s-config-%s.tar", cfg.TrueNASName, timestamp)

	s3Client, err := createS3Client(cfg)
	if err != nil {
		return fmt.Errorf("creating S3 client: %w", err)
	}

	if _, err := uploadToS3(ctx, s3Client, cfg, backupData, filename); err != nil {
		return err
	}

	if err := cleanupOldBackups(ctx, s3Client, cfg); err != nil {
		return fmt.Errorf("cleanup failed: %w", err)
	}

	fmt.Printf("Backup successful: %s\n", filename)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}