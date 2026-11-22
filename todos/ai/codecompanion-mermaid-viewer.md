# CodeCompanion: VS Code-quality Mermaid diagrams

Status: **open** (future enhancement, set 2026-11-22 by Myo). Needs dedicated
time; do not tweak piecemeal.

## Goal

Read Mermaid diagrams inside the CodeCompanion chat as clearly as VS Code
Copilot Chat does: the diagram is drawn in place of the code block, at full
panel width, sharp and readable, without leaving Neovim.

## What ships today (PR #71, #73, `lua/config/mermaid-chat.lua`)

- After a reply finishes (`CodeCompanionChatDone`), each ```` ```mermaid ````
  block gets an inline image under it (snacks.nvim image, `mmdr` renderer).
- `<leader>am` opens a popup viewer: `+`/`-` zoom, `hjkl` pan, `0` fit,
  `o` browser, `q` close. Each step is a `magick` crop of the full render.

## Why it is not good enough (Myo, 2026-11-22)

- The raw Mermaid source stays visible; the image is added below it, not in
  place of it.
- Inline images are hard to read, nowhere near VS Code.

## Findings to start from

- **mmdr layout wastes space.** On a real 26-node flowchart the nodes covered
  4.1% of a 4596x3842 canvas; no mmdr flag (spacing, fontSize, aspect ratio)
  got fitted text above ~5 px. `fontSize` must be a number.
- **snacks only scales down**, never zooms (`placement.lua` `state()`,
  `util.fit()`). Without a cap it also *upscales* small PNGs (~2.7x) because
  of 72 dpi metadata x terminal scale.
- **Viewer cost:** ~0.5-0.7 s per new zoom/pan step on a 4600 px render
  (`magick -crop ... -scale`); Lanczos was ~1.2 s, MPC cache didn't help.
- **mmdc (official, dagre) not yet measured.** Expected to be 2-3x tighter and
  correct (mmdr 0.2.2 misplaces `alt` boxes in sequence diagrams, ER labels
  overlap). Install: `npm i -g @mermaid-js/mermaid-cli` (Myo must run it; the
  agent's auto mode blocks global installs).
- snacks auto doc mode is the wrong tool: it re-renders on every streamed chunk.
- tmux can misplace inline images after scroll/resize.

## Ideas to evaluate

1. Hide the source block and draw the image in its place (snacks placement
   `conceal = true` over the fence range, as snacks does for math), with a key
   to toggle source/diagram.
2. Use mmdc (or mmdc for big diagrams only) for a tighter, correct layout.
3. Render the visible region straight from SVG (resvg/rsvg-convert) instead of
   cropping a huge PNG, for fast zoom/pan.
4. Text renderers (termaid, mermaid-ascii) as a fallback that is always sharp.
5. Render at the terminal's cell pixel size so text matches the chat font.

Related: chat markdown styling (Copilot Chat look) is PR #72.
