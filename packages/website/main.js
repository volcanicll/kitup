// kitup website — no dependencies

(function () {
  "use strict";

  // Progressive enhancement: only hide reveal targets when JS is running.
  document.documentElement.classList.add("js");

  /* ---------- install command, platform-aware ---------- */
  var INSTALL_COMMANDS = {
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

  var platformKey = /win/i.test(navigator.userAgent) ? "windows" : "unix";
  var commandEl = document.getElementById("install-command");
  var platformEl = document.getElementById("install-platform");
  var switchBtn = document.getElementById("install-switch");
  var copyBtn = document.getElementById("copy-btn");
  var copyLabel = document.getElementById("copy-label");

  function renderInstall() {
    var current = INSTALL_COMMANDS[platformKey];
    var other = INSTALL_COMMANDS[platformKey === "unix" ? "windows" : "unix"];
    commandEl.textContent = current.command;
    platformEl.textContent = current.platform;
    copyBtn.setAttribute("data-command", current.command);
    switchBtn.textContent = "also available for " + other.platform + " →";
  }

  switchBtn.addEventListener("click", function () {
    platformKey = platformKey === "unix" ? "windows" : "unix";
    renderInstall();
  });

  copyBtn.addEventListener("click", function () {
    var text = copyBtn.getAttribute("data-command") || "";
    function done(ok) {
      copyLabel.textContent = ok ? "copied ✓" : "copy failed";
      setTimeout(function () {
        copyLabel.textContent = "copy";
      }, 1600);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        function () { done(true); },
        function () { done(false); }
      );
    } else {
      var ta = document.createElement("textarea");
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
      document.body.removeChild(ta);
      done(ok);
    }
  });

  renderInstall();

  /* ---------- tools grid ---------- */
  // 与 Rust TOOL_REGISTRY (crates/kitup-core/src/tool.rs) 同步
  var TOOLS = [
    { name: "Claude Code", description: "Anthropic's AI coding assistant", color: "#D4A574", methods: ["npm", "brew", "standalone"] },
    { name: "OpenCode", description: "Open source AI coding assistant", color: "#00D9FF", methods: ["npm", "brew", "standalone"] },
    { name: "Codex", description: "OpenAI's official CLI tool", color: "#10A37F", methods: ["npm", "brew", "standalone"] },
    { name: "Gemini CLI", description: "Google's Gemini command line", color: "#4285F4", methods: ["npm", "brew"] },
    { name: "Kimi CLI", description: "Moonshot AI's terminal assistant", color: "#7CFFB2", methods: ["pipx", "uv"] },
    { name: "Cline CLI", description: "Cline's command-line agent", color: "#FF8C42", methods: ["npm"] },
    { name: "Qwen Code", description: "Alibaba Qwen's coding CLI", color: "#9D7CFF", methods: ["npm", "brew", "standalone"] },
    { name: "Goose", description: "Block's AI agent", color: "#FF6B35", methods: ["brew", "standalone"] },
    { name: "Aider", description: "AI pair programming tool", color: "#4A90E2", methods: ["pipx", "uv", "brew"] },
    { name: "Cursor CLI", description: "Cursor AI editor CLI", color: "#007ACC", methods: ["brew", "standalone"] },
    { name: "Windsurf CLI", description: "Codeium's AI assistant", color: "#00D9FF", methods: ["brew", "standalone"] },
    { name: "Tabby", description: "Self-hosted AI coding assistant", color: "#FF6B6B", methods: ["brew"] },
  ];

  var grid = document.getElementById("tools-grid");
  TOOLS.forEach(function (tool) {
    var card = document.createElement("article");
    card.className = "tool-card reveal";

    var head = document.createElement("div");
    head.className = "tool-head";
    var dot = document.createElement("span");
    dot.className = "tool-dot";
    dot.style.background = tool.color;
    var name = document.createElement("span");
    name.className = "tool-name";
    name.textContent = tool.name;
    head.appendChild(dot);
    head.appendChild(name);

    var desc = document.createElement("p");
    desc.className = "tool-desc";
    desc.textContent = tool.description;

    var methods = document.createElement("div");
    methods.className = "tool-methods";
    tool.methods.forEach(function (m) {
      var chip = document.createElement("span");
      chip.className = "tool-method";
      chip.textContent = m;
      methods.appendChild(chip);
    });

    card.appendChild(head);
    card.appendChild(desc);
    card.appendChild(methods);
    grid.appendChild(card);
  });

  /* ---------- marquee ---------- */
  var track = document.getElementById("marquee-track");
  // duplicate the list so the -50% keyframe loops seamlessly
  TOOLS
    .map(function (t) { return t.name; })
    .concat(TOOLS.map(function (t) { return t.name; }))
    .forEach(function (name) {
      var span = document.createElement("span");
      span.textContent = name;
      track.appendChild(span);
    });

  /* ---------- scroll reveal ---------- */
  document
    .querySelectorAll(".section-head, .terminal, .feature, .install-card, .hero-stats, .cta-actions")
    .forEach(function (el) { el.classList.add("reveal"); });

  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12 }
    );
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("is-visible"); });
  }
})();
