FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git tar gzip jq unzip xz-utils zip gnupg rsync xvfb \
    build-essential pkg-config libatomic1 \
    libglib2.0-0t64 libnss3 libnspr4 libdbus-1-3 libatk1.0-0t64 libatk-bridge2.0-0t64 \
    libcups2t64 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libgbm1 libpango-1.0-0 libcairo2 libasound2t64 libatspi2.0-0t64 libx11-6 libxcb1 libxext6 \
    && rm -rf /var/lib/apt/lists/*
# static docker CLI so jobs can use the host docker daemon via the mounted socket
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz \
    | tar -xz --strip-components=1 -C /usr/local/bin docker/docker \
    && chmod +x /usr/local/bin/docker
RUN useradd -m -u 1000 runner && mkdir -p /data && chown runner:runner /data
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER runner
WORKDIR /data
ENTRYPOINT ["/entrypoint.sh"]
