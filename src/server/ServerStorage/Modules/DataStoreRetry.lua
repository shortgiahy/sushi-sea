-- DataStoreRetry: pcall + exponential-backoff wrapper for DataStore calls (PRD §8) — pure, no Roblox services
local DataStoreRetry = {}

local MAX_ATTEMPTS = 3

-- Real Roblox exposes `task` as a true global; the Lune headless test runner does not — it's a
-- `require`d library there instead. This keeps the module identical in both runtimes.
local taskLib = if task ~= nil then task else require("@lune/task")

DataStoreRetry.MAX_ATTEMPTS = MAX_ATTEMPTS

function DataStoreRetry.retryAsync(fn: (...any) -> any, ...: any): (boolean, any)
    local attempts = 0
    local success, result
    repeat
        attempts += 1
        success, result = pcall(fn, ...)
        if not success then
            taskLib.wait(2 ^ (attempts - 1))
        end
    until success or attempts >= MAX_ATTEMPTS
    return success, result
end

return DataStoreRetry
