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
