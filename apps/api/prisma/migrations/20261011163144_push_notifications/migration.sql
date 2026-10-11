-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('android', 'ios');

-- CreateTable
CREATE TABLE "device_tokens" (
    "token" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "platform" "DevicePlatform" NOT NULL,
    "locale" "AppLocale" NOT NULL DEFAULT 'en',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("token")
);

-- CreateTable
CREATE TABLE "due_reminders" (
    "card_id" UUID NOT NULL,
    "due_date" TIMESTAMP(3) NOT NULL,
    "sent_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "due_reminders_pkey" PRIMARY KEY ("card_id","due_date")
);

-- CreateIndex
CREATE INDEX "device_tokens_user_id_idx" ON "device_tokens"("user_id");

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "due_reminders" ADD CONSTRAINT "due_reminders_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;
