import { Controller, Get } from '@nestjs/common'
@Controller('api/health')
export class HealthController {
  @Get() ok() { return { status: 'ok', time: new Date().toISOString() } }
  @Get('live') live() { return { status: 'alive' } }
  @Get('ready') ready() { return { status: 'ready' } }
}
