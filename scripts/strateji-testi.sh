#!/bin/sh
# ISS'nin DPI filtresinde hangi ByeDPI stratejisinin çalıştığını Pi üzerinden test eder.
# Kullanım (PC'den):  ssh <PI_SSH_HOST> 'sh -s' < scripts/strateji-testi.sh
# Sonuç: her strateji için alan adı başına 20 denemede kaç bağlantının geçtiği.
set -e

BYEDPI_URL=https://github.com/hufrea/byedpi/releases/download/v0.17.3/byedpi-17.3-aarch64.tar.gz
BYEDPI_SHA256=d5806504e159e8119ede5af1164a609251b0520cd4483a7db611b6d238b9404b
WORK=/tmp/strateji-testi
TRIES=20

rm -rf "$WORK" && mkdir -p "$WORK/dl" && cd "$WORK/dl"
curl -fsSL -o byedpi.tgz "$BYEDPI_URL"
echo "$BYEDPI_SHA256  byedpi.tgz" | sha256sum -c - >/dev/null
tar xzf byedpi.tgz
BIN="$WORK/dl/ciadpi-aarch64"

# Gerçek IP'ler DoH ile alınır (ISS DNS'i zehirli olabilir)
doh() { curl -s --max-time 5 -H 'accept: application/dns-json' \
  "https://1.1.1.1/dns-query?name=$1&type=A" | grep -o '"data":"[0-9.]*"' | head -1 | cut -d'"' -f4; }

HOSTS="discord.com gateway.discord.gg cdn.discordapp.com"
RES=""
for h in $HOSTS; do RES="$RES --resolve $h:443:$(doh $h)"; done

# Proxy olmadan referans ölçüm
LINE=""
for h in $HOSTS; do
  OK=0
  for i in $(seq 1 $TRIES); do
    # curl başarısız olunca set -e betiği durdurmasın; başarısız deneme "000" olarak sayılır
    c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 $RES "https://$h/") || true
    [ "$c" != "000" ] && OK=$((OK+1))
  done
  LINE="$LINE $h=$OK/$TRIES"
done
echo "[proxy yok]$LINE"

PORT=13080
while IFS= read -r ARGS; do
  [ -z "$ARGS" ] && continue
  PORT=$((PORT+1))
  # shellcheck disable=SC2086
  $BIN -i 127.0.0.1 -p $PORT $ARGS >/dev/null 2>&1 &
  PID=$!; sleep 0.4
  LINE=""
  for h in $HOSTS; do
    OK=0
    for i in $(seq 1 $TRIES); do
      c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 --socks5 127.0.0.1:$PORT $RES "https://$h/") || true
      [ "$c" != "000" ] && OK=$((OK+1))
    done
    LINE="$LINE $h=$OK/$TRIES"
  done
  kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
  echo "[$ARGS]$LINE"
done <<'EOF'
--tlsrec 3+s --split 1+s
--tlsrec 1+s
--oob 1+s
--disoob 1+s
--fake -1 --ttl 5
--disorder 1 --fake -1 --ttl 5
--split 1+s
--disorder 1
EOF

rm -rf "$WORK"
