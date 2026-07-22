---
layout: post
title: UniFi OS behind Caddy 2.11 - fixing the permanent loading bar
date: '2026-07-22 22:00:00'
tags: [caddy, unifi, homelab, reverse-proxy, websocket]
hidden: false
---

I proxy my UCG Max through Caddy on a small Ubuntu VM. The login page loaded fine; after signing in, the UI sat on a permanent loading bar.

`GET /` returns 200, so this does not look like DNS or TLS. The failure is WebSockets: devtools and Caddy logs show `/api/users/self` → 200 but `/api/ws/system` → 500.

## Cause

From Caddy 2.11, `reverse_proxy` to an HTTPS upstream sets `Host` to `{upstream_hostport}` (e.g. `192.168.1.1:443`) instead of the client hostname. UniFi OS nginx accepts the initial page but rejects WebSocket upgrades. See [Caddy community thread](https://caddy.community/t/reverse-proxy-for-unifi-network-controller-for-caddy-2-11/33531).

## Fix

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
	}
}
```

Key points:

- `header_up Host {hostport}` - pass `unifi.example.com`, not the gateway IP
- `header_up Origin ""` - UniFi rejects proxied Origin on WebSocket upgrade
- `versions 1.1` - WebSocket upgrade needs HTTP/1.1 upstream
- Do **not** add `header_up Connection` / `header_up Upgrade` - Caddy handles upgrades automatically; those lines caused `502` with `invalid Upgrade request header: ["{>Upgrade}"]`

After deploy, `systemctl restart caddy` if reload leaves stale config in memory. Success looks like `101 Switching Protocols` on `/api/ws/system` in the browser.

## Verify

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://unifi.home.aioue.net/
# WebSocket without auth should be 401, not 502/500:
curl -sk -o /dev/null -w "%{http_code}\n" \
  -H "Upgrade: websocket" -H "Connection: Upgrade" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://unifi.home.aioue.net/api/ws/system
```

References: [caddy#7454](https://github.com/caddyserver/caddy/pull/7454), [reverse_proxy docs](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
