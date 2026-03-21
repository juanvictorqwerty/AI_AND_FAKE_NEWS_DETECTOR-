import { pgTable , timestamp, uuid ,boolean,varchar, jsonb,integer } from "drizzle-orm/pg-core";

export const usersTable = pgTable("users", {
    id: uuid("id").defaultRandom().primaryKey().notNull(),
    created_at:timestamp("created_at",{withTimezone:true}).defaultNow(),
    isAdmin: boolean("isAdmin").default(false).notNull(),
    isBanned:boolean("isBanned").default(false).notNull(),
    email:varchar("email",{length:255}).unique(),
    name:varchar("name",{length:255}),
    password:varchar("password",{length:255})
});

export const newsCheckedTable=pgTable("news_checked",{
    id:uuid("id").defaultRandom().primaryKey().notNull(),
    created_at:timestamp("created_at",{withTimezone:true}).defaultNow(),
    userID:uuid("userID").notNull().references(()=>usersTable.id),
    requests:jsonb("requests").notNull(),
    score:integer("score").notNull()
});

export const newsCheckedIndexTable=pgTable("news_checked_index",{
    userID:uuid("userID").primaryKey().notNull().references(()=>usersTable.id),
    newsList:jsonb("newsList")
});

export const mediaCheckedTable=pgTable("media_checked",{
    id:uuid("id").defaultRandom().primaryKey().notNull(),
    created_at:timestamp("created_at",{withTimezone:true}).defaultNow(),
    userID:uuid("userID").notNull().references(()=>usersTable.id),
    isPhoto:boolean("isPhoto").notNull(),
    isVideo:boolean("isVideo").notNull(),
    urlList:jsonb("url_list").notNull(),
    score:integer("score").notNull()
});

export const mediaCheckedIndexTable= pgTable("media_checked_index",{
    userID:uuid("userID").primaryKey().notNull().references(()=>usersTable.id),
    mediaCheckedList:jsonb("media_checked_list")
});

export const logsTable=pgTable("logs",{
    id:uuid("id").primaryKey().notNull().references(()=>usersTable.id),
    created_at:timestamp("created_at",{withTimezone:true}).defaultNow(),
    authorID:uuid("authorID"),
    isException:boolean("isException").default(false).notNull()
})