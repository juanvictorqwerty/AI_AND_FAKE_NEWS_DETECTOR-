import { neon } from "@neondatabase/serverless";

export default async function ActualUsers() {
    const db = neon(process.env.DATABASE_URL!);
    const users = await db.query("SELECT COUNT(*) as count FROM users");

    return (
        <section className="w-full mt-16 flex flex-col items-center">
        <div className="bg-linear-to-r from-blue-600 to-indigo-600 text-white rounded-2xl px-10 py-8 shadow-lg text-center">
            
            <p className="text-sm uppercase tracking-widest opacity-80">
            Trusted by
            </p>

            <h2 className="text-5xl font-bold mt-2">
            {users[0].count}
            </h2>

            <p className="mt-2 text-lg opacity-90">
            users worldwide 🌍
            </p>
        </div>
        </section>
    );
}