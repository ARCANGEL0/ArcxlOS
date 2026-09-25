#!/bin/bash

set -eu

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sed -i 's|#Server https://ftp.halifax|Server https://ftp.halifax|g' \
  /etc/pacman.d/mirrorlist

sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

systemctl enable pacman-init.service choose-mirror.service

if [ ! -d /root ]; then
  mkdir /root
  chmod 700 root && chown -R root:root /root
fi

echo "root:toor" | chpasswd

if [ -x /usr/bin/archangelos-fastfetch-setup ]; then
  /usr/bin/archangelos-fastfetch-setup || true
fi

id -u liveuser &>/dev/null || useradd -m -g users -G wheel,power,audio,video,storage -s /bin/fish liveuser
usermod -s /bin/fish liveuser
useradd -D -s /bin/fish
passwd -d liveuser

ARCSHELL_DIR="/opt/arcshell"
if [ ! -d "$ARCSHELL_DIR" ]; then
  git clone --depth 1 https://github.com/sud0-L/arcshell.git "$ARCSHELL_DIR" || true
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
systemctl enable sddm NetworkManager

cp -r /etc/skel/. /root/.

curl -s https://blackarch.org/strap.sh | sh

pacman -Syyu --noconfirm
pacman-key --init
pacman-key --populate blackarch archlinux
pacman -Fyy
pacman-db-upgrade
updatedb
sync

chsh -s /bin/fish
useradd -D -s /bin/fish

echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f /root/{.automated_script.sh,.zlogin}
rm -rf /etc/initcpio

echo "Type blackarch-install and follow the instructions." > /root/INSTALL
rm -rf /root/install.txt


fc-cache -f >/dev/null 2>&1 || true

echo 'ArchangelOS' > /etc/arch-release

