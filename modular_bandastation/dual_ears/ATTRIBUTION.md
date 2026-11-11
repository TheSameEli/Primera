<!-- AI EDIT START - Credit the existing artwork used for baked ear-side variants -->
# Ear-side sprite variants

The `_right` and `_left` headset states derive only from artwork already present
in this repository at revision `384548c6aa73b320623a97a9b544469527a8e8fc`:

- `icons/mob/clothing/ears.dmi`: /tg/station and its contributors.
  [Upstream file history](https://github.com/tgstation/tgstation/commits/master/icons/mob/clothing/ears.dmi).
- `modular_bandastation/aesthetics/radio/icons/mob/ears.dmi`: BandaStation,
  /tg/station and their contributors. The BandaStation radio artwork includes
  contributions by konushi in commit `1c9a6cc2110670c2067fffdee3a503426ca750dd`.
  [Source file history](https://github.com/ss220club/BandaStation/commits/master/modular_bandastation/aesthetics/radio/icons/mob/ears.dmi).
- `icons/bandastation/mob/species/vox/clothing/ears.dmi`: BandaStation,
  NovaSector and their contributors, imported through BandaStation PR #2682 by
  WMEJlb and contributors. Existing [Vox attribution](../../icons/bandastation/mob/species/vox/attributions.txt)
  retains the pinned source revisions and license declarations.

Each one-ear headset keeps its original state. The new state for the artwork's
native ear is an exact copy; the opposite-ear state reflects its pixels
horizontally and exchanges east/west profiles. All original pixels, states,
animation frames, delays, palettes and other PNG metadata are preserved.
No external artwork was imported. Only states used by single-slot headsets
receive variants. Protected headsets, bilateral ear protection and headphones
keep their original states unchanged.

The original and derived artwork is licensed under
[Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/),
as declared by the [repository asset license](../../README.md#license).
<!-- AI EDIT END -->
