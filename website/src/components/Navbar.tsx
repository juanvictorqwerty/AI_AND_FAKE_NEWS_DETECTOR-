"use client";

import { usePathname } from "next/navigation";

export default function Navbar() {
    const pathname = usePathname();

    const isActive = (path: string) => {
        if (path === "/" && pathname === "/") return true;
        if (path !== "/" && pathname.startsWith(path)) return true;
        return false;
    };

    const navLinks = [
        { label: "Home", path: "/" },
        { label: "Guide", path: "/Guide" },
        { label: "Objectives", path: "/Objectives" },
        { label: "About Us", path: "/AboutUs" },
    ];

    return (
        <nav className="w-full bg-linear-to-r from-blue-600 to-purple-600 dark:from-blue-900 dark:to-purple-900 shadow-lg sticky top-0 z-50">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">
                    <div className="flex items-center">
                        <a 
                            href="/" 
                            className="text-2xl font-bold text-white hover:text-gray-100 transition-colors duration-200"
                        >
                            AFND
                        </a>
                    </div>
                    <div className="hidden md:block">
                        <div className="ml-10 flex items-baseline space-x-1">
                            {navLinks.map((link) => (
                                <a
                                    key={link.path}
                                    href={link.path}
                                    className={`px-4 py-2 rounded-md text-sm font-medium transition-all duration-200 ${
                                        isActive(link.path)
                                            ? "bg-white dark:bg-gray-200 text-blue-600 dark:text-blue-900 shadow-md"
                                            : "text-white hover:bg-blue-500 dark:hover:bg-blue-800 hover:text-white"
                                    }`}
                                >
                                    {link.label}
                                </a>
                            ))}
                        </div>
                    </div>
                    {/* Mobile menu button (optional - can be expanded) */}
                    <div className="md:hidden">
                        <div className="flex items-baseline space-x-1">
                            {navLinks.map((link) => (
                                <a
                                    key={link.path}
                                    href={link.path}
                                    className={`px-2 py-1 rounded text-xs font-medium transition-all duration-200 ${
                                        isActive(link.path)
                                            ? "bg-white dark:bg-gray-200 text-blue-600 dark:text-blue-900"
                                            : "text-white hover:bg-blue-500 dark:hover:bg-blue-800"
                                    }`}
                                >
                                    {link.label}
                                </a>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        </nav>
    );
}