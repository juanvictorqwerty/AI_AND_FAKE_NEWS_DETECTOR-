"use client";

import { Search, Image as ImageIcon, Share2, Bell, CheckCircle } from "lucide-react";

export default function Guide() {
    return (
        <main className="min-h-screen px-6 py-12 flex flex-col items-center bg-white dark:bg-gray-900">
        
        {/* Header */}
        <div className="text-center max-w-3xl mb-12">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-800 dark:text-gray-100">
            User Guide
            </h1>
            <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">
            Learn how to use our platform to verify information, detect AI-generated
            images, and fight misinformation effortlessly.
            </p>
        </div>

        {/* Sections */}
        <div className="grid gap-8 max-w-5xl w-full">

            {/* Fact Checking */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Search className="w-7 h-7 text-blue-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Fact-Checking Tool
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400 mb-4">
                Verify any claim instantly using our AI-powered fact-checking system.
            </p>

            <ul className="space-y-3 text-gray-600 dark:text-gray-400">
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Enter a claim or statement in the input bar
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                The system analyzes it using AI models
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Get a verdict (True / False / Uncertain)
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                View sources and explanations
                </li>
            </ul>
            </div>

            {/* Image Detection */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <ImageIcon className="w-7 h-7 text-purple-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                AI Image Detection
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400 mb-4">
                Detect deepfakes and AI-generated images in seconds.
            </p>

            <ul className="space-y-3 text-gray-600 dark:text-gray-400">
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Upload or share an image
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                AI analyzes patterns and inconsistencies
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Receive a confidence score
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Understand why the image may be AI-generated
                </li>
            </ul>
            </div>

            {/* Background Mode */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Bell className="w-7 h-7 text-yellow-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Background Mode
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400">
                Our app works seamlessly in the background. You can verify content
                without interrupting your workflow.
            </p>

            <ul className="mt-4 space-y-3 text-gray-600 dark:text-gray-400">
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Results appear as notifications
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                No need to open the app manually
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Fast and non-intrusive experience
                </li>
            </ul>
            </div>

            {/* Smart Integration */}
            <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-800 shadow-md">
            <div className="flex items-center gap-3 mb-4">
                <Share2 className="w-7 h-7 text-pink-500" />
                <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200">
                Smart Integration
                </h2>
            </div>

            <p className="text-gray-600 dark:text-gray-400">
                Use the app directly from other apps like social media or your browser.
            </p>

            <ul className="mt-4 space-y-3 text-gray-600 dark:text-gray-400">
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Use the “Share” button to send images
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Works with Facebook, Instagram, browsers
                </li>
                <li className="flex gap-2">
                <CheckCircle className="text-green-500 w-5 h-5 mt-1" />
                Instant analysis in the background
                </li>
            </ul>
            </div>

        </div>

        {/* Bottom CTA */}
        <div className="mt-16 text-center max-w-2xl">
            <h2 className="text-2xl font-semibold text-gray-800 dark:text-gray-200 mb-4">
            Start Fighting Misinformation Today
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
            Use these tools daily to verify content and contribute to a more
            truthful digital world.
            </p>

            <a
            href="/download"
            className="inline-block rounded-full bg-blue-600 px-8 py-3 text-white font-medium shadow-md hover:bg-blue-700 transition"
            >
            Get Started
            </a>
        </div>

        </main>
    );
}