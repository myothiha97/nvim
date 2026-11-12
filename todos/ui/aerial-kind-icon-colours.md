# Aerial panel: distinct icon colours per symbol kind

Requested 2026-11-11, deferred (palette closed until 2026-12-31).

Goal: make `<leader>cs` read like the JetBrains Structure view, where each kind
(function, method, hook, component, variable, field, type) has its own icon colour.

What exists today: aerial already colours icons by kind through `Aerial<Kind>Icon`
groups, but many share one link. Function, Method and Hook (our link in
`lua/plugins/aerial.lua`) all use `Function`. Variable, Field, Property and Object
all use `Identifier`. `AerialComponentIcon` is a hard-coded `#61afef`, not a theme link.

Likely shape: set the shared `Aerial*Icon` groups to distinct links from the theme,
and link Component instead of using a hex. These are highlight groups set once at
load, so the cost is effectively zero. Icon glyph changes are a separate, optional part.

Target (Myo, 2026-11-11): follow WebStorm and GoLand closely, so each kind gets
the icon colour those IDEs use (not a new scheme of our own).
