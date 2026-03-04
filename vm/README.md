# DeepCyber VM Build System

Automated build pipeline for the DeepCyber AI Red Team VM appliance.

Produces a Kali Linux ARM64 minimal VM with all Phase 1 tools installed
natively, traditional pentesting tools, AI assistant CLIs, and DeepCyber
branding.

## Editions

| Edition | Desktop | Build target |
|---------|---------|-------------|
| **Standard** | XFCE 4 | `make build-xfce` (default) |
| **Founder's Edition** | MATE | `make build-mate` |

Both editions include identical tooling. The Founder's Edition uses the MATE
desktop environment with custom DeepCyber branding.

## Prerequisites

### macOS (Apple Silicon)

```bash
brew install packer qemu ansible
packer plugins install github.com/hashicorp/qemu
packer plugins install github.com/hashicorp/ansible
```

### Kali ISO

Download the Kali Linux ARM64 netinst ISO and update `vm/packer/variables.pkrvars.hcl`
with the URL and SHA256 checksum. Default points to Kali 2025.4.

## Build

```bash
cd vm

# Standard Edition (XFCE)
make build                 # or: make build-xfce

# Founder's Edition (MATE)
make build-mate

# Export to UTM bundle (macOS — double-click to launch)
make DESKTOP=xfce export-utm
make DESKTOP=mate export-utm

# Export to OVA (VMware, VirtualBox, Proxmox)
make DESKTOP=xfce export-ova
make DESKTOP=mate export-ova

# Run automated validation tests
make DESKTOP=xfce test
make DESKTOP=mate test

# Clean all build outputs
make clean
```

## What Gets Installed

### AI Red Teaming & Evaluation (Phase 1)

HumanBound, Promptfoo, Garak, PyRIT, DeepTeam, TextAttack, LLM Guard,
NeMo Guardrails, Guardrails AI, Giskard, Inspect AI, DeepEval, ModelScan,
ART, AIF360, FAISS, JupyterLab

### Security Tools

Burp Suite Community, OWASP ZAP, Metasploit Framework, THC Hydra, Medusa,
John the Ripper, Hashcat

### AI Red Team Assistant

Claude Code, Gemini CLI, OpenAI Codex — pre-configured with DeepCyber
instructions. Run `dcr ai setup` to add API keys, then `dcr ai` to launch.

## VM Details

| Property | Value |
|----------|-------|
| Base OS | Kali Linux ARM64 minimal (kali-rolling) |
| Desktop | XFCE 4 (Standard) or MATE (Founder's Edition) |
| User | `deepcyber` (passwordless sudo) |
| Disk | 40 GB (virtio, QCOW2) |
| RAM | 4 GB (configurable) |
| CPUs | 2 (configurable) |

## Directory Layout (inside VM)

```
/home/deepcyber/
├── bin/dcr              # DeepCyber CLI
├── lib/redteam/         # Tool integration library
├── configs/             # Tool configuration templates
├── scripts/             # Utility scripts
├── projects/
│   ├── template/        # Copy to start a new project
│   └── examples/        # Example project configs
├── docs/                # AI assistant instructions
└── results/             # Scan output directory
```

## Customisation

### Packer Variables

Override defaults in `packer/variables.pkrvars.hcl` or pass on the command line:

```bash
cd vm/packer
packer build -var "memory=8192" -var "cpus=4" -var "desktop=mate" deepcyber-vm.pkr.hcl
```

### Ansible-Only Provisioning

To re-run Ansible against an already-built VM (via SSH):

```bash
cd vm/ansible

# Standard (XFCE)
ansible-playbook -i "VM_IP," playbook.yml -u deepcyber --become

# Founder's Edition (MATE)
ansible-playbook -i "VM_IP," playbook.yml -u deepcyber --become \
  --extra-vars "desktop_environment=mate"
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
