import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { MqttService } from './mqtt.service'
import { BridgeModule } from '../bridge/bridge.module'

@Module({
  imports: [ConfigModule, BridgeModule],
  providers: [MqttService],
  exports: [MqttService],
})
export class MqttModule {}
