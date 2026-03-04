packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "iso_url" {
  type        = string
  description = "URL to the Kali Linux ARM64 netinst ISO"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the ISO (prefixed with sha256:)"
}

variable "disk_size" {
  type    = string
  default = "40G"
}

variable "memory" {
  type    = number
  default = 4096
}

variable "cpus" {
  type    = number
  default = 2
}

variable "ssh_username" {
  type    = string
  default = "deepcyber"
}

variable "ssh_password" {
  type      = string
  default   = "deepcyber"
  sensitive = true
}

variable "vm_name" {
  type    = string
  default = "deepcyber-vm"
}

variable "headless" {
  type    = bool
  default = true
}

# Desktop environment: "xfce" (default) or "mate" (Founder's Edition)
variable "desktop" {
  type    = string
  default = "xfce"
  validation {
    condition     = contains(["xfce", "mate"], var.desktop)
    error_message = "Desktop must be 'xfce' or 'mate'."
  }
}

# EFI firmware paths — defaults for macOS Homebrew QEMU.
# Override for Linux: /usr/share/qemu-efi-aarch64/QEMU_EFI.fd
variable "efi_firmware_code" {
  type    = string
  default = "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
}

variable "efi_firmware_vars" {
  type    = string
  default = "/opt/homebrew/share/qemu/edk2-arm-vars.fd"
}

# ---------------------------------------------------------------------------
# Source: QEMU ARM64
# ---------------------------------------------------------------------------

source "qemu" "deepcyber" {
  vm_name          = var.vm_name
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-${var.vm_name}"

  # ARM64 configuration
  qemu_binary  = "qemu-system-aarch64"
  machine_type = "virt"
  accelerator  = "hvf"

  # EFI firmware (required for aarch64)
  efi_firmware_code = var.efi_firmware_code
  efi_firmware_vars = var.efi_firmware_vars

  # Disk
  disk_size      = var.disk_size
  format         = "qcow2"
  disk_interface = "virtio"

  # Network
  net_device = "virtio-net"

  # Resources
  cpus   = var.cpus
  memory = var.memory

  # CDROM — use SCSI to avoid index conflict with virtio disk
  cdrom_interface = "virtio-scsi"

  # Boot — use GRUB command line to boot installer with preseed
  #
  # The Kali ARM64 netinst ISO uses GRUB2 with no timeout (menu waits
  # indefinitely). We press 'c' to enter the GRUB command line and type
  # the full linux/initrd/boot commands with our preseed URL.
  #
  # IMPORTANT: We hardcode 10.0.2.2 (QEMU user-mode networking gateway)
  # instead of {{ .HTTPIP }} because Packer resolves {{ .HTTPIP }} to
  # the host's LAN IP, which is unreachable from inside the QEMU VM.
  # The HTTP server binds to 0.0.0.0, so 10.0.2.2:port reaches it.
  boot_wait         = "30s"
  boot_key_interval = "50ms"
  boot_command      = [
    # Enter GRUB command line
    "c",
    "<wait3>",
    # Load kernel with preseed parameters (all BEFORE ---)
    "linux /install.a64/vmlinuz",
    " net.ifnames=0",
    " auto=true",
    " priority=critical",
    " url=http://10.0.2.2:{{ .HTTPPort }}/preseed-${var.desktop}.cfg",
    " locale=en_US.UTF-8",
    " keymap=us",
    " hostname=deepcyber",
    " domain=local",
    " --- quiet",
    "<enter>",
    "<wait3>",
    # Load initrd
    "initrd /install.a64/initrd.gz",
    "<enter>",
    "<wait3>",
    # Boot
    "boot",
    "<enter>"
  ]

  # HTTP server for preseed file
  http_directory = "http"

  # SSH connection (Ansible provisioner connects over this)
  ssh_username    = var.ssh_username
  ssh_password    = var.ssh_password
  ssh_timeout     = "90m"
  ssh_port        = 22
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Display
  headless = var.headless

  # QEMU arguments for aarch64
  qemuargs = [
    ["-cpu", "host"],
  ]
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  sources = ["source.qemu.deepcyber"]

  # Provision with Ansible
  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars", "ansible_become_pass=${var.ssh_password}",
      "--extra-vars", "deepcyber_user=${var.ssh_username}",
      "--extra-vars", "repo_root=${abspath("../../")}",
      "--extra-vars", "desktop_environment=${var.desktop}",
    ]
  }

  # Generate checksum for the output image
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output-${var.vm_name}/${var.vm_name}.{{.ChecksumType}}"
  }
}
