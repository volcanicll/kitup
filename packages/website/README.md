# kitup website

Static website for [kitup](https://github.com/volcanicll/kitup) — plain HTML, CSS, and vanilla JavaScript. No build dependencies, no framework.

## Development

```bash
pnpm dev        # serves on http://localhost:3000 (python http.server)
```

Or open `index.html` directly in a browser.

## Build

```bash
pnpm build      # copies the four files into dist/
```

## Deploy

GitHub Pages via `.github/workflows/website-deploy.yml` — builds `dist/` on every push to `main` under `packages/website/**`.

## Structure

- `index.html` — single-page markup (hero, TUI mockup, features, tools, CTA)
- `style.css` — amber-on-ink terminal editorial theme
- `main.js` — platform-aware install command, tools grid, marquee, scroll reveal
- `favicon.svg` — inline SVG icon

The tool list in `main.js` mirrors `crates/kitup-core/src/tool.rs` (`TOOL_REGISTRY`) — keep them in sync when adding tools.
