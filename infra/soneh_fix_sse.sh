#!/usr/bin/env bash
set -euo pipefail

# 0) Segurança: rodar no diretório infra
cd "$(dirname "$0")"

echo "🔧 Regravando ../apps/api/src/index.js (SSE limpo)..."
cat > ../apps/api/src/index.js <<'JS'
// Minimal API (Express) + MQTT bridge + SSE
import express from 'express'
import cors from 'cors'
import morgan from 'morgan'
import mqtt from 'mqtt'

const PORT = process.env.PORT || 3001
const MQTT_URL = process.env.MQTT_URL || 'mqtt://emqx:1883'
const MQTT_USERNAME = process.env.MQTT_USERNAME || undefined
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || undefined
const MQTT_NAMESPACE = process.env.MQTT_NAMESPACE || 'soneh'

const app = express()
app.use(cors({ origin: '*' }))
app.use(express.json())
app.use(morgan('dev'))

// In-memory MVP
const devices = new Map()    // id -> { id, projectId, name, type, createdAt }
const streams = new Map()    // projectId -> Set<res>
const rid = () => Math.random().toString(36).slice(2, 11)

// ---------- MQTT ----------
const client = mqtt.connect(MQTT_URL, {
  username: MQTT_USERNAME,
  password: MQTT_PASSWORD,
  reconnectPeriod: 1000,
})

client.on('connect', () => {
  console.log(`[MqttService] connected: ${MQTT_URL}`)
  const topic = `${MQTT_NAMESPACE}/+/+/state`
  client.subscribe(topic, { qos: 1 }, err => {
    if (err) console.error('[MqttService] subscribe error', err)
    else console.log(`[MqttService] subscribing to ${topic}`)
  })
})

client.on('error', (err) => console.error('[MqttService] error', err?.message || err))

function broadcast(projectId, event, data) {
  const set = streams.get(projectId)
  if (!set || set.size === 0) return
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
  for (const res of set) { try { res.write(payload) } catch {} }
}

client.on('message', (topic, payload) => {
  if (!payload || payload.length === 0) return
  const parts = topic.split('/')
  if (parts.length < 4) return
  const [ns, projectId, deviceId, leaf] = parts
  if (!ns || !projectId || !deviceId || leaf !== 'state') return

  let data; try { data = JSON.parse(payload.toString('utf8')) } catch { return }

  console.log('[Bridge] state %s/%s: %o', projectId, deviceId, data)
  if (!devices.has(deviceId)) {
    devices.set(deviceId, {
      id: deviceId, projectId, name: `Device ${deviceId}`,
      type: 'RELAY', createdAt: new Date().toISOString(),
    })
  }
  broadcast(projectId, 'device-state', { projectId, deviceId, state: data })
})

// ---------- API ----------
app.get('/api/health', (_req, res) =>
  res.json({ status: 'ok', time: new Date().toISOString() })
)

app.get('/api/devices', (_req, res) =>
  res.json(Array.from(devices.values()))
)

app.post('/api/devices', (req, res) => {
  const { projectId, name, type } = req.body || {}
  if (!projectId) return res.status(400).json({ error: 'projectId required' })
  const id = rid()
  const dev = { id, projectId, name: name || 'Device', type: type || 'RELAY', createdAt: new Date().toISOString() }
  devices.set(id, dev)
  return res.status(201).json(dev)
})

app.post('/api/devices/:id/command', (req, res) => {
  const id = req.params.id
  const dev = devices.get(id)
  if (!dev) return res.status(404).json({ error: 'device not found' })
  const cmd = { action: req.body?.action, value: req.body?.value }
  if (!cmd.action) return res.status(400).json({ error: 'action required' })
  const topic = `${MQTT_NAMESPACE}/${dev.projectId}/${dev.id}/cmd`
  client.publish(topic, JSON.stringify(cmd), { qos: 1 }, (err) => {
    if (err) return res.status(500).json({ error: 'mqtt publish failed' })
    return res.json({ ok: true, topic })
  })
})

// SSE: /api/devices/stream?projectId=proj1
app.get('/api/devices/stream', (req, res) => {
  const projectId = req.query.projectId
  if (!projectId) return res.status(400).json({ error: 'projectId required' })
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.setHeader('X-Accel-Buffering', 'no') // evita buffering em proxies
  res.flushHeaders?.()
  res.write(': connected\n\n')

  let set = streams.get(projectId)
  if (!set) { set = new Set(); streams.set(projectId, set) }
  set.add(res)

  const ka = setInterval(() => { try { res.write(': keepalive\n\n') } catch {} }, 15000)
  req.on('close', () => {
    clearInterval(ka)
    set.delete(res)
    if (set.size === 0) streams.delete(projectId)
  })
})

app.listen(PORT, () => {
  console.log(`[API] listening on :${PORT}`)
  console.log(`[API] env MQTT_URL=${MQTT_URL} NS=${MQTT_NAMESPACE}`)
})
JS

echo "🧱 Rebuild API (sem cache) e subir..."
docker compose build --no-cache api >/dev/null
docker compose up -d api >/dev/null

# Espera a API responder
echo "⏳ Aguardando API /api/health..."
for i in {1..30}; do
  if curl -fsS http://localhost:3001/api/health >/dev/null; then
    echo "✅ API OK"; break
  fi
  sleep 1
done

echo "🔎 Teste SSE direto (porta 3001):"
curl -iN "http://localhost:3001/api/devices/stream?projectId=proj1" --max-time 3 | sed -n '1,12p'

echo "🔎 Teste SSE via Caddy (porta 80):"
curl -iN "http://localhost/api/devices/stream?projectId=proj1" --max-time 3 | sed -n '1,12p'

echo "➕ Criando device de teste..."
DEV_ID="$(curl -s -X POST http://localhost:3001/api/devices \
  -H 'content-type: application/json' \
  -d '{"projectId":"proj1","name":"Sala","type":"RELAY"}' | jq -r .id)"
echo "DEV_ID=${DEV_ID}"

echo "📤 Publicando state retained..."
docker run --rm --network host efrecon/mqtt-client \
  pub -h localhost -p 1883 -t "soneh/proj1/${DEV_ID}/state" \
  -m "{\"relay\":true,\"ts\":$(date +%s)}" -r

echo "📥 Enviando command..."
curl -s "http://localhost:3001/api/devices/${DEV_ID}/command" \
  -H 'content-type: application/json' \
  -d '{"action":"relay","value":false}'
echo
