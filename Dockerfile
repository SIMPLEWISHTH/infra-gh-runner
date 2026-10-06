FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git tar gzip jq libicu72 libssl3 unzip xz-utils \
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
