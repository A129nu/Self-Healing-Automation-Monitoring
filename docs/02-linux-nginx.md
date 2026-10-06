# Phase 2 — Linux and Nginx

Install Ubuntu updates and Nginx, create the Azure Self-Healing Monitoring System HTML page, verify Nginx with systemd and curl, and confirm HTTP access from the VM public IP.

Key commands:
```bash
sudo apt update
sudo apt install nginx -y
sudo systemctl status nginx
curl http://127.0.0.1/
```
