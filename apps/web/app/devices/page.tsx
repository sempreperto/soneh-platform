'use client'

import { useEffect, useMemo, useState } from 'react'
import { apiGet, apiPost } from '@/lib/api'

type Device = {
  id: string
  projectId: string
  name: string
  type: string
  createdAt?: string
  lastState?: any | null
}

export default function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = async () => {
    try {
      setError(null)
      const list = await apiGet<Device[]>('/api/devices')
      // enrich with lastState
      const withState = await Promise.all(
        list.map(async d => {
          try {
            const full = await apiGet<Device>(`/api/devices/${d.id}`)
            return full
          } catch {
            return d
          }
        }),
      )
      setDevices(withState)
    } catch (e: any) {
      setError(e?.message ?? 'erro ao carregar')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    refresh()
    const t = setInterval(refresh, 2000)
    return () => clearInterval(t)
  }, [])

  const rows = useMemo(() => devices.map(d => {
    const relay = d.lastState?.relay ?? null
    const status = relay === null ? '—' : relay ? 'ON' : 'OFF'
    return (
      <tr key={d.id}>
        <td style={{padding:'8px'}}>{d.name}</td>
        <td style={{padding:'8px', fontFamily:'monospace'}}>{d.id}</td>
        <td style={{padding:'8px'}}>{status}</td>
        <td style={{padding:'8px'}}>
          <button
            onClick={async () => {
              const value = !(relay ?? false)
              await apiPost(`/api/devices/${d.id}/command`, { action: 'relay', value })
              // optimistic: update local
              setDevices(prev => prev.map(p => p.id === d.id ? ({ ...p, lastState: { ...(p.lastState||{}), relay: value } }) : p))
            }}
            style={{padding:'6px 12px', borderRadius:8, border:'1px solid #ddd', cursor:'pointer'}}
          >
            Toggle
          </button>
        </td>
      </tr>
    )
  }), [devices])

  return (
    <div style={{maxWidth:940, margin:'40px auto', fontFamily:'Inter, ui-sans-serif, system-ui'}}>
      <h1 style={{fontSize:26, fontWeight:700, marginBottom:12}}>Dispositivos</h1>
      <p style={{color:'#666', marginBottom:16}}>Atualiza a cada 2s (MVP, sem WS).</p>
      {loading ? <p>Carregando…</p> : null}
      {error ? <p style={{color:'crimson'}}>{error}</p> : null}
      <table style={{width:'100%', borderCollapse:'collapse'}}>
        <thead>
          <tr>
            <th style={{textAlign:'left', padding:'8px'}}>Nome</th>
            <th style={{textAlign:'left', padding:'8px'}}>ID</th>
            <th style={{textAlign:'left', padding:'8px'}}>Relé</th>
            <th style={{textAlign:'left', padding:'8px'}}>Ações</th>
          </tr>
        </thead>
        <tbody>
          {rows}
        </tbody>
      </table>
    </div>
  )
}
