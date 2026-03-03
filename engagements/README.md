# Engagements

This folder contains everything needed to run red team assessments against conversational AI APIs.

## Structure

```
engagements/
├── GUIDE.md              # Step-by-step engagement cheatsheet
├── README.md             # This file
├── template/             # Copy this for each new engagement
│   ├── target.yaml       # THE config file — edit this
│   ├── .env.example      # Credential template
│   ├── shared/           # Config loader + auth (don't edit)
│   ├── humanbound/       # HumanBound CLI integration
│   ├── promptfoo/        # Promptfoo red team
│   ├── garak/            # Garak probe scanner
│   ├── pyrit/            # PyRIT adversarial framework
│   ├── giskard/          # Giskard vulnerability scan
│   └── deepcyber/        # Container launcher
└── examples/             # Example target.yaml files
    ├── foodie-ai.yaml    # Cognito JWT auth, simple body
    ├── openai-compatible.yaml  # Bearer token, messages array
    └── api-key-simple.yaml     # Static API key, flat body
```

## Starting a New Engagement

```bash
cp -r engagements/template engagements/acme-chatbot
cd engagements/acme-chatbot
vim target.yaml     # fill in API details (see examples/ for patterns)
cp .env.example .env && vim .env
python shared/auth.py   # verify it works
```

See [GUIDE.md](GUIDE.md) for the full walkthrough.

---

Copyright Deep Cyber Ltd 2026
