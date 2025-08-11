import { Module } from '@nestjs/common'
import { BridgeService } from './bridge.service'
import { StateModule } from '../state/state.module'

@Module({
  imports: [StateModule],
  providers: [BridgeService],
  exports: [BridgeService],
})
export class BridgeModule {}
