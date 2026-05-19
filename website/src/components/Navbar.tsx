export default function Navbar() {
    return (
        <nav className="w-full bg-white dark:bg-gray-800 shadow">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">
                    <div className="flex items-center">
                        <a href="/" className="text-xl font-bold text-gray-800 dark:text-gray-200">
                        FactCheckAI
                        </a>
                    </div>
                    <div className="hidden md:block">
                        <div className="ml-10 flex items-baseline space-x-4">
                            <a
                                href="/features"
                                className="text-gray-800 dark:text-gray-200 hover:text-gray-600 dark:hover:text-gray-400 px-3 py-2 rounded-md text-sm font-medium"
                            >
                                Features
                            </a>
                            <a
                                href="/about"
                                className="text-gray-800 dark:text-gray-200 hover:text-gray-600 dark:hover:text-gray-400 px-3 py-2 rounded-md text-sm font-medium"
                            >
                                About
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </nav>
    );
}