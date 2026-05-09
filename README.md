# selfhostedhomeuk-scripts

Custom configurations, Docker stacks, and automation scripts for the home hosting setup detailed at [selfhostedhome.co.uk](https://selfhostedhome.co.uk).

## 🌍 Overview
This repository contains the infrastructure-as-code and supporting scripts for my hybrid UK-based home lab. It is designed to sync across a **Lenovo Server** (Primary) and a **selfhostedpi** (Raspberry Pi).

## 🛠 Hardware Environment
*   **Lenovo Server:** Ubuntu-based core hosting native services and heavy Docker workloads.
*   **selfhostedpi:** Raspberry Pi handling network services and automated backup redundancy.

## 📂 Project Structure
*   **`docker/`**: Categorised YAML stacks.
    *   `ghost/`: CMS for the blog.
    *   `umami/`: Privacy-focused analytics.
*   **`scripts/`**: Automation logic.
    *   `plex/`: Backup scripts and cron examples for native Plex installations.
    *   `networking/`: WireGuard and VPN switching logic.
    *   `backups/`: General system maintenance and sync scripts.

## 🚀 Getting Started
1. **Clone the repo:**
   ```bash
   git clone [https://github.com/YOUR_USERNAME/selfhostedhomeuk-scripts.git](https://github.com/YOUR_USERNAME/selfhostedhomeuk-scripts.git)
   
