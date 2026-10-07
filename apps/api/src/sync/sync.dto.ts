import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsIn,
  IsInt,
  IsNumberString,
  IsObject,
  IsOptional,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export const SYNC_ENTITIES = [
  'board',
  'column',
  'card',
  'checklistItem',
  'comment',
] as const;
export type SyncEntity = (typeof SYNC_ENTITIES)[number];

export const SYNC_OPERATIONS = ['create', 'update', 'delete'] as const;
export type SyncOperation = (typeof SYNC_OPERATIONS)[number];

export const MAX_PUSH_OPS = 100;
export const DEFAULT_PULL_LIMIT = 500;
export const MAX_PULL_LIMIT = 1000;

export class PushOpDto {
  @ApiProperty({ format: 'uuid', description: 'Idempotency key.' })
  @IsUUID()
  opId!: string;

  @ApiProperty({ enum: SYNC_ENTITIES })
  @IsIn(SYNC_ENTITIES)
  entity!: SyncEntity;

  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  entityId!: string;

  @ApiProperty({ enum: SYNC_OPERATIONS })
  @IsIn(SYNC_OPERATIONS)
  operation!: SyncOperation;

  @ApiPropertyOptional({
    description: 'Version the client based the change on (diagnostics).',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  baseVersion?: number;

  @ApiProperty({
    type: 'object',
    additionalProperties: true,
    description:
      'Changed fields only (full row for create). Validated per entity; ' +
      'an invalid payload rejects only this op.',
  })
  @IsObject()
  payload!: Record<string, unknown>;
}

export class PushDto {
  @ApiProperty({ type: [PushOpDto], maxItems: MAX_PUSH_OPS })
  @ValidateNested({ each: true })
  @Type(() => PushOpDto)
  @ArrayMaxSize(MAX_PUSH_OPS)
  ops!: PushOpDto[];
}

export const SYNC_REJECT_CODES = [
  'SYNC_ENTITY_DELETED',
  'SYNC_PARENT_DELETED',
  'SYNC_NOT_FOUND',
  'SYNC_FORBIDDEN',
  'SYNC_INVALID_OP',
] as const;
export type SyncRejectCode = (typeof SYNC_REJECT_CODES)[number];

export type PushStatus = 'applied' | 'duplicate' | 'rejected';

export class PushResultDto {
  @ApiProperty({ format: 'uuid' })
  opId!: string;

  @ApiProperty({ enum: ['applied', 'duplicate', 'rejected'] })
  status!: PushStatus;

  @ApiPropertyOptional({ enum: SYNC_REJECT_CODES })
  code?: SyncRejectCode;

  @ApiPropertyOptional({ description: 'Row version after the change.' })
  version?: number;
}

export class PushResponseDto {
  @ApiProperty({ type: [PushResultDto] })
  results!: PushResultDto[];
}

export class PullQueryDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  workspaceId!: string;

  @ApiPropertyOptional({
    description: 'Cursor from the previous pull; "0" for a full sync.',
    default: '0',
  })
  @IsOptional()
  @IsNumberString({ no_symbols: true })
  since?: string;

  @ApiPropertyOptional({
    minimum: 1,
    maximum: MAX_PULL_LIMIT,
    default: DEFAULT_PULL_LIMIT,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_PULL_LIMIT)
  limit?: number;
}

type Row = Record<string, unknown>;

export class PullResponseDto {
  @ApiProperty({ type: 'array', items: { type: 'object' } })
  boards!: Row[];

  @ApiProperty({ type: 'array', items: { type: 'object' } })
  columns!: Row[];

  @ApiProperty({ type: 'array', items: { type: 'object' } })
  cards!: Row[];

  @ApiProperty({ type: 'array', items: { type: 'object' } })
  checklistItems!: Row[];

  @ApiProperty({ type: 'array', items: { type: 'object' } })
  comments!: Row[];

  @ApiProperty({ description: 'Max seq in this page (bigint as string).' })
  cursor!: string;

  @ApiProperty()
  hasMore!: boolean;
}
