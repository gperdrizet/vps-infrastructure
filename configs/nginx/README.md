# Nginx Configuration Management

## Directory Structure

```
/srv/infra/configs/nginx/
└── sites-available/
    ├── bench.perdrizet.org      # Bench application
    ├── blue.conf                # LogKeep blue slot
    ├── green.conf               # LogKeep green slot
    ├── staging.conf             # LogKeep staging
    ├── headscale                # Headscale VPN admin
    ├── gpt.conf                 # GPT/LLM service
    ├── matrix.perdrizet.org     # Matrix server (historical)
    └── prism.perdrizet.org      # Prism service (historical)
```

## Active Sites

Current nginx configuration in `/etc/nginx/sites-enabled/`:
- `bench.perdrizet.org` → http://127.0.0.1:8010
- `gpt.conf` → (check config for upstream)
- `headscale` → (Headscale service)
- `staging.conf` → LogKeep staging app

## SSL Certificates

Managed by **Let's Encrypt** via certbot:
- Auto-renewal enabled via systemd timer
- Certificates stored in `/etc/letsencrypt/live/`
- Nginx configs reference certs with "managed by Certbot" comments

### Renewal Process
```bash
# Check certificate status
sudo certbot certificates

# Manual renewal (not Usually needed - auto-renews)
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

## Configuration Management

### Current State (Phase 3)
- **Source files**: `/srv/infra/configs/nginx/sites-available/`
- **Active configs**: `/etc/nginx/sites-enabled/` (symlinks)
- **System config**: `/etc/nginx/sites-available/` (current location)

### Workflow
1. Edit configs in `/srv/infra/configs/nginx/sites-available/`
2. Copy to `/etc/nginx/sites-available/`
3. Create symlink in `/etc/nginx/sites-enabled/`
4. Test: `sudo nginx -t`
5. Reload: `sudo systemctl reload nginx`
6. Commit changes to vps-infrastructure git repo

### Adding a New Site

```bash
# 1. Create config
vim /srv/infra/configs/nginx/sites-available/example.com

# 2. Copy to nginx directory
sudo cp /srv/infra/configs/nginx/sites-available/example.com /etc/nginx/sites-available/

# 3. Enable site
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# 4. Get SSL certificate
sudo certbot --nginx -d example.com

# 5. Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

### Removing a Site

```bash
# 1. Disable site
sudo rm /etc/nginx/sites-enabled/example.com

# 2. Reload nginx
sudo systemctl reload nginx

# 3. Revoke certificate (optional)
sudo certbot revoke --cert-name example.com

# 4. Archive config
mv /srv/infra/configs/nginx/sites-available/example.com \
   /srv/infra/configs/nginx/sites-available/.archived/
```

## Standard Configuration Template

```nginx
server {
    server_name example.com;

    # Logging
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Proxy settings
    location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        
        proxy_pass http://127.0.0.1:PORT;
        
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # SSL configuration (added by certbot)
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}
```

## Security Best Practices

1. **SSL/TLS** - All sites must use HTTPS (certbot managed)
2. **Headers** - Include security headers (X-Forwarded-For, X-Forwarded-Proto)
3. **Upstream** - Only bind to 127.0.0.1 for application ports
4. **Logs** - Separate access/error logs per site
5. **Updates** - Keep nginx and certbot updated

## Monitoring

Nginx metrics exported to Prometheus via:
- **monitoring-nginx-exporter** (port 9113)
- Scraped by monitoring-prometheus
- Alerts configured for:
  - High error rates
  - Certificate expiration (< 30 days)
  - Service unavailability

## Troubleshooting

```bash
# Check nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/error.log

# View site-specific logs
sudo tail -f /var/log/nginx/SITENAME.access.log

# Reload configuration
sudo systemctl reload nginx

# Restart nginx
sudo systemctl restart nginx

# Check SSL certificate
sudo certbot certificates

# Check which ports are listening
sudo ss -tlnp | grep nginx
```

## Future Improvements

- [ ] Containerize nginx (optional - current systemd setup works well)
- [ ] Centralized logging to Loki (currently file-based)
- [ ] Rate limiting configuration
- [ ] WAF/ModSecurity integration
- [ ] HTTP/3 support
- [ ] Automated config testing in CI/CD

## References

- Nginx docs: https://nginx.org/en/docs/
- Let's Encrypt: https://letsencrypt.org/docs/
- Certbot: https://eff-certbot.readthedocs.io/
