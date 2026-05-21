"use client";

import { ShieldCheck, Search, Image as ImageIcon, Zap, Globe } from "lucide-react";

export default function ObjectiveComponent() {
    const objectives = [
        {
        title: "Fight Misinformation",
        icon: <ShieldCheck className="w-8 h-8 text-blue-500" />,
        description:
            "We aim to reduce the spread of false information by giving users reliable tools to verify content instantly and accurately.",
        },
        {
        title: "Real-time Fact Checking",
        icon: <Search className="w-8 h-8 text-green-500" />,
        description:
            "Our platform allows users to check the credibility of news, posts, and claims in seconds without disrupting their workflow.",
        },
        {
        title: "AI Image Detection",
        icon: <ImageIcon className="w-8 h-8 text-purple-500" />,
        description:
            "We provide advanced detection of AI-generated and manipulated images, including deepfakes and synthetic media.",
        },
        {
        title: "Seamless User Experience",
        icon: <Zap className="w-8 h-8 text-yellow-500" />,
        description:
            "Designed to integrate smoothly into daily digital habits, including background processing and share-based analysis.",
        },
        {
        title: "Promote Digital Trust",
        icon: <Globe className="w-8 h-8 text-red-500" />,
        description:
            "Our mission is to build a safer digital ecosystem where users can confidently trust the information they consume.",
        },
    ];

    return (
        <main className="min-h-screen px-6 py-12 flex flex-col items-center bg-white dark:bg-gray-900">
        
        {/* Header */}
        <div className="text-center max-w-3xl mb-12">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-800 dark:text-gray-100">
            Our Objectives
            </h1>
            <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">
            We are building intelligent tools to help users navigate the modern
            digital world, detect misinformation, and verify content with ease.
            </p>
        </div>

        {/* Objectives Grid */}
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 max-w-6xl w-full">
            {objectives.map((obj, index) => (
            <div
                key={index}
                className="p-6 rounded-2xl shadow-md bg-gray-50 dark:bg-gray-800 hover:shadow-xl transition duration-300"
            >
                <div className="mb-4">{obj.icon}</div>
                <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200 mb-2">
                {obj.title}
                </h2>
                <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
                {obj.description}
                </p>
            </div>
            ))}
        </div>

        {/* Bottom Section */}
        <div className="mt-16 max-w-3xl text-center">
            <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200 mb-4">
            Our Vision
            </h2>
            <p className="text-gray-600 dark:text-gray-400">
            We envision a future where misinformation is easily identifiable,
            where users are empowered with intelligent tools, and where truth
            becomes the default in digital communication. Our platform will
            continue evolving to meet emerging challenges in AI-generated content
            and online credibility.
            </p>
        </div>
        </main>
    );
}