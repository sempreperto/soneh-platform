00000000000,,,,
















































0
0

#!/usr/bin/env bash
set -euo pipefail

# Detecta a raiz do repo (onde tem apps/api/src)
if [ -d "./apps/api/src" ]; then
  ROOT="."
elif [ -d "../apps/api/src" ]; then
  ROOT=".."
else
  echo "❌ Rode este script dentro do monorepo (onde existe apps/api/src)."
  exit 1
fi

echo "➡️  Atualizando BridgeService (guardar último state + stream por projeto)..."
cat > "$ROOT/apps/api/src/bridge/bridge.service.ts" <<'TS'
import { Injectable, Logger } from '@nestjs/common'
import { Subject, Observable } from 'rxjs'

@Injectable()
export class BridgeService {
  private readonly logger = new Logger('BridgeService')
  private readonly lastStates = new Map<string, any>()
  private readonly projectStreams = new Map<string, Subject<{ deviceId: string; data: any }>>()

  handleState(input: { namespace: string; projectId: string; deviceId: string; data: any }) {
    const { projectId, deviceId, data } = input
    if (!projectId || !deviceId) return
    try {
      const key = `${projectId}:${deviceId}`
      this.lastStates.set(key, data)

      let stream = this.projectStreams.get(projectId)
      if (!stream) {
        stream = new Subject<{ deviceId: string; data: any }>()
        this.projectStreams.set(projectId, stream)
      }
      stream.next({ deviceId, data })
    } catch (e) {
      this.logger.error('Bridge broadcast error')
      this.logger.error(e as any)
    }
  }

  getLastState(projectId: string, deviceId: string) {
    return this.lastStates.get(`${projectId}:${deviceId}`) ?? null
  }

  observeProject(projectId: string): Observable<{ deviceId: string; data: any }> {
    let stream = this.projectStreams.get(projectId)
    if (!stream) {
      stream = new Subject<{ deviceId: string; data: any }>()
      this.projectStreams.set(projectId, stream)
    }
    return stream.asObservable()
  }
}
TS

echo "➡️  Atualizando DevicesController (SSE /api/devices/stream)..."
cat > "$ROOT/apps/api/src/devices/devices.controller.ts" <<'TS'
import {
  Controller, Get, Post, Body, Param, NotFoundException,
  BadRequestException, Sse, MessageEvent, Query
} from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { Observable, map } from 'rxjs'
import { MqttService } from '../mqtt/mqtt.service'
import { DevicesService } from './devices.service'
import { BridgeService } from '../bridge/bridge.service'

@Controller('devices')
export class DevicesController {
  private readonly ns: string

  constructor(
    private readonly devices: DevicesService,
    private readonly mqtt: MqttService,
    private readonly config: ConfigService,
    private readonly bridge: BridgeService,
  ) {
    this.ns = this.config.get<string>('MQTT_NAMESPACE') || 'soneh'
  }

  @Get()
  async list() {
    // adapte ao seu service real
    return (this.devices as any).findAll?.() ?? []
  }

  @Post()
  async create(@Body() body: any) {
    // adapta ao seu service real
    return (this.devices as any).create?.(body)
  }

  @Post(':id/command')
  async sendCommand(@Param('id') id: string, @Body() body: any) {
    if (!id) throw new BadRequestException('device id required')
    const device = await (this.devices as any).findById?.(id)
    if (!device) throw new NotFoundException()
    if (!body || typeof body.action !== 'string') {
      throw new BadRequestException('invalid command payload')
    }
    const cmd = { action: body.action, value: body.value }
    this.mqtt.publishCommand(device.projectId, device.id, cmd)
    return { ok: true, topic: `${this.ns}/${device.projectId}/${device.id}/cmd` }
  }

  // SSE: /api/devices/stream?projectId=proj1
  @Sse('stream')
  stream(@Query('projectId') projectId: string): Observable<MessageEvent> {
    if (!projectId) throw new BadRequestException('projectId required')
    return this.bridge.observeProject(projectId).pipe(
      map(({ deviceId, data }) => ({
        type: 'state',
        data: { deviceId, state: data },
      }))
    )
  }
}
TS

echo "➡️  Criando página web simples (Nginx estático) em apps/web/public/index.html..."
mkdir -p "$ROOT/apps/web/public"
cat > "$ROOT/apps/web/public/index.html" <<'HTML'
<!doctype html>
<html lang="pt-br">
  <head>
    <meta charset="utf-8" />
    <title>Soneh — Realtime</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Arial, "Apple Color Emoji","Segoe UI Emoji"; margin: 2rem; }
      .row { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
      input, button { padding: .5rem .75rem; font-size: 14px; }
      button { cursor: pointer; }
      ul { list-style: none; padding: 0; }
      li { padding: .35rem .5rem; background: #f5f5f5; margin-bottom: .35rem; border-radius: 6px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; }
      .muted { color: #666; }
      .ok { color: #0a7; }
    </style>
  </head>
  <body>
    <h1>Soneh — Realtime</h1>
    <p class="muted">Escutando <code>/api/devices/stream?projectId=proj1</code> (SSE) e enviando comandos para <code>/api/devices/:id/command</code>.</p>

    <div class="row">
      <label for="dev">DEV_ID:</label>
      <input id="dev" placeholder="ex: x6op7ppr4j" />
      <button id="on">Relay ON</button>
      <button id="off">Relay OFF</button>
      <button id="ping">Publicar state fake</button>
    </div>

    <ul id="log"></ul>

    <script>
      const $log = document.getElementById('log');
      const $dev = document.getElementById('dev');
      const log = (msg) => {
        const li = document.createElement('li');
        li.textContent = msg;
        $log.prepend(li);
      };

      // SSE
      const es = new EventSource('/api/devices/stream?projectId=proj1');
      es.onopen = () => log('[SSE] conectado');
      es.onerror = () => log('[SSE] erro (verifique API)');
      es.onmessage = (ev) => {
        try {
          const data = JSON.parse(ev.data);
          log(`[state] ${data.deviceId} -> ${JSON.stringify(data.state)}`);
        } catch {}
      };

      async function sendCmd(value) {
        const id = $dev.value.trim();
        if (!id) return alert('Informe DEV_ID');
        const res = await fetch(`/api/devices/${id}/command`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ action: 'relay', value })
        });
        const j = await res.json();
        if (res.ok) {
          log(`[cmd] ${id} -> relay:${value} ✅ (${j.topic})`);
        } else {
          log(`[cmd] erro: ${res.status} ${JSON.stringify(j)}`);
        }
      }

      document.getElementById('on').onclick = () => sendCmd(true);
      document.getElementById('off').onclick = () => sendCmd(false);

      // botão "ping": publica um state fake via API? (não — aqui só chama EMQX direto)
      document.getElementById('ping').onclick = async () => {
        const id = $dev.value.trim();
        if (!id) return alert('Informe DEV_ID');
        // dica: no terminal, rode: docker run --rm --network host efrecon/mqtt-client pub -h localhost -p 1883 -t "soneh/proj1/DEV/state" -m '{"relay":true,"ts":1690000000}' -r
        alert('Para "pingar", publique um state via MQTT (vide comentário no código).');
      };
    </script>
  </body>
</html>
HTML

echo "➡️  Rebuild e up de API + WEB..."
cd "$ROOT/infra"
docker compose up -d --build web api

echo "✅ Pronto!"
echo
echo "Abra:  http://localhost"
echo "SSE:   /api/devices/stream?projectId=proj1"
echo
echo "Dica de teste rápido:"
echo "  DEV_ID=\$(curl -s -X POST http://localhost:3001/api/devices -H 'content-type: application/json' -d '{\"projectId\":\"proj1\",\"name\":\"Sala\",\"type\":\"RELAY\"}' | jq -r .id)"
echo "  docker run --rm --network host efrecon/mqtt-client pub -h localhost -p 1883 -t \"soneh/proj1/\$DEV_ID/state\" -m '{\"relay\":true,\"ts\":'\"\$(date +%s)\"'}' -r"

