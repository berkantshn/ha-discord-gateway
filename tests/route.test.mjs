// Made By FALCREB
// Demonun gerçek config.yaml listesiyle doğru karar verdiğini sınar: node --test "tests/*.test.mjs"
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseDomains, normalizeHost, route } from '../site/route.js';

const domains = parseDomains(readFileSync(new URL('../addon/discord_gateway/config.yaml', import.meta.url), 'utf8'));

test('liste config.yaml dosyasından okunur', () => {
  assert.ok(domains.includes('discord.com'));
  assert.ok(domains.includes('dis.gd'));
  assert.ok(!domains.some((d) => d.includes('dns-query')));
});

test('listedeki alan adı ve alt alan adı geçitten geçer', () => {
  assert.equal(route('discord.gg', domains).viaGateway, true);
  assert.equal(route('cdn.discordapp.com', domains).viaGateway, true);
});

test('benzer adlı veya listede olmayan alan adı geçmez', () => {
  assert.equal(route('notdiscord.com', domains).viaGateway, false);
  assert.equal(route('discord.com.evil.net', domains).viaGateway, false);
  assert.equal(route('google.com', domains).viaGateway, false);
});

test('adres temizlenir, geçersizler reddedilir', () => {
  assert.equal(normalizeHost(' HTTPS://Discord.com:443/channels?x=1 '), 'discord.com');
  assert.equal(normalizeHost('merhaba dünya'), null);
  assert.equal(normalizeHost('localhost'), null);
});
