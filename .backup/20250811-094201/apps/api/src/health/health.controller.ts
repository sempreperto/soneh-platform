import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return { status: 'ok', time: new Date().toISOString() };
  }

  // opcionais (se quiser usar em k8s no futuro):
  @Get('live')
  liveness() {
    return { status: 'alive' };
  }

  @Get('ready')
  readiness() {
    // aqui daria pra checar conexões (db/redis/mqtt) se quiser
    return { status: 'ready' };
  }
}
