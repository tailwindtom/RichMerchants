# Rich Merchants — Gothic 1 Remake (UE4SS Lua Mod)

Gives every trader more **ore**, **arrows** and **bolts** so merchants stay useful as
buyers and sellers for much longer. All multipliers are configurable — default **3×**.

Runtime-only: **no original game files are modified.** The mod only changes trader
stock in memory at load time, and only those three resources — nothing else. It is
idempotent and save-safe.

**📥 Download / mod page:** https://www.nexusmods.com/gothic1remake/mods/161

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Console commands](#console-commands)
- [How it works](#how-it-works)
- [Reverse-engineering notes (what we learned)](#reverse-engineering-notes-what-we-learned)
- [Limitations](#limitations)
- [Building & contributing](#building--contributing)
- [Credits](#credits)
- [License](#license)

## Features

- More **ore** (`OreMultiplier`) — ore is also the merchant's buying money
- More **arrows** (`ArrowMultiplier`) and **bolts** (`BoltMultiplier`)
- Fully configurable via `config.lua` (2×, 5×, 10×, … — no code editing)
- **Idempotent & save-safe:** the multiplier is always applied to the game's hidden
  *vanilla default*, so it never stacks — not on re-apply, not across save/reload, not
  after the game's own chapter restocks
- **Only raises stock** (`OnlyRaise`, default on): a merchant who is already richer than
  the target keeps what he has — the mod never reduces anyone
- Touches trader ore/arrow/bolt stock only — no prices, no XP, no other mechanics
- Crash-safe on the G1R UE4SS build (no global object scans; all access guarded)

## Requirements

- **[UE4SS for Gothic 1 Remake](https://www.nexusmods.com/gothic1remake/mods/3)**
  (the `3.0.1-326-g940af53` build this mod was developed and tested against), or install
  UE4SS via the **G1L mod manager**.
- Optional: **ConsoleEnablerMod** (bundled with UE4SS) for the `rm_apply` / `rm_status`
  console commands.

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

Launch the game and load a save — the boost is applied automatically a few seconds after
you spawn (and again after each level/chapter load).

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

`2.0` = double, `5.0` = five times, `1.0` = leave that item unchanged. Changes take
effect on the next game launch.

## Console commands

(need ConsoleEnablerMod; open the console with `~` or `F10`)

- `rm_apply` — re-apply the boost now (writes a summary to `UE4SS.log`)
- `rm_status` — print every trader's current ore/arrow/bolt amounts to `UE4SS.log`

---

## How it works

The 31 traders are stored as `TraderConfig` objects in the game state's
`TraderManager` component (`…BP_GR1GameState_C.TraderManagerComponent`). The mod resolves
that component with `FindFirstOf("TraderManager")` — a single-class lookup that is safe on
this UE4SS build — and iterates `m_InstancedTraders`.

Each `TraderConfig` holds two `TMap`s of **item-class → amount**:

| Field | Meaning |
| --- | --- |
| `m_Items` | the trader's **current, displayed** stock (ore here is the trader's money) |
| `m_DefaultItems` | the **vanilla baseline** (treated as read-only) |

The relevant item classes are `ItMi_Orenugget` (ore), `ItAm_Arrow` (arrows) and
`ItAm_Bolt` (bolts).

On each load the mod sets, for every trader and each of those items:

```
m_Items[item] = max( current , round( m_DefaultItems[item] × multiplier ) )
```

Because the multiplier is always taken from the **untouched** vanilla default
(`m_DefaultItems` is never written), the result is **idempotent**: re-applying, reloading
a save, or the game restocking at a chapter change all compute the same target and never
stack. `OnlyRaise` (the `max(current, …)`) guarantees a trader is never made poorer.

The boost runs ~4 seconds after `ClientRestart` (spawn / level / chapter load), a moment
when no trade window is open — writing into a trader's map while its trade UI is live can
crash, so that is deliberately avoided.

---

## Reverse-engineering notes (what we learned)

This section documents how the mod was figured out on the live game (UE4SS experimental
`3.0.1-326-g940af53`, G1R UE 5.4.3 build 168781). It doubles as a field guide for anyone
modding G1R's trader/economy system.

### The trader data model

- `TraderManager` is a component on the game state. It contains:
  - `m_InstancedTraders` — `TArray` of all 31 `TraderConfig` objects (Wolf, Fisk, Xardas,
    Cavalorn, Cronos, …; the first entry is a `TraderConfigBase` template).
  - `m_GlobalItemAmountForTrading` / `m_RegionItemAmountForTrading` — `TMap`s used by the
    **price** (supply/demand) calculation, populated once trading is active. These are
    *not* the per-trader stock — they are the *Classic Traders* mod's territory. Leave
    them alone for a stock mod.
  - `m_PayloadMods`, `m_RegionLiquidity`, `m_RegionTraders`, and the functions
    `GetCharacterOre` / `RemoveCharacterOre`.
- `TraderConfig` (one per trader) holds `m_UniqueName` (e.g. `NC_ORG_Wolf_855`),
  `m_Region`, `m_Type`, `m_Items`, `m_DefaultItems`, `m_LastDefaultItems`,
  `m_ItemsByDifficulty`, `m_Liquidity`, and an `AddTraderItem` function.
- Items are **Angelscript classes** (`/Script/Angelscript.*`). Naming convention:
  `ItMi_` misc (e.g. `ItMi_Orenugget`), `ItAm_` ammo (`ItAm_Arrow`, `ItAm_Bolt`),
  `ItFo_` food, `ItKe_` keys/lockpicks, `ItWr_` writings, `ItMw_`/`ItRw_` weapons, etc.
- The world definition (`DefaultWorldDefinition`, an Angelscript subclass of
  `WorldDefinition`) exposes `m_DefaultOre = ItMi_Orenugget` plus the regional/liquidity
  price multipliers — again price territory, not stock.

### TMap access on this UE4SS build (important quirks)

- **Reading:** `map:ForEach(function(key, value) … end)` works. `map:Find(key)` works.
- **Writing:** `map:Add(key, value)` works and overwrites an existing key.
- **`map:Num()` does NOT return a usable number here** — it reports `userdata/noNum`. Do
  not gate logic on it (an early version did and silently found "0" entries everywhere).
  Count via `ForEach` instead.
- **`map[key]` is NOT a keyed getter** — indexing the map returned the map itself, so a
  naive read-back looked like it failed. Use `map:Find(key)`.
- Keys come back as the item `UClass`; match them by `GetFullName():find("ItAm_Arrow")`.

### Object resolution & crash-safety rules (learned the hard way)

On this experimental build several "normal" UE4SS patterns crash **uncatchably** (a native
access violation `pcall` cannot trap). What proved safe vs. fatal:

- ✅ **`FindFirstOf("ClassName")`** for a single live singleton/component is safe (the
  shipping *Economy Tweaks* mod relies on it too).
- ❌ **Global object scans** (`FindAllOf`, `ForEachUObject`, UEHelpers iteration) can crash
  on a "bad boot" — never used.
- ❌ **Enumerating ALL properties of a freshly-constructed / live object** crashed (a
  half-initialised object has null pointers that native reads dereference). Only fully
  initialised Class Default Objects (CDOs) were safe to dump.
- ❌ **Reading guessed/arbitrary property names** on a live object crashed — only read
  fields you know exist.
- ❌ **Reading delegate / unsupported property types' values** errors (e.g.
  `MulticastSparseDelegateProperty`). Skip them by type.
- ❌ **Iterating a `UFunction`'s parameters** (`fn:ForEachProperty`) silently aborted the
  whole dump — couldn't introspect signatures that way.
- ❌ **Writing into the currently-OPEN trader's live map** crashed. Applying after spawn
  (no trade UI open) is safe. ✅
- ⚠️ **`RegisterHook` on the trade functions is unreliable here.** Hooks on
  `TradingMain:NewInventoryOre`, `TradingBalanceInventory:UpdateInventory`,
  `TraderConfig:AddTraderItem` registered but usually did **not** fire during a real trade
  (the trade flow appears to run as native Angelscript that bypasses hookable dispatch).
  So the mod does **not** depend on hooks — it resolves objects with `FindFirstOf` and
  applies on `ClientRestart`.

### Idempotency without a file

Because `m_DefaultItems` is the vanilla baseline and we **never** write it, it serves as a
permanent, save-persistent anchor. Computing `max(current, round(default × mult))` every
time is therefore stable across re-apply, save/reload and the game's own restocks — no
external snapshot file needed.

### Recon method

The mod was built by an iterative read-only recon harness driven from the in-game console
and debug keybinds (`F6` apply, `F7` verify/dump, `F8` enumerate), with every result read
back out of `UE4SS.log`. Useful helpers in the UE4SS distribution: `ConsoleEnablerMod`
(console with `~`/`F10`) and `ConsoleCommandsMod`'s `dump_object`. A matching
`Mappings.usmap` (UE 5.4.3 / build 168781) enables static inspection in FModel if needed,
though runtime introspection was enough here.

---

## Limitations

- Traders that sell **none** of the three resources (e.g. a mage selling only runes, or a
  trader with an empty stock for them) are naturally skipped — there is nothing to
  multiply. In a full run, ~28 of 31 traders are touched; the rest either sell none of the
  three or already hold more than the target.
- Stock is re-applied on each load / chapter change. Within a very long single session,
  the game's internal restocking is re-covered the next time you load.
- "Ore" in `m_Items` is the merchant's tradeable ore (and money pool). If you ever observe
  that a boosted trader still won't *buy* more from you, his spending purse may be tracked
  separately (`GetCharacterOre`) — a candidate for a future version.

## Building & contributing

There is nothing to compile — it is plain Lua. The repository layout:

```
RichMerchants/
├─ README.md, CHANGELOG.md, LICENSE
├─ media/banner.png
└─ RichMerchants/                 ← the deployable UE4SS mod folder
   ├─ enabled.txt
   └─ Scripts/
      ├─ main.lua
      ├─ config.lua
      └─ lib/log.lua
```

To test a change, copy the `RichMerchants` folder into your UE4SS `Mods` directory and
restart the game (this UE4SS build has no hot reload). Set `DebugKeys = true` in
`config.lua` to enable the `F6`/`F7` test keys.

## Credits

- **UE4SS** (AstAnDK / the RE-UE4SS team) — the script extender this mod runs on.
- Vvarlord's **Classic Traders** and the **Economy Tweaks** mod — their UE4SS approaches
  and crash-safety conventions were a helpful reference while reverse-engineering the
  Gothic 1 Remake trader system. *(No code reused.)*
- The Gothic 1 Remake modding community for mappings, docs and shared knowledge.

## License

MIT — see [LICENSE](LICENSE).
