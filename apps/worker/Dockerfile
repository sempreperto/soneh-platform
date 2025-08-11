
FROM node:18-alpine
WORKDIR /app
RUN npm i -g pnpm@9
COPY package.json pnpm-workspace.yaml turbo.json tsconfig.base.json ./
COPY apps/worker/package.json apps/worker/package.json
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json
COPY packages/ui/package.json packages/ui/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/config/package.json packages/config/package.json
RUN pnpm install
COPY . .
CMD ["pnpm","--filter","worker","dev"]
