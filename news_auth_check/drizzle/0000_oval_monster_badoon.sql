CREATE TABLE "logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now(),
	"authorID" uuid,
	"isException" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "media_checked_index" (
	"userID" uuid PRIMARY KEY NOT NULL,
	"media_checked_list" jsonb
);
--> statement-breakpoint
CREATE TABLE "media_checked" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now(),
	"userID" uuid NOT NULL,
	"isPhoto" boolean NOT NULL,
	"isVideo" boolean NOT NULL,
	"url_list" jsonb NOT NULL,
	"score" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE "news_checked_index" (
	"userID" uuid PRIMARY KEY NOT NULL,
	"newsList" jsonb
);
--> statement-breakpoint
CREATE TABLE "news_checked" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now(),
	"userID" uuid NOT NULL,
	"requests" jsonb NOT NULL,
	"score" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"token" varchar(512) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now(),
	"expires_at" timestamp with time zone NOT NULL,
	"is_revoked" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now(),
	"isAdmin" boolean DEFAULT false NOT NULL,
	"isBanned" boolean DEFAULT false NOT NULL,
	"email" varchar(255),
	"name" varchar(255),
	"password" varchar(255),
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
ALTER TABLE "logs" ADD CONSTRAINT "logs_authorID_users_id_fk" FOREIGN KEY ("authorID") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "media_checked_index" ADD CONSTRAINT "media_checked_index_userID_users_id_fk" FOREIGN KEY ("userID") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "media_checked" ADD CONSTRAINT "media_checked_userID_users_id_fk" FOREIGN KEY ("userID") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "news_checked_index" ADD CONSTRAINT "news_checked_index_userID_users_id_fk" FOREIGN KEY ("userID") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "news_checked" ADD CONSTRAINT "news_checked_userID_users_id_fk" FOREIGN KEY ("userID") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tokens" ADD CONSTRAINT "tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;