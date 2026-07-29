-- Headless tests for DataStoreRetry (PRD §8): pcall + exponential-backoff wrapper.
local DataStoreRetry = require("../src/server/ServerStorage/Modules/DataStoreRetry")

-- Retry exhaustion: a call that always fails must give up cleanly after MAX_ATTEMPTS — not hang,
-- not throw past the pcall boundary, and not return a fabricated "success".
do
    local callCount = 0
    local success, result = DataStoreRetry.retryAsync(function()
        callCount += 1
        error("simulated DataStore outage")
    end)

    assert(success == false, "retryAsync must report failure once attempts are exhausted")
    assert(
        callCount == DataStoreRetry.MAX_ATTEMPTS,
        "retryAsync must call fn exactly MAX_ATTEMPTS times, got " .. callCount
    )
    assert(
        type(result) == "string" and result:find("simulated DataStore outage") ~= nil,
        "retryAsync must surface the underlying error"
    )
    print("DataStoreRetry.spec: exhaustion after " .. callCount .. " attempts, clean failure OK")
end

-- Recovery mid-retry: a call that fails once then succeeds must return success with the real result,
-- proving the loop doesn't corrupt state or discard a later success.
do
    local callCount = 0
    local success, result = DataStoreRetry.retryAsync(function()
        callCount += 1
        if callCount < 2 then
            error("transient failure")
        end
        return "ok-value"
    end)

    assert(success == true, "retryAsync must succeed once fn stops failing")
    assert(result == "ok-value", "retryAsync must return the successful result")
    assert(callCount == 2, "retryAsync must stop retrying as soon as fn succeeds, got " .. callCount)
    print("DataStoreRetry.spec: recovers after transient failure OK")
end

-- Immediate success: no retries, no unnecessary backoff wait.
do
    local callCount = 0
    local success, result = DataStoreRetry.retryAsync(function()
        callCount += 1
        return 42
    end)

    assert(success == true and result == 42, "retryAsync must pass through an immediate success untouched")
    assert(callCount == 1, "retryAsync must not retry a call that succeeded on the first attempt")
    print("DataStoreRetry.spec: immediate success, no retries OK")
end

print("DataStoreRetry.spec: all assertions passed")
