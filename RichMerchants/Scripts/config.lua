-- Rich Merchants — configuration
--
-- Multiplies every trader's stock of ore, arrows and bolts so they stay useful
-- as buyers/sellers for longer. The multiplier is applied to each trader's
-- VANILLA amount (the game's hidden default), so re-applying never stacks — you
-- always get exactly Multiplier x the original, even across saves and the game's
-- own chapter restocks.
--
-- Change the numbers below to taste — 2.0 = double, 5.0 = five times, 10.0 = ten
-- times, 1.0 = leave that item untouched. You never need to edit main.lua.

return {
    ModName = "Rich Merchants",
    Version = "1.0.2",

    -- ---- Stock multipliers (applied to the trader's vanilla amount) -----------
    OreMultiplier   = 3.0, -- ore  (ItMi_Orenugget — also the trader's buying money)
    ArrowMultiplier = 3.0, -- arrows (ItAm_Arrow)
    BoltMultiplier  = 3.0, -- bolts  (ItAm_Bolt)

    -- ---- Behaviour ------------------------------------------------------------
    -- true  (recommended): only ever RAISE stock — a trader who already has more
    --       than Multiplier x vanilla (e.g. a rich merchant) keeps what he has.
    -- false: set stock to exactly Multiplier x vanilla, even if that lowers it.
    OnlyRaise = true,

    -- ---- Diagnostics ----------------------------------------------------------
    -- Verbose = true logs every changed amount to UE4SS.log (otherwise just a
    -- one-line summary per apply).
    Verbose = false,

    -- Optional debug keybinds (default off). When true:
    --   F6 = apply now (use in the open world, NOT inside a trade window)
    --   F7 = print current ore/arrow/bolt stock to UE4SS.log
    -- Console commands rm_apply / rm_status work regardless (need ConsoleEnablerMod).
    DebugKeys = false,
}
