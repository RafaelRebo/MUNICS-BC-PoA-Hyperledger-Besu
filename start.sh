#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "=========================================="
echo " Iniciando Hyperledger Besu (QBFT)"
echo "=========================================="

if [ -f .quorumDevQuickstart.lock ]; then
	rm -f .quorumDevQuickstart.lock
fi

mkdir -p ./logs/besu


# 3. Levantar contenedores Docker Compose
echo "[+] Desplegando servicios con Docker Compose..."
docker compose up -d

# 4. Esperar arranque e inicialización básica
echo "[*] Verificando arranque de servicios..."
sleep 7

# 5. Comprobar disponibilidad de rpcnode
if docker ps --filter "name=rpcnode" --filter "status=running" | grep -q rpcnode; then
    echo "[✓] Nodo RPC operativo en http://localhost:8545"
else
    echo "[X] rpcnode no parece estar en ejecución"
fi

# 6. Comprobar Chainlens
if docker ps --filter "name=chainlensnginx" --filter "status=running" | grep -q chainlensnginx; then
    echo "[✓] Chainlens activo en http://localhost:8081"
fi

echo "=========================================="
echo " Despliegue completado"
echo "=========================================="
