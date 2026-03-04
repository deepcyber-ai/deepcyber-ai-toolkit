#!/bin/bash
set -euo pipefail

# Export QCOW2 to OVA (VMware, VirtualBox, Proxmox compatible)
# Usage: export-ova.sh <qcow2-path> [output-dir]

QCOW2_PATH="${1:?Usage: export-ova.sh <qcow2-path> [output-dir]}"
OUTPUT_DIR="${2:-$(pwd)}"
VM_NAME="deepcyber-vm"

echo "Creating OVA: $OUTPUT_DIR/$VM_NAME.ova"

# Check for qemu-img
if ! command -v qemu-img &>/dev/null; then
    echo "Error: qemu-img not found. Install QEMU: brew install qemu"
    exit 1
fi

# Convert QCOW2 to VMDK (stream-optimised for OVA)
echo "  Converting QCOW2 to VMDK..."
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized \
    "$QCOW2_PATH" "$OUTPUT_DIR/$VM_NAME.vmdk"

VMDK_SIZE=$(stat -f%z "$OUTPUT_DIR/$VM_NAME.vmdk" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$VM_NAME.vmdk")

# Generate OVF descriptor
echo "  Generating OVF descriptor..."
cat > "$OUTPUT_DIR/$VM_NAME.ovf" << OVF
<?xml version="1.0" encoding="UTF-8"?>
<Envelope xmlns="http://schemas.dmtf.org/ovf/envelope/1"
          xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common"
          xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
          xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"
          xmlns:vmw="http://www.vmware.com/schema/ovf"
          xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData">
  <References>
    <File ovf:href="$VM_NAME.vmdk" ovf:id="file1" ovf:size="$VMDK_SIZE"/>
  </References>
  <DiskSection>
    <Info>Virtual disk information</Info>
    <Disk ovf:capacity="42949672960" ovf:diskId="vmdisk1" ovf:fileRef="file1"
          ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized"/>
  </DiskSection>
  <NetworkSection>
    <Info>Virtual network</Info>
    <Network ovf:name="NAT">
      <Description>NAT network</Description>
    </Network>
  </NetworkSection>
  <VirtualSystem ovf:id="$VM_NAME">
    <Info>DeepCyber AI Red Team Toolkit VM</Info>
    <Name>DeepCyber VM</Name>
    <OperatingSystemSection ovf:id="101">
      <Info>Debian 12 64-bit ARM</Info>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Virtual hardware requirements</Info>
      <System>
        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <vssd:VirtualSystemIdentifier>$VM_NAME</vssd:VirtualSystemIdentifier>
        <vssd:VirtualSystemType>vmx-21</vssd:VirtualSystemType>
      </System>
      <Item>
        <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
        <rasd:Description>Number of Virtual CPUs</rasd:Description>
        <rasd:ElementName>2 virtual CPU(s)</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>2</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
        <rasd:Description>Memory Size</rasd:Description>
        <rasd:ElementName>4096MB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>4096</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:ElementName>Hard Disk 1</rasd:ElementName>
        <rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceType>17</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>NAT</rasd:Connection>
        <rasd:ElementName>Network adapter 1</rasd:ElementName>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
    </VirtualHardwareSection>
  </VirtualSystem>
</Envelope>
OVF

# Generate manifest with SHA256 checksums
echo "  Generating manifest..."
cd "$OUTPUT_DIR"
sha256sum "$VM_NAME.ovf" "$VM_NAME.vmdk" > "$VM_NAME.mf" 2>/dev/null || \
    shasum -a 256 "$VM_NAME.ovf" "$VM_NAME.vmdk" > "$VM_NAME.mf"

# Package as OVA (TAR with specific file order: OVF first)
echo "  Packaging OVA..."
tar -cf "$VM_NAME.ova" "$VM_NAME.ovf" "$VM_NAME.vmdk" "$VM_NAME.mf"

# Clean up intermediate files
rm -f "$VM_NAME.vmdk" "$VM_NAME.ovf" "$VM_NAME.mf"

OVA_SIZE=$(du -sh "$VM_NAME.ova" | cut -f1)
echo ""
echo "OVA created: $OUTPUT_DIR/$VM_NAME.ova ($OVA_SIZE)"
echo ""
echo "Import with: VMware, VirtualBox, or Proxmox"
