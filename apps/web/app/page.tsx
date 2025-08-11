// apps/web/app/page.tsx
'use client'

import { useEffect, useMemo, useRef, useState } from 'react'

const API = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:3001'

type Device = { id: string; projectId: string; name: string; type: string; createdAt?: string }
type DeviceState = Record<string, any>

export default function Page() {
  const [devices, setDevices] = useState<Device[]>([])
  const [states, setStates] = useState<Record<string, DeviceState>>({})
  const [projectId, setProjectId] = useState('proj1')

  useEffect(() => {
    // load devices
    fetch(`${API}/api/devices`).then(r => r.json()).then((list: Device[]) => {
      setDevices(list)
      // prefetch snapshot states
      list.forEach(d => {
        fetch(`${API}/api/devices/${d.id}/state`).then(r => r.json()).then(s => {
          setStates(prev => ({ ...prev, [d.id]: s?.state ?? {} }))
        }).catch(() => {})
      })
    }).catch(() => {})
  }, [])

  useEffect(() => {
    // SSE realtime
    const url = `${API}/api/devices/stream?projectId=${encodeURIComponent(projectId)}`
    const es = new EventSource(url)
    es.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data)
        if (msg?.type === 'device-state') {
          setStates(prev => ({ ...prev, [msg.deviceId]: msg.state }))
        }
      } catch {}
    }
    es.onerror = () => {}
    return () => es.close()
  }, [projectId])

  const onToggle = async (d: Device, next: boolean) => {
    await fetch(`${API}/api/devices/${d.id}/command`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'relay', value: next }),
    })
  }

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12 }}>
        <label>projectId:</label>
        <input value={projectId} onChange={e => setProjectId(e.target.value)} style={{ padding: 6, border: '1px solid #ccc' }} />
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Nome</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>ID</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Estado</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Ação</th>
          </tr>
        </thead>
        <tbody>
          {devices.map(d => {
            const st = states[d.id] || {}
            const relay = !!st.relay
            return (
              <tr key={d.id}>
                <td style={{ borderBottom: '1px solid #f0f0f0', padding: 8 }}>{d.name}</td>
                <td style={{ borderBottom: '1px solid #f0f0f0', padding: 8, fontFamily: 'monospace' }}>{d.id}</td>
                <td style={{ borderBottom: '1px solid #f0f0f0', padding: 8 }}>
                  {Object.keys(st).length ? <code>{JSON.stringify(st)}</code> : <em>—</em>}
                </td>
                <td style={{ borderBottom: '1px solid #f0f0f0', padding: 8 }}>
                  <button onClick={() => onToggle(d, !relay)} style={{ padding: '6px 10px', border: '1px solid #222', cursor: 'pointer' }}>
                    {relay ? 'Desligar' : 'Ligar'}
                  </button>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
