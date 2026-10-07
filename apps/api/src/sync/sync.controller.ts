import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import {
  PullQueryDto,
  PullResponseDto,
  PushDto,
  PushResponseDto,
} from './sync.dto.js';
import { SyncService } from './sync.service.js';

@ApiTags('sync')
@ApiBearerAuth()
@Controller('sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  /** Applies client ops in order; each op gets its own result. */
  @Post('push')
  @HttpCode(200)
  @ApiOkResponse({ type: PushResponseDto })
  async push(
    @CurrentUser() user: AuthUser,
    @Body() dto: PushDto,
  ): Promise<PushResponseDto> {
    return { results: await this.sync.push(user.id, dto.ops) };
  }

  /** Rows of one workspace changed after `since`, including tombstones. */
  @Get('pull')
  @ApiOkResponse({ type: PullResponseDto })
  pull(
    @CurrentUser() user: AuthUser,
    @Query() query: PullQueryDto,
  ): Promise<PullResponseDto> {
    return this.sync.pull(user.id, query);
  }
}
