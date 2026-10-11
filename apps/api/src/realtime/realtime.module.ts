import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SyncModule } from '../sync/sync.module.js';
import { WorkspacesModule } from '../workspaces/workspaces.module.js';
import { RealtimeGateway } from './realtime.gateway.js';

@Module({
  imports: [AuthModule, SyncModule, WorkspacesModule],
  providers: [RealtimeGateway],
})
export class RealtimeModule {}
