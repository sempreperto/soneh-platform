import { Injectable } from '@nestjs/common'

export type DeviceType = 'RELAY' | 'SENSOR' | 'CAMERA'
export interface Device {
  id: string
  projectId: string
  name: string
  type: DeviceType
  createdAt: Date
}

@Injectable()
export class DevicesService {
  private readonly items = new Map<string, Device>()

  async findAll(): Promise<Device[]> {
    return Array.from(this.items.values())
  }

  async create(input: { projectId: string; name: string; type: DeviceType }): Promise<Device> {
    if (!input?.projectId) throw new Error('projectId required')
    const id = Math.random().toString(36).slice(2, 12) // id simples p/ dev
    const device: Device = {
      id,
      projectId: input.projectId,
      name: input.name ?? 'Device',
      type: input.type ?? 'RELAY',
      createdAt: new Date(),
    }
    this.items.set(id, device)
    return device
  }

  async findById(id: string): Promise<Device | undefined> {
    return this.items.get(id)
  }
}
