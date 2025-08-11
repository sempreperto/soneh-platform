#!/usr/bin/env bash
set -euo pipefail
echo "[1/3] docker compose down -v --remove-orphans"
docker compose down -v --remove-orphans || true

echo "[2/3] Removendo containers com nome 'soneh-*' remanescentes (se houver)"
ids=$(docker ps -aq -f "name=soneh-") || true
if [ -n "${ids}" ]; then
  docker rm -f ${ids}
fi

echo "[3/3] Prune de redes/volumes órfãos (opcional)"
docker network prune -f || true
docker volume prune -f || true

echo "Pronto. Agora rode: docker compose up -d --build"
