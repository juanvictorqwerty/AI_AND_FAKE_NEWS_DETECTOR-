ALTER TABLE "news_checked" ADD COLUMN "response" jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "news_checked" DROP COLUMN "score";