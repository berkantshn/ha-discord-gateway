# Home Assistant Discord Gateway for Raspberry Pi

> **⚠️ This is NOT a Windows or PC app.** It requires a Raspberry Pi (64-bit ARM, `aarch64`) running
> Home Assistant OS, always on, in your home network. You install it as a Home Assistant add-on, and your
> devices are then pointed at it.
>
> **⚠️ Bu bir Windows veya PC uygulaması DEĞİLDİR.** Ev ağınızda sürekli açık duran, Home Assistant OS
> çalıştıran bir Raspberry Pi (64-bit ARM, `aarch64`) gerektirir. Home Assistant eklentisi olarak kurulur,
> ardından cihazlarınız bu eklentiye yönlendirilir.

[![Add to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fberkantshn%2Fha-discord-gateway)

**[▶ Try the routing demo](https://berkantshn.github.io/ha-discord-gateway/)**: type a website and see whether it passes through the gateway.

[English](#english) | [Türkçe](#türkçe)

## English

A Home Assistant OS add-on for Raspberry Pi (`aarch64`) that runs a selective DNS + SNI gateway using
[gost](https://github.com/go-gost/gost) and [ByeDPI](https://github.com/hufrea/byedpi). It is meant for
networks where an ISP uses DNS poisoning and SNI filtering. Only the domains you list are routed through
the device. It is not a default gateway, so all other traffic goes straight to your router.

Placeholders used below: `<PI_IP>`, `<PI_IPV6_LINK_LOCAL>`, `<PI_SSH_HOST>`, `<INTERFACE_NAME>`,
`<TAILSCALE_MACHINE>`.

### How it works

An ISP of this kind typically interferes in two places:

- **DNS poisoning:** its resolver returns a wrong IP for the domain.
- **SNI filtering:** deep packet inspection (DPI) reads the domain name in the TLS ClientHello and
  interrupts the connection, even when the IP is correct.

The add-on handles each one:

```
Client ──DNS──▶ Pi:53 (gost)      listed domains → <PI_IP>, others → DoH upstream
Client ──TLS──▶ Pi:443 (gost SNI) ──▶ ByeDPI (splits ClientHello) ──▶ real server
Voice (UDP) ────────────────────────────────────────────────────────▶ direct
```

1. Clients use the add-on as their DNS server. Listed domains resolve to `<PI_IP>`. All other names are
   resolved through DNS over HTTPS (DoH).
2. gost accepts the connection on port 443 or 80 and reads the destination from the SNI or HTTP `Host`.
3. gost resolves the name through DoH and passes the connection to ByeDPI over a local SOCKS5 port
   (`127.0.0.1:1080`). ByeDPI splits the ClientHello according to `byedpi_args`.
4. TLS stays end to end between client and server. The add-on does not decrypt traffic.

### Compared with common alternatives

These are differences that follow from how each approach is designed. No speed or reliability measurements
were made, and each option suits different needs.

| | This add-on | Windows DPI tool (such as GoodbyeDPI or SplitWire-type apps) | DNS change alone | Full VPN |
|---|---|---|---|---|
| Where it runs | One Raspberry Pi with Home Assistant OS | On each PC | Setting on each device or router | App on each device or router, plus a VPN server |
| Devices served | Any device set up as described under Client setup, including phones | The PC it runs on | The devices you change | The devices connected to it |
| Addresses DNS poisoning | Yes | Depends on the tool | Usually, unless the network intercepts DNS | Yes |
| Addresses SNI filtering | Yes, while the ByeDPI method works on your network | Yes, while its method works on your network | No | Yes, the name is inside the tunnel |
| Traffic it handles | Listed domains only | Depends on the tool and its settings | DNS lookups only | Usually all traffic |
| Protects your other traffic | No | No | No | Yes |
| Extra hardware | An always-on Pi | None | None | None, or a server if you host it yourself |

**Advantages of this design**

- One install can serve several devices, including phones, once each device has the DNS or Tailscale setup
  below. No gateway software is installed per device beyond that setup.
- Only listed domains pass through the gateway. The rest of your internet traffic does not, so the gateway adds
  no VPN-style routing to it. With manual DNS, name lookups for all sites still use the add-on.
- Voice (UDP) goes directly from the client to the server and does not pass through the Pi.
- gost and ByeDPI are pinned to exact versions and checked against SHA256 values at build time.

**Drawbacks**

- It needs an always-on Raspberry Pi with Home Assistant OS, and takes more setup than a desktop app or a DNS
  change.
- It may stop working when filtering methods change, and it does nothing for voice if voice itself is blocked.
- A VPN also protects your other traffic. This does not.
- It provides no encryption of its own and no anonymity. Your ISP can still see the IP addresses you connect to.
- It has no authentication and must not be exposed to the internet. See the limits below.
- With manual DNS, the device loses all DNS while the add-on or Pi is down, and it only works on the home network. Away from home, a device needs the Tailscale setup.

### What is forwarded, and the limits

`run.sh` generates a gost whitelist from the `domains` option. The add-on refuses to start if the list is empty
or an entry is not a plain domain name such as `example.com`. This is what the protections do and do not cover:

- **Source addresses:** ports 53, 80 and 443 accept only loopback, private LAN (`10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`, IPv6 `fc00::/7`), Tailscale (`100.64.0.0/10`) and IPv6 link-local (`fe80::/10`) sources.
  Other sources get no DNS answer and their TCP connections are closed. gost does this itself, so the add-on
  needs no extra privileges. The ranges are set in `run.sh`.
- **TLS with SNI:** only listed domains and their subdomains are forwarded. Other names, and TLS without SNI, are
  dropped.
- **Plain HTTP:** gost v3.3.2 checks every HTTP/1.x and HTTP/2 cleartext request against the list, including later
  requests on a kept-alive connection. A request can name another port on a listed domain (`Host: example.com:8080`),
  and the add-on will connect to that port. Unlisted hosts are refused on any port.
- **DNS:** port 53 answers allowed clients for any name by design, because they use it as their resolver. Unlisted
  names are forwarded to the DoH servers, and their real answers are returned unchanged.
- **DoH:** in testing, gost refused a DoH server whose certificate it could not verify.
- **ByeDPI:** its SOCKS5 port listens on loopback only and cannot be reached from the LAN. With `host_network`, this
  is the Pi's own loopback, so other software on the Pi using the host network could reach it, with no domain list
  applied.
- **Access:** there is no authentication, and with `host_network` the services listen on all host interfaces.
  Anyone allowed by the source filter can use them, including guest Wi-Fi if it shares a private range.
- **The source filter is not a firewall:** a router port forward that rewrites the source address can make internet
  traffic look like a private address, and forged UDP source addresses can reach the DNS service if the port is
  reachable.
- **IPv6:** only IPv4 mappings are generated. A dual-stack client may receive a real AAAA record for a listed domain
  and connect directly.

Treat this as a service for a trusted LAN or private tailnet. **Do not expose ports 53, 80 or 443 to the internet**,
and check your router's IPv6 firewall as well.

### Testing status

The Dockerfile was built for `linux/arm64` and run under emulation in isolated Docker networks, with local fake
backends and a fake DoH server. That covered the whitelist, the source filter, the plain-HTTP checks and the startup
refusals. **It has not been tested on a real Raspberry Pi or Home Assistant install in this form**, including the
install steps below, Tailscale, and real filtering networks.

### Components and licences

| Component | Version | Licence |
|---|---|---|
| [ByeDPI](https://github.com/hufrea/byedpi) (`ciadpi`) | v0.17.3 | [MIT](https://github.com/hufrea/byedpi/blob/v0.17.3/LICENSE), Copyright (c) 2024 hufrea |
| [gost](https://github.com/go-gost/gost) | v3.3.2 | [MIT](https://github.com/go-gost/gost/blob/v3.3.2/LICENSE), Copyright (c) 2016 ginuerzh |

The Dockerfile downloads both from their official GitHub releases at build time and verifies each archive
against a pinned SHA256. No upstream binaries are stored in this repository. If you publish a built image,
include the upstream licence notices with it.

### Installation

*These steps have not been tested on a device. Menu names vary between Home Assistant releases, which may say
"Add-ons" or "Apps".*

**From this repository**

1. Press the **Add to Home Assistant** button at the top of this page. Or open Settings → Add-ons (or Apps) → the store → ⋮ → Repositories.
2. If you did not use the button, add `https://github.com/berkantshn/ha-discord-gateway`.
3. Install and start "Discord Gateway". Home Assistant builds it on the Pi. Ports 53, 80 and 443 must be free.
4. Reserve `<PI_IP>` on your router (DHCP reservation).
5. Set up your client devices as described below.

**As a local add-on**

Download `discord_gateway-addon.zip` from the [latest release](https://github.com/berkantshn/ha-discord-gateway/releases/latest) and extract it, or use `addon/discord_gateway` from this repository. Copy the folder to `/local_apps/discord_gateway` on the device, choose ⋮ → Reload in the store, then
continue from step 3. Other releases may use `/addons` and `ha addons` in place of `/local_apps` and `ha apps`.

### Client setup

**Option A: Tailscale split DNS.** Clients keep automatic DNS, and only the listed domains are sent to the
gateway, so a stopped device does not take down all DNS.

- In the Tailscale add-on, advertise the route `<PI_IP>/32`, then approve it for `<TAILSCALE_MACHINE>` in the
  admin console.
- Under DNS → Nameservers, add `<PI_IP>` with "Restrict to domain" for `discord.com`, `discord.gg`,
  `discordapp.com`, `discordapp.net` and `discord.media`.
- Leave "Override DNS servers" off.
- Run Tailscale on each client and leave Wi-Fi DNS on automatic.

**Option B: manual DNS.** Point the client's DNS at the device. All of its DNS then depends on the add-on.

- **iOS:** Settings → Wi-Fi → (i) → Configure DNS → Manual → remove existing servers and add `<PI_IP>`.
- **Windows (administrator PowerShell):**
  `Set-DnsClientServerAddress -InterfaceAlias "<INTERFACE_NAME>" -ServerAddresses ("<PI_IP>","<PI_IPV6_LINK_LOCAL>")`
- **Undo on Windows:**
  `Set-DnsClientServerAddress -InterfaceAlias "<INTERFACE_NAME>" -ResetServerAddresses`

### Maintenance

**Compare ByeDPI strategies:** the script below downloads the pinned ByeDPI to a temporary folder and tests
each strategy against three sample hostnames.

```sh
ssh <PI_SSH_HOST> 'sh -s' < scripts/strateji-testi.sh
```

Put a working value in the add-on's `byedpi_args` option and restart it. Other values to try:
`--oob 1+s`, `--tlsrec 1+s`, `--disoob 1+s`, `--fake -1 --ttl 5`. Results vary by network.

**Update a local install:**

```sh
scp addon/discord_gateway/* <PI_SSH_HOST>:/local_apps/discord_gateway/
ssh <PI_SSH_HOST> 'ha apps rebuild local_discord_gateway && ha apps restart local_discord_gateway'
```

If you change `version` in `config.yaml`, Home Assistant offers an update in its UI instead. Installs from this
repository update the same way when a new version is published.

### Disclaimer

This project is for education and personal use on networks you own. You are responsible for complying with
local laws and the terms of the services you use. It is provided without any guarantee. It is not affiliated
with Discord, ByeDPI or gost.

### License

[MIT](LICENSE)

---

## Türkçe

Raspberry Pi (`aarch64`) için, [gost](https://github.com/go-gost/gost) ve
[ByeDPI](https://github.com/hufrea/byedpi) kullanan, seçici bir DNS + SNI geçidi kuran Home Assistant OS eklentisi.
DNS zehirleme ve SNI filtreleme kullanan bir ISS'nin bulunduğu ağlar için tasarlanmıştır. Cihazdan sadece
listelediğiniz alan adları geçer. Cihaz ağ geçidi yapılmaz; diğer tüm trafik doğrudan modeme gider.

Aşağıdaki yer tutucular: `<PI_IP>`, `<PI_IPV6_LINK_LOCAL>`, `<PI_SSH_HOST>`, `<INTERFACE_NAME>`,
`<TAILSCALE_MACHINE>`.

### Nasıl çalışır

Bu tür bir ISS genellikle iki noktada müdahale eder:

- **DNS zehirleme:** ISS'nin DNS sunucusu alan adı için yanlış IP döner.
- **SNI filtreleme:** Derin paket incelemesi (DPI), TLS ClientHello içindeki alan adını okur ve IP doğru
  olsa bile bağlantıyı keser.

Eklenti ikisini de şöyle ele alır:

```
İstemci ──DNS──▶ Pi:53 (gost)      listedeki alan adları → <PI_IP>, diğerleri → DoH
İstemci ──TLS──▶ Pi:443 (gost SNI) ──▶ ByeDPI (ClientHello bölme) ──▶ gerçek sunucu
Sesli (UDP) ─────────────────────────────────────────────────────────▶ doğrudan
```

1. İstemciler eklentiyi DNS sunucusu olarak kullanır. Listedeki alan adları `<PI_IP>` olarak çözülür. Diğer
   tüm adlar DoH (HTTPS üzerinden DNS) ile çözülür.
2. gost, 443 veya 80 portundaki bağlantıyı alır ve hedefi SNI veya HTTP `Host` alanından okur.
3. gost adı DoH ile çözer ve bağlantıyı yerel bir SOCKS5 portu (`127.0.0.1:1080`) üzerinden ByeDPI'a verir.
   ByeDPI, ClientHello'yu `byedpi_args` ayarına göre böler.
4. TLS, istemci ile sunucu arasında uçtan uca kalır. Eklenti trafiğin şifresini çözmez.

### Yaygın alternatiflerle karşılaştırma

Buradaki farklar her yaklaşımın tasarımından kaynaklanır. Hız veya güvenilirlik ölçümü yapılmamıştır ve her
seçenek farklı ihtiyaçlara uyar.

| | Bu eklenti | Windows DPI aracı (GoodbyeDPI veya SplitWire türü uygulamalar gibi) | Yalnızca DNS değişikliği | Tam VPN |
|---|---|---|---|---|
| Nerede çalışır | Home Assistant OS çalıştıran tek bir Raspberry Pi | Her bilgisayarda | Her cihazda veya modemde bir ayar | Her cihazda veya modemde uygulama, ayrıca bir VPN sunucusu |
| Hizmet verdiği cihazlar | İstemci kurulumunda anlatıldığı gibi ayarlanan her cihaz, telefonlar dahil | Çalıştığı bilgisayar | Ayarı değiştirilen cihazlar | Ona bağlı cihazlar |
| DNS zehirlemeye çözüm | Evet | Araca göre değişir | Genellikle, ağ DNS trafiğine müdahale etmiyorsa | Evet |
| SNI filtrelemeye çözüm | Evet, ByeDPI yöntemi ağınızda çalıştığı sürece | Evet, yöntemi ağınızda çalıştığı sürece | Hayır | Evet, ad tünelin içinde kalır |
| Ele aldığı trafik | Yalnızca listedeki alan adları | Araca ve ayarlarına göre değişir | Yalnızca DNS sorguları | Genellikle tüm trafik |
| Diğer trafiğinizi korur | Hayır | Hayır | Hayır | Evet |
| Ek donanım | Sürekli açık bir Pi | Yok | Yok | Yok; kendiniz barındırırsanız bir sunucu |

**Bu tasarımın avantajları**

- Tek kurulum, aşağıdaki DNS veya Tailscale ayarı yapıldıktan sonra telefonlar dahil birden çok cihaza hizmet
  verebilir. Bu ayar dışında cihaz başına geçit yazılımı kurulmaz.
- Geçitten yalnızca listedeki alan adları geçer. İnternet trafiğinizin geri kalanı geçmez, bu yüzden geçit ona VPN
  tarzı bir yönlendirme eklemez. Elle DNS kullanıldığında tüm sitelerin ad sorguları yine eklentiye gider.
- Sesli görüşme (UDP) istemciden sunucuya doğrudan gider, Pi'den geçmez.
- gost ve ByeDPI tam sürüme sabitlenmiştir ve derleme sırasında SHA256 değerleriyle doğrulanır.

**Dezavantajlar**

- Home Assistant OS çalıştıran, sürekli açık bir Raspberry Pi gerektirir; masaüstü uygulamasına veya DNS
  değişikliğine göre kurulumu daha uzundur.
- Filtreleme yöntemleri değiştiğinde çalışmayı bırakabilir; sesli görüşmenin kendisi engelliyse ona bir faydası yoktur.
- VPN diğer trafiğinizi de korur. Bu eklenti korumaz.
- Kendisi şifreleme veya anonimlik sağlamaz. ISS'niz bağlandığınız IP adreslerini görmeye devam eder.
- Kimlik doğrulaması yoktur ve internete açılmamalıdır. Aşağıdaki sınırlara bakın.
- Elle DNS kullanıldığında, eklenti veya Pi kapalıyken cihazın DNS'i tamamen çalışmaz ve yalnızca ev ağında çalışır. Cihazın evin dışında çalışması için Tailscale kurulumu gerekir.

### Neler iletilir, sınırlar neler

`run.sh`, `domains` seçeneğinden bir gost whitelist'i üretir. Liste boşsa veya bir girdi `example.com` gibi düz bir
alan adı değilse eklenti başlamaz. Korumaların kapsamı şöyledir:

- **Kaynak adresler:** 53, 80 ve 443 portları yalnızca loopback, özel LAN (`10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`, IPv6 `fc00::/7`), Tailscale (`100.64.0.0/10`) ve IPv6 link-local (`fe80::/10`) kaynaklarını kabul
  eder. Diğer kaynaklar DNS yanıtı alamaz, TCP bağlantıları kapatılır. Bunu gost kendisi yaptığı için eklentinin ek
  yetkiye ihtiyacı yoktur. Aralıklar `run.sh` içinde tanımlıdır.
- **SNI içeren TLS:** Sadece listedeki alan adları ve alt alan adları iletilir. Diğer adlar ve SNI içermeyen TLS
  düşürülür.
- **Şifresiz HTTP:** gost v3.3.2, açık tutulan bağlantıdaki sonraki istekler dahil her HTTP/1.x ve şifresiz HTTP/2
  isteğini listeye göre denetler. Bir istek, listedeki alan adının başka bir portunu belirtebilir
  (`Host: example.com:8080`) ve eklenti o porta bağlanır. Listede olmayan adresler her portta reddedilir.
- **DNS:** İzin verilen istemciler 53 portunu DNS sunucusu olarak kullandığı için bu port tasarım gereği her ada yanıt
  verir. Listede olmayan adlar DoH sunucularına iletilir ve gerçek yanıtları değiştirilmeden döner.
- **DoH:** Testte gost, sertifikasını doğrulayamadığı DoH sunucusunu reddetti.
- **ByeDPI:** SOCKS5 portu yalnızca loopback'te dinler ve LAN'dan erişilemez. `host_network` nedeniyle bu, Pi'nin kendi
  loopback'idir; Pi üzerinde host ağını kullanan başka yazılımlar bu porta alan adı listesi uygulanmadan ulaşabilir.
- **Erişim:** Kimlik doğrulama yoktur; `host_network` nedeniyle servisler cihazın tüm ağ arayüzlerini dinler. Kaynak
  filtresinin izin verdiği herkes kullanabilir; özel aralık kullanan misafir Wi-Fi'si de buna dahildir.
- **Kaynak filtresi güvenlik duvarı değildir:** Kaynak adresi değiştiren bir modem port yönlendirmesi, internet
  trafiğini özel adres gibi gösterebilir. Port erişilebilirse sahte UDP kaynak adresleri DNS servisine ulaşabilir.
- **IPv6:** Sadece IPv4 eşlemesi üretilir. Çift yığınlı (IPv4 + IPv6) bir istemci, listedeki bir alan adı için
  gerçek AAAA kaydı alıp doğrudan bağlanabilir.

Bunu güvendiğiniz bir yerel ağ veya özel tailnet için bir servis olarak düşünün. **53, 80 ve 443 portlarını
internete açmayın**; modeminizin IPv6 güvenlik duvarını da kontrol edin.

### Test durumu

Dockerfile `linux/arm64` için derlendi ve yalıtılmış Docker ağlarında, yerel sahte sunucular ve sahte bir DoH
sunucusuyla emülasyon altında çalıştırıldı. Whitelist, kaynak filtresi, şifresiz HTTP denetimleri ve başlatma
retleri bu şekilde sınandı. **Bu haliyle gerçek bir Raspberry Pi veya Home Assistant kurulumunda test edilmedi**;
aşağıdaki kurulum adımları, Tailscale ve gerçek filtreleme yapan ağlar da buna dahildir.

### Bileşenler ve lisanslar

| Bileşen | Sürüm | Lisans |
|---|---|---|
| [ByeDPI](https://github.com/hufrea/byedpi) (`ciadpi`) | v0.17.3 | [MIT](https://github.com/hufrea/byedpi/blob/v0.17.3/LICENSE), Copyright (c) 2024 hufrea |
| [gost](https://github.com/go-gost/gost) | v3.3.2 | [MIT](https://github.com/go-gost/gost/blob/v3.3.2/LICENSE), Copyright (c) 2016 ginuerzh |

Dockerfile ikisini de derleme sırasında resmi GitHub release'lerinden indirir ve her arşivi sabitlenmiş bir
SHA256 ile doğrular. Bu repoda upstream ikili dosyası tutulmaz. Derlenmiş bir imaj yayımlarsanız upstream lisans
metinlerini de birlikte verin.

### Kurulum

*Bu adımlar bir cihazda test edilmedi. Menü adları Home Assistant sürümüne göre değişir; "Eklentiler" veya "Uygulamalar"
yazabilir.*

**Bu repodan**

1. Bu sayfanın üstündeki **Add to Home Assistant** düğmesine bas. Ya da Home Assistant'ta Ayarlar → Eklentiler (veya Uygulamalar) → mağaza → ⋮ → Depolar'ı açın.
2. Düğmeyi kullanmadıysan: `https://github.com/berkantshn/ha-discord-gateway` adresini ekleyin.
3. "Discord Gateway"i kurup başlatın. Home Assistant eklentiyi Pi üzerinde derler. 53, 80 ve 443 portları boş olmalıdır.
4. Modemde `<PI_IP>` adresini sabitleyin (DHCP rezervasyonu).
5. İstemci cihazları aşağıdaki gibi ayarlayın.

**Yerel eklenti olarak**

[Son sürümden](https://github.com/berkantshn/ha-discord-gateway/releases/latest) `discord_gateway-addon.zip` dosyasını indirip çıkart ya da bu depodaki klasörü kullan. `addon/discord_gateway` klasörünü cihazda `/local_apps/discord_gateway` olarak kopyalayın, mağazada ⋮ → Yeniden yükle'yi
seçin ve 3. adımdan devam edin. Başka sürümlerde `/local_apps` ve `ha apps` yerine `/addons` ve `ha addons` geçerli
olabilir.

### İstemci kurulumu

**Seçenek A: Tailscale split DNS.** İstemcilerde DNS otomatik kalır ve sadece listedeki alan adları geçide sorulur.
Böylece cihaz durduğunda tüm DNS devre dışı kalmaz.

- Tailscale eklentisinde `<PI_IP>/32` rotasını duyurun, ardından yönetim panelinde `<TAILSCALE_MACHINE>` için
  onaylayın.
- DNS → Nameservers altında `<PI_IP>` ekleyin ve "Restrict to domain" ile `discord.com`, `discord.gg`,
  `discordapp.com`, `discordapp.net`, `discord.media` alan adlarıyla sınırlayın.
- "Override DNS servers" kapalı kalsın.
- Her istemcide Tailscale'i çalıştırın, Wi-Fi DNS'i otomatikte bırakın.

**Seçenek B: elle DNS.** İstemcinin DNS'i cihaza yönlendirilir. Bu durumda istemcinin tüm DNS'i eklentiye bağlı olur.

- **iOS:** Ayarlar → Wi-Fi → (i) → DNS'i Yapılandır → El ile → mevcut sunucuları silip `<PI_IP>` ekleyin.
- **Windows (yönetici PowerShell):**
  `Set-DnsClientServerAddress -InterfaceAlias "<INTERFACE_NAME>" -ServerAddresses ("<PI_IP>","<PI_IPV6_LINK_LOCAL>")`
- **Windows'ta geri almak için:**
  `Set-DnsClientServerAddress -InterfaceAlias "<INTERFACE_NAME>" -ResetServerAddresses`

### Bakım

**ByeDPI stratejilerini karşılaştırma:** Aşağıdaki betik, sabitlenen ByeDPI sürümünü geçici bir klasöre indirir ve
her stratejiyi üç örnek adres üzerinde dener.

```sh
ssh <PI_SSH_HOST> 'sh -s' < scripts/strateji-testi.sh
```

Çalışan bir değeri eklentinin `byedpi_args` seçeneğine yazın ve eklentiyi yeniden başlatın. Denenebilecek diğer
değerler: `--oob 1+s`, `--tlsrec 1+s`, `--disoob 1+s`, `--fake -1 --ttl 5`. Sonuçlar ağa göre değişir.

**Yerel kurulumu güncelleme:**

```sh
scp addon/discord_gateway/* <PI_SSH_HOST>:/local_apps/discord_gateway/
ssh <PI_SSH_HOST> 'ha apps rebuild local_discord_gateway && ha apps restart local_discord_gateway'
```

`config.yaml` içindeki `version` değiştirilirse Home Assistant arayüzünde güncelleme seçeneği çıkar. Bu repodan yapılan
kurulumlar da yeni sürüm yayımlandığında aynı şekilde güncellenir.

### Sorumluluk reddi

Bu proje, eğitim ve sahibi olduğunuz ağlarda kişisel kullanım içindir. Yerel yasalara ve kullandığınız hizmetlerin
koşullarına uymak sizin sorumluluğunuzdadır. Hiçbir garanti verilmez. Discord, ByeDPI veya gost ile bağlantılı
değildir.

### Lisans

[MIT](LICENSE)

---

## ⭐ Support this project

If this project helped you, please give it a ⭐ and [follow me on GitHub](https://github.com/berkantshn) for more.

İşine yaradıysa projeye ⭐ verip [beni GitHub'da takip edebilirsin](https://github.com/berkantshn).

---

Made By FALCREB
