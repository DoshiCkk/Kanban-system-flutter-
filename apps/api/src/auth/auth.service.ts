import { HttpStatus, Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';
import { ApiException, ErrorCode } from '../common/api-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { toUserDto } from '../users/user.dto.js';
import type { AuthResponseDto, LoginDto, RegisterDto } from './auth.dto.js';
import { TokensService } from './tokens.service.js';

// Verified against when the email is unknown, so response time does not
// reveal whether an account exists.
const DUMMY_HASH_PROMISE = argon2.hash('flowboard-timing-equalizer');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokensService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const passwordHash = await argon2.hash(dto.password);
    try {
      const user = await this.prisma.user.create({
        data: {
          email: dto.email,
          passwordHash,
          name: dto.name,
          locale: dto.locale,
        },
      });
      return { user: toUserDto(user), tokens: await this.tokens.issue(user) };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ApiException(
          HttpStatus.CONFLICT,
          ErrorCode.EmailTaken,
          'Email is already registered',
        );
      }
      throw error;
    }
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    const hash = user?.passwordHash ?? (await DUMMY_HASH_PROMISE);
    const valid = await argon2.verify(hash, dto.password);
    if (!user || !valid) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        ErrorCode.InvalidCredentials,
        'Invalid email or password',
      );
    }
    return { user: toUserDto(user), tokens: await this.tokens.issue(user) };
  }
}
