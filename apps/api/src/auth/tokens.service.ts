import { HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'node:crypto';
import { ApiException, ErrorCode } from '../common/api-error.js';
import { generateToken, hashToken } from '../common/crypto.js';
import type { EnvironmentVariables } from '../config/env.validation.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthUser, JwtPayload } from './auth-user.js';
import type { TokenPairDto } from './auth.dto.js';

const DAY_MS = 24 * 60 * 60 * 1000;

const invalidRefreshToken = (): ApiException =>
  new ApiException(
    HttpStatus.UNAUTHORIZED,
    ErrorCode.InvalidRefreshToken,
    'Refresh token is invalid or expired',
  );

/**
 * Access tokens: short-lived JWTs. Refresh tokens: opaque random strings,
 * stored hashed, single-use with rotation. Presenting an already rotated
 * token is treated as theft and revokes the whole token family.
 */
@Injectable()
export class TokensService {
  private readonly accessTtlSeconds: number;
  private readonly refreshTtlMs: number;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    config: ConfigService<EnvironmentVariables, true>,
  ) {
    this.accessTtlSeconds = config.get('JWT_ACCESS_TTL_SECONDS', {
      infer: true,
    });
    this.refreshTtlMs =
      config.get('REFRESH_TOKEN_TTL_DAYS', { infer: true }) * DAY_MS;
  }

  /** Starts a new token family (login/register). */
  async issue(user: AuthUser): Promise<TokenPairDto> {
    const refreshToken = generateToken();
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + this.refreshTtlMs),
      },
    });
    return this.pair(user, refreshToken);
  }

  async rotate(refreshToken: string): Promise<TokenPairDto> {
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashToken(refreshToken) },
      include: { user: { select: { id: true, email: true } } },
    });
    if (!record) throw invalidRefreshToken();

    if (record.revokedAt) {
      await this.revokeFamily(record.familyId);
      throw invalidRefreshToken();
    }
    if (record.expiresAt <= new Date()) throw invalidRefreshToken();

    const next = generateToken();
    await this.prisma.$transaction(async (tx) => {
      const created = await tx.refreshToken.create({
        data: {
          userId: record.userId,
          familyId: record.familyId,
          tokenHash: hashToken(next),
          expiresAt: new Date(Date.now() + this.refreshTtlMs),
        },
      });
      // Conditional update guards against two concurrent rotations of the
      // same token: only one of them can flip revokedAt.
      const { count } = await tx.refreshToken.updateMany({
        where: { id: record.id, revokedAt: null },
        data: { revokedAt: new Date(), replacedById: created.id },
      });
      if (count === 0) throw invalidRefreshToken();
    });

    return this.pair(record.user, next);
  }

  /** Logout: revokes the family of the given token. Unknown tokens are ignored. */
  async revoke(refreshToken: string): Promise<void> {
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashToken(refreshToken) },
      select: { familyId: true },
    });
    if (record) await this.revokeFamily(record.familyId);
  }

  private async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async pair(
    user: AuthUser,
    refreshToken: string,
  ): Promise<TokenPairDto> {
    const payload: JwtPayload = { sub: user.id, email: user.email };
    const accessToken = await this.jwt.signAsync(payload, {
      expiresIn: this.accessTtlSeconds,
    });
    return { accessToken, refreshToken, expiresIn: this.accessTtlSeconds };
  }
}
