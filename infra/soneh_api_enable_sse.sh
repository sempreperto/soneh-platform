#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"  # deve estar em ~/soneh/infra

API_DIR=apps/api/src
mkdir -p "$API_DIR"

# Backup do index.js atual (se existir)
if [ -f "$API_DIR/index.js" ]; then
  cp -f "$API_DIR/index.js" "$API_DIR/index.js.bak.$(date +%s)"
fi

# -------- escreve um index.js completo com SSE + MQTT + devices/command --------
cat > "$API_DIR/index.js" <<'JS'
/* Minimal Soneh API c/ SSE + MQTT (Express) */
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const mqtt = require('mqtt');

const PORT = process.env.PORT || 3001;
const MQTT_URL = process.env.MQTT_URL || 'mqtt://emqx:1883';
const MQTT_USERNAME = process.env.MQTT_USERNAME || undefined;
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || undefined;
const NS = process.env.MQTT_NAMESPACE || 'soneh';

const app = express();
app.use(cors({ origin: '*' }));
app.use(bodyParser.json());

/* ------- storage em memória para/dev ------- */
const devices = []; // {id, projectId, name, type, createdAt, lastState}
const byId = (id) => devices.find(d => d.id === id);

/* ------- util ------- */
const sid = () => Math.random().toString(36).slice(2, 12);

/* ------- MQTT ------- */
const mClient = mqtt.connect(MQTT_URL, { username: MQTT_USERNAME, password: MQTT_PASSWORD });
mClient.on('connect', () => {
  console.log('[MqttService] connected:', MQTT_URL);
  const topic = `${NS}/+/+/state`;
  console.log('[MqttService] subscribing to', topic);
  mClient.subscribe(topic, { qos: 1 });
});
mClient.on('error', (e) => console.error('[MqttService] error', e?.message || e));

/* ------- SSE (por projeto) ------- */
const streams = new Map(); // projectId -> Set(res)

function sseAdd(projectId, res) {
  if (!streams.has(projectId)) streams.set(projectId, new Set());
  streams.get(projectId).add(res);
}

function sseRemove(projectId, res) {
  const set = streams.get(projectId);
  if (!set) return;
  set.delete(res);
  if (set.size === 0) streams.delete(projectId);
}

function broadcast(projectId, event, payload) {
  const set = streams.get(projectId);
  if (!set) return;
  const data = `event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`;
  for (const res of set) res.write(data);
}

/* ------- MQTT -> SSE bridge ------- */
mClient.on('message', (topic, buf) => {
  try {
    if (!buf || buf.length === 0) return;
    const parts = topic.split('/');
    if (parts.length < 4) return;
    const [ns, projectId, deviceId, leaf] = parts;
    if (leaf !== 'state' || !projectId || !deviceId) return;

    const data = JSON.parse(buf.toString('utf8'));
    const d = byId(deviceId);
    if (d) d.lastState = data;

    // envia para ouvintes SSE do projeto
    broadcast(projectId, 'device-state', { deviceId, state: data, ts: Date.now() });
    console.log('[Bridge] state', `${projectId}/${deviceId}:`, data);
  } catch (_) {}
});

/* ------- HTTP endpoints ------- */
app.get('/api/health', (_req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

// lista devices
app.get('/api/devices', (_req, res) => res.json(devices));

// cria device
app.post('/api/devices', (req, res) => {
  const { projectId = 'proj1', name = 'Device', type = 'RELAY' } = req.body || {};
  const d = { id: sid(), projectId, name, type, createdAt: new Date().toISOString() };
  devices.push(d);
  res.status(201).json(d);
});

// envia command -> publica MQTT
app.post('/api/devices/:id/command', (req, res) => {
  const dev = byId(req.params.id);
  if (!dev) return res.status(404).json({ message: 'device not found' });
  const { action, value } = req.body || {};
  if (!action) return res.status(400).json({ message: 'action required' });
  const topic = `${NS}/${dev.projectId}/${dev.id}/cmd`;
  mClient.publish(topic, JSON.stringify({ action, value }), { qos: 1 });
  return res.json({ ok: true, topic });
});

// SSE por projeto: /api/devices/stream?projectId=proj1
app.get('/api/devices/stream', (req, res) => {
  const projectId = String(req.query.projectId || 'proj1');

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
  });
  res.write(': connected\n\n'); // comentário inicial
  sseAdd(projectId, res);

  req.on('close', () => sseRemove(projectId, res));
});

app.listen(PORT, () => console.log('[API] listening on :' + PORT, 'env MQTT_URL=' + MQTT_URL, 'NS=' + NS));
JS
# -------- fim do index.js --------

echo "🔧 Rebuild apenas da API..."
docker compose up -d --build api >/dev/null

echo "⏳ Aguardando API..."
for i in $(seq 1 20); do
  if curl -fsS http://localhost:3001/api/health >/dev/null; then
    echo "✅ API OK"
    break
  fi
  sleep 1
done

echo "🔎 Testando cabeçalhos SSE..."
curl -sI "http://localhost/api/devices/stream?projectId=proj1" | sed -n '1,8p'
echo "Pronto. Recarregue a página Realtime."
