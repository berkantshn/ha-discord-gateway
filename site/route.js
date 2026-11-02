// Made By FALCREB
// run.sh'ın gost'a verdiği ".alanadi" eşleşmesinin aynısı: listedeki alan adı ve
// onun alt alan adları geçitten geçer, diğer her şey doğrudan yönlendiriciye gider.

export function parseDomains(configYaml) {
  const lines = configYaml.replaceAll('\r\n', '\n').split('\n');
  const start = lines.findIndex((l) => l.trim() === 'domains:');
  const domains = [];
  for (let i = start + 1; i < lines.length; i++) {
    const m = lines[i].match(/^\s+-\s+([a-z0-9.-]+)\s*$/i);
    if (!m) break;
    domains.push(m[1].toLowerCase());
  }
  return domains;
}

export function normalizeHost(input) {
  let host = input.trim().toLowerCase();
  host = host.replace(/^[a-z]+:\/\//, '').split(/[/?#]/)[0].split(':')[0].replace(/\.$/, '');
  return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(host) ? host : null;
}

export function route(host, domains) {
  const match = domains.find((d) => host === d || host.endsWith(`.${d}`));
  return { viaGateway: Boolean(match), match: match || null };
}
