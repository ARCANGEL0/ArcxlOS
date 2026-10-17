#!/bin/bash

set -eu

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

enabled_services=('choose-mirror.service' 'sddm.service' 'pacman-init'
  'NetworkManager' 'irqbalance' 'vboxservice' 'power-profiles-daemon.service')
# BlackArch's blackarch-config-lxdm claims /etc/systemd/system/display-manager.service
# for lxdm, so `systemctl enable sddm.service` refuses to overwrite that symlink and
# exits non-zero — which, under `set -eu`, aborts the whole build. Free the slot first
# so sddm becomes the display manager cleanly.
rm -f /etc/systemd/system/display-manager.service
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
  [ -f /usr/share/blackarch/config/zsh/zshrc ] && cp /usr/share/blackarch/config/zsh/zshrc /etc/skel/.zshrc || true
  if [ -d /usr/share/blackarch/config/vim/vim ]; then
    cp -r /usr/share/blackarch/config/vim/vim /etc/skel/.vim || true
  fi
  [ -f /usr/share/blackarch/config/vim/vimrc ] && cp /usr/share/blackarch/config/vim/vimrc /etc/skel/.vimrc || true
  if [ -d /usr/share/blackarch/config/xfce ]; then
    mkdir -p /etc/skel/.config/xfce4 /etc/xdg/xfce4
    cp -rf /usr/share/blackarch/config/xfce/. /etc/skel/.config/xfce4/ || true
    cp -rf /usr/share/blackarch/config/xfce/. /etc/xdg/xfce4/ || true
  fi
else
  cat > /etc/skel/.bashrc << 'BASHEOF'
[[ $- != *i* ]] && return
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -laf'
PS1='\[\e[0;31m\]\u\[\e[0m\]@\[\e[0;34m\]\h\[\e[0m\] \W\$ '
fastfetch
BASHEOF
  cp /etc/skel/.bashrc /etc/skel/.bash_profile
  cat > /etc/skel/.zshrc << 'ZSHEOF'
autoload -Uz compinit && compinit
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -laf'
PROMPT='%F{red}%n%f@%F{blue}%m%f %F{green}%~%f %# '
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
ln -sf /usr/share/applications/archangelos-gui-installer.desktop /home/liveuser/Desktop/archangelos-gui-installer.desktop 2>/dev/null || true
ln -sf /usr/share/applications/org.wireshark.Wireshark.desktop /home/liveuser/Desktop/wireshark.desktop 2>/dev/null || true
ln -sf /usr/share/applications/zenmap.desktop /home/liveuser/Desktop/zenmap.desktop 2>/dev/null || true
chmod +x /etc/skel/Desktop/*.desktop /home/liveuser/Desktop/*.desktop 2>/dev/null || true

cp -r /etc/skel/. /root/.

pacman-key --init || true
pacman-key --populate archlinux || true
if curl -s https://blackarch.org/strap.sh > /tmp/strap.sh; then
  sh /tmp/strap.sh || true
else
  if [ -f /usr/share/doc/blackarch-keyring/keyring.gpg ] || [ -f /usr/share/pacman/keyrings/blackarch.gpg ]; then
    pacman-key --populate blackarch || true
  fi
  if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
    cat << 'EOF' >> /etc/pacman.conf

[blackarch]
SigLevel = Required DatabaseOptional
Server = https://www.blackarch.org/blackarch/$repo/os/$arch
EOF
  fi
fi
pacman -Syy --noconfirm || true

# Bootstrap yay from AUR (yay-bin is prebuilt) so AUR installs work in-chroot.
if ! command -v yay >/dev/null 2>&1 && id -u liveuser >/dev/null 2>&1; then
  pacman -S --noconfirm --needed git base-devel >/dev/null 2>&1 || true
  su - liveuser -c "rm -rf /tmp/yay-bin && git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -s --noconfirm" >/dev/null 2>&1 || true
  pacman -U --noconfirm /tmp/yay-bin/yay-bin-*.pkg.tar.zst >/dev/null 2>&1 || true
  rm -rf /tmp/yay-bin
fi
pacman-key --populate blackarch archlinux || true
pacman -Fyy || true
pacman-db-upgrade || true
updatedb || true
sync

ln -sf /etc/fonts/conf.avail/* /etc/fonts/conf.d 2>/dev/null || true
rm -f /etc/fonts/conf.d/05-reset-dirs-sample.conf
rm -f /etc/fonts/conf.d/09-autohint-if-no-hinting.conf

fc-cache -f /usr/share/fonts/archangelos >/dev/null 2>&1 || true
fc-cache -f >/dev/null 2>&1 || true

has_internet=0
if curl -s --connect-timeout 3 https://rubygems.org >/dev/null; then
  has_internet=1
fi

if command -v sploitctl >/dev/null 2>&1 && [ "$has_internet" -eq 1 ]; then
  sploitctl -f 1 -t 5 -r 2 -XR || true
  sploitctl -f 2 -t 5 -r 2 -XR || true
  sploitctl -f 3 -t 5 -r 2 -XR || true
  rm -rf /usr/share/exploits/exploit-db/exploitdb-bin-sploits || true
fi

fix_ruby_tool() {
  local tool_dir="$1"
  local bundle_cmd="${2:-bundle}"
  local bundle_args="${3:-}"
  if [ "$has_internet" -eq 0 ]; then
    echo "No internet connection inside chroot, skipping bundle install for $tool_dir"
    return 0
  fi
  if [ -d "$tool_dir" ]; then
    (
      cd "$tool_dir"
      rm -f Gemfile.lock
      $bundle_cmd config set build.nokogiri --use-system-libraries || true
      $bundle_cmd config set path 'vendor/bundle' || true
      if [ -n "$bundle_args" ]; then
        $bundle_cmd install $bundle_args || true
      else
        $bundle_cmd install || true
      fi
      rm -f Gemfile.lock
    )
  fi
}

fix_ruby_tool "/usr/share/arachni/" "bundle-2.3"
fix_ruby_tool "/usr/share/smbexec/"
fix_ruby_tool "/usr/share/beef/"
fix_ruby_tool "/usr/share/catphish/"
fix_ruby_tool "/usr/share/wpbrute-rpc/" "bundle" "--without test development"
fix_ruby_tool "/usr/share/staekka/" "bundle" "--no-cache --deployment"
fix_ruby_tool "/usr/share/vane/" "bundle" "--without test development"
fix_ruby_tool "/usr/share/vcsmap/" "bundle" "--without test development"
fix_ruby_tool "/usr/share/vsaudit/"
fix_ruby_tool "/usr/share/whitewidow/"
fix_ruby_tool "/usr/share/sitediff/"
fix_ruby_tool "/usr/share/wordpress-exploit-framework/"
fix_ruby_tool "/usr/share/kautilya/"
fix_ruby_tool "/usr/share/whatweb/"

rm -f /usr/share/xsessions/blackarch-dwm.desktop 2>/dev/null || true
rm -f /usr/share/xsessions/openbox-kde.desktop 2>/dev/null || true
rm -f /usr/share/xsessions/i3-with-shmlog.desktop 2>/dev/null || true
rm -f /usr/share/xsessions/*gnome*.desktop 2>/dev/null || true
rm -f /usr/share/xsessions/*kde*.desktop 2>/dev/null || true
rm -f /root/install.txt 2>/dev/null || true

ARCSHELL_DIR="/opt/arcshell"
if [ ! -d "$ARCSHELL_DIR" ]; then
  git clone --depth 1 https://github.com/sud0-L/arcshell.git "$ARCSHELL_DIR" || true
fi
# Drop VCS history from the shallow clone — not needed at runtime, keeps it out of the ISO.
rm -rf "$ARCSHELL_DIR/.git" "$ARCSHELL_DIR/.github" 2>/dev/null || true
if [ -f "$ARCSHELL_DIR/install.sh" ] && [ -d /home/liveuser ]; then
  chmod +x "$ARCSHELL_DIR/install.sh"
  # ArcShell's own installer self-destructs in a headless chroot (its bootstrap
  # health gate needs a live systemd user session + running shell). Bake the
  # fully-installed desktop directly instead — see archangelos-arcshell-bake.
  chmod +x /usr/bin/archangelos-arcshell-bake 2>/dev/null || true
  su - liveuser -c "/usr/bin/archangelos-arcshell-bake" || echo "  [warn] arcshell desktop bake failed" >&2
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
done
chown liveuser:users /home/liveuser/.config/mimeapps.list 2>/dev/null || true

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-archangelos.conf << 'SDDMEOF'
[Theme]
Current=archangelos

[Autologin]
User=liveuser
Session=hyprland.desktop
Relogin=false

[General]
GreeterEnvironment=QT_QUICK_CONTROLS_STYLE=Basic
SDDMEOF
# AX default session: Hyprland is preselected at the login screen (other WMs such as
# Openbox/Fluxbox on Fallen stay selectable, but are never the default).
mkdir -p /var/lib/sddm
printf '[Last]\nSession=/usr/share/wayland-sessions/hyprland.desktop\nUser=liveuser\n' > /var/lib/sddm/state.conf
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

if [ -d /usr/share/wayland-sessions ] && [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
  sed -i 's|^Name=.*|Name=ArchangelOS Fallen (Hyprland)|' /usr/share/wayland-sessions/hyprland.desktop
fi

cat > /etc/skel/.config/hypr/99-archangelos-wheel.conf << 'HYPRWHEELEOF'
bind = SUPER, Tab, exec, archangelos-wheel
HYPRWHEELEOF
if [ -f /home/liveuser/.config/hypr/hyprland.conf ]; then
  grep -q 'archangelos-wheel' /home/liveuser/.config/hypr/hyprland.conf || \
    echo "bind = SUPER, Tab, exec, archangelos-wheel" >> /home/liveuser/.config/hypr/hyprland.conf
  grep -q '99-archangelos-wheel' /home/liveuser/.config/hypr/hyprland.conf || \
    echo "source = ~/.config/hypr/99-archangelos-wheel.conf" >> /home/liveuser/.config/hypr/hyprland.conf
fi
if [ -f /usr/bin/archangelos-wheel ]; then
  ln -sf /usr/bin/archangelos-wheel /usr/bin/archangelos-radial 2>/dev/null || true
fi

# ArchangelOS: install curated apps (prebuilt from chaotic-aur, fallback to AUR build)
AUR_PKGS="anki mpvpaper geogebra google-cloud-cli gpu-screen-recorder gpu-viewer i7z lact mission-center proton-mail-bin proton-pass-bin proton-vpn-gtk-app subtitleeditor tauon-music-box vagrant warpinator wps-office zotero-bin"
if [ -d /home/liveuser ]; then
  for p in $AUR_PKGS; do
    pacman -S --noconfirm --needed "$p" 2>/dev/null \
      || su - liveuser -c "yay -S --noconfirm --needed $p" \
      || echo "  [warn] could not install $p" >&2
  done
  rm -rf /home/liveuser/.cache/yay/* 2>/dev/null || true
fi




# ArchangelOS Fallen: the curated core arsenal ships baked in via
# packages.x86_64. The full ~1000-tool catalog is installed on demand:
# per-tool on first launch from the app menu, or all at once via
# `archangelos-install-arsenal` (wraps archangelos-redops-tools). It is
# intentionally NOT run at build time so the live ISO stays slim.

echo "Type archangelos-install and follow the instructions." > /root/INSTALL
echo "Type archangelos-install and follow the instructions." > /home/liveuser/INSTALL
chown liveuser:users /home/liveuser/INSTALL
if [ -f /usr/bin/blackarch-install ]; then
  ln -sf /usr/bin/blackarch-install /usr/bin/archangelos-install
else
  ln -sf /usr/bin/archangelos-installer /usr/bin/blackarch-install 2>/dev/null || true
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

for dest_dir in "/usr/share/blackarch/wallpaper" "/usr/share/backgrounds/xfce"; do
  mkdir -p "$dest_dir"
  rm -f "$dest_dir"/* 2>/dev/null || true
  find /usr/share/backgrounds/archangelos/wallpapers -maxdepth 1 -type f -exec cp -f {} "$dest_dir/" \; 2>/dev/null || true
done

if grep -q '^wireshark:' /etc/group; then
  usermod -aG wireshark liveuser
  if [ -f /usr/bin/dumpcap ]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 4755 /usr/bin/dumpcap
  fi
fi

cp -rf /etc/skel/. /home/liveuser/
cp -rf /etc/skel/. /root/
chown -R liveuser:users /home/liveuser
chown -R root:root /root

orphans="$(pacman -Qtdq 2>/dev/null || true)"
[ -n "$orphans" ] && pacman -Rns --noconfirm $orphans 2>/dev/null || true

pacman -Scc --noconfirm || true
rm -rf /var/cache/pacman/pkg/* 2>/dev/null || true

rm -rf /var/lib/pacman/sync/* 2>/dev/null || true

rm -rf /root/.cache/* 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true

sync
