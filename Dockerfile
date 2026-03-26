FROM debian:bookworm-slim

ARG FACTORIO_VERSION
ENV FACTORIO_VERSION=${FACTORIO_VERSION:-2.0.76}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        xz-utils \
        ffmpeg \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Install mcrcon for RCON communication
RUN curl -fsSL https://github.com/Tiiffi/mcrcon/releases/download/v0.7.2/mcrcon-0.7.2-linux-x86-64.tar.gz \
    | tar -xz -C /usr/local/bin/ mcrcon \
    && chmod +x /usr/local/bin/mcrcon

# Download and install Factorio headless server
RUN curl -fsSL -o /tmp/factorio.tar.xz \
        "https://factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" \
    && tar -xJf /tmp/factorio.tar.xz -C /opt \
    && rm /tmp/factorio.tar.xz

# Create factorio user and directories
RUN useradd -r -m -d /factorio factorio \
    && mkdir -p /factorio/saves /factorio/config /factorio/mods \
    && chown -R factorio:factorio /factorio

COPY scripts/ /opt/factorio/scripts/
RUN chmod +x /opt/factorio/scripts/*.sh

# Store mods separately (not in factorio's auto-scan path)
# entrypoint.sh copies them to /factorio/mods/ only when SERVER_MODE=modded
COPY mods/ /opt/dockerio-mods/

EXPOSE 34197/udp 27015/tcp

VOLUME ["/factorio/saves", "/factorio/config"]

ENTRYPOINT ["/opt/factorio/scripts/entrypoint.sh"]
