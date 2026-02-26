ARG S6_OVERLAY_VERSION=3.2.2.0

FROM alpine

ARG S6_OVERLAY_VERSION

RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash curl privoxy shadow tor tzdata wget xz &&\
    arch="$(apk --print-arch)" && \
    wget -qO /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
    wget -qO /tmp/s6-overlay-arch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${arch}.tar.xz" && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz && \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-arch.tar.xz && \
    cp /etc/privoxy/default.filter.new /etc/privoxy/default.filter && \
    cp /etc/privoxy/user.filter.new /etc/privoxy/user.filter && \
    cp /etc/privoxy/default.action.new /etc/privoxy/default.action && \
    cp /etc/privoxy/user.action.new /etc/privoxy/user.action && \
    cp /etc/privoxy/match-all.action.new /etc/privoxy/match-all.action && \
    chown -R privoxy:privoxy /etc/privoxy && \
    mkdir -p /etc/tor/run && \
    chown -Rh tor /var/lib/tor /etc/tor/run && \
    chmod 0750 /etc/tor/run && \
    rm -rf /tmp/*

COPY torproxy.sh /usr/bin/
COPY rootfs/ /

RUN chmod +x /usr/bin/torproxy.sh \
    /etc/s6-overlay/s6-rc.d/torproxy-config/up \
    /etc/s6-overlay/s6-rc.d/tor/run \
    /etc/s6-overlay/s6-rc.d/privoxy/run

EXPOSE 8118 9050

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
            CMD curl -sx localhost:8118 'https://check.torproject.org/' | \
            grep -qm1 Congratulations

# VOLUME ["/etc/tor", "/var/lib/tor"]

ENTRYPOINT ["/init"]
