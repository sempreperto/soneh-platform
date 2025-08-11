// apps/api/src/mqtt/mqtt.service.ts
import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import * as mqtt from 'mqtt'
import { BridgeService } from '../bridge/bridge.service'

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private client?: mqtt.MqttClient
  private readonly logger = new Logger('MqttService')

  constructor(
    private readonly config: ConfigService,
    private readonly bridge: BridgeService,
  ) {}

  async onModuleInit() {
    const url = this.config.get<string>('MQTT_URL')
    const username = this.config.get<string>('MQTT_USERNAME')
    const password = this.config.get<string>('MQTT_PASSWORD')
    const namespace = this.config.get<string>('MQTT_NAMESPACE') || 'soneh'

    this.client = mqtt.connect(url!, { username, password })

    this.client.on('connect', () => this.logger.log(`MQTT connected: ${url}`))
    this.client.on('error', (err) => this.logger.error('MQTT error', err as any))

    const topic = `${namespace}/+/+/state`
    this.logger.log(`Subscribing to ${topic}`)
    this.client.subscribe(topic, { qos: 1 })

    this.client.on('message', (topic, payload) => {
      // 1) Ignora retained vazio (“tombstone”)
      if (!payload || payload.length === 0) return

      // 2) Valida tópico: ns/{projectId}/{deviceId}/state
      const parts = topic.split('/')
      if (parts.length < 4) return
      const [ns, projectId, deviceId, leaf] = parts
      if (!ns || !projectId || !deviceId || leaf !== 'state') return

      // 3) Parse seguro do JSON
      let data: any
      try {
        data = JSON.parse(payload.toString('utf8'))
      } catch {
        return
      }

      this.bridge.handleState({ namespace: ns, projectId, deviceId, data })
    })
  }

  onModuleDestroy() {
    try { this.client?.end(true) } catch {}
  }

  publishCommand(projectId: string, deviceId: string, cmd: any) {
    if (!this.client) {
      this.logger.warn('MQTT ainda não conectado — ignorando publishCommand')
      return
    }
    if (!projectId || !deviceId) {
      this.logger.warn('publishCommand ignorado: projectId/deviceId vazio')
      return
    }
    const topic = `${this.config.get('MQTT_NAMESPACE')}/${projectId}/${deviceId}/cmd`
    this.client.publish(topic, JSON.stringify(cmd), { qos: 1 })
  }
}
