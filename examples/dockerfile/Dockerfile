# Platform: Dockerfile
# Purpose: Intentionally insecure image build to demonstrate FCS CLI IaC
#          detections. DO NOT BUILD/PUBLISH.

# Unpinned base image using :latest
# Category: Supply-Chain
FROM ubuntu:latest

# Secrets baked into image layers and ENV
# Category: Secret Management
ENV AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
ENV AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
ENV DB_PASSWORD=SuperSecretP@ssw0rd123
ARG GITHUB_TOKEN=ghp_000000000000000000000000000000000000

# apt-get without version pinning and without cleaning lists
# Categories: Supply-Chain, Best Practices
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    sudo \
    openssh-server \
    telnet

# Piping remote content straight into a shell
# Category: Insecure Configurations
RUN curl -sSL http://example.com/install.sh | bash

# Disabling TLS verification on downloads
# Category: Encryption
RUN wget --no-check-certificate https://example.com/package.tar.gz -O /tmp/package.tar.gz
RUN curl -k https://example.com/other.tar.gz -o /tmp/other.tar.gz

# ADD with a remote URL instead of COPY
# Category: Best Practices
ADD http://example.com/app.tar.gz /opt/app/

# World-writable permissions
# Category: Access Control
RUN chmod 777 /opt/app

# Passwordless sudo for all users
# Category: Access Control
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Exposing SSH
# Category: Networking and Firewall
EXPOSE 22
EXPOSE 80

# No HEALTHCHECK instruction
# Category: Observability

# Container runs as root (no USER directive switching away from root)
# Category: Access Control
USER root

# Shell form of CMD, root process
# Category: Best Practices
CMD /opt/app/start.sh
