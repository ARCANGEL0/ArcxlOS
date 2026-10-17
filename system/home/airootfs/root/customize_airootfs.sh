#!/bin/bash

set -eu

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sed -i 's|#Server https://ftp.halifax|Server https://ftp.halifax|g' \
  /etc/pacman.d/mirrorlist

sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's|#XferCommand = /usr/bin/archangelos-hyperdl.sh|XferCommand = /usr/bin/archangelos-hyperdl.sh|g' /etc/pacman.conf
sed -i 's|^ParallelDownloads =|#ParallelDownloads =|g' /etc/pacman.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

enabled_services=('choose-mirror.service' 'sddm.service' 'pacman-init'
  'NetworkManager' 'irqbalance' 'vboxservice' 'power-profiles-daemon.service')
systemctl enable ${enabled_services[@]}
systemctl set-default graphical.target

if [ ! -d /root ]; then
  mkdir /root
  chmod 700 /root && chown -R root:root /root
fi

echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

rm -f /etc/udev/rules.d/81-dhcpcd.rules
systemctl disable dhcpcd sshd rpcbind.service systemd-networkd.service systemd-networkd-wait-online.service NetworkManager-wait-online.service systemd-resolved.service iwd.service

rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f /root/{.automated_script.sh,.zlogin}

echo "root:live" | chpasswd

if [ -f /usr/share/blackarch/config/bash/bashrc ]; then
  cp /usr/share/blackarch/config/bash/bashrc /etc/skel/.bashrc
  cp /usr/share/blackarch/config/bash/bash_profile /etc/skel/.bash_profile
  cp /usr/share/blackarch/config/zsh/zshrc /etc/skel/.zshrc
else
  cat > /etc/skel/.bashrc << 'BASHEOF'
[[ $- != *i* ]] && return
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -laf'
PS1='[\u@\h \W]\$ '
fastfetch
BASHEOF
  cp /etc/skel/.bashrc /etc/skel/.bash_profile
  cat > /etc/skel/.zshrc << 'ZSHEOF'
autoload -Uz compinit && compinit
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -laf'
PROMPT='%F{cyan}%n%f@%F{blue}%m%f %F{green}%~%f %# '
fastfetch
ZSHEOF
fi

id -u liveuser &>/dev/null || useradd -m -g users -G wheel,power,audio,video,storage -s /bin/fish liveuser
usermod -s /bin/fish liveuser
useradd -D -s /bin/fish
passwd -d liveuser
ln -sf /usr/share/sddm/themes/archangelos/assets/logo.png /home/liveuser/.face 2>/dev/null || true
mkdir -p /etc/skel/Desktop /home/liveuser/Desktop
chown -R liveuser:users /home/liveuser/Desktop
chmod -R 755 /home/liveuser/Desktop

ln -sf /usr/share/applications/archangelos-gui-installer.desktop /etc/skel/Desktop/archangelos-gui-installer.desktop 2>/dev/null || true
ln -sf /usr/share/applications/archangelos-cli-installer.desktop /etc/skel/Desktop/archangelos-cli-installer.desktop 2>/dev/null || true
ln -sf /usr/share/applications/archangelos-gui-installer.desktop /home/liveuser/Desktop/archangelos-gui-installer.desktop 2>/dev/null || true
ln -sf /usr/share/applications/archangelos-cli-installer.desktop /home/liveuser/Desktop/archangelos-cli-installer.desktop 2>/dev/null || true
ln -sf /usr/share/applications/wps-office-prometheus.desktop /home/liveuser/Desktop/office.desktop 2>/dev/null || true
ln -sf /usr/share/applications/librewolf.desktop /home/liveuser/Desktop/librewolf.desktop 2>/dev/null || true
chmod +x /etc/skel/Desktop/*.desktop /home/liveuser/Desktop/*.desktop 2>/dev/null || true

cp -r /etc/skel/. /root/.

pacman -Syy --noconfirm || true

# Bootstrap yay from AUR (yay-bin is prebuilt) so AUR installs work in-chroot.
if ! command -v yay >/dev/null 2>&1 && id -u liveuser >/dev/null 2>&1; then
  pacman -S --noconfirm --needed git base-devel >/dev/null 2>&1 || true
  su - liveuser -c "rm -rf /tmp/yay-bin && git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -s --noconfirm" >/dev/null 2>&1 || true
  pacman -U --noconfirm /tmp/yay-bin/yay-bin-*.pkg.tar.zst >/dev/null 2>&1 || true
  rm -rf /tmp/yay-bin
fi
pacman-key --init || true
pacman-key --populate archlinux || true
pacman -Fyy || true
updatedb || true
sync

ARCSHELL_DIR="/opt/arcshell"
if [ ! -d "$ARCSHELL_DIR" ]; then
  git clone --depth 1 https://github.com/sud0-L/arcshell.git "$ARCSHELL_DIR" || true
fi
# Drop VCS history from the shallow clone — not needed at runtime, keeps it out of the ISO.
rm -rf "$ARCSHELL_DIR/.git" "$ARCSHELL_DIR/.github" 2>/dev/null || true
# The desktop bake (archangelos-engine-init) runs as liveuser and patches this
# tree IN PLACE (SUPER+T=Rio in keybinds.lua, AMOLED dark surfaces, the video
# wallpaper patch). The clone above runs as root, so those writes silently fail
# on a root-owned tree — hand it to liveuser first.
if id -u liveuser >/dev/null 2>&1; then
  chown -R liveuser:users "$ARCSHELL_DIR" 2>/dev/null || true
fi
if [ -f "$ARCSHELL_DIR/install.sh" ] && [ -d /home/liveuser ]; then
  chmod +x "$ARCSHELL_DIR/install.sh"
  # ArcShell's own installer self-destructs in a headless chroot (its bootstrap
  # health gate needs a live systemd user session + running shell). Bake the
  # fully-installed desktop directly instead — see archangelos-engine-init.
  chmod +x /usr/bin/archangelos-engine-init 2>/dev/null || true
  su - liveuser -c "/usr/bin/archangelos-engine-init" || echo "  [warn] arcshell desktop bake failed" >&2
  if [ -d /home/liveuser/.config ]; then
    cp -rf /home/liveuser/.config/. /etc/skel/.config/ 2>/dev/null || true
  fi
  mkdir -p /home/liveuser/Pictures/Wallpapers
  find /usr/share/backgrounds/archangelos/wallpapers -maxdepth 1 -type f -exec cp -f {} /home/liveuser/Pictures/Wallpapers/ \; 2>/dev/null || true
  chown -R liveuser:users /home/liveuser/Pictures 2>/dev/null || true
fi

if [ -x /usr/bin/archangelos-wallpaper-setup ]; then
  /usr/bin/archangelos-wallpaper-setup || true
fi

if [ -x /usr/bin/archangelos-theme-setup ]; then
  /usr/bin/archangelos-theme-setup || true
fi

if [ -x /usr/bin/archangelos-fastfetch-setup ]; then
  /usr/bin/archangelos-fastfetch-setup || true
fi

if [ -d /etc/skel/.config/rio ]; then
  mkdir -p /home/liveuser/.config/rio
  cp -rf /etc/skel/.config/rio/. /home/liveuser/.config/rio/ 2>/dev/null || true
  chown -R liveuser:users /home/liveuser/.config/rio 2>/dev/null || true
fi
for conf in /home/liveuser/.config/hypr/hyprland.conf /etc/skel/.config/hypr/hyprland.conf; do
  if [ -f "$conf" ]; then
    sed -i -E 's/exec[[:space:]]*,[[:space:]]*(kitty|\$terminal|\$term)/exec, rio/' "$conf"
    sed -i -E 's/^\$terminal[[:space:]]*=[[:space:]]*.*/\$terminal = rio/' "$conf"
    grep -q 'bind[[:space:]]*=[^,]*,[[:space:]]*T[[:space:]]*,[[:space:]]*exec[[:space:]]*,[[:space:]]*rio' "$conf" || \
      printf 'bind = SUPER, T, exec, rio\n' >> "$conf"
  fi
done
if [ -d /etc/skel/.config/hypr ]; then
  cat > /etc/skel/.config/hypr/99-archangelos-rio.conf << 'RIOEOF'
bind = SUPER, T, exec, rio
RIOEOF
fi

for conf in /home/liveuser/.config/hypr/hyprland.conf /etc/skel/.config/hypr/hyprland.conf; do
  if [ -f "$conf" ]; then
    sed -i -E 's/^\$fileManager[[:space:]]*=[[:space:]]*.*/\$fileManager = dolphin/' "$conf"
    grep -q 'bind = SUPER, E, exec, dolphin' "$conf" || \
      printf 'bind = SUPER, E, exec, dolphin\n' >> "$conf"
  fi
done
if [ -d /etc/skel/.config/hypr ]; then
  cat > /etc/skel/.config/hypr/99-archangelos-dolphin.conf << 'DOLEOF'
bind = SUPER, E, exec, dolphin
DOLEOF
fi
for target in /home/liveuser/.config/mimeapps.list /root/.config/mimeapps.list /etc/skel/.config/mimeapps.list; do
  mkdir -p "$(dirname "$target")"
  grep -q '^\[Default Applications\]' "$target" 2>/dev/null || printf '[Default Applications]\n' >> "$target"
  grep -q '^inode/directory=' "$target" 2>/dev/null || \
    sed -i '/^\[Default Applications\]/a inode/directory=org.kde.dolphin.desktop' "$target"
  # LibreWolf is the sole browser — make it the default web handler.
  for h in x-scheme-handler/http x-scheme-handler/https text/html x-scheme-handler/about x-scheme-handler/unknown; do
    grep -q "^${h}=" "$target" 2>/dev/null || \
      sed -i "/^\[Default Applications\]/a ${h}=librewolf.desktop" "$target"
  done
done
chown liveuser:users /home/liveuser/.config/mimeapps.list 2>/dev/null || true
if [ -x /usr/bin/librewolf ]; then
  su - liveuser -c 'xdg-settings set default-web-browser librewolf.desktop' 2>/dev/null || true
fi

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-archangelos.conf << 'SDDMEOF'
[Theme]
Current=archangelos

[General]
GreeterEnvironment=QT_QUICK_CONTROLS_STYLE=Basic
SDDMEOF
# AX default session: Hyprland is preselected at the login screen (other WMs such as
# Openbox/Fluxbox on Fallen stay selectable, but are never the default).
mkdir -p /var/lib/sddm
printf '[Last]\nSession=/usr/share/wayland-sessions/hyprland.desktop\nUser=liveuser\n' > /var/lib/sddm/state.conf
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

if [ -d /usr/share/wayland-sessions ] && [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
  sed -i 's|^Name=.*|Name=ArchangelOS (Hyprland)|' /usr/share/wayland-sessions/hyprland.desktop
fi

ln -sf /etc/fonts/conf.avail/* /etc/fonts/conf.d 2>/dev/null || true
rm -f /etc/fonts/conf.d/05-reset-dirs-sample.conf
rm -f /etc/fonts/conf.d/09-autohint-if-no-hinting.conf

fc-cache -f /usr/share/fonts/archangelos >/dev/null 2>&1 || true
fc-cache -f >/dev/null 2>&1 || true

default_java=$(archlinux-java status 2>/dev/null | grep -o 'java-[a-zA-Z0-9/-]\+' | head -n 1 || true)
if [ -n "$default_java" ]; then
  archlinux-java set "$default_java" || true
fi

gdk-pixbuf-query-loaders --update-cache || true

echo 'ArchangelOS' > /etc/arch-release

default_hotload="/usr/share/backgrounds/archangelos/wallpapers/default.png"
if [ -f /etc/archangelos/wallpaper.conf ]; then
  . /etc/archangelos/wallpaper.conf 2>/dev/null || true
  default_hotload="$POOL_DIR/$HOTLOAD_IMAGE"
fi
find /etc/skel/.config/ /root/.config/ /etc/xdg/ -name "*.xml" 2>/dev/null | while read -r config_file; do
  sed -i "s|/usr/share/backgrounds/[^\"]*|$default_hotload|g" "$config_file" 2>/dev/null || true
done

for dest_dir in "/usr/share/backgrounds/xfce" "/usr/share/xfce4/backdrops"; do
  mkdir -p "$dest_dir"
  rm -f "$dest_dir"/* 2>/dev/null || true
  find /usr/share/backgrounds/archangelos/wallpapers -maxdepth 1 -type f -exec cp -f {} "$dest_dir/" \; 2>/dev/null || true
done

if [ -f /usr/bin/blackarch-install ] && [ ! -L /usr/bin/blackarch-install ]; then
  mv /usr/bin/blackarch-install /usr/bin/blackarch-install-original
fi
ln -sf /usr/bin/archangelos-installer /usr/bin/blackarch-install 2>/dev/null || true

if grep -q '^wireshark:' /etc/group; then
  usermod -aG wireshark liveuser
  if [ -f /usr/bin/dumpcap ]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 4755 /usr/bin/dumpcap
  fi
fi


# ArchangelOS: install curated apps (prebuilt from chaotic-aur, fallback to AUR build)
AUR_PKGS="anki mpvpaper fresh-editor geogebra jupyterlab proton-mail-bin proton-pass-bin proton-vpn-gtk-app subtitleeditor wps-office zotero-bin"
if [ -d /home/liveuser ]; then
  for p in $AUR_PKGS; do
    pacman -S --noconfirm --needed "$p" 2>/dev/null \
      || su - liveuser -c "yay -S --noconfirm --needed $p" \
      || echo "  [warn] could not install $p" >&2
  done
  rm -rf /home/liveuser/.cache/yay/* 2>/dev/null || true
fi

cp -rf /etc/skel/. /home/liveuser/
# The skel copy above overwrites liveuser's hyprland.lua, dropping the welcome
# require that archangelos-wallpaper-setup added (skel never gets it — welcome is
# live-session only). Re-assert it here so the welcome window loads at first login.
lhl=/home/liveuser/.config/hypr/hyprland.lua
if [ -f "$lhl" ]; then
  mkdir -p /home/liveuser/.config/hypr/config
  cp -f /usr/share/archangelos/hypr/archangelos-welcome.lua \
    /home/liveuser/.config/hypr/config/archangelos-welcome.lua 2>/dev/null || true
  grep -q 'require("config.archangelos-welcome")' "$lhl" 2>/dev/null || \
    printf '\nrequire("config.archangelos-welcome")\n' >> "$lhl"
fi
cp -rf /etc/skel/. /root/
chown -R liveuser:users /home/liveuser
chown -R root:root /root

orphans="$(pacman -Qtdq 2>/dev/null || true)"
[ -n "$orphans" ] && pacman -Rns --noconfirm $orphans 2>/dev/null || true

pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/*

rm -rf /var/lib/pacman/sync/*

rm -rf /root/.cache/*
find /var/log -type f -exec truncate -s 0 {} +

sync
