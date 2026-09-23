---
origin: mined # or generated
date: 2026-09-23
model: "" # when generated, e.g. grok-imagine; leave empty when mined
---

# Brand prompts

Provenance for this kit's assets so a later model or a redesign does not
start from a chat transcript. Present, not counted — same class as
`README.md`. Keep prompts here, never in `public/`. Standard:
`~/Code/natabula/docs/DESIGN-STANDARDS.md` §"Brand kit".

## logo.svg

- mined: `source:` `logo.png` (repo root, 532×543 RGBA PNG, chip + broom +
  green crosshair mark)
- converter: none — `logo.png` is a heavily gradient-shaded, ~17,000-unique-color
  raster (soft bevels, drop shadow); a pixel/color-layer auto-trace
  (potrace / ImageMagick posterize+trace) produced unusable path soup or
  lost the silhouette. Hand-redrawn instead: same composition (rounded
  chip body with 6 pins/side, diagonal broom with fan head + bristle
  lines, two simplified circuit traces with node dots, green
  ring-crosshair target with navy center disc), same sampled palette
  (chip gradient ~#F3F6F8→#AEBBC5, broom ~#FFFFFF→#DEE4E8, green
  #4FD873, navy #3E6E96), built as plain SVG shapes + two linear
  gradients. No raster embedded.

## favicon.svg

- mined: `source:` `logo.png`, same hand-redraw lineage as `logo.svg`
- converter: none — see `logo.svg` note. Further simplified for 16 px:
  fewer/chunkier pins, no circuit traces, no bristle lines, no crosshair
  ticks, bolder strokes. All shapes are filled (no `fill="none"` +
  stroke-only paths), so an ImageMagick tab-trio cut rasterizes correctly.

## promo-16x9.webp

- omitted — no real 1600×900 producer still exists. The
  `fakeneuron.com/projects/pidlyse-logo.webp` site card is a cropped
  derivative of `logo.png`, not a producer still, and per §"Brand kit"
  is explicitly not a mining source.

## What not to change

- Palette: chip = cool gray-silver metallic gradient, broom = near-white,
  target = green ring/dot on a navy disc, circuit dots = navy. Don't
  reskin to the fleet's generic accent color — this mark's palette is
  the identity.
- Fill-not-stroke for `favicon.svg` (tab-trio constraint above).
- Composition: chip square with pins on all 4 sides, broom sweeping
  lower-left → upper-right, target upper-right overlapping the broom's
  top end — matches `logo.png`, don't rearrange.
