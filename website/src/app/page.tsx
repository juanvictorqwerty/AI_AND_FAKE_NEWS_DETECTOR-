import Hero from "@/components/Hero";
import applogo from "../../public/applogo.png";
import ActualUsers from "@/components/actualUsers";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col items-center bg-linear-to-b from-zinc-50 to-white dark:from-black dark:to-zinc-900 font-sans">
      
      <main className="w-full max-w-5xl px-6 py-16 flex flex-col items-center">
        
        {/* Logo */}
        <img
          className="mb-6 dark:invert"
          src={applogo.src}
          alt="App logo"
          width={120}
        />

        {/* Hero */}
        <Hero />

        {/* Users */}
        <ActualUsers />

      </main>
    </div>
  );
}