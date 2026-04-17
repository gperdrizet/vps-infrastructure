#!/bin/bash
# Apply nginx security hardening
# Run once with: sudo bash /srv/infra/scripts/apply-nginx-hardening.sh

set -euo pipefail

echo "=== Applying nginx security hardening ==="

# 1. Security headers snippet
echo "Installing security headers snippet..."
cp /srv/infra/configs/nginx/security-headers.conf /etc/nginx/snippets/security-headers.conf

# 2. Add rate limiting + request limits + timeouts to nginx.conf http block
echo "Adding rate limiting and request limits to nginx.conf..."
# Inject after 'server_tokens off;'
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    sed -i '/server_tokens off;/a\\n\t# Rate limiting zones\n\tlimit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;\n\tlimit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;\n\tlimit_conn_zone $binary_remote_addr zone=conn_limit:10m;\n\n\t# Request size limits\n\tclient_max_body_size 10M;\n\tclient_body_buffer_size 128k;\n\tclient_header_buffer_size 1k;\n\tlarge_client_header_buffers 4 8k;\n\n\t# Timeout hardening (prevents slowloris)\n\tclient_body_timeout 12;\n\tclient_header_timeout 12;\n\tkeepalive_timeout 15;\n\tsend_timeout 10;' /etc/nginx/nginx.conf
    echo "  Added rate limiting zones and request limits"
else
    echo "  Rate limiting already present, skipping"
fi

# 3. Test configuration
echo ""
echo "Testing nginx configuration..."
nginx -t

# 4. Reload nginx
echo "Reloading nginx..."
systemctl reload nginx

echo ""
echo "=== Nginx hardening complete ==="
echo ""
echo "Changes applied:"
echo "  - Security headers snippet: /etc/nginx/snippets/security-headers.conf"
echo "  - Rate limiting: 10r/s general, 30r/s API, max 10 concurrent conns"
echo "  - Request size limits: 10MB max body"
echo "  - Timeout hardening: 12s body/header, 15s keepalive, 10s send"
echo ""
echo "To add security headers to a site, add inside the server block:"
echo "  include snippets/security-headers.conf;"
