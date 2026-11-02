# Discord Gateway

[English](#english) | [Türkçe](#türkçe)

## English

A small selective DNS + SNI gateway for Home Assistant OS on a Raspberry Pi (64-bit ARM), for networks where an ISP
uses DNS poisoning and SNI filtering. It handles only the domains you list. The device is not a default gateway, and
all other traffic goes straight to your router. This is not a Windows or PC app: the Pi must stay on, and your devices
are pointed at it.

### How it works

1. A client device uses `<PI_IP>` as its DNS server.
2. The add-on answers listed domains with `<PI_IP>`. Everything else is resolved through DoH
   (DNS over HTTPS).
3. The client connects to `<PI_IP>`. gost reads the destination from the TLS SNI and passes the
   connection to ByeDPI, which splits the ClientHello and connects to the real server.
4. Voice (UDP, `*.discord.media`) does not pass through the add-on.

### Client setup

- **iOS:** Settings → Wi-Fi → (i) next to your network → Configure DNS → Manual → remove the existing
  servers and add `<PI_IP>`.
- **Windows:** Set `<PI_IP>` as the DNS server of your network adapter.

While the add-on is stopped, these clients have no DNS. Set DNS back to "Automatic" to recover.

### Options

| Option | Description |
|---|---|
| `pi_ip` | Detected automatically when empty. Reserve this IP on your router (DHCP reservation). |
| `byedpi_args` | ByeDPI arguments. Alternatives to try: `--oob 1+s`, `--tlsrec 1+s`, `--disoob 1+s` |
| `domains` | Domains to route through the add-on, including subdomains. Must not be empty, and each entry must be a plain domain name such as `example.com`. |
| `dns_upstreams` | DoH servers. |
| `log_level` | `debug`, `info`, `warn` or `error`. |

### Security

The add-on has no authentication and listens on all host interfaces on ports 53, 80 and 443. It accepts only loopback,
private LAN, Tailscale and IPv6 link-local source addresses, and gost checks every plain-HTTP request against the domain
list. DNS answers allowed clients for any name. The source filter is not a firewall, so never expose these ports to the
internet, including through a router port forward. See the README for details.

## Türkçe

DNS zehirleme ve SNI filtreleme kullanan bir ISS'nin bulunduğu ağlar için, Raspberry Pi (64-bit ARM) üzerindeki Home
Assistant OS'te çalışan küçük, seçici bir DNS + SNI geçidi. Sadece listelediğiniz alan adlarıyla ilgilenir. Cihaz ağ
geçidi yapılmaz; diğer tüm trafik doğrudan modeme gider. Bu bir Windows veya PC uygulaması değildir: Pi sürekli açık
kalmalı ve cihazlarınız ona yönlendirilmelidir.

### Nasıl çalışır

1. İstemci cihaz DNS sunucusu olarak `<PI_IP>` kullanır.
2. Eklenti, listedeki alan adları için `<PI_IP>` döner. Diğer her şey DoH (HTTPS üzerinden DNS) ile çözülür.
3. İstemci `<PI_IP>` adresine bağlanır. gost hedefi TLS SNI'dan okur ve bağlantıyı ByeDPI'a verir;
   ByeDPI ClientHello'yu bölerek gerçek sunucuya bağlanır.
4. Sesli görüşme (UDP, `*.discord.media`) eklentiden geçmez.

### İstemci ayarı

- **iOS:** Ayarlar → Wi-Fi → ağınızın yanındaki (i) → DNS'i Yapılandır → El ile → mevcut sunucuları
  silip `<PI_IP>` ekleyin.
- **Windows:** Ağ bağdaştırıcınızın DNS sunucusu olarak `<PI_IP>` ayarlayın.

Eklenti durduğunda bu cihazlarda DNS çalışmaz. Düzeltmek için DNS'i "Otomatik"e alın.

### Seçenekler

| Seçenek | Açıklama |
|---|---|
| `pi_ip` | Boş bırakılırsa otomatik bulunur. Bu IP'yi modemde sabitleyin (DHCP rezervasyonu). |
| `byedpi_args` | ByeDPI parametreleri. Denenebilecek alternatifler: `--oob 1+s`, `--tlsrec 1+s`, `--disoob 1+s` |
| `domains` | Eklenti üzerinden geçirilecek alan adları (alt alan adları dahil). Boş olamaz; her girdi `example.com` gibi düz bir alan adı olmalıdır. |
| `dns_upstreams` | DoH sunucuları. |
| `log_level` | `debug`, `info`, `warn` veya `error`. |

### Güvenlik

Eklentide kimlik doğrulama yoktur; 53, 80 ve 443 portlarında cihazın tüm ağ arayüzlerini dinler. Yalnızca loopback, özel
LAN, Tailscale ve IPv6 link-local kaynak adreslerini kabul eder; gost her şifresiz HTTP isteğini alan adı listesine göre
denetler. DNS, izin verilen istemcilere her ad için yanıt verir. Kaynak filtresi güvenlik duvarı değildir; bu portları
modem port yönlendirmesi dahil asla internete açmayın. Ayrıntılar README'dedir.

---

Made By FALCREB
