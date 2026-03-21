import { relations } from "drizzle-orm";
import { 
    usersTable, 
    newsCheckedTable, 
    newsCheckedIndexTable, 
    mediaCheckedTable, 
    mediaCheckedIndexTable, 
    logsTable 
} from "./schema";

export const usersRelations = relations(usersTable, ({ many }) => ({
    newsChecked: many(newsCheckedTable),
    newsCheckedIndex: many(newsCheckedIndexTable),
    mediaChecked: many(mediaCheckedTable),
    mediaCheckedIndex: many(mediaCheckedIndexTable),
    logs: many(logsTable)
}));

export const newsCheckedRelations = relations(newsCheckedTable, ({ one }) => ({
    user: one(usersTable, {
        fields: [newsCheckedTable.userID],
        references: [usersTable.id]
    })
}));

export const newsCheckedIndexRelations = relations(newsCheckedIndexTable, ({ one }) => ({
    user: one(usersTable, {
        fields: [newsCheckedIndexTable.userID],
        references: [usersTable.id]
    })
}));

export const mediaCheckedRelations = relations(mediaCheckedTable, ({ one }) => ({
    user: one(usersTable, {
        fields: [mediaCheckedTable.userID],
        references: [usersTable.id]
    })
}));

export const mediaCheckedIndexRelations = relations(mediaCheckedIndexTable, ({ one }) => ({
    user: one(usersTable, {
        fields: [mediaCheckedIndexTable.userID],
        references: [usersTable.id]
    })
}));

export const logsRelations = relations(logsTable, ({ one }) => ({
    author: one(usersTable, {
        fields: [logsTable.authorID],
        references: [usersTable.id]
    })
}));
