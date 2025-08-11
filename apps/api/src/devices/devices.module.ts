import { Module } from '@nestjs/common'
import { DevicesController } from './devices.controller'
import { DevicesService } from './devices.service'
import { MqttModule } from '../mqtt/mqtt.module'

@Module({
  imports: [MqttModule],
  controllers: [DevicesController],
  providers: [DevicesService],
  exports: [DevicesService],
})
export class DevicesModule {}
