#!/bin/bash
set -euo pipefail

# Export QCOW2 to .utm bundle for macOS UTM
# Usage: export-utm.sh <qcow2-path> [output-dir]

QCOW2_PATH="${1:?Usage: export-utm.sh <qcow2-path> [output-dir]}"
OUTPUT_DIR="${2:-$(pwd)}"
VM_NAME="DeepCyber-VM"
UTM_BUNDLE="$OUTPUT_DIR/$VM_NAME.utm"

echo "Creating UTM bundle: $UTM_BUNDLE"

# Clean any previous bundle
rm -rf "$UTM_BUNDLE"
mkdir -p "$UTM_BUNDLE/Data"

# Copy the QCOW2 disk image into the bundle
echo "  Copying disk image..."
cp "$QCOW2_PATH" "$UTM_BUNDLE/Data/deepcyber-vm.qcow2"

# Generate config.plist for UTM (aarch64, virtio, shared networking)
cat > "$UTM_BUNDLE/config.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ConfigurationVersion</key>
  <integer>4</integer>
  <key>Name</key>
  <string>DeepCyber VM</string>
  <key>Notes</key>
  <string>DeepCyber AI Red Team Toolkit VM - Kali Linux ARM64 with XFCE</string>
  <key>Backend</key>
  <string>Apple</string>
  <key>System</key>
  <dict>
    <key>Architecture</key>
    <string>aarch64</string>
    <key>CPU</key>
    <dict>
      <key>Count</key>
      <integer>2</integer>
    </dict>
    <key>MemorySize</key>
    <integer>4096</integer>
  </dict>
  <key>Drives</key>
  <array>
    <dict>
      <key>ImageName</key>
      <string>deepcyber-vm.qcow2</string>
      <key>ImageType</key>
      <string>Disk</string>
      <key>Interface</key>
      <string>VirtIO</string>
    </dict>
  </array>
  <key>Display</key>
  <dict>
    <key>ConsoleOnly</key>
    <false/>
    <key>UpscalerEnabled</key>
    <true/>
  </dict>
  <key>Input</key>
  <dict>
    <key>Sharing</key>
    <true/>
  </dict>
  <key>Network</key>
  <array>
    <dict>
      <key>Mode</key>
      <string>Shared</string>
    </dict>
  </array>
  <key>Sound</key>
  <dict>
    <key>Enabled</key>
    <false/>
  </dict>
  <key>Sharing</key>
  <dict>
    <key>ClipboardSharing</key>
    <true/>
    <key>DirectorySharing</key>
    <false/>
  </dict>
</dict>
</plist>
PLIST

# Calculate disk image size for display
DISK_SIZE=$(du -sh "$UTM_BUNDLE/Data/deepcyber-vm.qcow2" | cut -f1)

echo ""
echo "UTM bundle created: $UTM_BUNDLE"
echo "  Disk size: $DISK_SIZE"
echo ""
echo "Double-click $VM_NAME.utm to open in UTM on macOS."
echo ""
echo "Note: If UTM does not recognise this config.plist format,"
echo "import the QCOW2 manually: UTM > Create VM > Emulate > Linux"
echo "and point to $UTM_BUNDLE/Data/deepcyber-vm.qcow2"
