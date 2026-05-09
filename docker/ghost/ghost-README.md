# Ghost + Caddy — Self Hosted Home UK

A minimal Docker Compose stack for running a [Ghost](https://ghost.org) blog behind a [Caddy](https://caddyserver.com) reverse proxy, designed for self-hosting on a Raspberry Pi or similar Linux server behind a Cloudflare Tunnel.

This is the exact stack running [selfhostedhome.co.uk](https://selfhostedhome.co.uk). A full walkthrough of the setup, reasoning, and deployment process is documented in the blog post:

**[Self Hosting a Ghost Blog on a Raspberry Pi — The Setup](https://selfhostedhome.co.uk/self-hosting-a-ghost-blog-on-a-raspberry-pi-the-setup/)**

---

## Stack Overview

| Service | Image | Purpose |
|---------|-------|---------|
| Ghost | `ghost:alpine` | Blog engine |
| Caddy | `caddy:2-alpine` | Reverse proxy |

Ghost uses SQLite — lightweight and perfectly adequate for a personal or small business blog with no external database dependency.

---

## Files

```
ghost/
├── docker-compose.yml   — Ghost and Caddy services
├── Caddyfile            — Caddy reverse proxy configuration
└── README.md            — This file
```

---

## Prerequisites

- Docker and Docker Compose installed
- A domain name pointed to Cloudflare (recommended) or directly to your server
- A Cloudflare Tunnel configured if self-hosting locally — see the blog post for details
- Port 80 accessible from your reverse proxy or tunnel

---

## Setup

**1. Clone or download these files into a directory on your server:**

```bash
mkdir selfhostedhome-ghost && cd selfhostedhome-ghost
```

**2. Edit `docker-compose.yml` — replace the URL:**

```yaml
url: http://yourdomain.com
```

**3. Edit `Caddyfile` — replace the domain in both blocks:**

```
http://yourdomain.com {
```

If you are not using a Cloudflare Tunnel and want Caddy to handle HTTPS directly, remove `auto_https off` from the Caddyfile and change `http://` to `https://` on your domain blocks. Caddy will obtain and renew certificates automatically.

**4. Start the stack:**

```bash
docker compose up -d
```

**5. Access Ghost admin:**

```
http://yourdomain.com/ghost
```

---

## Cloudflare Tunnel

This stack is configured for use behind a Cloudflare Tunnel, which handles SSL/TLS termination externally. Caddy serves HTTP only on port 80 locally. This is why `auto_https off` is set in the Caddyfile.

If you are running this on a cloud VPS with a public IP and want to point DNS directly at your server, remove `auto_https off` and let Caddy manage your certificates — it will handle everything automatically.

---

## Umami Analytics

The Caddyfile includes an optional block for routing a `umami.yourdomain.com` subdomain to a separately running Umami analytics container. Remove this block if you are not using Umami, or refer to the Umami stack in this repository.

---

## Notes

- Ghost content (themes, images, database) is stored in the `ghost-content` Docker volume
- Caddy certificates and config are stored in `caddy-data` and `caddy-config` volumes
- The stack uses an internal Docker network (`ghost-net`) — Ghost is not directly exposed to the host

---

Built and maintained by [Self Hosted Home UK](https://selfhostedhome.co.uk) — [@SelfHostHomeUK](https://x.com/SelfHostHomeUK)
