import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsString, Length } from 'class-validator';
import { AppLocale, DevicePlatform } from '../generated/prisma/client.js';

export class RegisterDeviceDto {
  @ApiProperty({ description: 'FCM registration token', maxLength: 4096 })
  @IsString()
  @Length(1, 4096)
  token!: string;

  @ApiProperty({ enum: DevicePlatform })
  @IsEnum(DevicePlatform)
  platform!: DevicePlatform;

  @ApiProperty({ enum: AppLocale, description: 'Language of push texts' })
  @IsEnum(AppLocale)
  locale!: AppLocale;
}
