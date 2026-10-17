#!/usr/bin/env bash

iso_name="archangelos-gaming"
iso_label="ARCHANGELOS_GAMING_$(date +%Y%m)"
iso_publisher="ArchangelOS <https://arcangelo.net>"
iso_application="ArchangelOS Gaming Edition"
iso_version="${ARCHANGELOS_VERSION:-$(date +%Y.%m.%d)}"
install_dir="archangelos"
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"

airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M' '-processors' '4')

file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/sudoers.d"]="0:0:0750"
  ["/etc/sudoers.d/wheel"]="0:0:0440"
  ["/etc/polkit-1/rules.d"]="102:102:0750"
  ["/etc/polkit-1/rules.d/49-nopasswd_global.rules"]="102:102:0640"
  ["/root"]="0:0:0700"
  ["/root/customize_airootfs.sh"]="0:0:0755"
  ["/usr/bin/archangelos-installer"]="0:0:0755"
  ["/usr/bin/archangelos-gui-installer"]="0:0:0755"
  ["/usr/bin/archangelos-set-wallpaper"]="0:0:0755"
  ["/usr/bin/archangelos-wallpaper"]="0:0:0755"
  ["/usr/bin/archangelos-wallpaper-setup"]="0:0:0755"
  ["/usr/bin/archangelos-lock"]="0:0:0755"
  ["/usr/bin/archangelos-welcome"]="0:0:0755"
  ["/usr/bin/archangelos-launcher"]="0:0:0755"
  ["/usr/bin/arcfetch"]="0:0:0755"
  ["/usr/bin/cyberspace"]="0:0:0755"
  ["/usr/bin/archangelos-launcher-toggle"]="0:0:0755"
  ["/usr/bin/archangelos-redops-tools"]="0:0:0755"
  ["/usr/bin/archangelos-install-tool"]="0:0:0755"
  ["/usr/bin/onionchat"]="0:0:0755"
  ["/usr/bin/archangelos-fastfetch-setup"]="0:0:0755"
  ["/usr/bin/archangelos-hyper-dl"]="0:0:0755"
  ["/usr/bin/archangelos-dl"]="0:0:0755"
  ["/usr/bin/archangelos-hyperdl.sh"]="0:0:0755"
  ["/usr/bin/archangelos-hyperdl"]="0:0:0755"
  ["/usr/bin/archangelos-demo.sh"]="0:0:0755"
)

