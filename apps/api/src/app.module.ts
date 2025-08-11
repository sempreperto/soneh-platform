import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DevicesModule } from './devices/devices.module';
import { MqttModule } from './mqtt/mqtt.module';
import { BridgeModule } from './bridge/bridge.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    HealthModule,
    DevicesModule,
    MqttModule,
    BridgeModule,
  ],
})
export class AppModule {}
