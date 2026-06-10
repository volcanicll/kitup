import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "kitup — Update All AI Coding Assistants",
  description:
    "One command to update Claude Code, Codex, Gemini CLI, and 9 more AI tools. PATH-aware, cross-platform, zero dependencies.",
  keywords: [
    "AI",
    "CLI",
    "developer tools",
    "Claude Code",
    "Codex",
    "Gemini CLI",
    "updater",
    "package manager",
  ],
  authors: [{ name: "volcanicll" }],
  openGraph: {
    title: "kitup — Update All AI Coding Assistants",
    description:
      "One command to update 12 AI coding assistants. PATH-aware, cross-platform, zero dependencies.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
