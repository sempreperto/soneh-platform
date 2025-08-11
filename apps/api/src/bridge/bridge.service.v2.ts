// apps/api/src/bridge/bridge.service.ts (v2 stitch: add realtime + snapshot)
import { Injectable, Logger } from '@nestjs/common'
import { deviceEvents$, setLastState } from '../realtime/bus'

@Injectable()
export class BridgeService {
  private readonly logger = new Logger('BridgeService')

  handleState(input: { namespace: string; projectId: string; deviceId: string; data: any }) {
    const { projectId, deviceId, data } = input
    if (!projectId || !deviceId) return
    try {
      // snapshot (dev)
      setLastState(projectId, deviceId, data)
      // broadcast interno (SSE)
      deviceEvents$.next({ projectId, deviceId, data })
      this.broadcast(projectId, deviceId, data)
    } catch (e) {
      this.logger.error('Bridge broadcast error')
      this.logger.error(e as any)
    }
  }

  private broadcast(projectId: string, deviceId: string, data: any) {
    // (mantém log de debug)
    this.logger.debug(`broadcast ${projectId}/${deviceId}: ${JSON.stringify(data)}`)
  }
}
