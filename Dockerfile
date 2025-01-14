FROM simplefs/switch-base:1.10.12 AS base

RUN apt update && apt install -y iproute2 curl

COPY bin /tmp/bin
COPY conf /tmp/conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /tmp/bin/*

ENV DB_HOST=""
ENV DB_PORT=5432
ENV DB_USER=""
ENV DB_PASS=""
ENV DB_NAME="switch"
ENV DB_OPTS=""

ENTRYPOINT ["/entrypoint.sh"]

# CMD ["tail", "-f", "/dev/null"]