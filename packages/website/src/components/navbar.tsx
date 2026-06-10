import { Github } from "lucide-react";

export function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-border bg-bg/80 backdrop-blur-sm">
      <div className="max-w-5xl mx-auto px-6 h-14 flex items-center justify-between">
        <a href="/" className="flex items-center gap-2">
          <span className="text-lg font-semibold tracking-tight">kitup</span>
          <span className="text-xs text-text-dim border border-border rounded px-1.5 py-0.5">
            v0.2.0
          </span>
        </a>

        <div className="flex items-center gap-6">
          <a
            href="#features"
            className="text-sm text-text-muted hover:text-text transition-colors"
          >
            Features
          </a>
          <a
            href="#tools"
            className="text-sm text-text-muted hover:text-text transition-colors"
          >
            Tools
          </a>
          <a
            href="https://github.com/volcanicll/kitup"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 text-sm text-text-muted hover:text-text transition-colors"
          >
            <Github className="w-4 h-4" />
            GitHub
          </a>
        </div>
      </div>
    </nav>
  );
}
