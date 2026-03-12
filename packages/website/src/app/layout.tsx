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
  description: "Update all your AI coding assistants with a single command. Claude Code, OpenCode, Codex, Gemini CLI, Goose, and Aider.",
  keywords: ["AI", "CLI", "developer tools", "Claude Code", "OpenCode", "Codex", "Gemini CLI", "Goose", "Aider"],
  authors: [{ name: "volcanicll" }],
  openGraph: {
    title: "kitup - AI Coding Assistant Updater",
    description: "Update all your AI coding assistants with a single command",
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
