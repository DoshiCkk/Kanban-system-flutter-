import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { isUUID } from 'class-validator';
import { forbidden, notFound } from '../common/api-error.js';
import type { AuthenticatedRequest } from '../auth/auth-user.js';
import type { Membership, Role } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const WORKSPACE_ROLES_KEY = 'flowboard:workspaceRoles';

/** Restricts a workspace route to the given roles. Default: any member. */
export const WorkspaceRoles = (...roles: Role[]): MethodDecorator =>
  SetMetadata(WORKSPACE_ROLES_KEY, roles);

type WorkspaceRequest = AuthenticatedRequest & { membership?: Membership };

/**
 * Resolves the caller's membership in `:workspaceId`.
 * Non-members get 404 so workspace ids cannot be probed.
 */
@Injectable()
export class WorkspaceMemberGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<WorkspaceRequest>();
    const workspaceId = request.params.workspaceId;
    if (typeof workspaceId !== 'string' || !isUUID(workspaceId)) {
      throw notFound('Workspace');
    }

    const membership = await this.prisma.membership.findFirst({
      where: {
        userId: request.user.id,
        workspaceId,
        workspace: { deletedAt: null },
      },
    });
    if (!membership) throw notFound('Workspace');

    const roles = this.reflector.get<Role[] | undefined>(
      WORKSPACE_ROLES_KEY,
      context.getHandler(),
    );
    if (roles && !roles.includes(membership.role)) throw forbidden();

    request.membership = membership;
    return true;
  }
}

export const CurrentMembership = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): Membership => {
    const membership = ctx
      .switchToHttp()
      .getRequest<WorkspaceRequest>().membership;
    if (!membership) {
      throw new Error('CurrentMembership used without WorkspaceMemberGuard');
    }
    return membership;
  },
);
