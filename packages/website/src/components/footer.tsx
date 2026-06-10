import { Github } from "lucide-react";

export function Footer() {
  return (
    <footer className="py-12 px-6 border-t border-border">
      <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold">kitup</span>
          <span className="text-xs text-text-dim">MIT License · v0.2.0</span>
        </div>

        <div className="flex items-center gap-6 text-sm text-text-dim">
          <a
            href="https://github.com/volcanicll/kitup"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-text transition-colors inline-flex items-center gap-1.5"
          >
            <Github className="w-3.5 h-3.5" />
            GitHub
          </a>
          <a
            href="https://github.com/volcanicll/kitup/releases"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-text transition-colors"
          >
            Releases
          </a>
          <a
            href="https://github.com/volcanicll/kitup/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-text transition-colors"
          >
            Issues
          </a>
        </div>

        <div className="text-xs text-text-dim">
          © 2026{" "}
          <a
            href="https://github.com/volcanicll"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-text-muted transition-colors"
          >
            volcanicll
          </a>
        </div>
      </div>
    </footer>
  );
}
