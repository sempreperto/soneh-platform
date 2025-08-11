
# Soneh — SaaS IoT & Vision (G1 Monorepo)

Data: 2025-08-09

## Como rodar (dev)

1) **Subir infraestrutura** (Postgres, Redis, EMQX, MinIO, Caddy) e apps:
```bash
cd infra
docker compose up -d --build
```

2) **Acessos**
- Web: https://localhost
- API: https://localhost/api/health
- EMQX Dashboard: http://localhost:18083
- MinIO Console: http://localhost:9001

> Certificado é **autoassinado** — aceite o aviso no navegador (apenas em dev).

## Estrutura
- `apps/web` (Next.js 14, Hello World)
- `apps/api` (NestJS, `/health`)
- `apps/worker` (Node + BullMQ, stub)
- `apps/mobile` (Expo, stub)
- `packages/*` (ui, sdk, config)
- `infra/` (docker-compose, Caddyfile, Prisma schema stub)
