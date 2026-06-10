"use client";

import { useEffect, useMemo, useState } from "react";
import { CopyButton } from "@/components/ui/copy-button";
import { FadeIn } from "@/components/ui/fade-in";

const INSTALL_COMMANDS = {
  unix: {
    platform: "macOS / Linux",
    command:
      "curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash",
  },
  windows: {
    platform: "Windows",
    command:
      "irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex",
  },
};

export function Hero() {
  const [platform, setPlatform] = useState<"unix" | "windows">("unix");

  useEffect(() => {
    if (navigator.userAgent.toLowerCase().includes("win")) {
      setPlatform("windows");
    }
  }, []);

  const current = useMemo(() => INSTALL_COMMANDS[platform], [platform]);
  const alternate =
    platform === "windows" ? INSTALL_COMMANDS.unix : INSTALL_COMMANDS.windows;

  return (
    <section className="min-h-screen flex items-center justify-center pt-14 px-6">
      <div className="max-w-3xl mx-auto text-center">
        <FadeIn>
          <div className="mb-8">
            <span className="text-sm text-text-dim tracking-wide">
              One command for all your AI tools
            </span>
          </div>
        </FadeIn>

        <FadeIn>
          <h1 className="text-5xl md:text-6xl font-bold leading-tight tracking-tight mb-6">
            Update all your
            <br />
            AI tools.
            <span className="text-text-muted"> One command.</span>
          </h1>
        </FadeIn>

        <FadeIn>
          <p className="text-lg text-text-muted max-w-xl mx-auto mb-12 leading-relaxed">
            kitup keeps 12 AI coding assistants current across npm, Homebrew,
            pipx, and standalone installs. PATH-aware. Cross-platform. Zero
            dependencies.
          </p>
        </FadeIn>

        {/* 安装命令 */}
        <FadeIn>
          <div className="max-w-2xl mx-auto mb-4">
            <div className="bg-bg-raised border border-border rounded-xl overflow-hidden">
              <div className="flex items-center justify-between px-4 py-3 border-b border-border">
                <span className="text-xs text-text-dim font-mono">
                  {current.platform}
                </span>
                <CopyButton text={current.command} />
              </div>
              <div className="px-4 py-4">
                <code className="text-sm font-mono text-text-muted break-all">
                  {current.command}
                </code>
              </div>
            </div>
          </div>
        </FadeIn>

        <FadeIn>
          <button
            onClick={() =>
              setPlatform(platform === "unix" ? "windows" : "unix")
            }
            className="text-xs text-text-dim hover:text-text-muted transition-colors mb-16"
          >
            Also available for {alternate.platform} →
          </button>
        </FadeIn>

        {/* 统计 */}
        <FadeIn>
          <div className="flex items-center justify-center gap-8 text-sm text-text-dim">
            <span>
              <strong className="text-text font-medium">12</strong> tools
            </span>
            <span className="w-px h-4 bg-border" />
            <span>
              <strong className="text-text font-medium">5</strong> package
              managers
            </span>
            <span className="w-px h-4 bg-border" />
            <span>
              <strong className="text-text font-medium">~9MB</strong> binary
            </span>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
