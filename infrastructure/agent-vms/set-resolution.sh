#!/bin/bash
# Pin the VM desktop resolution (RDP desktop sharing mirrors it). Run as tt over SSH, then reboot the VM.
# Needs the VM display on virtio (qm set <vmid> --vga virtio): the cloud-image kernel has no bochs driver,
# so the default display is stuck at the 1280x800 UEFI framebuffer.
set -euo pipefail
width=${1:-1920}
height=${2:-1200}
rate=${3:-59.885}
mkdir -p ~/.config
cat > ~/.config/monitors.xml <<XML
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>Virtual-1</connector>
          <vendor>RHT</vendor>
          <product>QEMU Monitor</product>
          <serial>0x00000000</serial>
        </monitorspec>
        <mode>
          <width>${width}</width>
          <height>${height}</height>
          <rate>${rate}</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
XML
echo "wrote ~/.config/monitors.xml: ${width}x${height}@${rate}"
