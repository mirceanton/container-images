# syntax=docker/dockerfile:1

# This is a clean-room rebuild distilled from selkies-project/docker-nvidia-glx-desktop
# (MPL-2.0). We keep the parts that are genuinely hard to get right -- the NVIDIA
# in-a-container Xorg setup (see files/entrypoint.sh) and the PipeWire audio stack --
# and drop everything this image does not need for Sunshine/Moonlight game streaming:
# the KDE Plasma desktop, Wine/Lutris/Heroic, Firefox/Chrome, LibreOffice, VLC, the
# Selkies WebRTC stack, KasmVNC, RustDesk, coTURN and NGINX.
#
# The NVIDIA userspace driver is NOT baked in; the entrypoint installs it at container
# start (matching the host kernel driver via the NVIDIA Container Toolkit), so the
# "NVIDIA driver installer dependencies" below must stay.

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ARG TZ=UTC

# -------------------------------------------------------------------------------
# Rootless user environment (uid/gid 1000 "ubuntu"), sudo -> fakeroot shim with a
# real "sudo-root" kept for the few genuine privileged ops (chgrp/chmod on /dev).
# Lifted from the upstream base so behaviour matches inside containers.
# -------------------------------------------------------------------------------
ENV PASSWD=mypasswd
# hadolint ignore=DL3008
RUN apt-get clean && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install --no-install-recommends -y \
        apt-utils \
        ca-certificates \
        dbus-user-session \
        fakeroot \
        fuse \
        kmod \
        locales \
        ssl-cert \
        sudo \
        tzdata \
        udev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

RUN locale-gen en_US.UTF-8 && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

# Only use sudo-root for root-owned directory (/dev, /proc, /sys) or user/group permission operations
RUN mv -f /usr/bin/sudo /usr/bin/sudo-root && \
    ln -snf /usr/bin/fakeroot /usr/bin/sudo

RUN groupadd -g 1000 ubuntu || echo 'Failed to add ubuntu group' && \
    useradd -ms /bin/bash ubuntu -u 1000 -g 1000 || echo 'Failed to add ubuntu user' && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,games,input,lp,plugdev,render,ssl-cert,sudo,tape,tty,video,voice ubuntu && \
    echo "ubuntu ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "ubuntu:${PASSWD}" | chpasswd

RUN chown -R -f -h --no-preserve-root ubuntu:ubuntu / || echo 'Failed to set filesystem ownership in some paths to ubuntu user' && \
    # Preserve setuid/setgid removed by chown
    chmod -f 4755 /usr/lib/dbus-1.0/dbus-daemon-launch-helper /usr/bin/chfn /usr/bin/chsh /usr/bin/mount /usr/bin/gpasswd /usr/bin/passwd /usr/bin/newgrp /usr/bin/umount /usr/bin/su /usr/bin/sudo-root /usr/bin/fusermount || echo 'Failed to set chmod setuid for some paths' && \
    chmod -f 2755 /var/local /var/mail /usr/sbin/unix_chkpwd /usr/sbin/pam_extrausers_chkpwd /usr/bin/expiry /usr/bin/chage || echo 'Failed to set chmod setgid for some paths'

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

# -------------------------------------------------------------------------------
# Core libraries: GL/GLVND + Vulkan loader + X server + NVIDIA installer deps.
# i386 multiarch is enabled for 32-bit Steam titles and DXVK.
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008,SC2028
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install --no-install-recommends -y \
        # Core utilities
        curl \
        wget \
        gnupg \
        file \
        xz-utils \
        zstd \
        bzip2 \
        gzip \
        nano \
        htop \
        nvtop \
        # Process manager
        supervisor \
        # Audio (PipeWire/ALSA compat libs; the PipeWire stack itself is added below)
        alsa-utils \
        libpulse0 \
        # Fonts (minimal set for Steam / game UI text + emoji)
        fonts-dejavu \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-color-emoji \
        fonts-ubuntu \
        # GL / Vulkan diagnostics + loader
        mesa-utils \
        vulkan-tools \
        libvulkan1 \
        libvulkan1:i386 \
        # NVIDIA driver installer dependencies (driver userspace is installed at runtime by entrypoint.sh)
        libc6-dev \
        libpci3 \
        libelf-dev \
        libglvnd-dev \
        # OpenGL / GLVND runtime libraries
        libxau6 \
        libxdmcp6 \
        libxcb1 \
        libxext6 \
        libx11-6 \
        libxv1 \
        libxtst6 \
        libdrm2 \
        libegl1 \
        libgl1 \
        libopengl0 \
        libgles1 \
        libgles2 \
        libglvnd0 \
        libglx0 \
        libglu1 \
        libsm6 \
        # 32-bit OpenGL / GLVND runtime libraries (Steam + DXVK)
        libc6:i386 \
        libxau6:i386 \
        libxdmcp6:i386 \
        libxcb1:i386 \
        libxext6:i386 \
        libx11-6:i386 \
        libxv1:i386 \
        libxtst6:i386 \
        libdrm2:i386 \
        libegl1:i386 \
        libgl1:i386 \
        libopengl0:i386 \
        libgles1:i386 \
        libgles2:i386 \
        libglvnd0:i386 \
        libglx0:i386 \
        libglu1:i386 \
        libsm6:i386 \
        # Xorg server + the bits the entrypoint needs (cvt, xauth, xkb, sharevts wrapper)
        xserver-xorg-core \
        xserver-xorg-legacy \
        xserver-xorg-input-all \
        xcvt \
        xinit \
        xauth \
        xkb-data \
        x11-xkb-utils \
        x11-xserver-utils \
        x11-utils \
        xfonts-base \
        xdg-user-dirs \
        xdg-utils && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/* && \
    # Loader path for the runtime-installed NVIDIA userspace driver
    echo "/usr/local/nvidia/lib"   >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
    # Vulkan ICD -> NVIDIA
    VULKAN_API_VERSION=$(dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)') && \
    mkdir -pm755 /etc/vulkan/icd.d/ && echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libGLX_nvidia.so.0\",\n\
        \"api_version\" : \"${VULKAN_API_VERSION}\"\n\
    }\n\
}" > /etc/vulkan/icd.d/nvidia_icd.json && \
    # EGL ICD -> NVIDIA
    mkdir -pm755 /usr/share/glvnd/egl_vendor.d/ && echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libEGL_nvidia.so.0\"\n\
    }\n\
}" > /usr/share/glvnd/egl_vendor.d/10_nvidia.json && \
    # The runtime NVIDIA driver install (entrypoint.sh) runs as uid 1000 and must
    # write nvidia_drv.so + libglxserver_nvidia.so here. These packages are
    # installed as root (after the base chown), so hand the Xorg module tree to the
    # ubuntu user; otherwise the install hits "Permission denied", Xorg falls back
    # to llvmpipe and NvFBC capture fails. (privileged does not give a non-root uid
    # an effective CAP_DAC_OVERRIDE, so ownership -- not privilege -- is what matters.)
    chown -R ubuntu:ubuntu /usr/lib/xorg

# Expose NVIDIA libraries and paths
ENV PATH="/usr/local/nvidia/bin${PATH:+:${PATH}}"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}/usr/local/nvidia/lib:/usr/local/nvidia/lib64"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
# Disable VSYNC for NVIDIA GPUs
ENV __GL_SYNC_TO_VBLANK=0

# -------------------------------------------------------------------------------
# XFCE desktop environment (wallpaper + desktop icons + panel). A curated minimal
# set installed with --no-install-recommends, so none of the xfce4-goodies bloat.
# xfwm4 compositing is disabled (see files/xfwm4.xml): pointless under NvFBC screen
# capture and only adds latency. dbus-x11 provides dbus-launch (also silences the
# Sunshine system-tray warning).
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008
RUN apt-get update && apt-get install --no-install-recommends -y \
        xfce4-session \
        xfwm4 \
        xfce4-panel \
        xfdesktop4 \
        xfce4-settings \
        xfce4-terminal \
        thunar \
        adwaita-icon-theme \
        dbus-x11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Disable xfwm4 compositing by default (system-wide xfconf default)
COPY files/xfwm4.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

# -------------------------------------------------------------------------------
# Firefox from Mozilla's official APT repo. Ubuntu's `firefox` package is a snap
# transitional that needs snapd (absent in a container), so we pin the real .deb
# from packages.mozilla.org. helpers.rc registers it as XFCE's default browser so
# the panel/menu "Web Browser" launcher (exo-open) works out of the box.
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008
RUN install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla && \
    apt-get update && apt-get install --no-install-recommends -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# XFCE default applications (web browser + terminal) for exo-open launchers
COPY files/helpers.rc /etc/xdg/xfce4/helpers.rc

# Embedded desktop wallpaper, applied once via an autostart hook (the home directory
# is a persistent volume, so a baked-in system default would be ignored; the hook
# sets it on first run and then lets the user change it freely afterwards).
COPY files/wallpaper.png       /usr/share/backgrounds/wallpaper.png
COPY files/set-wallpaper.sh    /usr/local/bin/set-wallpaper.sh
COPY files/set-wallpaper.desktop /etc/xdg/autostart/set-wallpaper.desktop
RUN chmod 0755 /usr/local/bin/set-wallpaper.sh

# -------------------------------------------------------------------------------
# PipeWire + WirePlumber (upstream PPA) -- Sunshine captures audio from this stack.
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008,SC2174
RUN mkdir -pm755 /etc/apt/trusted.gpg.d && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xFC43B7352BCC0EC8AF2EEB8B25088A0359807596" | gpg --dearmor -o /etc/apt/trusted.gpg.d/pipewire-debian-ubuntu-pipewire-upstream.gpg && \
    CODENAME="$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')" && \
    mkdir -pm755 /etc/apt/sources.list.d && \
    echo "deb https://ppa.launchpadcontent.net/pipewire-debian/pipewire-upstream/ubuntu ${CODENAME} main"   > "/etc/apt/sources.list.d/pipewire-debian-ubuntu-pipewire-upstream-${CODENAME}.list" && \
    echo "deb https://ppa.launchpadcontent.net/pipewire-debian/wireplumber-upstream/ubuntu ${CODENAME} main" > "/etc/apt/sources.list.d/pipewire-debian-ubuntu-wireplumber-upstream-${CODENAME}.list" && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        pipewire \
        pipewire-alsa \
        pipewire-audio-client-libraries \
        pipewire-pulse \
        pipewire-jack \
        pipewire-locales \
        libpipewire-0.3-modules \
        libspa-0.2-modules \
        wireplumber \
        wireplumber-locales && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -------------------------------------------------------------------------------
# Steam (multiverse). Proton ships its own runtime, so no Wine here.
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        steam-installer \
        steam-libs-amd64 \
        steam-libs-i386 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -------------------------------------------------------------------------------
# Sunshine (LizardByte) -- the Moonlight streaming server.
# -------------------------------------------------------------------------------
ARG SUNSHINE_VERSION=2026.516.143833
# hadolint ignore=DL3008,DL3015
RUN curl -fsSL "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VERSION}/sunshine-ubuntu-24.04-amd64.deb" \
        -o /tmp/sunshine.deb && \
    apt-get update && \
    apt-get install -y /tmp/sunshine.deb && \
    rm -f /tmp/sunshine.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -------------------------------------------------------------------------------
# Default display configuration (consumed by entrypoint.sh to build xorg.conf).
# -------------------------------------------------------------------------------
ENV DISPLAY=":20"
ENV DISPLAY_SIZEW=1920
ENV DISPLAY_SIZEH=1080
ENV DISPLAY_REFRESH=60
ENV DISPLAY_DPI=96
ENV DISPLAY_CDEPTH=24
ENV VIDEO_PORT=DFP

# -------------------------------------------------------------------------------
# Startup scripts and supervisor configuration.
#
# All supervisor programs are defined inline in supervisord.conf
# The helper scripts referenced by those programs are copied here.
# sunshine.conf (the Sunshine app config) is injected at runtime at /etc/sunshine/sunshine.conf.
# -------------------------------------------------------------------------------
COPY --chown=1000:1000 files/entrypoint.sh    /etc/entrypoint.sh
COPY --chown=1000:1000 files/supervisord.conf /etc/supervisord.conf
COPY files/sunshine-entrypoint.sh /etc/sunshine/entrypoint.sh
COPY files/input-watcher.sh       /etc/sunshine/input-watcher.sh
COPY files/audio-router.sh        /etc/sunshine/audio-router.sh

RUN chmod -f 755 /etc/entrypoint.sh /etc/supervisord.conf && \
    chmod +x /etc/sunshine/entrypoint.sh /etc/sunshine/input-watcher.sh /etc/sunshine/audio-router.sh

# -------------------------------------------------------------------------------
# Re-grant root ownership/setuid to sudo-root so the privileged /dev perm fixes work.
# -------------------------------------------------------------------------------
USER 0
RUN if [ -d "/usr/libexec/sudo" ]; then SUDO_LIB="/usr/libexec/sudo"; else SUDO_LIB="/usr/lib/sudo"; fi && \
    chown -R -f -h --no-preserve-root root:root /usr/bin/sudo-root /etc/sudo.conf /etc/sudoers /etc/sudoers.d /etc/sudo_logsrvd.conf "${SUDO_LIB}" || echo 'Failed to provide root permissions in some paths relevant to sudo' && \
    chmod -f 4755 /usr/bin/sudo-root || echo 'Failed to set chmod setuid for root'
USER 1000

# -------------------------------------------------------------------------------
# PipeWire / dbus runtime environment.
# -------------------------------------------------------------------------------
ENV PIPEWIRE_LATENCY="128/48000"
ENV XDG_RUNTIME_DIR=/tmp/runtime-ubuntu
ENV PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
ENV PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
ENV PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"
ENV DBUS_SYSTEM_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/tmp}/dbus-system-bus"

ENV SHELL=/bin/bash
ENV USER=ubuntu
ENV HOME=/home/ubuntu
WORKDIR /home/ubuntu

# Sunshine: 47984/tcp (HTTPS), 47989/tcp (HTTP), 47990/tcp (Web UI), 48010/tcp (RTSP),
# 47998-48000/udp + 48002/udp (video/control/audio/mic)
EXPOSE 47984/tcp 47989/tcp 47990/tcp 48010/tcp 47998/udp 47999/udp 48000/udp 48002/udp

ENTRYPOINT ["/usr/bin/supervisord"]
