#!/usr/bin/with-contenv bashio
# Made By FALCREB
# Discord Gateway
#  - gost DNS (53): Discord alan adlarını Pi'ye yönlendirir, geri kalan her şeyi DoH ile doğru çözer
#  - gost SNI (80/443): Pi'ye gelen Discord bağlantısını ByeDPI üzerinden gerçek sunucuya iletir
#  - gost admission: 53/80/443 yalnızca özel LAN ve Tailscale kaynak adreslerine açıktır
#  - ByeDPI (127.0.0.1:1080): TLS ClientHello'yu parçalara böler (SNI filtreleyen DPI için)
set -e

CONF=/tmp/gost.yaml

PI_IP=""
if bashio::config.has_value 'pi_ip'; then
    PI_IP=$(bashio::config 'pi_ip')
else
    # Varsayılan rota üzerindeki kaynak IP = Pi'nin LAN adresi
    PI_IP=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}') || true
fi
if [ -z "$PI_IP" ]; then
    bashio::exit.nok "Pi'nin LAN IP adresi bulunamadı, 'pi_ip' seçeneğini elle girin"
fi

BYEDPI_ARGS=$(bashio::config 'byedpi_args')
LOG_LEVEL=$(bashio::config 'log_level')
DOMAINS=$(jq -r '.domains[]' /data/options.json)
# Boş listede gost whitelist'i hiçbir şeyi engellemez, bu yüzden başlatma
if [ -z "${DOMAINS//[[:space:]]/}" ]; then
    bashio::exit.nok "'domains' listesi boş olamaz"
fi
# Whitelist'i genişletebilecek hatalı girdileri (*, tek etiket vb.) reddet
set -f
for d in $DOMAINS; do
    if ! printf '%s' "$d" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$'; then
        bashio::exit.nok "'domains' içinde geçersiz alan adı: ${d}"
    fi
done
set +f
UPSTREAMS=$(jq -r '.dns_upstreams[]' /data/options.json)

bashio::log.info "Pi IP: ${PI_IP}"
bashio::log.info "Yönlendirilen alan adları: $(echo "$DOMAINS" | tr '\n' ' ')"
bashio::log.info "ByeDPI parametreleri: ${BYEDPI_ARGS}"

# gost yapılandırmasını seçeneklerden üret
{
    echo "log:"
    echo "  level: ${LOG_LEVEL}"
    echo "services:"
    for proto in udp tcp; do
        echo "- name: dns-${proto}"
        echo "  addr: \":53\""
        echo "  admission: yerel-ag"
        echo "  handler:"
        echo "    type: dns"
        echo "  listener:"
        echo "    type: dns"
        echo "    metadata:"
        echo "      mode: ${proto}"
        echo "  hosts: discord"
        echo "  forwarder:"
        echo "    nodes:"
        i=0
        for u in $UPSTREAMS; do
            echo "    - name: up${i}"
            echo "      addr: ${u}"
            i=$((i + 1))
        done
    done
    for port in 443 80; do
        echo "- name: sni-${port}"
        echo "  addr: \":${port}\""
        echo "  admission: yerel-ag"
        echo "  resolver: doh"
        echo "  bypass: sadece-discord"
        echo "  handler:"
        echo "    type: sni"
        echo "    chain: byedpi"
        echo "  listener:"
        echo "    type: tcp"
    done
    echo "chains:"
    echo "- name: byedpi"
    echo "  hops:"
    echo "  - name: hop0"
    echo "    resolver: doh"
    echo "    nodes:"
    echo "    - name: ciadpi"
    echo "      addr: 127.0.0.1:1080"
    echo "      connector:"
    echo "        type: socks5"
    echo "      dialer:"
    echo "        type: tcp"
    echo "resolvers:"
    echo "- name: doh"
    echo "  nameservers:"
    for u in $UPSTREAMS; do
        echo "  - addr: ${u}"
        echo "    prefer: ipv4"
    done
    # Kaynak adres sınırı: loopback, RFC 1918 ve IPv6 ULA (LAN), 100.64.0.0/10 (Tailscale), IPv6 link-local.
    # gost bunu bağlantı kabul edilirken uygular; ek yetki (NET_ADMIN, iptables) gerektirmez.
    echo "admissions:"
    echo "- name: yerel-ag"
    echo "  whitelist: true"
    echo "  matchers:"
    for cidr in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 ::1/128 fc00::/7 fe80::/10; do
        echo "  - ${cidr}"
    done
    # Sadece listedeki alan adları iletilir; gost v3.3.2 her HTTP isteğini ayrı denetler. Sınırlar için README'ye bakın
    echo "bypasses:"
    echo "- name: sadece-discord"
    echo "  whitelist: true"
    echo "  matchers:"
    for d in $DOMAINS; do
        echo "  - .${d}"
    done
    echo "hosts:"
    echo "- name: discord"
    echo "  mappings:"
    for d in $DOMAINS; do
        echo "  - ip: ${PI_IP}"
        echo "    hostname: .${d}"
    done
} > "$CONF"

# Süreç çökerse 3 sn sonra yeniden başlat (cihazların DNS'i bu geçide bağlı olabilir)
run_forever() {
    local name=$1; shift
    while true; do
        "$@" || true
        bashio::log.warning "${name} durdu, 3 sn sonra yeniden başlatılıyor"
        sleep 3
    done
}

# -N: ByeDPI kendisi DNS çözmesin (ISS DNS'i zehirli olabilir), IP'yi gost DoH ile verir
# shellcheck disable=SC2086
run_forever byedpi ciadpi -i 127.0.0.1 -p 1080 -N ${BYEDPI_ARGS} &
sleep 1
run_forever gost gost -C "$CONF" &

wait
