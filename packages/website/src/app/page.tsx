"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  Terminal,
  Sparkles,
  Zap,
  Shield,
  Globe,
  ChevronRight,
  Github,
  Package,
  Download,
  Cpu,
  Bot,
  Code2,
  Bird,
  GitBranch,
  Copy,
  Check,
  MoonStar,
  Workflow,
  BrainCircuit,
} from "lucide-react";

const tools = [
  {
    name: "Claude Code",
    description: "Anthropic's AI coding assistant",
    icon: Bot,
    color: "#D4A574",
    installMethods: ["npm", "brew"],
  },
  {
    name: "OpenCode",
    description: "Open source AI coding assistant",
    icon: Code2,
    color: "#00D9FF",
    installMethods: ["npm", "brew", "choco", "scoop", "curl"],
  },
  {
    name: "Codex",
    description: "OpenAI's official CLI tool",
    icon: Terminal,
    color: "#10A37F",
    installMethods: ["npm", "brew", "choco"],
  },
  {
    name: "Gemini CLI",
    description: "Google's Gemini command line",
    icon: Sparkles,
    color: "#4285F4",
    installMethods: ["npm", "choco"],
  },
  {
    name: "Kimi CLI",
    description: "Moonshot AI's terminal coding assistant",
    icon: MoonStar,
    color: "#7CFFB2",
    installMethods: ["pipx", "uv"],
  },
  {
    name: "Cline CLI",
    description: "Cline's command-line agent workflow",
    icon: Workflow,
    color: "#FF8C42",
    installMethods: ["npm"],
  },
  {
    name: "Qwen Code",
    description: "Alibaba Qwen's coding CLI",
    icon: BrainCircuit,
    color: "#9D7CFF",
    installMethods: ["npm", "brew", "curl"],
  },
  {
    name: "Goose",
    description: "Block's AI agent",
    icon: Bird,
    color: "#FF6B35",
    installMethods: ["curl", "brew"],
  },
  {
    name: "Aider",
    description: "AI pair programming tool",
    icon: GitBranch,
    color: "#4A90E2",
    installMethods: ["pipx", "uv", "brew"],
  },
  {
    name: "Cursor CLI",
    description: "Cursor AI editor command line tool",
    icon: Terminal,
    color: "#007ACC",
    installMethods: ["brew", "curl"],
  },
  {
    name: "Windsurf CLI",
    description: "Codeium's AI programming assistant",
    icon: Sparkles,
    color: "#00D9FF",
    installMethods: ["brew", "curl"],
  },
  {
    name: "Tabby",
    description: "Self-hosted AI coding assistant",
    icon: Cpu,
    color: "#FF6B6B",
    installMethods: ["brew"],
  },
];

const features = [
  {
    icon: Zap,
    title: "One Command",
    description: "Update all your AI tools with a single command. No more manual checking.",
  },
  {
    icon: Shield,
    title: "PATH Aware",
    description: "Prefers the binary currently selected by your shell instead of updating the wrong duplicate install.",
  },
  {
    icon: Globe,
    title: "Cross Platform",
    description: "Works across macOS, Linux, and Windows with platform-specific implementations behind one entry command.",
  },
  {
    icon: Package,
    title: "Native Sources",
    description: "Supports npm, Homebrew, pipx, uv, Chocolatey, Scoop, and official installers.",
  },
  {
    icon: Cpu,
    title: "Parallel Updates",
    description: "Update multiple tools simultaneously with configurable parallel jobs for faster updates.",
  },
  {
    icon: GitBranch,
    title: "Version Pinning",
    description: "Pin specific versions of tools to prevent unwanted updates while keeping others current.",
  },
];

const capabilityCards = [
  {
    title: "Stable Entry Command",
    body: "Installers place one `kitup` entry command in PATH and dispatch to the right implementation for the host platform.",
  },
  {
    title: "Windows Package Managers",
    body: "The PowerShell implementation now supports Chocolatey and Scoop for tools that ship native Windows packages.",
  },
  {
    title: "Regression Backed",
    body: "The CLI package includes repeatable regression tests for PATH priority, restore flow, and entrypoint dispatch.",
  },
];

const installCommands = {
  unix: {
    platform: "macOS / Linux",
    command: "curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash",
  },
  windows: {
    platform: "Windows PowerShell",
    command: 'irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex',
  },
};

function AnimatedCounter({ end, duration = 2000 }: { end: number; duration?: number }) {
  const [count, setCount] = useState(0);
  const countRef = useRef<HTMLSpanElement>(null);
  const hasAnimated = useRef(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !hasAnimated.current) {
          hasAnimated.current = true;
          let startTime: number;
          const animate = (currentTime: number) => {
            if (!startTime) startTime = currentTime;
            const progress = Math.min((currentTime - startTime) / duration, 1);
            setCount(Math.floor(progress * end));
            if (progress < 1) {
              requestAnimationFrame(animate);
            }
          };
          requestAnimationFrame(animate);
        }
      },
      { threshold: 0.5 }
    );

    if (countRef.current) {
      observer.observe(countRef.current);
    }

    return () => observer.disconnect();
  }, [end, duration]);

  return <span ref={countRef}>{count}</span>;
}

function ScrollReveal({ children, delay = 0 }: { children: React.ReactNode; delay?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setTimeout(() => setIsVisible(true), delay);
        }
      },
      { threshold: 0.1 }
    );

    if (ref.current) {
      observer.observe(ref.current);
    }

    return () => observer.disconnect();
  }, [delay]);

  return (
    <div
      ref={ref}
      className={`transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
    >
      {children}
    </div>
  );
}

function TerminalDemo() {
  const [lines, setLines] = useState<string[]>([]);
  const [currentLine, setCurrentLine] = useState(0);
  const terminalRef = useRef<HTMLDivElement>(null);

  const demoLines = [
    { text: "kitup --all --dry-run", type: "input" },
    { text: "Checking installed tools and active PATH targets...", type: "output", delay: 300 },
    { text: "claude is already up to date (2.1.74)", type: "output", delay: 700 },
    { text: "Updating codex from 0.106.0 to 0.114.0...", type: "output", delay: 1100 },
    { text: "[DRY RUN] Would update codex using brew", type: "output", delay: 1450 },
    { text: "Updating gemini from 0.28.0 to 0.33.0...", type: "output", delay: 1800 },
    { text: "[DRY RUN] Would update gemini using npm", type: "output", delay: 2150 },
    { text: "Update Summary: Updated 2, Failed 0, Skipped 4", type: "output", delay: 2800 },
  ];

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          runDemo();
        }
      },
      { threshold: 0.5 }
    );

    if (terminalRef.current) {
      observer.observe(terminalRef.current);
    }

    return () => observer.disconnect();
  }, []);

  const runDemo = () => {
    setLines([]);
    setCurrentLine(0);

    demoLines.forEach((line, index) => {
      setTimeout(() => {
        if (line.type === "input") {
          setLines((prev) => [...prev, `$ ${line.text}`]);
        } else {
          setLines((prev) => [...prev, line.text]);
        }
        setCurrentLine(index);
      }, line.delay || index * 500);
    });
  };

  return (
    <div ref={terminalRef} className="terminal w-full max-w-2xl mx-auto">
      <div className="terminal-header">
        <div className="terminal-dot terminal-dot-red" />
        <div className="terminal-dot terminal-dot-yellow" />
        <div className="terminal-dot terminal-dot-green" />
        <span className="ml-4 text-sm text-white/40">kitup demo</span>
      </div>
      <div className="terminal-body min-h-[280px]">
        {lines.map((line, index) => (
          <div
            key={index}
            className={`terminal-line ${line.startsWith("$") ? "text-[var(--accent-1)]" : "text-white/70"
              }`}
          >
            {line}
          </div>
        ))}
        {currentLine >= demoLines.length - 1 && (
          <div className="terminal-line mt-4">
            <span className="text-[var(--accent-1)]">$</span>
            <span className="terminal-cursor" />
          </div>
        )}
      </div>
    </div>
  );
}

function CopyCommandBlock({ platform, command }: { platform: string; command: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <div className="group">
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-white/50">{platform}</span>
        <span className={`text-xs transition-all duration-300 ${copied ? 'text-green-400 opacity-100' : 'opacity-0'}`}>
          Copied!
        </span>
      </div>
      <div className="relative">
        <div className="terminal overflow-hidden">
          <div className="terminal-body pr-12">
            <code className="text-[var(--accent-1)] break-all">{command}</code>
          </div>
        </div>
        <button
          onClick={handleCopy}
          className="absolute right-3 top-1/2 -translate-y-1/2 p-2 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 hover:border-white/20 transition-all duration-200 opacity-0 group-hover:opacity-100 focus:opacity-100"
          aria-label="Copy command"
        >
          {copied ? (
            <Check className="w-4 h-4 text-green-400" />
          ) : (
            <Copy className="w-4 h-4 text-white/60" />
          )}
        </button>
      </div>
    </div>
  );
}

export default function Home() {
  const [detectedPlatform, setDetectedPlatform] = useState<"unix" | "windows">("unix");

  useEffect(() => {
    const userAgent = navigator.userAgent.toLowerCase();
    if (userAgent.includes("win")) {
      setDetectedPlatform("windows");
    } else {
      setDetectedPlatform("unix");
    }
  }, []);

  const recommendedInstall = useMemo(() => installCommands[detectedPlatform], [detectedPlatform]);
  const alternateInstall = detectedPlatform === "windows" ? installCommands.unix : installCommands.windows;

  return (
    <main className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 glass">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[var(--accent-1)] to-[var(--accent-3)] flex items-center justify-center">
              <Zap className="w-5 h-5 text-black" />
            </div>
            <span className="text-xl font-bold">kitup</span>
          </div>
          <div className="flex items-center gap-6">
            <a href="#tools" className="text-sm text-white/60 hover:text-white transition-colors link-hover">
              Tools
            </a>
            <a href="#features" className="text-sm text-white/60 hover:text-white transition-colors link-hover">
              Features
            </a>
            <a
              href="https://github.com/volcanicll/kitup"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-sm text-white/60 hover:text-white transition-colors"
            >
              <Github className="w-4 h-4" />
              GitHub
            </a>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center pt-20 px-6">
        <div className="max-w-5xl mx-auto text-center">
          <ScrollReveal>
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-8">
              <span className="status-dot status-dot-online" />
              <span className="text-sm text-white/70">v0.0.12 Now Available</span>
            </div>
          </ScrollReveal>

          <ScrollReveal delay={100}>
            <h1 className="text-5xl md:text-7xl font-bold mb-6 leading-tight">
              Update All Your{" "}
              <span className="gradient-text">AI Tools</span>
              <br />
              With One Command
            </h1>
          </ScrollReveal>

          <ScrollReveal delay={200}>
              <p className="text-lg md:text-xl text-white/60 max-w-2xl mx-auto mb-10">
              kitup keeps Claude Code, OpenCode, Codex, Gemini CLI, Kimi CLI, Cline CLI, Qwen Code, Goose, and Aider current
              without switching package managers behind your back.
            </p>
          </ScrollReveal>

          <ScrollReveal delay={300}>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
              <a
                href="#install"
                className="btn-primary flex items-center gap-2"
              >
                <Download className="w-5 h-5" />
                Install Now
              </a>
              <a
                href="https://github.com/volcanicll/kitup"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary flex items-center gap-2"
              >
                <Github className="w-5 h-5" />
                View on GitHub
              </a>
            </div>
          </ScrollReveal>

          <ScrollReveal delay={400}>
            <div className="grid grid-cols-3 gap-8 max-w-lg mx-auto">
              <div className="text-center">
                <div className="text-3xl font-bold gradient-text-alt">
                  <AnimatedCounter end={12} />
                </div>
                <div className="text-sm text-white/50 mt-1">AI Tools</div>
              </div>
              <div className="text-center">
              <div className="text-3xl font-bold gradient-text">
                  <AnimatedCounter end={7} />
                </div>
                <div className="text-sm text-white/50 mt-1">Package Sources</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-[var(--accent-1)]">1</div>
                <div className="text-sm text-white/50 mt-1">Command</div>
              </div>
            </div>
          </ScrollReveal>
        </div>

        {/* Scroll indicator */}
        <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
          <ChevronRight className="w-6 h-6 text-white/30 rotate-90" />
        </div>
      </section>

      {/* Terminal Demo Section */}
      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">See It In Action</h2>
              <p className="text-white/60 max-w-xl mx-auto">
                Watch kitup resolve active binaries, match the right update source, and preview changes safely.
              </p>
            </div>
          </ScrollReveal>

          <ScrollReveal delay={200}>
            <TerminalDemo />
          </ScrollReveal>
        </div>
      </section>

      <div className="section-divider max-w-4xl mx-auto" />

      {/* Tools Section */}
      <section id="tools" className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">
                Supported <span className="gradient-text">AI Tools</span>
              </h2>
              <p className="text-white/60 max-w-xl mx-auto">
                kitup supports major AI coding assistants across package managers and direct installers.
              </p>
            </div>
          </ScrollReveal>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {tools.map((tool, index) => (
              <ScrollReveal key={tool.name} delay={index * 100}>
                <div className="tool-card glass-card rounded-2xl p-6 h-full">
                  <div className="flex items-start justify-between mb-4">
                    <div
                      className="w-12 h-12 rounded-xl flex items-center justify-center"
                      style={{ background: `${tool.color}20` }}
                    >
                      <tool.icon className="w-6 h-6" style={{ color: tool.color }} />
                    </div>
                    <div className="flex gap-1">
                      {tool.installMethods.map((method) => (
                        <span
                          key={method}
                          className="text-xs px-2 py-1 rounded-full bg-white/5 text-white/50"
                        >
                          {method}
                        </span>
                      ))}
                    </div>
                  </div>
                  <h3 className="text-lg font-semibold mb-2">{tool.name}</h3>
                  <p className="text-sm text-white/50">{tool.description}</p>
                </div>
              </ScrollReveal>
            ))}
          </div>
        </div>
      </section>

      {/* Tool Comparison Matrix */}
      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">
                Tool <span className="gradient-text">Comparison</span>
              </h2>
              <p className="text-white/60 max-w-xl mx-auto">
                Compare supported tools and their available installation methods.
              </p>
            </div>
          </ScrollReveal>

          <ScrollReveal delay={200}>
            <div className="glass-card rounded-2xl overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-white/10">
                      <th className="text-left p-4 font-semibold">Tool</th>
                      <th className="text-center p-4 font-semibold">npm</th>
                      <th className="text-center p-4 font-semibold">Homebrew</th>
                      <th className="text-center p-4 font-semibold">pipx/uv</th>
                      <th className="text-center p-4 font-semibold">Chocolatey</th>
                      <th className="text-center p-4 font-semibold">Scoop</th>
                      <th className="text-center p-4 font-semibold">Standalone</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tools.map((tool, index) => (
                      <tr key={tool.name} className={index % 2 === 0 ? "bg-white/5" : ""}>
                        <td className="p-4 font-medium">{tool.name}</td>
                        <td className="text-center p-4">
                          {tool.installMethods.includes("npm") && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                        <td className="text-center p-4">
                          {tool.installMethods.includes("brew") && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                        <td className="text-center p-4">
                          {(tool.installMethods.includes("pipx") || tool.installMethods.includes("uv")) && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                        <td className="text-center p-4">
                          {tool.installMethods.includes("choco") && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                        <td className="text-center p-4">
                          {tool.installMethods.includes("scoop") && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                        <td className="text-center p-4">
                          {tool.installMethods.includes("curl") && <Check className="w-4 h-4 mx-auto text-green-400" />}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </ScrollReveal>
        </div>
      </section>

      <div className="section-divider max-w-4xl mx-auto" />

      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">
                Built For <span className="gradient-text">Real Environments</span>
              </h2>
              <p className="text-white/60 max-w-2xl mx-auto">
                Mixed installs happen. PATH drift happens. kitup is designed to update the tool you are actually invoking.
              </p>
            </div>
          </ScrollReveal>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {capabilityCards.map((card, index) => (
              <ScrollReveal key={card.title} delay={index * 100}>
                <div className="glass-card rounded-2xl p-7 h-full">
                  <div className="text-sm uppercase tracking-[0.24em] text-[var(--accent-1)]/70 mb-3">
                    {String(index + 1).padStart(2, "0")}
                  </div>
                  <h3 className="text-xl font-semibold mb-3">{card.title}</h3>
                  <p className="text-white/55 leading-relaxed">{card.body}</p>
                </div>
              </ScrollReveal>
            ))}
          </div>
        </div>
      </section>

      <div className="section-divider max-w-4xl mx-auto" />

      {/* Features Section */}
      <section id="features" className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-16">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">
                Why <span className="gradient-text-alt">kitup</span>?
              </h2>
              <p className="text-white/60 max-w-xl mx-auto">
                Built for developers who want correct updates, not just convenient ones.
              </p>
            </div>
          </ScrollReveal>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {features.map((feature, index) => (
              <ScrollReveal key={feature.title} delay={index * 100}>
                <div className="glass-card rounded-2xl p-8 flex gap-6 group hover:scale-[1.02] transition-transform duration-300">
                  <div className="flex-shrink-0">
                    <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[var(--accent-1)]/20 to-[var(--accent-3)]/20 flex items-center justify-center icon-float">
                      <feature.icon className="w-7 h-7 text-[var(--accent-1)]" />
                    </div>
                  </div>
                  <div>
                    <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                    <p className="text-white/50 leading-relaxed">{feature.description}</p>
                  </div>
                </div>
              </ScrollReveal>
            ))}
          </div>
        </div>
      </section>

      <div className="section-divider max-w-4xl mx-auto" />

      {/* Install Section */}
      <section id="install" className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <ScrollReveal>
            <div className="text-center mb-12">
              <h2 className="text-3xl md:text-4xl font-bold mb-4">Quick Install</h2>
              <p className="text-white/60">
                Get started in seconds with a single command.
              </p>
            </div>
          </ScrollReveal>

          <ScrollReveal delay={200}>
            <div className="glass-card rounded-2xl p-8">
              <div className="flex items-center gap-3 mb-6">
                <Cpu className="w-5 h-5 text-[var(--accent-1)]" />
                <span className="font-medium">Recommended For Your Device</span>
              </div>

              <div className="space-y-4">
                <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[var(--accent-1)]/10 border border-[var(--accent-1)]/20 text-xs text-[var(--accent-1)] uppercase tracking-[0.18em]">
                  Detected {recommendedInstall.platform}
                </div>
                <CopyCommandBlock platform={recommendedInstall.platform} command={recommendedInstall.command} />
              </div>

              <div className="mt-8 pt-6 border-t border-white/10">
                <div className="flex items-center justify-between mb-4 gap-4 flex-wrap">
                  <p className="text-sm text-white/45">
                    Install bootstrap is platform-specific, but the installed command is always `kitup`.
                  </p>
                </div>
                <CopyCommandBlock platform={`Other option: ${alternateInstall.platform}`} command={alternateInstall.command} />
              </div>

              <div className="mt-8 pt-6 border-t border-white/10">
                <p className="text-sm text-white/40">
                  Installers fetch the versioned `packages/cli` entrypoint and dispatch to the matching platform script automatically. Source and releases live on{" "}
                  <a
                    href="https://github.com/volcanicll/kitup/releases"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[var(--accent-1)] hover:underline"
                  >
                    GitHub Releases
                  </a>
                </p>
              </div>
            </div>
          </ScrollReveal>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <ScrollReveal>
            <div className="glass-card rounded-3xl p-12 text-center relative overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-r from-[var(--accent-1)]/10 via-transparent to-[var(--accent-3)]/10" />
              <div className="relative z-10">
                <h2 className="text-3xl md:text-4xl font-bold mb-4">
                  Ready to Update?
                </h2>
                <p className="text-white/60 max-w-lg mx-auto mb-8">
                  Use one command, keep the active binary current, and stop guessing which package manager owns each tool.
                </p>
                <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                  <a
                    href="https://github.com/volcanicll/kitup"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-primary flex items-center gap-2"
                  >
                    <Github className="w-5 h-5" />
                    Star on GitHub
                  </a>
                  <a
                    href="#install"
                    className="btn-secondary flex items-center gap-2"
                  >
                    <Download className="w-5 h-5" />
                    Install kitup
                  </a>
                </div>
              </div>
            </div>
          </ScrollReveal>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6 border-t border-white/5">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[var(--accent-1)] to-[var(--accent-3)] flex items-center justify-center">
                <Zap className="w-5 h-5 text-black" />
              </div>
              <span className="text-lg font-bold">kitup</span>
            </div>

            <div className="flex items-center gap-6 text-sm text-white/40">
              <a
                href="https://github.com/volcanicll/kitup"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-white transition-colors"
              >
                GitHub
              </a>
              <a
                href="https://github.com/volcanicll/kitup/issues"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-white transition-colors"
              >
                Issues
              </a>
              <a
                href="https://github.com/volcanicll/kitup/releases"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-white transition-colors"
              >
                Releases
              </a>
            </div>

            <div className="text-sm text-white/30">
              © 2026 kitup. Made by{" "}
              <a
                href="https://github.com/volcanicll"
                target="_blank"
                rel="noopener noreferrer"
                className="text-white/50 hover:text-white"
              >
                volcanicll
              </a>
            </div>
          </div>
        </div>
      </footer>
    </main>
  );
}
