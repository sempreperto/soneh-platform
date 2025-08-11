// apps/api/src/devices/devices.controller.v2.ts
// Copie os métodos abaixo para o seu devices.controller.ts existente.
// Adições: GET /devices/:id/state e SSE /devices/stream?projectId=...
import { Controller, Get, Post, Body, Param, NotFoundException, BadRequestException, Sse, MessageEvent, Query } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { MqttService } from '../mqtt/mqtt.service'
import { DevicesService } from './devices.service'
import { deviceEvents$, getLastState } from '../realtime/bus'
import { filter, map } from 'rxjs/operators'
import { Observable } from 'rxjs'

@Controller('devices')
export class DevicesControllerV2 {
  private readonly ns: string
  constructor(
    private readonly devices: DevicesService,
    private readonly mqtt: MqttService,
    private readonly config: ConfigService,
  ) {
    this.ns = this.config.get<string>('MQTT_NAMESPACE') || 'soneh'
  }

  @Get(':id/state')
  async getState(@Param('id') id: string) {
    const device = await (this.devices as any).findById?.(id)
    if (!device) throw new NotFoundException()
    const state = getLastState(device.projectId, device.id)
    return { id: device.id, projectId: device.projectId, state }
  }

  @Sse('stream')
  stream(@Query('projectId') projectId: string): Observable<MessageEvent> {
    if (!projectId) {
      // stream vazio (evita fechar conexão)
      return new Observable<MessageEvent>((subscriber) => {})
    }
    return deviceEvents$.pipe(
      filter((e) => e.projectId === projectId),
      map((e) => ({
        data: { type: 'device-state', deviceId: e.deviceId, projectId: e.projectId, state: e.data } as any,
      })),
    )
  }
}
