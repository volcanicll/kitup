export interface ToolInfo {
  name: string;
  description: string;
  color: string;
  methods: string[];
}

// 与 Rust TOOL_REGISTRY (crates/kitup-core/src/tool.rs) 同步
export const TOOL_DATA: ToolInfo[] = [
  {
    name: "Claude Code",
    description: "Anthropic's AI coding assistant",
    color: "#D4A574",
    methods: ["npm", "brew", "standalone"],
  },
  {
    name: "OpenCode",
    description: "Open source AI coding assistant",
    color: "#00D9FF",
    methods: ["npm", "brew", "standalone"],
  },
  {
    name: "Codex",
    description: "OpenAI's official CLI tool",
    color: "#10A37F",
    methods: ["npm", "brew", "standalone"],
  },
  {
    name: "Gemini CLI",
    description: "Google's Gemini command line",
    color: "#4285F4",
    methods: ["npm", "brew"],
  },
  {
    name: "Kimi CLI",
    description: "Moonshot AI's terminal assistant",
    color: "#7CFFB2",
    methods: ["pipx", "uv"],
  },
  {
    name: "Cline CLI",
    description: "Cline's command-line agent",
    color: "#FF8C42",
    methods: ["npm"],
  },
  {
    name: "Qwen Code",
    description: "Alibaba Qwen's coding CLI",
    color: "#9D7CFF",
    methods: ["npm", "brew", "standalone"],
  },
  {
    name: "Goose",
    description: "Block's AI agent",
    color: "#FF6B35",
    methods: ["brew", "standalone"],
  },
  {
    name: "Aider",
    description: "AI pair programming tool",
    color: "#4A90E2",
    methods: ["pipx", "uv", "brew"],
  },
  {
    name: "Cursor CLI",
    description: "Cursor AI editor CLI",
    color: "#007ACC",
    methods: ["brew", "standalone"],
  },
  {
    name: "Windsurf CLI",
    description: "Codeium's AI assistant",
    color: "#00D9FF",
    methods: ["brew", "standalone"],
  },
  {
    name: "Tabby",
    description: "Self-hosted AI coding assistant",
    color: "#FF6B6B",
    methods: ["brew"],
  },
];
