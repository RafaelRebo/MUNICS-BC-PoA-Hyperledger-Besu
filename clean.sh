#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "=========================================="
echo " ATENCIÓN: Restablecimiento total de la red"
echo "=========================================="
read -p "¿Confirmas la eliminación irreversible de todos los datos de la red? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi

# 1. Parar contenedores y eliminarlos
echo "[+] Eliminando contenedores y redes..."
docker compose down -v --remove-orphans

# 2. Purgar contenedores asociados
docker rm -f chainlensredis 2>/dev/null || true

# 3. Eliminar ficheros y registros locales
echo "[+] Eliminando archivos de registro..."
rm -f .quorumDevQuickstart.lock
rm -rf ./logs/besu/*

mkdir -p ./logs/besu

echo "=========================================="
echo " [✓] Entorno reiniciado por completo."
echo "=========================================="
