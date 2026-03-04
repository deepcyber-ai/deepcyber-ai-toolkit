# DeepCyber VM — Packer Variable Defaults
#
# Update iso_url and iso_checksum when a new Kali release is available.
# Find ISOs at: https://www.kali.org/get-kali/#kali-installer-images
#
# To verify checksum:
#   curl -sL https://cdimage.kali.org/kali-2025.4/SHA256SUMS | grep netinst-arm64

iso_url      = "https://cdimage.kali.org/kali-2025.4/kali-linux-2025.4-installer-netinst-arm64.iso"
iso_checksum = "sha256:bd85a8e8230e52cb4a0a7600d433220f7b630d306377b7c7e81ded65acfe2808"

disk_size = "40G"
memory    = 4096
cpus      = 2
headless  = true

# EFI firmware — macOS Homebrew defaults (override for Linux hosts)
# efi_firmware_code = "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
# efi_firmware_vars = "/usr/share/qemu-efi-aarch64/vars-template-pflash.raw"
