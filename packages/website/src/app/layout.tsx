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
  title: "kitup - AI Coding Assistant Updater",
  description: "Update AI coding assistants with one command while preserving the active package manager on your PATH across macOS, Linux, and Windows.",
  keywords: ["AI", "CLI", "developer tools", "Claude Code", "OpenCode", "Codex", "Gemini CLI", "Goose", "Aider", "Chocolatey", "Scoop"],
  authors: [{ name: "volcanicll" }],
  openGraph: {
    title: "kitup - AI Coding Assistant Updater",
    description: "A path-aware updater for AI coding assistants across macOS, Linux, and Windows.",
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
        <div className="gradient-bg" />
        <div className="grid-pattern" />
        <div className="noise" />
        <div className="orb orb-1" />
        <div className="orb orb-2" />
        <div className="orb orb-3" />
        <div className="orb orb-4" />
        {children}
      </body>
    </html>
  );
}
