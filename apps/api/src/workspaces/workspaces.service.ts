import { HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ApiException,
  ErrorCode,
  forbidden,
  notFound,
} from '../common/api-error.js';
import { generateToken, hashToken } from '../common/crypto.js';
import type { EnvironmentVariables } from '../config/env.validation.js';
import {
  type Membership,
  Prisma,
  Role,
  type Workspace,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type {
  AssignableRole,
  CreateWorkspaceDto,
  InviteDto,
  InvitePreviewDto,
  MemberDto,
  WorkspaceDto,
} from './workspaces.dto.js';

const HOUR_MS = 60 * 60 * 1000;

type WorkspaceWithCount = Workspace & { _count: { memberships: number } };

const toWorkspaceDto = (w: WorkspaceWithCount, role: Role): WorkspaceDto => ({
  id: w.id,
  name: w.name,
  role,
  memberCount: w._count.memberships,
  createdAt: w.createdAt,
  updatedAt: w.updatedAt,
});

const withMemberCount = {
  _count: { select: { memberships: true } },
} as const;

const inviteInvalid = (): ApiException =>
  new ApiException(
    HttpStatus.NOT_FOUND,
    ErrorCode.InviteInvalid,
    'Invite is invalid or expired',
  );

@Injectable()
export class WorkspacesService {
  private readonly inviteTtlMs: number;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService<EnvironmentVariables, true>,
  ) {
    this.inviteTtlMs =
      config.get('INVITE_TTL_HOURS', { infer: true }) * HOUR_MS;
  }

  async create(userId: string, dto: CreateWorkspaceDto): Promise<WorkspaceDto> {
    try {
      const workspace = await this.prisma.workspace.create({
        data: {
          id: dto.id,
          name: dto.name,
          memberships: { create: { userId, role: Role.owner } },
        },
        include: withMemberCount,
      });
      return toWorkspaceDto(workspace, Role.owner);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ApiException(
          HttpStatus.CONFLICT,
          ErrorCode.Conflict,
          'Workspace id already exists',
        );
      }
      throw error;
    }
  }

  async listForUser(userId: string): Promise<WorkspaceDto[]> {
    const memberships = await this.prisma.membership.findMany({
      where: { userId, workspace: { deletedAt: null } },
      include: { workspace: { include: withMemberCount } },
      orderBy: { workspace: { name: 'asc' } },
    });
    return memberships.map((m) => toWorkspaceDto(m.workspace, m.role));
  }

  async get(membership: Membership): Promise<WorkspaceDto> {
    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: membership.workspaceId },
      include: withMemberCount,
    });
    return toWorkspaceDto(workspace, membership.role);
  }

  async rename(membership: Membership, name: string): Promise<WorkspaceDto> {
    const workspace = await this.prisma.workspace.update({
      where: { id: membership.workspaceId },
      data: { name },
      include: withMemberCount,
    });
    return toWorkspaceDto(workspace, membership.role);
  }

  async members(workspaceId: string): Promise<MemberDto[]> {
    const memberships = await this.prisma.membership.findMany({
      where: { workspaceId },
      include: {
        user: {
          select: { id: true, email: true, name: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    return memberships.map((m) => ({
      user: m.user,
      role: m.role,
      joinedAt: m.createdAt,
    }));
  }

  /** Owner only (enforced by the guard). The owner's own role is locked. */
  async updateMemberRole(
    actor: Membership,
    targetUserId: string,
    role: AssignableRole,
  ): Promise<MemberDto> {
    const target = await this.findMember(actor.workspaceId, targetUserId);
    if (target.role === Role.owner) {
      throw new ApiException(
        HttpStatus.FORBIDDEN,
        ErrorCode.OwnerRoleLocked,
        'The owner role cannot be changed',
      );
    }
    const updated = await this.prisma.membership.update({
      where: {
        userId_workspaceId: {
          userId: targetUserId,
          workspaceId: actor.workspaceId,
        },
      },
      data: { role },
      include: {
        user: {
          select: { id: true, email: true, name: true, avatarUrl: true },
        },
      },
    });
    return {
      user: updated.user,
      role: updated.role,
      joinedAt: updated.createdAt,
    };
  }

  /**
   * - anyone except the owner may leave;
   * - the owner may remove anyone else;
   * - an admin may remove plain members.
   */
  async removeMember(actor: Membership, targetUserId: string): Promise<void> {
    const target = await this.findMember(actor.workspaceId, targetUserId);
    const isSelf = actor.userId === targetUserId;

    if (target.role === Role.owner) {
      throw new ApiException(
        HttpStatus.FORBIDDEN,
        ErrorCode.OwnerRoleLocked,
        'The owner cannot leave or be removed',
      );
    }
    const allowed =
      isSelf ||
      actor.role === Role.owner ||
      (actor.role === Role.admin && target.role === Role.member);
    if (!allowed) throw forbidden();

    await this.prisma.membership.delete({
      where: {
        userId_workspaceId: {
          userId: targetUserId,
          workspaceId: actor.workspaceId,
        },
      },
    });
  }

  async createInvite(actor: Membership): Promise<InviteDto> {
    const token = generateToken();
    const invite = await this.prisma.invite.create({
      data: {
        tokenHash: hashToken(token),
        workspaceId: actor.workspaceId,
        createdById: actor.userId,
        expiresAt: new Date(Date.now() + this.inviteTtlMs),
      },
    });
    return { token, expiresAt: invite.expiresAt };
  }

  async previewInvite(
    token: string,
    userId: string,
  ): Promise<InvitePreviewDto> {
    const invite = await this.findValidInvite(token);
    const membership = await this.prisma.membership.findUnique({
      where: {
        userId_workspaceId: { userId, workspaceId: invite.workspaceId },
      },
    });
    return {
      workspaceId: invite.workspace.id,
      workspaceName: invite.workspace.name,
      memberCount: invite.workspace._count.memberships,
      expiresAt: invite.expiresAt,
      alreadyMember: membership !== null,
    };
  }

  /** Idempotent: accepting twice keeps the existing role. */
  async acceptInvite(token: string, userId: string): Promise<WorkspaceDto> {
    const invite = await this.findValidInvite(token);
    const membership = await this.prisma.membership.upsert({
      where: {
        userId_workspaceId: { userId, workspaceId: invite.workspaceId },
      },
      create: { userId, workspaceId: invite.workspaceId, role: Role.member },
      update: {},
    });
    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: invite.workspaceId },
      include: withMemberCount,
    });
    return toWorkspaceDto(workspace, membership.role);
  }

  private async findMember(
    workspaceId: string,
    userId: string,
  ): Promise<Membership> {
    const member = await this.prisma.membership.findUnique({
      where: { userId_workspaceId: { userId, workspaceId } },
    });
    if (!member) throw notFound('Member');
    return member;
  }

  private async findValidInvite(token: string) {
    const invite = await this.prisma.invite.findUnique({
      where: { tokenHash: hashToken(token) },
      include: { workspace: { include: withMemberCount } },
    });
    if (
      !invite ||
      invite.revokedAt !== null ||
      invite.expiresAt <= new Date() ||
      invite.workspace.deletedAt !== null
    ) {
      throw inviteInvalid();
    }
    return invite;
  }
}
