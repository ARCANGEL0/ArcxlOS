#!/usr/bin/env bash

iso_name="archangelos-netinst"
iso_label="ARCHANGELOS_NET_$(date +%Y%m)"
iso_publisher="ArchangelOS <https://arcangelo.net>"
iso_application="ArchangelOS NetInstall"
iso_version="${ARCHANGELOS_VERSION:-$(date +%Y.%m.%d)}"
install_dir="blackarch"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
file_permissions=(
  ["/usr/bin/onionchat"]="0:0:0755"
  ["/usr/bin/archangelos-fastfetch-setup"]="0:0:0755"
  ["/usr/bin/archangelos-wallpaper-setup"]="0:0:0755"
  ["/usr/bin/archangelos-lock"]="0:0:0755"
  ["/usr/bin/archangelos-settings"]="0:0:0755"
  ["/usr/bin/archangelos-shell"]="0:0:0755"
  ["/usr/lib/archangelos/ghostwired"]="0:0:0755"
  ["/usr/lib/archangelos/ghostwired-exempt"]="0:0:0755"
  ["/usr/lib/archangelos/axs-admin"]="0:0:0755"
  ["/usr/lib/archangelos/power-mode"]="0:0:0755"
  ["/usr/bin/archangelos-welcome"]="0:0:0755"
  ["/usr/bin/archangelos-launcher"]="0:0:0755"
  ["/usr/bin/arcfetch"]="0:0:0755"
  ["/usr/bin/archangelos-launcher-toggle"]="0:0:0755"
  ["/usr/bin/archangelos-redops-tools"]="0:0:0755"
  ["/usr/bin/archangelos-install-tool"]="0:0:0755"
)
