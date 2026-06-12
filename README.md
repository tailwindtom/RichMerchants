# Rich Merchants — Gothic 1 Remake (UE4SS Lua Mod)

Gives every trader more **ore**, **arrows** and **bolts** so merchants stay useful
as buyers and sellers for much longer. All multipliers are configurable — default **3×**.

Runtime-only: **no original game files are modified.** The mod only changes trader
stock in memory at load time, and only those three resources — nothing else.

## Features

- All traders carry more **ore** (`OreMultiplier`) — ore is also the merchant's buying money
- All traders carry more **arrows** (`ArrowMultiplier`)
- All traders carry more **bolts** (`BoltMultiplier`)
- Fully configurable via `config.lua` (2×, 5×, 10×, … — no code editing)
- **Idempotent & save-safe:** the multiplier is always applied to the game's hidden
  *vanilla default*, so it never stacks — not on re-apply, not across save/reload,
  not after the game's own chapter restocks
- **Only raises stock** (`OnlyRaise`, default on): a merchant who is already richer
  than the target keeps what he has — the mod never reduces anyone
- Touches trader ore/arrow/bolt stock only — no prices, no other mechanics
- Crash-safe on the G1R UE4SS build (no global object scans; all access guarded)

## Requirements

- [UE4SS](https://www.nexusmods.com/gothic1remake/mods/3) for Gothic 1 Remake (the
  experimental build shipped for G1R)
- Optional: **ConsoleEnablerMod** (bundled with UE4SS) for the `rm_apply` / `rm_status`
  console commands

## Installation

Copy the `RichMerchants` folder into your UE4SS `Mods` directory:

```
<Gothic 1 Remake>\G1R\Binaries\Win64\Mods\RichMerchants\
```

so that you have:

```
Mods\RichMerchants\enabled.txt
Mods\RichMerchants\Scripts\main.lua
Mods\RichMerchants\Scripts\config.lua
Mods\RichMerchants\Scripts\lib\log.lua
```

Launch the game and load a save — the boost is applied automatically a few seconds
after you spawn (and again after each level/chapter load).

## Configuration (`Scripts/config.lua`)

```lua
return {
    OreMultiplier   = 3.0, -- ore (also the trader's buying money)
    ArrowMultiplier = 3.0, -- arrows
    BoltMultiplier  = 3.0, -- bolts
    OnlyRaise       = true,  -- never reduce a trader who already has more
    Verbose         = false, -- log every change to UE4SS.log
    DebugKeys       = false, -- F6 = apply now, F7 = print stock (for testing)
}
```

`2.0` = double, `5.0` = five times, `10.0` = ten times, `1.0` = leave that item
unchanged. Changes take effect on the next game launch.

## How it works (for the curious)

The 31 traders live as `TraderConfig` objects in the game state's
`TraderManager` component. Each holds a `TMap` of item-class → amount in `m_Items`
(current stock, including ore) with `m_DefaultItems` as the vanilla baseline. The
relevant item classes are `ItMi_Orenugget` (ore), `ItAm_Arrow` and `ItAm_Bolt`.

On load the mod resolves the `TraderManager` via `FindFirstOf` (a safe single-class
lookup — no global object-array scans, which can crash this build), iterates each
trader, and sets `m_Items[item] = max(current, round(m_DefaultItems[item] ×
multiplier))`. Because the multiplier is always taken from the untouched vanilla
default, the result is idempotent and never stacks.

## Console commands (needs ConsoleEnablerMod)

- `rm_apply` — re-apply the boost now (writes a summary to `UE4SS.log`)
- `rm_status` — print every trader's current ore/arrow/bolt amounts to `UE4SS.log`

## Notes & limitations

- Traders that sell **none** of the three resources (e.g. a mage selling only runes)
  are naturally skipped — there is nothing to multiply.
- Stock is re-applied on each load/chapter change. Long single-session play after the
  game's internal restocking is covered the next time you load.

## Credits

Reverse-engineering approach and crash-safety conventions informed by the
*Classic Traders* and *Economy Tweaks* UE4SS mods for Gothic 1 Remake.

## License

MIT — see [LICENSE](LICENSE).
