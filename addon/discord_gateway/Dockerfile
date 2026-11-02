# Made By FALCREB
ARG BUILD_FROM
FROM $BUILD_FROM

# Sürümler ve resmi release'lerden doğrulanmış SHA256 değerleri
ARG BYEDPI_URL=https://github.com/hufrea/byedpi/releases/download/v0.17.3/byedpi-17.3-aarch64.tar.gz
ARG BYEDPI_SHA256=d5806504e159e8119ede5af1164a609251b0520cd4483a7db611b6d238b9404b
ARG GOST_URL=https://github.com/go-gost/gost/releases/download/v3.3.2/gost_3.3.2_linux_arm64.tar.gz
ARG GOST_SHA256=10cabc396eb644de1104fd695759444d2a8bf7b83463a8ab8f96174041e5bd18

RUN set -eux; \
    mkdir -p /tmp/dl; cd /tmp/dl; \
    curl -fsSL -o byedpi.tgz "$BYEDPI_URL"; \
    echo "$BYEDPI_SHA256  byedpi.tgz" | sha256sum -c -; \
    tar xzf byedpi.tgz; \
    install -m 755 ciadpi-aarch64 /usr/local/bin/ciadpi; \
    curl -fsSL -o gost.tgz "$GOST_URL"; \
    echo "$GOST_SHA256  gost.tgz" | sha256sum -c -; \
    tar xzf gost.tgz gost; \
    install -m 755 gost /usr/local/bin/gost; \
    cd /; rm -rf /tmp/dl

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
