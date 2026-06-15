# selkies-gaming Container Image

Container image extending [selkies-project/nvidia-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) with [Steam](https://store.steampowered.com/) for NVIDIA-accelerated cloud gaming.

- **Selkies** streams the desktop over WebRTC (browser-accessible, no client required)
- **Steam** provides the gaming library

## Why a custom image?

The upstream `selkies-project/nvidia-glx-desktop` image does not bundle Steam. This image layers it on top so a single container provides a browser-accessible WebRTC desktop alongside the game library.

## Configuration

The upstream `selkies-project/nvidia-glx-desktop` image exposes the environment variables that drive this image (display resolution, WebRTC encoder settings, basic auth, etc.), documented in its own README. This image does not add any environment variables of its own.

### Ports

| Port   | Protocol | Description           |
| ------ | -------- | --------------------- |
| `8080` | TCP      | Selkies WebRTC web UI |

## Usage (Kubernetes)

The container requires:

- `runtimeClassName: nvidia` (NVIDIA device plugin)
- `hostNetwork: true` (avoids a TURN server for WebRTC; without it, Selkies needs a TURN server for media relay)

Gamepad input is handled by the Selkies userspace joystick interposer, so `/dev/input`, `/run/udev`, `/dev/uinput`, and `privileged: true` are **not** required for WebRTC streaming.

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
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          resources:
            requests:
              cpu: "2"
              memory: 4Gi
              nvidia.com/gpu: "1"
            limits:
              memory: 16Gi
              nvidia.com/gpu: "1"
          volumeMounts:
            - mountPath: /dev/shm
              name: dshm
            - mountPath: /home/ubuntu
              name: home
            - mountPath: /cache
              name: cache
      volumes:
        - name: dshm
          emptyDir:
            medium: Memory
        - name: home
          persistentVolumeClaim:
            claimName: selkies-home
        - name: cache
          persistentVolumeClaim:
            claimName: selkies-cache
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
```

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
