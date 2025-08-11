export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? ''

export async function apiGet<T>(path: string): Promise<T> {
  const url = `${API_BASE}${path}`
  const res = await fetch(url, { cache: 'no-store' })
  if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`)
  return res.json() as Promise<T>
}

export async function apiPost<T>(path: string, body: any): Promise<T> {
  const url = `${API_BASE}${path}`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`POST ${path} -> ${res.status}`)
  return res.json() as Promise<T>
}
