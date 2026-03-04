# DeepCyber AI Red Team Toolkit — Roadmap

## Phase 1: Container Toolkit (Current)

Containerised toolkit packaging open-source AI red teaming, guardrail testing, evaluation, and ML security tools into a single reproducible linux/arm64 environment.

**Status:** Complete

### Tools Shipped

- HumanBound, Promptfoo, Garak, PyRIT, DeepTeam, TextAttack
- LLM Guard, NeMo Guardrails, Guardrails AI
- Giskard, Giskard RAGET, Inspect AI, DeepEval
- ModelScan, ART, FAISS, AIF360
- JupyterLab

---

## Phase 1.5: Agentic AI Security Tooling

Extend the container with tools purpose-built for securing agentic AI workflows, MCP servers, and multi-agent systems.

### Agentic Workflow Scanning

| Tool | Source | Purpose |
|------|--------|---------|
| [Agentic Radar](https://github.com/splx-ai/agentic-radar) | SplxAI | Static analysis of agentic workflows — maps dependencies, identifies tools, detects MCP servers, flags missing security controls |
| [Invariant Analyzer](https://github.com/invariantlabs-ai/invariant) | Invariant Labs | Policy-based security analysis for AI agents — define security rules and verify agent traces |

### MCP Security Scanning

| Tool | Source | Purpose |
|------|--------|---------|
| [MCP Scan](https://github.com/invariantlabs-ai/mcp-scan) | Invariant Labs | Scans MCP server configurations for prompt injection, tool poisoning, and cross-origin escalation |
| [Proximity](https://github.com/nickcdryan/proximity) | Open source | Enumerates MCP server prompts, tools, and resources — evaluates security risks |
| [Agent Scan](https://github.com/snyk/agent-scan) | Snyk | Inventories installed agent components and scans for prompt injections and malware |

### Agent Behaviour and Detection

| Tool | Source | Purpose |
|------|--------|---------|
| [OpenClaw Scanner](https://github.com/openclaw/openclaw-scanner) | Open source | Detects autonomous AI agents operating without centralised oversight |
| [CAI](https://github.com/aliasrobotics/cai) | Alias Robotics | Cybersecurity AI framework — stitch together LLMs with security tools for agentic pentesting |

---

## Phase 2: DeepCyber VM

Transition from a container toolkit to a full virtual machine appliance with DeepCyber branding, documentation, and an integrated desktop environment.

### VM Foundation

- Base OS: Kali Linux minimal/netinstall ARM64 with XFCE (Standard) or MATE (Founder's Edition)
- Default user: `deepcyber` with passwordless sudo
- Automated build pipeline: Packer + Ansible
- Export formats: .utm (macOS), .ova (VMware/VirtualBox/Proxmox)

### DeepCyber Branding

- Custom Plymouth boot splash and LightDM login screen
- DeepCyber desktop wallpapers and theme
- Branded terminal prompt and MOTD banner
- Application menu organised by tool category

### Documentation Portal

- Built-in MkDocs Material documentation site
- Tool-by-tool guides with worked examples
- Project methodology walkthroughs
- OWASP Top 10 for LLMs mapping
- Accessible at `http://localhost/docs` on the VM

### Integrated Tooling

- All Phase 1 tools pre-installed natively
- Traditional security tools (Metasploit, Burp Suite, ZAP, Hydra, Medusa, John, Hashcat)
- AI red team assistant (Claude Code, Gemini CLI, Codex CLI)
- Pre-configured Jupyter notebooks

---

## Phase 3: DeepCyber Platform

Evolve the VM into a multi-user platform with collaboration, CI/CD integration, and continuous AI security monitoring.

### Multi-User and Collaboration

- Web-based UI for managing projects
- Role-based access (lead, tester, reviewer, client)
- Shared findings database with tagging and search
- Real-time collaboration on project notes

### CI/CD and Automation

- GitHub Actions / GitLab CI integration
- Scan-on-commit for AI applications
- Policy-as-code for AI security gates
- Scheduled recurring scans and alerting

### Continuous Monitoring

- Live agent behaviour monitoring
- MCP server drift detection
- Guardrail bypass alerting
- Model output anomaly detection

### Reporting and Compliance

- Executive summary generation
- OWASP Top 10 for LLMs compliance scorecard
- NIST AI RMF mapping reports
- EU AI Act risk assessment templates
- Client-ready PDF/HTML report export

---

## Phase 4: Deepfake Detection

Add deepfake detection capabilities for image, video, and audio — enabling red teams to assess synthetic media risks and verify content authenticity.

### Detection Platforms

| Tool | Source | Purpose |
|------|--------|---------|
| [DeepSafe](https://github.com/siddharthksah/DeepSafe) | Open source | Modular ensemble deepfake detection platform |
| [DeepFake-o-Meter v2.0](https://github.com/AaronComo/DeepFake-o-meter) | Open source | 18+ detection models across image, video, and audio |
| [DeepfakeDetector](https://github.com/TRahulsingh/DeepfakeDetector) | Open source | PyTorch + EfficientNet-B0 real-time detection |

### Face, Audio, and Content Authenticity

| Tool | Source | Purpose |
|------|--------|---------|
| [DeepFace](https://github.com/serengil/deepface) | Open source | Face recognition and analysis framework |
| [FaceForensics++](https://github.com/ondyari/FaceForensics) | TU Munich | Face manipulation detection benchmark |
| [ASVspoof](https://www.asvspoof.org/) | Community | Spoofed and deepfake speech detection |
| [Resemblyzer](https://github.com/resemble-ai/Resemblyzer) | Resemble AI | Speaker verification and cloned voice detection |
| [C2PA](https://github.com/contentauth/c2patool) | CAI | Content provenance and authenticity verification |

---

## Versioning

| Phase | Version | Target |
|-------|---------|--------|
| Phase 1 | 1.0 | Container toolkit (shipped) |
| Phase 1.5 | 1.5 | Agentic AI tooling |
| Phase 2 | 2.0 | DeepCyber VM |
| Phase 3 | 3.0 | DeepCyber Platform |
| Phase 4 | 4.0 | Deepfake Detection |
