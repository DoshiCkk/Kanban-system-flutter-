-- CreateEnum
CREATE TYPE "CardPriority" AS ENUM ('low', 'medium', 'high');

-- CreateTable
CREATE TABLE "boards" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "template_key" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "seq" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "boards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "board_columns" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "board_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "position" TEXT COLLATE "C" NOT NULL,
    "wip_limit" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "seq" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "board_columns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cards" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "board_id" UUID NOT NULL,
    "column_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "assignee_id" UUID,
    "due_date" TIMESTAMP(3),
    "priority" "CardPriority" NOT NULL DEFAULT 'medium',
    "labels" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "position" TEXT COLLATE "C" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "seq" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "cards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "checklist_items" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "card_id" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "done" BOOLEAN NOT NULL DEFAULT false,
    "position" TEXT COLLATE "C" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "seq" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "checklist_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "card_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "mentions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 0,
    "seq" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_applied_ops" (
    "op_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" TEXT NOT NULL,
    "code" TEXT,
    "version" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sync_applied_ops_pkey" PRIMARY KEY ("op_id")
);

-- CreateIndex
CREATE INDEX "boards_workspace_id_seq_idx" ON "boards"("workspace_id", "seq");

-- CreateIndex
CREATE INDEX "board_columns_workspace_id_seq_idx" ON "board_columns"("workspace_id", "seq");

-- CreateIndex
CREATE INDEX "board_columns_board_id_idx" ON "board_columns"("board_id");

-- CreateIndex
CREATE INDEX "cards_workspace_id_seq_idx" ON "cards"("workspace_id", "seq");

-- CreateIndex
CREATE INDEX "cards_column_id_idx" ON "cards"("column_id");

-- CreateIndex
CREATE INDEX "cards_board_id_idx" ON "cards"("board_id");

-- CreateIndex
CREATE INDEX "checklist_items_workspace_id_seq_idx" ON "checklist_items"("workspace_id", "seq");

-- CreateIndex
CREATE INDEX "checklist_items_card_id_idx" ON "checklist_items"("card_id");

-- CreateIndex
CREATE INDEX "comments_workspace_id_seq_idx" ON "comments"("workspace_id", "seq");

-- CreateIndex
CREATE INDEX "comments_card_id_idx" ON "comments"("card_id");

-- CreateIndex
CREATE INDEX "sync_applied_ops_created_at_idx" ON "sync_applied_ops"("created_at");

-- AddForeignKey
ALTER TABLE "boards" ADD CONSTRAINT "boards_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "board_columns" ADD CONSTRAINT "board_columns_board_id_fkey" FOREIGN KEY ("board_id") REFERENCES "boards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cards" ADD CONSTRAINT "cards_board_id_fkey" FOREIGN KEY ("board_id") REFERENCES "boards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cards" ADD CONSTRAINT "cards_column_id_fkey" FOREIGN KEY ("column_id") REFERENCES "board_columns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "checklist_items" ADD CONSTRAINT "checklist_items_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------
-- Hand-written (docs/sync.md): Prisma cannot express these.
-- position columns above use COLLATE "C" (byte order, matches the client).
-- ---------------------------------------------------------------------------

-- Global change counter; per-workspace cursors compare against it.
CREATE SEQUENCE "sync_seq" AS BIGINT;

-- Every write to a synced row gets a new seq, a bumped version and a server
-- updated_at, whatever code path performed it (including cascades).
CREATE FUNCTION "sync_touch"() RETURNS trigger AS $$
BEGIN
  NEW."seq" := nextval('sync_seq');
  NEW."updated_at" := now();
  IF TG_OP = 'UPDATE' THEN
    NEW."version" := OLD."version" + 1;
  ELSE
    NEW."version" := 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "boards_sync_touch" BEFORE INSERT OR UPDATE ON "boards"
  FOR EACH ROW EXECUTE FUNCTION "sync_touch"();
CREATE TRIGGER "board_columns_sync_touch" BEFORE INSERT OR UPDATE ON "board_columns"
  FOR EACH ROW EXECUTE FUNCTION "sync_touch"();
CREATE TRIGGER "cards_sync_touch" BEFORE INSERT OR UPDATE ON "cards"
  FOR EACH ROW EXECUTE FUNCTION "sync_touch"();
CREATE TRIGGER "checklist_items_sync_touch" BEFORE INSERT OR UPDATE ON "checklist_items"
  FOR EACH ROW EXECUTE FUNCTION "sync_touch"();
CREATE TRIGGER "comments_sync_touch" BEFORE INSERT OR UPDATE ON "comments"
  FOR EACH ROW EXECUTE FUNCTION "sync_touch"();
