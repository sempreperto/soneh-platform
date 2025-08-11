// apps/api/src/realtime/bus.ts
import { Subject } from 'rxjs';

export interface DeviceEvent {
  projectId: string;
  deviceId: string;
  data: any;
}

// Multicast de eventos de device state
export const deviceEvents$ = new Subject<DeviceEvent>();

// Snapshot simples em memória (dev). Em prod, use Redis.
const key = (projectId: string, deviceId: string) => `${projectId}:${deviceId}`;
const store = new Map<string, any>();

export function setLastState(projectId: string, deviceId: string, data: any) {
  store.set(key(projectId, deviceId), data);
}

export function getLastState(projectId: string, deviceId: string) {
  return store.get(key(projectId, deviceId)) ?? null;
}
