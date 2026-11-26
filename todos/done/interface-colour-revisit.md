# Interface Colour: Find a Better One Than Lavender

## Status

CLOSED 2026-11-27, the same day it was filed: the interface colour was dropped
altogether (interfaces use the type colour in every language), so there is no
colour left to improve. Reason and survey: `notes/palette-reference.md`,
"interface".

## The Idea

Go interface names (`@type.interface`) use lavender `#c0b3f5` since
2026-11-26 (TypeScript interfaces keep the gold type colour since 2026-11-27). It separates interfaces from the gold structs, but it is not
a favourite colour. Find a value that does the same job and looks better.

## Start Here

- Every measured candidate, the sweep method and why each lost:
  `notes/palette-reference.md`, section "interface".
- Already ruled out: periwinkle `#a7b1fe` (too close to the function blue,
  dE00 14.6), pink/mauve (not wanted), low-chroma lavenders (read flat).
- Constraint found in the sweep: the only open space left in the palette is the
  pink/mauve band; every other option trades function-blue distance against
  keyword-violet distance.
- The change is one line: `interface = ...` in the `custom-latest` build in
  `lua/colorschemes/solarized-osaka/variants.lua`. `false` puts interfaces back
  on the gold type colour.

## Done When

A colour is chosen (or lavender confirmed), and the verdict is recorded in
`notes/palette-reference.md`, "interface", per the record-every-trial rule in
`docs/CLAUDE.md`.
