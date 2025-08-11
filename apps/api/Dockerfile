FROM node:18-alpine
WORKDIR /app
# Instala dependências em camada separada
COPY apps/api/package.json ./package.json
RUN npm install --production
# Copia código
COPY apps/api/src ./src
ENV NODE_ENV=production
EXPOSE 3001
CMD ["npm","start"]
