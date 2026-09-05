#!/usr/bin/env bash
set -euo pipefail
cd /home/gasper/storagecloud
# Read only the address; never source a file containing secrets as shell code.
lan_address=$(sed -n 's/^LAN_IP=//p' .env)
for domain in cloud.storagecloud.download photos.storagecloud.download; do
    echo "$domain: local resolver"
    dig @"$lan_address" "$domain" A +short
    echo "$domain: current system resolver"
    dig "$domain" A +short
    curl --fail --silent --show-error --resolve "$domain:443:$lan_address" \
        --output /dev/null --write-out 'Direct HTTPS: %{remote_ip}; TLS verify: %{ssl_verify_result}; HTTP: %{http_code}\n' "https://$domain"
done
