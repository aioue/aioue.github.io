---
layout: post
title: UniFi OS behind Caddy 2.11 - fixing the permanent loading bar
date: '2026-07-23 00:20:00'
tags: [caddy, unifi, homelab, reverse-proxy, websocket]
hidden: false
---

I proxy my UCG Max at `https://unifi.home.aioue.net` through Caddy on a small Ubuntu VM. The login page loaded fine. After signing in, the UI sat on a permanent loading bar.

The first HTML response was HTTP 200, which made this look like a DNS or TLS problem. It wasn't. The failure was WebSockets.

## Symptom

- `https://unifi.home.aioue.net/` returns 200 and the UniFi OS shell HTML
- Login appears to work
- Dashboard never loads - just a spinner in the header bar
- Browser devtools: `GET /api/ws/system` returns **500**
- Caddy access log shows the same: `/api/users/self` → 200, `/api/ws/system` → 500

A plain `curl` health check on `/` will lie to you here. You need to watch WebSocket requests after login.

## Root cause: Caddy 2.11 Host header change

From Caddy 2.11, `reverse_proxy` to an HTTPS upstream sets `Host` to `{upstream_hostport}` by default - e.g. `192.168.1.1:443` instead of `unifi.home.aioue.net`.

UniFi OS nginx accepts the initial page load but rejects WebSocket upgrades when the `Host` header does not match the client-facing hostname. See [Caddy community thread](https://caddy.community/t/reverse-proxy-for-unifi-network-controller-for-caddy-2-11/33531) and [caddy#7454](https://github.com/caddyserver/caddy/pull/7454).

## Working Caddyfile block

```caddyfile
@unifi host unifi.home.aioue.net
handle @unifi {
	reverse_proxy https://192.168.1.1:443 {
		transport http {
			tls_insecure_skip_verify
			versions 1.1
		}
		flush_interval -1
		header_up Origin ""
		header_up -Referer
		header_up Host {hostport}
		header_up X-Real-IP {client_ip}
		header_up X-Forwarded-For {client_ip}
	}
}
```

What each piece does:

| Directive | Why |
|-----------|-----|
| `header_up Host {hostport}` | Pass the client hostname (`unifi.home.aioue.net`) upstream, not the gateway IP |
| `header_up Origin ""` | UniFi nginx rejects proxied `Origin` on WebSocket upgrade |
| `versions 1.1` | Force HTTP/1.1 to upstream - WebSocket upgrade needs it |
| `flush_interval -1` | Disable buffering for streaming/WebSocket |
| `tls_insecure_skip_verify` | UCG uses a self-signed cert on :443 |

## Do not manually forward WebSocket headers

This broke things worse:

```caddyfile
# BAD - do not do this with Caddy 2.x
header_up Connection {>Connection}
header_up Upgrade {>Upgrade}
```

Caddy handles WebSocket upgrades automatically. With those lines, every request to UniFi started failing with:

```
http2: invalid Upgrade request header: ["{>Upgrade}"]
```

Even `GET /` returned 502. Remove them and let Caddy do its job.

## Reload vs restart

`systemctl reload caddy` did not pick up the fixed config in my case - the old process still had the broken `{>Upgrade}` headers in memory. A full restart fixed it:

```bash
sudo systemctl restart caddy
```

After restart, logs showed `101 Switching Protocols` on `/api/ws/webrtc/local` and the UI loaded normally.

## Verifying the fix

```bash
# Page should be 200
curl -sk -o /dev/null -w "%{http_code}\n" https://unifi.home.aioue.net/

# Unauthenticated WebSocket should be 401, not 502 or 500
curl -sk -o /dev/null -w "%{http_code}\n" \
  -H "Upgrade: websocket" \
  -H "Connection: Upgrade" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://unifi.home.aioue.net/api/ws/system
```

In the browser after login, `/api/ws/system` should show **101**, not 500.

Check Caddy logs for UniFi errors:

```bash
sudo tail -100 /var/log/caddy/access.log \
  | python3 -c "
import sys, json
from collections import Counter
c = Counter()
for line in sys.stdin:
    d = json.loads(line)
    if 'unifi' not in d.get('request',{}).get('host',''): continue
    if d.get('status',0) >= 400:
        c[d['status']] += 1
print(dict(c) if c else 'no errors')
"
```

After the fix, the last 100 UniFi log lines were all 200s.

## Ansible

I manage this through an Ansible Caddy role ([proxmox-setup](https://github.com/aioue/proxmox-setup)). The service definition in `roles/caddy/defaults/main.yml`:

```yaml
- name: unifi
  upstream: "https://192.168.1.1:443"
  tls_skip_verify: true
  preserve_hostport: true
  clear_origin: true
  http1_only: true
  websocket: true
```

Deploy:

```bash
ansible-playbook -i inventory/unifi.yaml configure.yml --tags caddy --skip-tags dns -v
```

If the UI still looks broken after deploy, restart Caddy on the host before assuming the config is wrong.

## References

- [Caddy 2.11 UniFi reverse proxy thread](https://caddy.community/t/reverse-proxy-for-unifi-network-controller-for-caddy-2-11/33531)
- [caddy#7454 - Host header default for HTTPS upstreams](https://github.com/caddyserver/caddy/pull/7454)
- [Caddy reverse_proxy docs](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
