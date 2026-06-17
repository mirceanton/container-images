# selkies-gaming Container Image

Container image extending [selkies-project/nvidia-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) with [Steam](https://store.steampowered.com/) and [Sunshine](https://github.com/LizardByte/Sunshine) for NVIDIA-accelerated cloud gaming.

- **Selkies** streams the desktop over WebRTC (browser-accessible, no client required)
- **Sunshine** streams the desktop via the Moonlight protocol (low-latency, client-based)
- **Steam** provides the gaming library

## Why a custom image?

The upstream `selkies-project/nvidia-glx-desktop` image does not bundle Steam or Sunshine. This image layers both on top so a single container provides both WebRTC for "generic" desktop use via a web browser and Moonlight streaming for low-latency gaming (or any other workload) alongside the game library.

## Configuration

### Environment Variables

| Variable            | Description              | Default |
| ------------------- | ------------------------ | ------- |
| `SUNSHINE_USER`     | Sunshine web UI username | —       |
| `SUNSHINE_PASSWORD` | Sunshine web UI password | —       |

If `SUNSHINE_USER` and `SUNSHINE_PASSWORD` are both set, credentials are seeded into Sunshine on startup. The upstream `selkies-project/nvidia-glx-desktop` image exposes additional environment variables (display resolution, WebRTC encoder settings, etc.) documented in its own README.

### Ports

| Port          | Protocol | Description              |
| ------------- | -------- | ------------------------ |
| `8080`        | TCP      | Selkies WebRTC web UI    |
| `47984`       | TCP      | Moonlight HTTPS          |
| `47989`       | TCP      | Moonlight HTTP           |
| `47990`       | TCP      | Sunshine web UI          |
| `47998`       | UDP      | Moonlight video stream   |
| `47999`       | UDP      | Moonlight control stream |
| `48000`       | UDP      | Moonlight audio stream   |
| `48010`       | TCP      | Moonlight RTSP           |

## Usage (Kubernetes)

The container requires:

- `runtimeClassName: nvidia` (NVIDIA device plugin)
- `privileged: true` (needed for `/dev/uinput` and `/dev/input` access)
- `hostNetwork: true` (recommended for Moonlight to avoid NAT traversal issues with UDP streams)
- `/dev/input` and `/run/udev` mounted from the host (for virtual input device support)
- A `sunshine.conf` and `apps.json` injected

<details>
<summary>Deployment</summary>

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selkies
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: selkies
  template:
    metadata:
      labels:
        app: selkies
    spec:
      hostname: selkies
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      runtimeClassName: nvidia
      automountServiceAccountToken: false
      enableServiceLinks: false
      securityContext:
        seccompProfile:
          type: Unconfined
      containers:
        - name: selkies
          image: ghcr.io/mirceanton/selkies-gaming:latest
          stdin: true
          tty: true
          env:
            - name: TZ
              value: "Europe/London"
            - name: DISPLAY_SIZEW
              value: "2560"
            - name: DISPLAY_SIZEH
              value: "1440"
            - name: DISPLAY_REFRESH
              value: "60"
            - name: DISPLAY_DPI
              value: "96"
            - name: DISPLAY_CDEPTH
              value: "24"
            - name: VIDEO_PORT
              value: "DFP"
            - name: NVIDIA_DRIVER_CAPABILITIES
              value: "all"
            - name: PASSWD
              valueFrom:
                secretKeyRef:
                  name: selkies
                  key: passwd
            - name: SELKIES_ENCODER
              value: "nvh264enc"
            - name: SELKIES_ENABLE_RESIZE
              value: "false"
            - name: SELKIES_VIDEO_BITRATE
              value: "100000"
            - name: SELKIES_FRAMERATE
              value: "60"
            - name: SELKIES_AUDIO_BITRATE
              value: "128000"
            - name: SELKIES_ENABLE_BASIC_AUTH
              value: "true"
            - name: SELKIES_BASIC_AUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: selkies
                  key: passwd
            - name: SELKIES_ENABLE_HTTPS
              value: "false"
            - name: SUNSHINE_USER
              valueFrom:
                secretKeyRef:
                  name: selkies
                  key: sunshine-user
            - name: SUNSHINE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: selkies
                  key: sunshine-password
          securityContext:
            privileged: true
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: sunshine-ui
              containerPort: 47990
              protocol: TCP
            - name: sunshine-https
              containerPort: 47984
              protocol: TCP
            - name: sunshine-http
              containerPort: 47989
              protocol: TCP
            - name: sunshine-rtsp
              containerPort: 48010
              protocol: TCP
            - name: sunshine-video
              containerPort: 47998
              protocol: UDP
            - name: sunshine-ctrl
              containerPort: 47999
              protocol: UDP
            - name: sunshine-audio
              containerPort: 48000
              protocol: UDP
          resources:
            requests:
              cpu: "2"
              memory: 4Gi
              nvidia.com/gpu: "1"
              devic.es/uinput: "1"
            limits:
              memory: 16Gi
              nvidia.com/gpu: "1"
              devic.es/uinput: "1"
          volumeMounts:
            - mountPath: /dev/shm
              name: dshm
            - mountPath: /dev/input
              name: input-devices
            - mountPath: /run/udev
              name: udev-run
              readOnly: true
            - mountPath: /home/ubuntu
              name: home
            - mountPath: /cache
              name: cache
            - mountPath: /etc/sunshine/sunshine.conf
              name: sunshine-config
              subPath: sunshine.conf
            - mountPath: /etc/sunshine/apps.json
              name: sunshine-config
              subPath: apps.json
      volumes:
        - name: dshm
          emptyDir:
            medium: Memory
        - name: input-devices
          hostPath:
            path: /dev/input
            type: Directory
        - name: udev-run
          hostPath:
            path: /run/udev
            type: Directory
        - name: home
          persistentVolumeClaim:
            claimName: selkies-home
        - name: cache
          persistentVolumeClaim:
            claimName: selkies-cache
        - name: sunshine-config
          configMap:
            name: sunshine-config
```

</details>

<details>
<summary>Service</summary>

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: selkies
  namespace: games
spec:
  selector:
    app: selkies
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
    - name: sunshine-ui
      port: 47990
      targetPort: sunshine-ui
      protocol: TCP
```

With `hostNetwork: true` the Moonlight UDP/TCP ports are exposed directly on the host — no Service entries needed for them.

</details>

<details>
<summary>PersistentVolumeClaims</summary>

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: selkies-home
  namespace: games
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: selkies-cache
  namespace: games
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

</details>

<details>
<summary>ConfigMap (sunshine.conf + apps.json)</summary>

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: sunshine-config
  namespace: games
data:
  sunshine.conf: |
    sunshine_name = selkies-gaming
    origin_web_ui_allowed = lan
    file_apps = /etc/sunshine/apps.json
    min_log_level = info
    capture = x11
    nvenc_preset = 5
    nvenc_twopass = full_res
    nvenc_spatial_aq = enabled
    upnp = enabled
  apps.json: |
    {
      "env": {},
      "apps": [
        {
          "name": "Desktop",
          "image-path": "desktop.png"
        },
        {
          "name": "Steam Big Picture",
          "image-path": "steam.png",
          "detached": [
            "setsid /usr/games/steam -bigpicture"
          ]
        }
      ]
    }
```

</details>
