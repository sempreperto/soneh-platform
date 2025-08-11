import { Module } from '@nestjs/common'
import { LastStateService } from './last-state.service'

@Module({
  providers: [LastStateService],
  exports: [LastStateService],
})
export class StateModule {}
