# Projects

This folder contains everything needed to run red team assessments against conversational AI APIs.

## Structure

```
projects/
├── GUIDE.md              # Step-by-step project guide
├── README.md             # This file
├── template/             # Copy this for each new project
│   ├── target.yaml       # THE config file — edit this
│   ├── .env.example      # Credential template
│   ├── policies/         # External policy documents (optional)
│   └── pyrit/            # PyRIT scripts (editable per project)
└── examples/             # Example target.yaml files
    ├── foodie-ai.yaml    # Cognito JWT auth, simple body
    ├── openai-compatible.yaml  # Bearer token, messages array
    └── api-key-simple.yaml     # Static API key, flat body
```

## Starting a New Project

```bash
cp -r projects/template projects/acme-chatbot
cd projects/acme-chatbot
vim target.yaml     # fill in API details (see examples/ for patterns)
cp .env.example .env && vim .env
dcr auth            # verify it works
```

See [GUIDE.md](GUIDE.md) for the full walkthrough.

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
