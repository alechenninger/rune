# rune

DSL for describing maps and scenes that compile to ASM usable with ps4disasm.

NOTE: rune assumes "[Grand Cross](https://ps4grandcross.net/)" engine modifications to PS4 assembly and therefore has limited compatibility with the original engine.

`debug/options.dart` owns the debug-start configuration and resolution shared
by Macro sync and Demi presets: story milestones, additional flags, inferred party,
map entry defaults, positions and inventory. Map-transition and party catalogs
also live under `debug/`; macro-addon re-exports them for existing consumers.
Build-only scene fast-forwarding stays outside this configuration.
Macro and Demi each own their command-line argument registration and parsing;
Rune has no CLI-parser dependency.
