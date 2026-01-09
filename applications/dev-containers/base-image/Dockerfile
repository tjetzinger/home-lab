# Dev Container Base Image
# Ubuntu 22.04 with Node.js, Python, Claude Code CLI, and DevOps tools
# FR67: Single base image with all required tools

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base utilities and SSH server
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    git \
    vim \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    locales \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Node.js 20.x via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11 with pip
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl (latest stable)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm 3
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user 'dev' with sudo privileges
RUN useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# Configure SSH
RUN mkdir /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create .ssh directory for dev user
RUN mkdir -p /home/dev/.ssh \
    && chmod 700 /home/dev/.ssh \
    && chown -R dev:dev /home/dev/.ssh

# Create workspace directory
RUN mkdir -p /home/dev/workspace \
    && chown -R dev:dev /home/dev/workspace

# Set working directory
WORKDIR /home/dev/workspace

# Expose SSH port
EXPOSE 22

# Start SSH server in foreground
CMD ["/usr/sbin/sshd", "-D"]
