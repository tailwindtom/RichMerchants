-- Rich Merchants — UE4SS Lua mod for Gothic 1 Remake (G1R)
-- =============================================================================
-- Multiplies every trader's stock of ore / arrows / bolts so merchants stay
-- useful as buyers and sellers for longer. Fully configurable in config.lua
-- (default 3x). Runtime-only: no game files are modified.
--
-- HOW IT WORKS (established by recon):
--   * The 31 traders are TraderConfig objects in
--     TraderManager(component).m_InstancedTraders. The component is reached with
--     FindFirstOf("TraderManager") — a single-class lookup that is safe on this
--     UE4SS build (no global object-array scans, which can crash here).
--   * Each TraderConfig holds two TMaps (item-class -> amount):
--       m_Items        = the trader's CURRENT, displayed stock (ore = their money)
--       m_DefaultItems = the vanilla baseline (we treat it as read-only)
--   * Item classes:  ore = ItMi_Orenugget, arrows = ItAm_Arrow, bolts = ItAm_Bolt.
--   * TMap on this build: iterate with m:ForEach(k, v); write with m:Add(key, val).
--     (m:Num() is unreliable here, so we never rely on it.)
--
-- IDEMPOTENT BY DESIGN: target = round(m_DefaultItems[item] * multiplier), and we
-- only ever write m_Items, never m_DefaultItems. Because the baseline is always the
-- untouched vanilla default, re-applying (or applying again after a save/reload, or
-- after the game restocks on a chapter change) computes the same target and never
-- stacks. With OnlyRaise (default), we set max(current, target) so a trader that
-- already has more than target keeps it — the mod only ever increases stock.
--
-- TIMING: applied a few seconds after each spawn / level load (ClientRestart),
-- when no trade window is open. Writing into a CURRENTLY-OPEN trader's live map can
-- crash, so the optional manual re-apply key should only be used in the open world.
-- =============================================================================

local config = require("config")
local log = require("lib.log")

-- ---- small safe helpers ---------------------------------------------------
local function run_on_game_thread(fn)
    if type(ExecuteInGameThread) == "function" then ExecuteInGameThread(fn) else fn() end
end
local function run_later(ms, fn)
    if type(ExecuteInGameThreadWithDelay) == "function" then ExecuteInGameThreadWithDelay(ms, fn)
    elseif type(ExecuteWithDelay) == "function" then ExecuteWithDelay(ms, fn) else fn() end
end
local function valid(o)
    if o == nil then return false end
    local ok, r = pcall(function() return o:IsValid() end)
    return ok and r == true
end
local function unwrap(p)
    if p == nil then return nil end
    local ok, o = pcall(function() return p:get() end)
    if ok and o ~= nil then return o end
    return p
end
local function full_name(o)
    local ok, n = pcall(function() return o:GetFullName() end)
    return (ok and type(n) == "string") and n or "<unknown>"
end
local function read_name(o, f)
    local ok, v = pcall(function() return o[f]:ToString() end)
    if ok and type(v) == "string" then return v end
    return "?"
end

-- item class substring -> configured multiplier
local ITEM_MULT = {
    ItMi_Orenugget = tonumber(config.OreMultiplier) or 1.0,
    ItAm_Arrow     = tonumber(config.ArrowMultiplier) or 1.0,
    ItAm_Bolt      = tonumber(config.BoltMultiplier) or 1.0,
}
local ONLY_RAISE = config.OnlyRaise ~= false -- default true
-- Session snapshot for configs that lack a default entry for an item.
local fallback = _G.__RichMerchants_fallback or {}
_G.__RichMerchants_fallback = fallback

-- Get a TMap field, validated by ForEach (Num is unreliable on this build).
local function get_map(obj, field)
    local m
    if not pcall(function() m = obj[field] end) or m == nil then return nil end
    if pcall(function() m:ForEach(function() end) end) then return m end
    return nil
end

-- Read {item_substr -> amount} from a map for our three items.
local function read_item_amounts(m)
    local out = {}
    if not m then return out end
    pcall(function() m:ForEach(function(k, v)
        local kk, vv = unwrap(k), unwrap(v)
        if valid(kk) and type(vv) == "number" then
            local fn = full_name(kk)
            for item in pairs(ITEM_MULT) do
                if fn:find(item, 1, true) then out[item] = vv end
            end
        end
    end) end)
    return out
end

local function read_item(m, item)
    local val
    pcall(function() m:ForEach(function(k, v)
        if full_name(unwrap(k)):find(item, 1, true) then val = unwrap(v) end
    end) end)
    return val
end

-- Boost one trader's m_Items. Returns (changed_count, hit_count).
local function boost_config(cfg, label, verbose)
    local items = get_map(cfg, "m_Items")
    if not items then return 0, 0 end
    local default_amt = read_item_amounts(get_map(cfg, "m_DefaultItems"))

    -- Collect target key objects first (don't write while iterating the map).
    local hits = {}
    pcall(function() items:ForEach(function(k, v)
        local kk, vv = unwrap(k), unwrap(v)
        if valid(kk) and type(vv) == "number" then
            local fn = full_name(kk)
            for item, mult in pairs(ITEM_MULT) do
                if fn:find(item, 1, true) then
                    hits[#hits + 1] = { key = kk, item = item, mult = mult, cur = vv }
                end
            end
        end
    end) end)

    local changed = 0
    for _, h in ipairs(hits) do
        if h.mult ~= 1.0 then
            -- Vanilla baseline: the default entry if present, else a one-time
            -- snapshot of the current amount.
            local base = default_amt[h.item]
            if base == nil then
                local fk = full_name(cfg) .. "|" .. h.item
                if fallback[fk] == nil then fallback[fk] = h.cur end
                base = fallback[fk]
            end
            local target = math.floor(base * h.mult + 0.5)
            local desired = ONLY_RAISE and math.max(h.cur, target) or target
            if desired ~= h.cur then
                local ok = pcall(function() items:Add(h.key, desired) end)
                if ok and read_item(items, h.item) == desired then changed = changed + 1 end
                if verbose then
                    log.info(string.format("[RM] %s %s: base=%s cur=%s -> %s",
                        label, h.item, tostring(base), tostring(h.cur), tostring(desired)))
                end
            end
        end
    end
    return changed, #hits
end

local function apply_all(reason, verbose)
    if type(FindFirstOf) ~= "function" then log.warn("FindFirstOf unavailable; cannot apply.") return end
    local ok, tm = pcall(FindFirstOf, "TraderManager")
    if not (ok and valid(tm)) then
        log.debug(config.Verbose, "apply (" .. tostring(reason) .. "): TraderManager not ready yet.")
        return
    end
    local arr
    pcall(function() arr = tm.m_InstancedTraders end)
    if arr == nil then return end

    local list = {}
    pcall(function() arr:ForEach(function(_, ep) local e = unwrap(ep); if valid(e) then list[#list + 1] = e end end) end)

    local traders, total = 0, 0
    for _, cfg in ipairs(list) do
        local c = boost_config(cfg, read_name(cfg, "m_UniqueName"), verbose)
        if c > 0 then traders = traders + 1; total = total + c end
    end
    -- Only log when something actually changed (or when verbose). The frequent
    -- "0/31 raised" no-op level-loads otherwise flood UE4SS.log → frame stutter.
    if traders > 0 or verbose then
        log.info(string.format("applied (%s): %d/%d trader(s) raised, %d stack(s) changed [ore x%.1f arrow x%.1f bolt x%.1f]",
            tostring(reason), traders, #list, total, ITEM_MULT.ItMi_Orenugget, ITEM_MULT.ItAm_Arrow, ITEM_MULT.ItAm_Bolt))
    end
end

-- Print current ore/arrow/bolt of every trader that has any (diagnostics).
local function verify(reason)
    if type(FindFirstOf) ~= "function" then return end
    local ok, tm = pcall(FindFirstOf, "TraderManager")
    if not (ok and valid(tm)) then return end
    local arr; pcall(function() arr = tm.m_InstancedTraders end)
    if arr == nil then return end
    log.info(string.format("[RM-VERIFY] (%s)", tostring(reason)))
    pcall(function() arr:ForEach(function(_, ep)
        local e = unwrap(ep)
        if valid(e) then
            local a = read_item_amounts(get_map(e, "m_Items"))
            if a.ItMi_Orenugget or a.ItAm_Arrow or a.ItAm_Bolt then
                log.info(string.format("[RM-VERIFY] %-26s ore=%s arrow=%s bolt=%s",
                    read_name(e, "m_UniqueName"), tostring(a.ItMi_Orenugget), tostring(a.ItAm_Arrow), tostring(a.ItAm_Bolt)))
            end
        end
    end) end)
end

-- ---- wiring ---------------------------------------------------------------
print(string.format("[%s v%s] loaded\n", config.ModName, config.Version))
log.info(string.format("ore x%.2f, arrows x%.2f, bolts x%.2f, OnlyRaise=%s",
    ITEM_MULT.ItMi_Orenugget, ITEM_MULT.ItAm_Arrow, ITEM_MULT.ItAm_Bolt, tostring(ONLY_RAISE)))

-- Apply a few seconds after each spawn / level load. ClientRestart also re-fires
-- on level travel / chapter changes (when the game restocks traders), so the boost
-- is re-asserted then. But this hook fires *constantly* during open-world streaming
-- (moving, dismounting, crossing zones); re-iterating every trader each time caused
-- frame stutter. So: debounce + a cooldown → at most one apply per ~34s, which still
-- catches a real restock soon enough without hitching on every streaming event.
local apply_busy = false
pcall(RegisterHook, "/Script/Engine.PlayerController:ClientRestart", function()
    if apply_busy then return end
    apply_busy = true
    run_later(4000, function()
        apply_all("level-load", config.Verbose == true)
        run_later(30000, function() apply_busy = false end)   -- 30s cooldown before another re-apply
    end)
end)

-- Optional debug keybinds (off by default). Set DebugKeys = true in config to use:
--   F6 = apply now (use only in the open world, not in a trade window)
--   F7 = print current stock to UE4SS.log
if config.DebugKeys == true and type(RegisterKeyBind) == "function" then
    local function bind(vk, keyEnum, fn)
        local ok = false
        if type(Key) == "table" and keyEnum ~= nil then ok = pcall(RegisterKeyBind, keyEnum, fn) end
        if not ok then pcall(RegisterKeyBind, vk, fn) end
    end
    bind(0x75, type(Key) == "table" and Key.F6 or nil, function() run_on_game_thread(function() apply_all("F6", true) end) end)
    bind(0x76, type(Key) == "table" and Key.F7 or nil, function() run_on_game_thread(function() verify("F7") end) end)
    log.info("debug keybinds enabled: F6 = apply now, F7 = verify.")
end

-- Console commands (need ConsoleEnablerMod):
pcall(RegisterConsoleCommandHandler, "rm_apply", function(_, _, ar)
    run_on_game_thread(function() apply_all("console", true) end)
    if ar then ar:Log("[Rich Merchants] applied (see UE4SS.log)") end
    return true
end)
pcall(RegisterConsoleCommandHandler, "rm_status", function(_, _, ar)
    run_on_game_thread(function() verify("console") end)
    if ar then ar:Log("[Rich Merchants] status written to UE4SS.log") end
    return true
end)

log.info("ready. Stock is (re)applied ~4s after each load. Console: rm_apply, rm_status.")
