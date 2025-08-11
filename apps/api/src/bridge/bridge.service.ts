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
