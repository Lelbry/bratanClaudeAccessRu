#!/bin/bash
# install-tinyproxy.sh
# Ставит tinyproxy на Debian/Ubuntu сервер и подкладывает наш конфиг.
# Запускать на СЕРВЕРЕ от root.
#
# Использование:
#   scp -i <KEY> tinyproxy.conf install-tinyproxy.sh root@<SERVER_IP>:/tmp/
#   ssh -i <KEY> root@<SERVER_IP> "bash /tmp/install-tinyproxy.sh"

set -euo pipefail

CONF_SRC="${1:-/tmp/tinyproxy.conf}"
CONF_DST="/etc/tinyproxy/tinyproxy.conf"

if [ ! -f "$CONF_SRC" ]; then
    echo "ERROR: config not found at $CONF_SRC"
    echo "Положи tinyproxy.conf рядом или передай путь первым аргументом"
    exit 1
fi

echo "[1/4] apt install tinyproxy"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq tinyproxy

echo "[2/4] backup оригинального конфига"
if [ ! -f "${CONF_DST}.orig" ]; then
    cp "$CONF_DST" "${CONF_DST}.orig"
fi

echo "[3/4] подкладываем наш конфиг"
cp "$CONF_SRC" "$CONF_DST"

echo "[4/4] restart + enable"
systemctl restart tinyproxy
systemctl enable tinyproxy

sleep 1
echo ""
echo "=== Статус ==="
systemctl is-active tinyproxy
ss -tlnp | grep 8888 || echo "WARN: не слушает 8888"

echo ""
echo "=== Локальный тест (должно быть HTTP 200/301/401) ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" -x http://127.0.0.1:8888 https://api.anthropic.com/ --max-time 10

echo ""
echo "DONE. tinyproxy слушает 127.0.0.1:8888, доступен только через SSH-туннель."
