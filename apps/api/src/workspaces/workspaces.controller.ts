import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { type Membership, Role } from '../generated/prisma/client.js';
import {
  CurrentMembership,
  WorkspaceMemberGuard,
  WorkspaceRoles,
} from './workspace-access.js';
import {
  CreateWorkspaceDto,
  InviteDto,
  MemberDto,
  UpdateMemberRoleDto,
  UpdateWorkspaceDto,
  WorkspaceDto,
} from './workspaces.dto.js';
import { WorkspacesService } from './workspaces.service.js';

@ApiTags('workspaces')
@ApiBearerAuth()
@Controller('workspaces')
export class WorkspacesController {
  constructor(private readonly workspaces: WorkspacesService) {}

  @Post()
  @ApiCreatedResponse({ type: WorkspaceDto })
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateWorkspaceDto,
  ): Promise<WorkspaceDto> {
    return this.workspaces.create(user.id, dto);
  }

  @Get()
  @ApiOkResponse({ type: [WorkspaceDto] })
  list(@CurrentUser() user: AuthUser): Promise<WorkspaceDto[]> {
    return this.workspaces.listForUser(user.id);
  }

  @Get(':workspaceId')
  @UseGuards(WorkspaceMemberGuard)
  @ApiOkResponse({ type: WorkspaceDto })
  get(@CurrentMembership() membership: Membership): Promise<WorkspaceDto> {
    return this.workspaces.get(membership);
  }

  @Patch(':workspaceId')
  @UseGuards(WorkspaceMemberGuard)
  @WorkspaceRoles(Role.owner, Role.admin)
  @ApiOkResponse({ type: WorkspaceDto })
  rename(
    @CurrentMembership() membership: Membership,
    @Body() dto: UpdateWorkspaceDto,
  ): Promise<WorkspaceDto> {
    return this.workspaces.rename(membership, dto.name);
  }

  @Get(':workspaceId/members')
  @UseGuards(WorkspaceMemberGuard)
  @ApiOkResponse({ type: [MemberDto] })
  members(@CurrentMembership() membership: Membership): Promise<MemberDto[]> {
    return this.workspaces.members(membership.workspaceId);
  }

  @Patch(':workspaceId/members/:userId')
  @UseGuards(WorkspaceMemberGuard)
  @WorkspaceRoles(Role.owner)
  @ApiOkResponse({ type: MemberDto })
  updateMemberRole(
    @CurrentMembership() membership: Membership,
    @Param('userId', new ParseUUIDPipe()) userId: string,
    @Body() dto: UpdateMemberRoleDto,
  ): Promise<MemberDto> {
    return this.workspaces.updateMemberRole(membership, userId, dto.role);
  }

  @Delete(':workspaceId/members/:userId')
  @UseGuards(WorkspaceMemberGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiNoContentResponse()
  removeMember(
    @CurrentMembership() membership: Membership,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<void> {
    return this.workspaces.removeMember(membership, userId);
  }

  @Post(':workspaceId/invites')
  @UseGuards(WorkspaceMemberGuard)
  @WorkspaceRoles(Role.owner, Role.admin)
  @ApiCreatedResponse({ type: InviteDto })
  createInvite(
    @CurrentMembership() membership: Membership,
  ): Promise<InviteDto> {
    return this.workspaces.createInvite(membership);
  }
}
