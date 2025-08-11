#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# Soneh • Sprint1 • Setup & Validação End-to-End
# - Sobe docker-compose
# - Aguarda /health
# - Cria device
# - Publica state (retained)
# - Envia command e mostra tópico
# ------------------------------------------------------------

red()  { printf "\033[31m%s\033[0m\n" "$*" ; }
grn()  { printf "\033[32m%s\033[0m\n" "$*" ; }
ylw()  { printf "\033[33m%s\033[0m\n" "$*" ; }
blu()  { printf "\033[34m%s\033[0m\n" "$*" ; }
die()  { red "✖ $*"; exit 1; }

# 1) Detecta docker-compose.yml
if [[ -f "./infra/docker-compose.yml" ]]; then
  COMPOSE="./infra/docker-compose.yml"
  (cd infra && docker compose up -d --build)
elif [[ -f "./docker-compose.yml" ]]; then
  COMPOSE="./docker-compose.yml"
  docker compose up -d --build
else
  die "docker-compose.yml não encontrado (procurei em ./infra/ e ./)"
fi

# 2) Descobre URL da API
API_BASE="http://localhost:3001/api"
if curl -sSf "${API_BASE}/health" >/dev/null 2>&1; then
  :
else
  # tenta via Caddy
  API_BASE="http://localhost/api"
fi
ylw "API base: ${API_BASE}"

# 3) Aguarda /health ficar ok
ylw "Aguardando API ficar OK..."
for i in {1..60}; do
  if curl -sSf "${API_BASE}/health" >/dev/null 2>&1; then
    grn "✓ API OK"
    break
  fi
  sleep 2
  [[ $i -eq 60 ]] && die "API não respondeu a tempo"
done

# 4) Cria um device
ylw "Criando device..."
set +e
DEV_ID=$(curl -s -X POST "${API_BASE}/devices" \
  -H 'content-type: application/json' \
  -d '{"projectId":"proj1","name":"Sala","type":"RELAY"}' \
  | jq -r .id | tr -d '\r\n')
set -e

if [[ -z "${DEV_ID}" || "${DEV_ID}" == "null" ]]; then
  ylw "Não consegui criar device agora. Tentando listar existentes..."
  DEV_ID=$(curl -s "${API_BASE}/devices" | jq -r '.[-1].id' | tr -d '\r\n')
fi
[[ -z "${DEV_ID}" || "${DEV_ID}" == "null" ]] && die "Sem DEV_ID. Abortando."

grn "✓ DEV_ID=${DEV_ID}"

# 5) Detecta como publicar no MQTT
USE_NETWORK_HOST=0
if docker network ls --format '{{.Name}}' | grep -q '^infra_default$'; then
  MQTT_DOCKER_RUN=(docker run --rm --network infra_default efrecon/mqtt-client)
  MQTT_HOST="emqx"
  MQTT_PORT_OPT=()
else
  MQTT_DOCKER_RUN=(docker run --rm --network host efrecon/mqtt-client)
  MQTT_HOST="localhost"
  MQTT_PORT_OPT=(-p 1883)
  USE_NETWORK_HOST=1
fi

# 6) Publica um state (retido)
ylw "Publicando state retained via MQTT..."
TS=$(date +%s)
"${MQTT_DOCKER_RUN[@]}" pub -h "${MQTT_HOST}" "${MQTT_PORT_OPT[@]}" \
  -t "soneh/proj1/${DEV_ID}/state" \
  -m "{\"relay\":true,\"ts\":${TS}}" -r

grn "✓ State publicado"

# 7) Assina (em background) para capturar 1 cmd
ylw "Abrindo subscriber (captura 1 msg)..."
("${MQTT_DOCKER_RUN[@]}" sub -h "${MQTT_HOST}" "${MQTT_PORT_OPT[@]}" \
  -t "soneh/proj1/${DEV_ID}/#" -v -C 1) &
SUB_PID=$!

# 8) Envia command via API
ylw "Enviando command via API..."
RESP=$(curl -s -X POST "${API_BASE}/devices/${DEV_ID}/command" \
  -H 'content-type: application/json' \
  -d '{"action":"relay","value":false}') || true
echo "${RESP}" | jq . || echo "${RESP}"

wait "${SUB_PID}" || true

grn "✓ FIM — validação concluída"
echo
blu "Resumo:"
echo "  API.........: ${API_BASE}"
echo "  DEV_ID......: ${DEV_ID}"
if [[ $USE_NETWORK_HOST -eq 1 ]]; then
  echo "  MQTT........: host (localhost:1883)"
else
  echo "  MQTT........: docker net (infra_default → emqx:1883)"
fi
