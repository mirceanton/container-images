# steam-sunshine Container Image

A lean, NVIDIA-accelerated Ubuntu image with [Steam](https://store.steampowered.com/)
and [Sunshine](https://github.com/LizardByte/Sunshine) for **couch/controller game
streaming** over the Moonlight protocol.

- **Sunshine** streams the X11 desktop via Moonlight (low-latency, client-based)
- **Steam** (+ Proton) provides the gaming library
- **XFCE** is the desktop environment (wallpaper + desktop icons + panel; xfwm4 WM, compositing off)

> [!NOTE]
> This image descends from `selkies-project/nvidia-glx-desktop` (which is where the
> hard-won NVIDIA-in-a-container Xorg setup comes from) but **no longer ships
> Selkies/WebRTC** — it is a Steam + Sunshine build for TV/couch gaming with a
> controller.

## Why a custom image?

It started life on top of `selkies-project/nvidia-glx-desktop` (Selkies WebRTC + KDE +
a large suite of desktop apps). For couch gaming over Moonlight none of that is needed,
and Selkies actively conflicts with Sunshine (its `LD_PRELOAD` joystick interposer
hijacks controller input to the browser Gamepad API; `selkies-gstreamer` competes for
the PulseAudio capture sink).

So this is a **clean-room rebuild from `ubuntu:24.04`**, distilled from the upstream
Dockerfile (MPL-2.0). It keeps the parts that are genuinely hard to get right — the
NVIDIA in-a-container Xorg setup (`files/entrypoint.sh`) and the PipeWire audio stack —
and drops KDE Plasma, Wine/Lutris/Heroic, Google Chrome, LibreOffice, VLC, Selkies,
KasmVNC, RustDesk, coTURN and NGINX, replacing them with a minimal XFCE desktop and
Firefox. The result is a fraction of the original size.

The NVIDIA userspace driver is **not** baked in: `entrypoint.sh` installs it at
container start, matching the host kernel driver injected by the NVIDIA Container
Toolkit (`NVIDIA_DRIVER_CAPABILITIES=all`).

## Configuration

### Environment Variables

| Variable            | Description                          | Default      |
| ------------------- | ------------------------------------ | ------------ |
| `SUNSHINE_USER`     | Sunshine web UI username             | —            |
| `SUNSHINE_PASSWORD` | Sunshine web UI password             | —            |
| `TZ`                | Timezone                             | `UTC`        |
| `DISPLAY_SIZEW`     | Virtual display width                | `1920`       |
| `DISPLAY_SIZEH`     | Virtual display height               | `1080`       |
| `DISPLAY_REFRESH`   | Virtual display refresh rate (Hz)    | `60`         |
| `DISPLAY_DPI`       | Virtual display DPI                  | `96`         |
| `DISPLAY_CDEPTH`    | Virtual display color depth          | `24`         |
| `VIDEO_PORT`        | Xorg video port for RANDR            | `DFP`        |

If `SUNSHINE_USER` and `SUNSHINE_PASSWORD` are both set, credentials are seeded into
Sunshine on startup.

### Ports

| Port    | Protocol | Description              |
| ------- | -------- | ------------------------ |
| `47984` | TCP      | Moonlight HTTPS          |
| `47989` | TCP      | Moonlight HTTP           |
| `47990` | TCP      | Sunshine web UI          |
| `48010` | TCP      | Moonlight RTSP           |
| `47998` | UDP      | Moonlight video stream   |
| `47999` | UDP      | Moonlight control stream |
| `48000` | UDP      | Moonlight audio stream   |
| `48002` | UDP      | Moonlight mic stream     |

## Controllers & audio

- **Controllers** work via real kernel virtual-input devices. The `input-watcher`
  fixes group/permissions on `/dev/uinput`, `/dev/uhid` and the created
  `/dev/input/event*` nodes so Sunshine can create gamepads (Xbox pads use `uinput`;
  DS4/DS5 use `uhid`). Requires the `uinput`/`uhid`/`joydev` kernel modules on the host
  and the device nodes available in the container.
- **Audio** survives disconnect/reconnect via the `audio-router`, which re-links app
  playback streams back into Sunshine's capture sink after Sunshine's per-session audio
  teardown orphans them on disconnect.

## Usage (Kubernetes)

The container requires:

- `runtimeClassName: nvidia` (NVIDIA device plugin)
- `hostNetwork: true` (recommended for Moonlight low-latency UDP without NAT traversal)
- `/dev/input`, `/dev/uinput`, `/dev/uhid` and `/run/udev` mounted from the host
- A `sunshine.conf` (and optional `apps.json`) injected at `/etc/sunshine/`

> [!IMPORTANT]
> This needs **`privileged: true`**. Sunshine creates its virtual keyboard/mouse via
> `uinput` at runtime, and the resulting `/dev/input/event*` nodes get **dynamic minor
> numbers**. For the X server to read them, the device cgroup must allow the whole input
> class (`c 13:* rwm`) — which only `privileged: true` grants on standard Kubernetes.
> A device plugin (e.g. `generic-device-plugin`) can only allow nodes that exist at
> pod-admission time, so it cannot cover Sunshine's dynamically-created devices.
> Without privileged, the controller may still create but keyboard/mouse input fails.
> `CAP_SYS_NICE` is also added for Sunshine's real-time scheduling.

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
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: selkies
          image: ghcr.io/mirceanton/steam-sunshine:latest
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
              value: "120"
            - name: VIDEO_PORT
              value: "DFP"
            - name: NVIDIA_DRIVER_CAPABILITIES
              value: "all"
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
            privileged: true # required for dynamic /dev/input/event* access (see note above)
            capabilities:
              add: ["CAP_SYS_NICE"]
          ports:
            - { name: sunshine-ui,    containerPort: 47990, protocol: TCP }
            - { name: sunshine-https, containerPort: 47984, protocol: TCP }
            - { name: sunshine-http,  containerPort: 47989, protocol: TCP }
            - { name: sunshine-rtsp,  containerPort: 48010, protocol: TCP }
            - { name: sunshine-video, containerPort: 47998, protocol: UDP }
            - { name: sunshine-ctrl,  containerPort: 47999, protocol: UDP }
            - { name: sunshine-audio, containerPort: 48000, protocol: UDP }
          resources:
            requests:
              cpu: "2"
              memory: 4Gi
              nvidia.com/gpu: "1"
            limits:
              memory: 16Gi
              nvidia.com/gpu: "1"
          volumeMounts:
            - { mountPath: /dev/shm,   name: dshm }
            - { mountPath: /dev/input, name: input-devices }
            - { mountPath: /dev/uinput, name: uinput }
            - { mountPath: /dev/uhid,  name: uhid }
            - { mountPath: /run/udev,  name: udev-run, readOnly: true }
            - { mountPath: /home/ubuntu, name: home }
            - mountPath: /etc/sunshine/sunshine.conf
              name: sunshine-config
              subPath: sunshine.conf
      volumes:
        - name: dshm
          emptyDir:
            medium: Memory
        - name: input-devices
          hostPath: { path: /dev/input, type: Directory }
        - name: uinput
          hostPath: { path: /dev/uinput, type: CharDevice }
        - name: uhid
          hostPath: { path: /dev/uhid, type: CharDevice }
        - name: udev-run
          hostPath: { path: /run/udev, type: Directory }
        - name: home
          persistentVolumeClaim:
            claimName: selkies-home
        - name: sunshine-config
          configMap:
            name: sunshine-config
```

</details>

<details>
<summary>ConfigMap (sunshine.conf)</summary>

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: sunshine-config
  namespace: games
data:
  sunshine.conf: |
    sunshine_name = steam-sunshine
    origin_web_ui_allowed = lan
    min_log_level = info
    capture = nvfbc
    audio_sink = sink-sunshine-stereo
    nvenc_preset = 5
    upnp = enabled
```

</details>

With `hostNetwork: true` the Moonlight UDP/TCP ports are exposed directly on the host —
no Service entries are needed for them.
