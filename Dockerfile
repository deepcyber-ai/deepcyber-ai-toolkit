FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    ca-certificates \
    nodejs \
    npm \
    cargo \
    rustc \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g promptfoo

RUN pip install --no-cache-dir \
    garak==0.14.0 \
    pyrit==0.11.0 \
    inspect-ai==0.3.184 \
    modelscan==0.8.8 \
    faiss-cpu==1.13.2 \
    adversarial-robustness-toolbox==1.20.1 \
    aif360==0.6.1 \
    jupyterlab==4.5.5 \
    humanbound-cli==0.5.0

RUN pip install --no-cache-dir "scipy<1.14" "giskard[llm]==2.19.1"

RUN pip install --no-cache-dir \
    deepteam==1.0.5 \
    llm-guard==0.3.16 \
    nemoguardrails==0.20.0 \
    deepeval==3.8.8 \
    guardrails-ai==0.9.1 \
    textattack==0.3.10

RUN useradd -m -s /bin/bash deepcyber

COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY configs/ /home/deepcyber/configs/
COPY scripts/ /home/deepcyber/scripts/
RUN chmod +x /home/deepcyber/scripts/*.sh

COPY samples/ /home/deepcyber/samples/

RUN mkdir -p /home/deepcyber/results && \
    chown -R deepcyber:deepcyber /home/deepcyber

USER deepcyber
WORKDIR /home/deepcyber

ENTRYPOINT ["/start.sh"]
