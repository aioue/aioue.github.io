---
layout: post
title: Apache Guacamole in Docker with MariaDB and TOTP
date: '2026-08-27 12:00:00'
tags: [guacamole, ansible, docker, mariadb, totp]
hidden: false
---

Companion to [headless Wayland RDP with GNOME Remote Desktop]({% post_url 2026-01-21-gnome-remote-desktop-rdp-ubuntu-24.04 %}). That post configures RDP targets; this one runs Apache Guacamole in Docker so you can reach them from a browser.

Ansible playbook and role: [ansible-docker-guacamole-example](https://github.com/aioue/ansible-docker-guacamole-example). The YAML below is fetched from that repo when the page loads.

## Overview

The example deploys Guacamole 1.6.0 (`guacamole/guacamole:1.6.0`), `guacd`, and MariaDB LTS. Ansible initialises the JDBC schema, creates a custom admin over the REST API, enables TOTP, and disables the stock `guacadmin` account. It does not create regular users or connections.

- MariaDB backend with Guacamole's MySQL JDBC driver and `initdb.sh --mysql`
- Healthchecks on all three services, with `depends_on: condition: service_healthy`
- TOTP on first deploy, with a short bootstrap bypass scoped to the compose network gateway
- Default bind `127.0.0.1:8080` (Guacamole itself is HTTP; terminate TLS at a reverse proxy)

Needs Docker Engine with the Compose v2 plugin, Ansible 2.15+, and the `community.docker` collection.

## Compose

MariaDB speaks the MySQL protocol, so Guacamole still uses `MYSQL_*` environment variables and the upstream image generates schema SQL with `initdb.sh --mysql`. The MariaDB image healthcheck is `healthcheck.sh --connect --innodb_initialized`. `mysqladmin ping` is the MySQL-image equivalent and will not work here.

{% include github-embed.html repo="aioue/ansible-docker-guacamole-example" file="roles/docker_guacamole/templates/docker-compose.yml.j2" lang="yaml" %}

Compared with the stock [Guacamole Docker guide](https://guacamole.apache.org/doc/gug/guacamole-docker.html):

- `guacamole` waits on both `guacdb` and `guacd` with `condition: service_healthy`
- `guacd`: `nc -z 127.0.0.1 4822`
- `guacamole`: `curl --fail http://127.0.0.1:8080/guacamole` (the image's own check; omitting it on a later `docker compose up` can replace a working healthcheck with nothing)
- `json-file` logging with `max-size: 10m` and `max-file: 3` on every service
- MariaDB `--wait_timeout=86400 --interactive_timeout=86400` because RDP sessions through Guacamole can stay open all day (default is 28800 seconds)
- `MYSQL_AUTO_RECONNECT=true` on the Guacamole container

## Bootstrap

`bootstrap.yml` brings the database up first, loads the schema if needed, then starts the full stack. During bootstrap it sets `TOTP_BYPASS_HOSTS` to the Docker network gateway (the source address Tomcat sees for loopback API calls that arrived via docker-proxy), creates the custom admin, grants system permissions, and disables `guacadmin`. Add users and RDP connections in the Guacamole UI afterwards, or extend the playbook.

{% include github-embed.html repo="aioue/ansible-docker-guacamole-example" file="roles/docker_guacamole/tasks/bootstrap.yml" lang="yaml" %}

On a fresh schema the default admin is `guacadmin` / `guacadmin`. The example replaces that with a custom admin (username `admin` in `group_vars/all.yml.example`).

## Key steps explained

### 1. Schema initialisation

Ansible runs `docker run --rm guacamole/guacamole:1.6.0 /opt/guacamole/bin/initdb.sh --mysql` to generate `initdb.sql`, starts MariaDB alone, waits for it, then loads the script if the `guacamole_user` table is missing. Generating the SQL from the pinned image keeps the schema aligned with 1.6.0.

### 2. Healthchecks and startup order

Without healthchecks, Compose only waits for the container process to start, not for MariaDB or Tomcat to accept connections. The three checks above let `guacamole` wait until the database and `guacd` are actually ready.

### 3. Long-lived RDP sessions and the database

Guacamole holds JDBC connections open while users stay connected. MariaDB's default `wait_timeout` of 28800 seconds (8 hours) can drop idle connections mid-session. Raising both `wait_timeout` and `interactive_timeout` to 86400 (24 hours) avoids that. `MYSQL_AUTO_RECONNECT=true` covers the case where a connection still goes stale.

### 4. TOTP bootstrap and GUACAMOLE-2140

TOTP is enabled from the first full stack deploy (`TOTP_ENABLED=true`). Guacamole 1.6.0 will not persist TOTP-related user attributes over the REST API while TOTP is enforced for the caller ([GUACAMOLE-2140](https://issues.apache.org/jira/browse/GUACAMOLE-2140)). Bootstrap works around that by temporarily setting `TOTP_BYPASS_HOSTS` to the compose network gateway only, so automation can call the API from the host while off-box logins still require TOTP. After the custom admin exists and `guacadmin` is disabled, Ansible clears the bypass and redeploys.

The first browser login as the custom admin prompts TOTP enrollment (QR code). See the [TOTP auth guide](https://guacamole.apache.org/doc/gug/totp-auth.html).

### 5. Custom admin via REST API

Bootstrap authenticates as `guacadmin`, creates the custom admin if missing, and grants system permissions: `ADMINISTER`, `CREATE_USER`, `CREATE_USER_GROUP`, `CREATE_CONNECTION`, `CREATE_CONNECTION_GROUP`, `CREATE_SHARING_PROFILE`. It then disables `guacadmin` with a PUT (`disabled: true`). No connections or non-admin users are provisioned.

## Run

```bash
git clone https://github.com/aioue/ansible-docker-guacamole-example.git
cd ansible-docker-guacamole-example
cp group_vars/all.yml.example group_vars/all.yml
# Edit group_vars/all.yml: set passwords and guacamole_admin_username
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml
```

The inventory defaults to `localhost` with `ansible_connection: local`. Point `ansible_host` at another machine if Docker runs elsewhere.

By default Guacamole publishes on `127.0.0.1:8080`. Set `guacamole_bind_address` in `group_vars/all.yml` when a reverse proxy on another host needs to reach the container. Terminate TLS at the proxy.

## Verifying the setup

Check the login page responds:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/guacamole/
```

Expect `200`. Confirm all services are healthy:

```bash
docker compose --project-directory ~/docker/guacamole ps
```

(`guacamole_dir` defaults to `~/docker/guacamole` on the target host.)

Open `http://127.0.0.1:8080/guacamole/` in a browser, sign in as the custom admin (default `admin`), and complete TOTP enrollment. A login attempt as `guacadmin` should fail because that account is disabled.

Add an RDP connection in the Guacamole UI to a target configured per the [companion RDP post]({% post_url 2026-01-21-gnome-remote-desktop-rdp-ubuntu-24.04 %}).

## References

- [ansible-docker-guacamole-example](https://github.com/aioue/ansible-docker-guacamole-example)
- [Guacamole Docker installation guide](https://guacamole.apache.org/doc/gug/guacamole-docker.html)
- [Guacamole TOTP authentication](https://guacamole.apache.org/doc/gug/totp-auth.html)
- [Guacamole 1.6.0 MySQL/MariaDB auth](https://guacamole.apache.org/doc/1.6.0/gug/mysql-auth.html)
- [GUACAMOLE-2140](https://issues.apache.org/jira/browse/GUACAMOLE-2140)
- [Headless Wayland RDP with GNOME Remote Desktop on Ubuntu 24.04]({% post_url 2026-01-21-gnome-remote-desktop-rdp-ubuntu-24.04 %})
