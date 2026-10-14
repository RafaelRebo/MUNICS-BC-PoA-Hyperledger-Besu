#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "=========================================="
echo " Deteniendo Hyperledger Besu"
echo "=========================================="

# 1. Detener contenedores
docker compose stop

# 2. Limpieza de locl
rm -f .quorumDevQuickstart.lock

echo "[✓] Red Hyperledger Besu detenida"
