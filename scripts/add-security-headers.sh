#!/bin/bash
# Inject security headers snippet into nginx site configs that are missing them
# Run with: sudo bash /srv/infra/scripts/add-security-headers.sh

set -euo pipefail

SNIPPET="    include snippets/security-headers.conf;"

inject_after_server_name() {
    local file=$1
    local marker=$2  # line to insert after (grep pattern)
    if ! grep -q "security-headers\|X-Frame-Options\|X-XSS-Protection" "$file"; then
        sed -i "/$marker/a\\$SNIPPET" "$file"
        echo "  ✓ Added to $file"
    else
        echo "  - Skipped $file (headers already present)"
    fi
}

echo "=== Adding security headers to nginx site configs ==="

# bench.perdrizet.org - insert after server_name line in HTTPS block
inject_after_server_name /etc/nginx/sites-available/bench.perdrizet.org "server_name bench.perdrizet.org;"

# headscale - insert after server_name in HTTPS block
inject_after_server_name /etc/nginx/sites-available/headscale "server_name headscale.perdrizet.org;"

# gpt.conf - has HSTS + nosniff but missing X-Frame-Options etc; replace with snippet
if ! grep -q "security-headers" /etc/nginx/sites-enabled/gpt.conf; then
    sed -i \
        -e '/add_header Strict-Transport-Security.*always;/d' \
        -e '/add_header X-Content-Type-Options.*always;/d' \
        /etc/nginx/sites-enabled/gpt.conf
    sed -i "/server_name gpt.perdrizet.org;/a\\$SNIPPET" /etc/nginx/sites-enabled/gpt.conf
    echo "  ✓ Replaced inline headers with snippet in gpt.conf"
fi

# perdrizet.conf (redirect-only, low priority but consistent)
inject_after_server_name /etc/nginx/conf.d/perdrizet.conf "server_name perdrizet.org www.perdrizet.org;"

echo ""
echo "Testing nginx configuration..."
nginx -t

echo "Reloading nginx..."
systemctl reload nginx

echo ""
echo "=== Security headers applied and nginx reloaded ==="
