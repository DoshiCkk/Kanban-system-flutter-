import { plainToInstance } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateIf,
  validateSync,
} from 'class-validator';
import { CardPriority } from '../generated/prisma/client.js';

/**
 * Per-entity payload shapes of pushed ops. `undefined` = field not sent
 * (unchanged); `null` is accepted only for nullable fields.
 */

/** Optional but not nullable. */
const Sent = (): PropertyDecorator =>
  ValidateIf((_o: unknown, v: unknown) => v !== undefined);

/** Fractional-index key (base62, see apps/mobile fractional_index.dart). */
const OrderKey = (): PropertyDecorator => Matches(/^[0-9A-Za-z]{1,64}$/);

const PRIORITIES = Object.values(CardPriority);

export class BoardCreate {
  @IsUUID() workspaceId!: string;
  @IsString() @Length(1, 200) title!: string;
  @IsOptional() @IsString() @MaxLength(40) templateKey?: string | null;
  @IsISO8601() createdAt!: string;
}

export class BoardUpdate {
  @Sent() @IsString() @Length(1, 200) title?: string;
}

export class ColumnCreate {
  @IsUUID() boardId!: string;
  @IsString() @Length(1, 80) title!: string;
  @OrderKey() position!: string;
  @IsOptional() @IsInt() @Min(1) @Max(999) wipLimit?: number | null;
  @IsISO8601() createdAt!: string;
}

export class ColumnUpdate {
  @Sent() @IsString() @Length(1, 80) title?: string;
  @Sent() @OrderKey() position?: string;
  @IsOptional() @IsInt() @Min(1) @Max(999) wipLimit?: number | null;
}

export class CardUpdate {
  @Sent() @IsUUID() columnId?: string;
  @Sent() @IsString() @Length(1, 200) title?: string;
  @Sent() @IsString() @MaxLength(5000) description?: string;
  @IsOptional() @IsUUID() assigneeId?: string | null;
  @IsOptional() @IsISO8601() dueDate?: string | null;
  @Sent() @IsIn(PRIORITIES) priority?: CardPriority;

  @Sent()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Length(1, 30, { each: true })
  labels?: string[];

  @Sent() @OrderKey() position?: string;
}

export class CardCreate {
  @IsUUID() columnId!: string;
  @IsUUID() boardId!: string;
  @IsString() @Length(1, 200) title!: string;
  @Sent() @IsString() @MaxLength(5000) description?: string;
  @IsOptional() @IsUUID() assigneeId?: string | null;
  @IsOptional() @IsISO8601() dueDate?: string | null;
  @Sent() @IsIn(PRIORITIES) priority?: CardPriority;

  @Sent()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Length(1, 30, { each: true })
  labels?: string[];

  @OrderKey() position!: string;
  @IsISO8601() createdAt!: string;
}

export class ChecklistItemCreate {
  @IsUUID() cardId!: string;
  @IsString() @Length(1, 200) text!: string;
  @IsBoolean() done!: boolean;
  @OrderKey() position!: string;
  @IsISO8601() createdAt!: string;
}

export class ChecklistItemUpdate {
  @Sent() @IsString() @Length(1, 200) text?: string;
  @Sent() @IsBoolean() done?: boolean;
  @Sent() @OrderKey() position?: string;
}

export class CommentCreate {
  @IsUUID() cardId!: string;
  @IsString() @Length(1, 2000) text!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  mentions?: string[];

  @IsISO8601() createdAt!: string;
}

export class CommentUpdate {
  @Sent() @IsString() @Length(1, 2000) text?: string;
}

/**
 * Validates a raw payload. Unknown fields fail validation, so a client
 * cannot write server-owned columns (seq, version, workspaceId, …).
 * Returns `null` when invalid.
 */
export function parsePayload<T extends object>(
  cls: new () => T,
  payload: Record<string, unknown>,
): T | null {
  const instance = plainToInstance(cls, payload);
  const errors = validateSync(instance, {
    whitelist: true,
    forbidNonWhitelisted: true,
  });
  return errors.length === 0 ? instance : null;
}

/** Keeps only the given keys (used when a `create` is applied as `update`). */
export function pick(
  payload: Record<string, unknown>,
  keys: readonly string[],
): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(payload).filter(([k]) => keys.includes(k)),
  );
}

export const UPDATE_KEYS = {
  board: ['title'],
  column: ['title', 'position', 'wipLimit'],
  card: [
    'columnId',
    'title',
    'description',
    'assigneeId',
    'dueDate',
    'priority',
    'labels',
    'position',
  ],
  checklistItem: ['text', 'done', 'position'],
  comment: ['text'],
} as const;
