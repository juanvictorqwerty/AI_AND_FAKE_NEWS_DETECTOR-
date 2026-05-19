export default function Hero() {
    return (
        <main className="flex flex-col items-center gap-6 text-center">
        <h1 className="text-4xl font-bold text-gray-800 dark:text-gray-200">
            Welcome to our Design and implementation of a fact checking application and AI generated image detection system
        </h1>
        <p className="text-lg text-gray-600 dark:text-gray-400">
            Our project focuses on creating a powerful tool to combat misinformation by verifying facts and detecting AI-generated images. Join us in our mission to promote truth and authenticity in the digital age.
        </p>
        <a
            href="https://nextjs.org/docs"
            className="mt-4 inline-block rounded-full bg-blue-600 px-6 py-3 text-white transition-colors hover:bg-blue-700"
        >
            Learn More
        </a>

        <a
            href="URL"
            className="mt-4 inline-block rounded-full bg-green-600 px-6 py-3 text-white transition-colors hover:bg-green-700"
        >
            Download now
        </a>
        </main>
    );
}