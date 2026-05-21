"use client";

import { Mail, Users, Lightbulb, GitBranch } from "lucide-react";

    export default function AboutUs() {
    return (
        <main className="min-h-screen px-6 py-12 flex flex-col items-center bg-white dark:bg-gray-900">

        {/* Header */}
        <div className="text-center max-w-3xl mb-12">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-800 dark:text-gray-100">
            About Us
            </h1>
            <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">
            Learn more about our mission, our project, and how to reach us.
            </p>
        </div>

        {/* Content */}
        <div className="grid gap-8 max-w-5xl w-full">

            {/* Who we are */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Users className="w-7 h-7 text-blue-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Who I Am
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                I am a passionate developer dedicated to building intelligent
                solutions to combat misinformation. This project focuses on designing
                and implementing a fact-checking application alongside an AI-powered
                image detection system.
            </p>
            </div>

            {/* Mission */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Lightbulb className="w-7 h-7 text-yellow-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Our Mission
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                We believe in promoting truth and authenticity in the digital age.
                Our goal is to empower users with tools that allow them to verify
                information, detect manipulated media, and make informed decisions
                online.
            </p>
            </div>

            {/* Contact */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Mail className="w-7 h-7 text-green-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Contact
                </h2>
            </div>

            <button
                onClick={() => {
                    const email = atob("anVhbnZpY3RvcnF3ZXJ0eUBnbWFpbC5jb20=");
                    window.location.href = `mailto:${email}`;
                }}
                className="px-6 py-2 bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold rounded-lg transition flex items-center gap-2"
            >
                <Mail className="w-5 h-5" />
                Send Email
            </button>
            </div>

            {/* Github */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <GitBranch className="w-7 h-7 text-gray-800 dark:text-gray-200" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Github Repository
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400 mb-4">
                Explore the source code, contribute, or follow development:
            </p>

            <a
                href="https://github.com/juanvictorqwerty/AI_AND_FAKE_NEWS_DETECTOR-.git"
                target="_blank"
                className="flex items-center gap-2 text-blue-500 hover:text-blue-700 dark:text-blue-400 break-all"
            >
                <GitBranch className="w-5 h-5" />
                View Repository
            </a>
            </div>

        </div>

        {/* Bottom Note */}
        <div className="mt-16 text-center max-w-2xl">
            <p className="text-gray-600 dark:text-gray-400">
            I am always open to new ideas and collaborations. Together, we can
            build a safer and more truthful digital world.
            </p>
        </div>

        </main>
    );
}