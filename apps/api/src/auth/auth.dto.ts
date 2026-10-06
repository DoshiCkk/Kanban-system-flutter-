import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';
import { AppLocale } from '../generated/prisma/client.js';
import { UserDto } from '../users/user.dto.js';

const normalizeEmail = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 128;

export class RegisterDto {
  @ApiProperty({ example: 'aigerim@example.com' })
  @Transform(normalizeEmail)
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ minLength: PASSWORD_MIN, maxLength: PASSWORD_MAX })
  @IsString()
  @Length(PASSWORD_MIN, PASSWORD_MAX)
  password!: string;

  @ApiProperty({ minLength: 1, maxLength: 80, example: 'Aigerim' })
  @Transform(trim)
  @IsString()
  @Length(1, 80)
  name!: string;

  @ApiPropertyOptional({ enum: AppLocale })
  @IsOptional()
  @IsEnum(AppLocale)
  locale?: AppLocale;
}

export class LoginDto {
  @ApiProperty()
  @Transform(normalizeEmail)
  @IsEmail()
  email!: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(PASSWORD_MAX)
  password!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  refreshToken!: string;
}

export class TokenPairDto {
  @ApiProperty()
  accessToken!: string;

  @ApiProperty({ description: 'Opaque, single-use. Rotated on every refresh.' })
  refreshToken!: string;

  @ApiProperty({ description: 'Access token lifetime in seconds.' })
  expiresIn!: number;
}

export class AuthResponseDto {
  @ApiProperty({ type: UserDto })
  user!: UserDto;

  @ApiProperty({ type: TokenPairDto })
  tokens!: TokenPairDto;
}
