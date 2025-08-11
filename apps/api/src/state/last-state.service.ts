import { Injectable } from '@nestjs/common'

export interface DeviceKey {
  projectId: string
  deviceId: string
}

@Injectable()
export class LastStateService {
  private store = new Map<string, any>()

  private key({ projectId, deviceId }: DeviceKey) {
    return `${projectId}:${deviceId}`
  }

  set(input: DeviceKey, state: any) {
    if (!input.projectId || !input.deviceId) return
    this.store.set(this.key(input), state)
  }

  get(input: DeviceKey) {
    if (!input.projectId || !input.deviceId) return undefined
    return this.store.get(this.key(input))
  }
}
