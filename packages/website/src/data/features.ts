export interface FeatureInfo {
  id: string;
  number: string;
  title: string;
  description: string;
  span: "full" | "half" | "third";
}

export const FEATURES: FeatureInfo[] = [
  {
    id: "path-aware",
    number: "01",
    title: "PATH-Aware",
    description:
      "Updates the binary on your PATH, not a random duplicate. Handles multi-install detection automatically.",
    span: "half",
  },
  {
    id: "one-command",
    number: "02",
    title: "One Command",
    description:
      "kitup update --all. Or select individual tools. Dry-run mode previews changes before touching anything.",
    span: "third",
  },
  {
    id: "cross-platform",
    number: "03",
    title: "Cross-Platform",
    description:
      "macOS (Apple Silicon + Intel), Linux, Windows. Single ~9MB binary, zero runtime dependencies.",
    span: "third",
  },
  {
    id: "tui",
    number: "04",
    title: "Interactive TUI",
    description:
      "Multi-panel dashboard with keyboard navigation, search, real-time version detection, and parallel updates.",
    span: "third",
  },
  {
    id: "provider",
    number: "05",
    title: "Provider Management",
    description:
      "Switch API providers for Claude, Codex, and Gemini. Circuit breaker failover. Config backup on every switch.",
    span: "half",
  },
  {
    id: "health",
    number: "06",
    title: "Health Diagnostics",
    description:
      "kitup doctor checks network connectivity, detects multi-installs, and auto-fixes configuration issues.",
    span: "third",
  },
];
