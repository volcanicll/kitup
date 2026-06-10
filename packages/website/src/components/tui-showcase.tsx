import { FadeIn } from "@/components/ui/fade-in";

// TUI 仪表盘高保真模拟，基于 dashboard.rs 的实际布局
function TUIMockup() {
  return (
    <div className="bg-[#0c0c0e] border border-[#1a1a1a] rounded-xl overflow-hidden text-left">
      {/* 窗口标题栏 */}
      <div className="flex items-center gap-2 px-4 py-3 border-b border-[#1a1a1a]">
        <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
        <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
        <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
        <span className="ml-3 text-xs text-text-dim font-mono">kitup</span>
      </div>

      {/* 工具栏 */}
      <div className="flex items-center justify-between px-4 py-2 border-b border-[#1a1a1a] text-xs font-mono">
        <div className="flex gap-4">
          <span className="text-cyan-400 border-b border-cyan-400 pb-1">
            1:Tools
          </span>
          <span className="text-text-dim">2:Providers</span>
          <span className="text-text-dim">3:Health</span>
        </div>
        <span className="text-text-dim">[q]uit [?]help</span>
      </div>

      {/* 主内容：工具列表 */}
      <div className="p-4 font-mono text-sm leading-relaxed">
        <div className="text-text-dim text-xs mb-3 border-b border-[#1a1a1a] pb-2">
          Tools
        </div>

        {/* 表头 */}
        <div className="flex gap-3 text-xs text-text-dim mb-2 px-2">
          <span className="w-5" />
          <span className="w-28">NAME</span>
          <span className="w-28">VERSION</span>
          <span className="w-16">METHOD</span>
          <span>STATUS</span>
        </div>

        {/* 工具行 */}
        {[
          {
            sel: false,
            name: "claude",
            ver: "2.1.74",
            method: "npm",
            status: "up to date",
            statusColor: "text-green-400",
          },
          {
            sel: true,
            name: "codex",
            ver: "0.114.0",
            verLatest: "0.116.2",
            method: "brew",
            status: "update available",
            statusColor: "text-yellow-400",
          },
          {
            sel: true,
            name: "gemini",
            ver: "0.33.0",
            method: "npm",
            status: "up to date",
            statusColor: "text-green-400",
          },
          {
            sel: false,
            name: "aider",
            ver: "0.82.3",
            method: "pipx",
            status: "up to date",
            statusColor: "text-green-400",
          },
          {
            sel: false,
            name: "qwen",
            ver: "0.1.4",
            verLatest: "0.1.8",
            method: "npm",
            status: "update available",
            statusColor: "text-yellow-400",
          },
        ].map((tool) => (
          <div
            key={tool.name}
            className={`flex gap-3 py-1.5 px-2 rounded ${
              tool.name === "codex" ? "bg-[#1a1a1a]" : ""
            }`}
          >
            <span className="w-5 text-text-dim text-xs">
              {tool.sel ? "◉" : "○"}
            </span>
            <span className="w-28 text-text font-medium">{tool.name}</span>
            <span className="w-28 text-text-muted">
              {tool.ver}
              {tool.verLatest && (
                <span className="text-yellow-400">
                  {" "}
                  → {tool.verLatest}
                </span>
              )}
            </span>
            <span className="w-16 text-text-dim">{tool.method}</span>
            <span className={tool.statusColor}>{tool.status}</span>
          </div>
        ))}
      </div>

      {/* 操作栏 */}
      <div className="px-4 py-2 border-t border-[#1a1a1a] text-xs font-mono text-text-dim">
        <span className="text-cyan-400">[u]pdate</span>{" "}
        <span>[a]ll</span> <span>[Space]select</span>{" "}
        <span>[Enter]detail</span>
      </div>

      {/* 状态栏 */}
      <div className="px-4 py-2 border-t border-[#1a1a1a] text-xs font-mono flex gap-4">
        <span className="text-green-400">● 5 installed</span>
        <span className="text-yellow-400">↑ 2 updates</span>
        <span className="text-text-dim">◉ 2 selected</span>
      </div>
    </div>
  );
}

export function TUIShowcase() {
  return (
    <section className="py-24 px-6">
      <div className="max-w-4xl mx-auto">
        <FadeIn>
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-bold tracking-tight mb-4">
              See everything at a glance.
            </h2>
            <p className="text-text-muted max-w-lg mx-auto leading-relaxed">
              Multi-panel TUI with keyboard navigation, real-time version
              detection, and parallel updates. Runs with no arguments.
            </p>
          </div>
        </FadeIn>

        <FadeIn>
          <TUIMockup />
        </FadeIn>

        <FadeIn>
          <p className="text-center text-xs text-text-dim mt-6 font-mono">
            $ kitup
          </p>
        </FadeIn>
      </div>
    </section>
  );
}
