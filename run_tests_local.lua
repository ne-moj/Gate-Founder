package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/?.lua"
package.path = package.path .. ";data/scripts/tests/commands/?.lua"

function include(path)
    return require(path)
end

local Test = require("test_gateregistry_v2")
local results = Test.runAll()

print("Passed: " .. results.passed)
print("Failed: " .. results.failed)

if results.failed > 0 then
    for _, t in ipairs(results.tests) do
        if t.status == "FAIL" then
             print("FAIL: " .. t.name .. "\n  Expected: " .. tostring(t.expected) .. "\n  Actual: " .. tostring(t.actual))
        end
    end
    os.exit(1)
end
os.exit(0)
