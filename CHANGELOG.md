# Changelog

## 1.0.0
- First release.
- Multiplies every trader's ore, arrows and bolts (default 3×), configurable in `config.lua`.
- Idempotent and save-safe: the multiplier is always applied to the vanilla default
  (`m_DefaultItems`), so it never stacks across re-apply, save/reload, or the game's
  own chapter restocks.
- `OnlyRaise` (default on): never reduces a trader who already holds more than the target.
- Applied automatically a few seconds after each spawn / level load.
- Console commands `rm_apply` and `rm_status` (with ConsoleEnablerMod).
