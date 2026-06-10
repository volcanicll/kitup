import { FadeIn } from "@/components/ui/fade-in";
import { TOOL_DATA } from "@/data/tools";

export function ToolsList() {
  return (
    <section id="tools" className="py-24 px-6">
      <div className="max-w-5xl mx-auto">
        <FadeIn>
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold tracking-tight mb-4">
              12 AI tools. Every package manager.
            </h2>
            <p className="text-text-muted max-w-lg mx-auto leading-relaxed">
              Each tool updated through its native source — npm, Homebrew, pipx,
              uv, or standalone installer.
            </p>
          </div>
        </FadeIn>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {TOOL_DATA.map((tool) => (
            <FadeIn key={tool.name}>
              <div className="bg-bg-raised border border-border rounded-lg p-5 hover:border-border-hover transition-colors duration-200">
                <div className="flex items-center gap-3 mb-2">
                  <div
                    className="w-2.5 h-2.5 rounded-full shrink-0"
                    style={{ backgroundColor: tool.color }}
                  />
                  <span className="font-medium text-sm">{tool.name}</span>
                </div>
                <p className="text-xs text-text-muted mb-3 ml-[22px]">
                  {tool.description}
                </p>
                <div className="flex gap-1.5 ml-[22px]">
                  {tool.methods.map((method) => (
                    <span
                      key={method}
                      className="text-[10px] px-2 py-0.5 rounded bg-bg-subtle text-text-dim border border-border"
                    >
                      {method}
                    </span>
                  ))}
                </div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
