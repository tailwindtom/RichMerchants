# Changelog

All notable changes to **Rich Merchants** are documented here.
Mod page: https://www.nexusmods.com/gothic1remake/mods/161

## [1.0.1] — 2026-06-14

### Fixed
- **Stutter during open-world traversal.** The boost re-applied on every PlayerController
  `ClientRestart`, which fires constantly while streaming the open world (moving,
  dismounting, crossing zones) — re-iterating every trader each time and logging it. Now the
  re-apply has a **cooldown** (at most one per ~34s) and only **logs when stock actually
  changed**. The boost still re-asserts after a real restock, just without the per-event
  frame hitch.

## [1.0.0] — 2026-06-12

First public release.

### Added
- Multiplies every trader's **ore**, **arrows** and **bolts** (default **3×**),
  configurable per resource in `config.lua`.
- `OnlyRaise` option (default on): never reduces a trader who already holds more than the
  target — the mod only ever increases stock.
- Automatic application a few seconds after each spawn / level / chapter load
  (`ClientRestart`), at a moment when no trade window is open.
- Console commands `rm_apply` and `rm_status` (require ConsoleEnablerMod).
- Optional debug keybinds `F6` (apply now) / `F7` (print stock), gated behind
  `DebugKeys` in `config.lua`.

### Design
- **Idempotent & save-safe:** amounts are always computed from the untouched vanilla
  baseline `TraderConfig.m_DefaultItems`, so re-applying, reloading a save, or the game's
  own chapter restocks never stack the bonus.
- **Runtime-only:** no game files are modified; touches ore/arrow/bolt stock only.
- **Crash-safe:** resolves objects via `FindFirstOf` (no global object scans), guards every
  UObject access, and never writes into a currently-open trader's live map. Does not depend
  on `RegisterHook`, which is unreliable for the trade flow on this build.

### Notes
- Developed and tested against UE4SS `3.0.1-326-g940af53` on Gothic 1 Remake
  (UE 5.4.3, build 168781).
- See the README's "Reverse-engineering notes" for the full breakdown of the trader data
  model, TMap access quirks, and the crash-safety rules discovered while building this.
