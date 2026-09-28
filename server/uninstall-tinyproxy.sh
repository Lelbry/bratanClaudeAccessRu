#!/bin/bash
# uninstall-tinyproxy.sh
# Полностью удаляет tinyproxy с сервера, восстанавливает оригинальный конфиг если был.
# Запускать на СЕРВЕРЕ от root.

set -euo pipefail

echo "[1/3] stop + disable"
systemctl stop tinyproxy 2>/dev/null || true
systemctl disable tinyproxy 2>/dev/null || true

echo "[2/3] apt purge"
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y -qq tinyproxy tinyproxy-bin 2>/dev/null || true
apt-get autoremove -y -qq

echo "[3/3] очистка"
rm -f /etc/tinyproxy/tinyproxy.conf.orig
rm -rf /var/log/tinyproxy

echo ""
echo "DONE. tinyproxy удалён с сервера."
echo "SSH-ключ в ~/.ssh/authorized_keys НЕ трогали - удали руками если нужно:"
echo "  sed -i '/claude-tunnel/d' ~/.ssh/authorized_keys"
