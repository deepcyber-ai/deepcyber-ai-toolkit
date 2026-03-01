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
| [Agentic Radar](https://github.com/splx-ai/agentic-radar) | SplxAI | Static analysis of agentic workflows — maps dependencies, identifies tools, detects MCP servers, flags missing security controls. Supports LangGraph, CrewAI, N8N, OpenAI Agents, AutoGen. |
| [Invariant Analyzer](https://github.com/invariantlabs-ai/invariant) | Invariant Labs | Policy-based security analysis for AI agents — define security rules and verify agent traces against them. |

### MCP Security Scanning

| Tool | Source | Purpose |
|------|--------|---------|
| [MCP Scan](https://github.com/invariantlabs-ai/mcp-scan) | Invariant Labs | Scans MCP server configurations for prompt injection, tool poisoning, and cross-origin escalation. |
| [Proximity](https://github.com/nickcdryan/proximity) | Open source | Enumerates MCP server prompts, tools, and resources — evaluates how each element could introduce security risks. |
| [Agent Scan](https://github.com/snyk/agent-scan) | Snyk | Inventories installed agent components (harnesses, MCP servers, skills) and scans for prompt injections, sensitive data handling, and malware payloads. |

### Agent Behaviour and Detection

| Tool | Source | Purpose |
|------|--------|---------|
| [OpenClaw Scanner](https://github.com/openclaw/openclaw-scanner) | Open source | Detects autonomous AI agents operating without centralised oversight on internal systems. |
| [CAI](https://github.com/aliasrobotics/cai) | Alias Robotics | Cybersecurity AI framework — stitch together LLMs with security tools (Nmap, Burp, etc.) to build custom agentic pentest workflows. |

### Deliverables

- [ ] Add Agentic Radar to container
- [ ] Add MCP Scan to container
- [ ] Add Proximity to container
- [ ] Add Agent Scan to container
- [ ] Create sample agentic workflow scanning configs
- [ ] Add MCP security scanning to deepcyber-scan.sh
- [ ] Document agentic security testing playbook

---

## Phase 2: DeepCyber VM

Transition from a container toolkit to a full virtual machine appliance with DeepCyber branding, documentation, and an integrated desktop environment.

### VM Foundation

- [ ] Base OS: Debian 12 or Ubuntu 24.04 LTS (arm64)
- [ ] Lightweight desktop environment (XFCE or LXQt)
- [ ] OVA/QCOW2 export for VMware, VirtualBox, UTM, Proxmox
- [ ] Automated build pipeline (Packer + Ansible)
- [ ] Reproducible, versioned builds

### DeepCyber Branding

- [ ] Custom boot splash and login screen
- [ ] DeepCyber desktop wallpaper and theme
- [ ] Branded terminal prompt and MOTD banner
- [ ] Application menu organised by tool category
- [ ] DeepCyber favicon and icons for web UIs

### Documentation Portal

- [ ] Built-in documentation site (MkDocs or mdBook)
- [ ] Tool-by-tool guides with worked examples
- [ ] Engagement methodology walkthroughs
- [ ] OWASP Top 10 for LLMs mapping to toolkit capabilities
- [ ] NIST AI RMF alignment guide
- [ ] Cheat sheets for common red team scenarios
- [ ] Accessible at http://localhost on the VM

### Integrated Tooling

- [ ] All Phase 1 and Phase 1.5 tools pre-installed natively
- [ ] VS Code or Cursor with AI security extensions
- [ ] Pre-configured Jupyter notebooks with example attacks
- [ ] Report generation templates (HTML, PDF)
- [ ] Centralised results dashboard

### Engagement Workflow

- [ ] Project initialisation wizard (target model, scope, API keys)
- [ ] Guided scan runner with progress tracking
- [ ] Consolidated findings report across all tools
- [ ] Evidence collection and screenshot capture
- [ ] Export engagement bundle (findings + evidence + configs)

---

## Phase 3: DeepCyber Platform

Evolve the VM into a multi-user platform with collaboration, CI/CD integration, and continuous AI security monitoring.

### Multi-User and Collaboration

- [ ] Web-based UI for managing engagements
- [ ] Role-based access (lead, tester, reviewer, client)
- [ ] Shared findings database with tagging and search
- [ ] Real-time collaboration on engagement notes
- [ ] Audit trail for all actions

### CI/CD and Automation

- [ ] GitHub Actions / GitLab CI integration
- [ ] Scan-on-commit for AI applications
- [ ] Policy-as-code for AI security gates
- [ ] Scheduled recurring scans
- [ ] Alerting on new vulnerabilities (Slack, email, webhooks)

### Continuous Monitoring

- [ ] Live agent behaviour monitoring
- [ ] MCP server drift detection
- [ ] Guardrail bypass alerting
- [ ] Model output anomaly detection
- [ ] Dashboard with historical trends

### Reporting and Compliance

- [ ] Executive summary generation
- [ ] OWASP Top 10 for LLMs compliance scorecard
- [ ] NIST AI RMF mapping reports
- [ ] EU AI Act risk assessment templates
- [ ] Client-ready PDF/HTML report export with DeepCyber branding
- [ ] Finding severity classification (CVSS-style for AI)

### Ecosystem

- [ ] Plugin architecture for community-contributed tools
- [ ] DeepCyber marketplace for custom probes and detectors
- [ ] API for programmatic access to scan results
- [ ] Integration with SIEM/SOAR platforms
- [ ] Threat intelligence feed for emerging AI attack techniques

---

## Phase 4: Deepfake Detection

Add deepfake detection capabilities for image, video, and audio — enabling red teams to assess synthetic media risks and verify content authenticity.

### Detection Platforms

| Tool | Source | Purpose |
|------|--------|---------|
| [DeepSafe](https://github.com/siddharthksah/DeepSafe) | Open source | Modular ensemble deepfake detection platform — aggregates multiple SOTA models in isolated containers for enterprise-grade accuracy. |
| [DeepFake-o-Meter v2.0](https://github.com/AaronComo/DeepFake-o-meter) | Open source | Integrates 18+ detection models across image, video, and audio modalities. Flask-based web interface. |
| [DeepfakeDetector](https://github.com/TRahulsingh/DeepfakeDetector) | Open source | PyTorch + EfficientNet-B0 detection system with web interface for real-time image and video analysis. |

### Face and Media Analysis

| Tool | Source | Purpose |
|------|--------|---------|
| [DeepFace](https://github.com/serengil/deepface) | Open source | Face recognition and analysis framework — verification, age/gender/emotion detection, supports multiple backends (VGG-Face, FaceNet, ArcFace). |
| [FaceForensics++](https://github.com/ondyari/FaceForensics) | TU Munich | Benchmark and detection framework for face manipulation — covers FaceSwap, Face2Face, DeepFakes, NeuralTextures. |

### Audio Deepfake Detection

| Tool | Source | Purpose |
|------|--------|---------|
| [ASVspoof](https://www.asvspoof.org/) | Community | Challenge and toolkit for detecting spoofed and deepfake speech — covers text-to-speech, voice conversion, and replay attacks. |
| [Resemblyzer](https://github.com/resemble-ai/Resemblyzer) | Resemble AI | Speaker verification and voice embedding analysis — useful for detecting cloned voices. |

### Content Authenticity

| Tool | Source | Purpose |
|------|--------|---------|
| [C2PA](https://github.com/contentauth/c2patool) | Content Authenticity Initiative | Content provenance and authenticity verification — embeds and verifies tamper-evident metadata in media files. |

### Deliverables

- [ ] Integrate DeepSafe detection models
- [ ] Add DeepFake-o-Meter web interface
- [ ] Add audio deepfake detection pipeline
- [ ] Pre-trained model download and caching
- [ ] Deepfake detection notebook examples
- [ ] Content authenticity verification workflow
- [ ] Media forensics reporting templates
- [ ] GPU support (optional) for accelerated inference

---

## Versioning

| Phase | Version | Target |
|-------|---------|--------|
| Phase 1 | 1.0 | Container toolkit (shipped) |
| Phase 1.5 | 1.5 | Agentic AI tooling |
| Phase 2 | 2.0 | DeepCyber VM |
| Phase 3 | 3.0 | DeepCyber Platform |
| Phase 4 | 4.0 | Deepfake Detection |
