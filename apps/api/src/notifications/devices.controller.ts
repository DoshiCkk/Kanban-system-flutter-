import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  Put,
} from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiTags } from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RegisterDeviceDto } from './devices.dto.js';

/** Push tokens of the signed-in user's devices (docs/push.md). */
@ApiTags('devices')
@ApiBearerAuth()
@Controller('devices')
export class DevicesController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Registers or refreshes a token. A token belongs to one device, so a
   * token registered by another account moves to the caller (the device
   * switched accounts).
   */
  @Put()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiNoContentResponse()
  async register(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<void> {
    const fields = {
      userId: user.id,
      platform: dto.platform,
      locale: dto.locale,
    };
    await this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      create: { token: dto.token, ...fields },
      update: fields,
    });
  }

  /** Called before signing out. Idempotent; other users' tokens are kept. */
  @Delete(':token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiNoContentResponse()
  async unregister(
    @CurrentUser() user: AuthUser,
    @Param('token') token: string,
  ): Promise<void> {
    await this.prisma.deviceToken.deleteMany({
      where: { token, userId: user.id },
    });
  }
}
