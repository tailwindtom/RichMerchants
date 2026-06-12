-- Tiny logging helper. Output lands in UE4SS.log (and the GUI console) prefixed
-- with the mod name + version. Mirrors the convention used by Classic Traders.

local config = require("config")

local M = {}

local function line(level, message)
    print(string.format("[%s v%s] [%s] %s\n", config.ModName, config.Version, level, message))
end

function M.info(message)
    line("INFO", message)
end

function M.warn(message)
    line("WARN", message)
end

-- Only emitted when config.Verbose is true. Pass the flag explicitly so this
-- helper has no hidden dependency on the config module's current state.
function M.debug(enabled, message)
    if enabled then
        line("DEBUG", message)
    end
end

return M
