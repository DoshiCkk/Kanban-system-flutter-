import { Module } from '@nestjs/common';
import { InvitesController } from './invites.controller.js';
import { WorkspaceMemberGuard } from './workspace-access.js';
import { WorkspacesController } from './workspaces.controller.js';
import { WorkspacesService } from './workspaces.service.js';

@Module({
  controllers: [WorkspacesController, InvitesController],
  providers: [WorkspacesService, WorkspaceMemberGuard],
  exports: [WorkspacesService, WorkspaceMemberGuard],
})
export class WorkspacesModule {}
