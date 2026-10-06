import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { InvitePreviewDto, WorkspaceDto } from './workspaces.dto.js';
import { WorkspacesService } from './workspaces.service.js';

@ApiTags('invites')
@ApiBearerAuth()
@ApiNotFoundResponse({ description: 'INVITE_INVALID' })
@Controller('invites')
export class InvitesController {
  constructor(private readonly workspaces: WorkspacesService) {}

  @Get(':token')
  @ApiOkResponse({ type: InvitePreviewDto })
  preview(
    @Param('token') token: string,
    @CurrentUser() user: AuthUser,
  ): Promise<InvitePreviewDto> {
    return this.workspaces.previewInvite(token, user.id);
  }

  @Post(':token/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOkResponse({ type: WorkspaceDto })
  accept(
    @Param('token') token: string,
    @CurrentUser() user: AuthUser,
  ): Promise<WorkspaceDto> {
    return this.workspaces.acceptInvite(token, user.id);
  }
}
