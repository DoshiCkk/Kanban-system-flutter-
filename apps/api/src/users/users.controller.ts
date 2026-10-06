import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { notFound } from '../common/api-error.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { toUserDto, UpdateMeDto, UserDto } from './user.dto.js';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('me')
  @ApiOkResponse({ type: UserDto })
  async me(@CurrentUser() auth: AuthUser): Promise<UserDto> {
    const user = await this.prisma.user.findUnique({ where: { id: auth.id } });
    if (!user) throw notFound('User');
    return toUserDto(user);
  }

  @Patch('me')
  @ApiOkResponse({ type: UserDto })
  async updateMe(
    @CurrentUser() auth: AuthUser,
    @Body() dto: UpdateMeDto,
  ): Promise<UserDto> {
    const user = await this.prisma.user.update({
      where: { id: auth.id },
      data: { name: dto.name, locale: dto.locale },
    });
    return toUserDto(user);
  }
}
