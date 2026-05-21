export default function Hero() {
    return (
        <section className="flex flex-col items-center text-center gap-8 mt-10">
        
        {/* Title */}
        <h1 className="text-4xl md:text-6xl font-extrabold leading-tight text-gray-900 dark:text-white">
            Detect Truth. <br />
            <span className="text-blue-600">Fight Misinformation.</span>
        </h1>

        {/* Subtitle */}
        <p className="max-w-2xl text-lg md:text-xl text-gray-600 dark:text-gray-400">
            A powerful AI-driven platform that helps you verify facts and detect
            AI-generated images instantly. Stay informed, stay ahead.
        </p>

        {/* Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 mt-4">
            
            <a
            href="/Objectives"
            className="rounded-full bg-blue-600 px-8 py-3 text-white font-medium shadow-md hover:bg-blue-700 transition"
            >
            Learn More
            </a>

            <a
            href="/download"
            className="rounded-full bg-green-600 px-8 py-3 text-white font-medium shadow-md hover:bg-green-700 transition"
            >
            Download App
            </a>
        </div>

        {/* Optional badge */}
        <div className="mt-6 text-sm text-gray-500 dark:text-gray-400">
            🚀 AI-powered • ⚡ Fast • 🔒 Reliable
        </div>
        </section>
    );
}