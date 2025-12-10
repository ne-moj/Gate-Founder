package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/?.lua"

local UnitTest = include("unittest")
UnitTest.injectGlobals()
local ColorUtils = include("colorutils")

local TestColorUtils = {}

function TestColorUtils.test_isValidColor_true()
    assertTrue("Red is valid", ColorUtils.isValidColor("red"))
    assertTrue("Cyan is valid", ColorUtils.isValidColor("cyan"))
end

function TestColorUtils.test_isValidColor_false()
    assertFalse("Orange is invalid", ColorUtils.isValidColor("orange"))
    assertFalse("Purple is invalid", ColorUtils.isValidColor("purple")) -- magenta exists, purple likely not
end

function TestColorUtils.test_getColor()
    local rgb = ColorUtils.getColor("red")
    assertType("rgb is table", "table", rgb)
    assertEqual("Red R", 1, rgb[1])
    assertEqual("Red G", 0, rgb[2])
    assertEqual("Red B", 0, rgb[3])
    
    assertNil("Invalid color returns nil", ColorUtils.getColor("invalid"))
end

function TestColorUtils.test_colorToMask()
    assertEqual("Red mask", 4, ColorUtils.colorToMask({1, 0, 0}))    -- 100 binary
    assertEqual("Green mask", 2, ColorUtils.colorToMask({0, 1, 0}))  -- 010 binary
    assertEqual("Blue mask", 1, ColorUtils.colorToMask({0, 0, 1}))   -- 001 binary
    assertEqual("Yellow mask", 6, ColorUtils.colorToMask({1, 1, 0})) -- 110 binary
    assertEqual("White mask", 7, ColorUtils.colorToMask({1, 1, 1}))  -- 111 binary
    assertEqual("Black mask", 0, ColorUtils.colorToMask({0, 0, 0}))  -- 000 binary
end

function TestColorUtils.test_maskToColor()
    local red = ColorUtils.maskToColor(4)
    assertEqual("Mask 4 -> R", 1, red[1])
    assertEqual("Mask 4 -> G", 0, red[2])
    assertEqual("Mask 4 -> B", 0, red[3])
    
    local white = ColorUtils.maskToColor(7)
    assertEqual("Mask 7 -> R", 1, white[1])
    assertEqual("Mask 7 -> G", 1, white[2])
    assertEqual("Mask 7 -> B", 1, white[3])
end

function TestColorUtils.test_countChannels()
    assertEqual("Red channels", 1, ColorUtils.countChannels({1, 0, 0}))
    assertEqual("Yellow channels", 2, ColorUtils.countChannels({1, 1, 0}))
    assertEqual("White channels", 3, ColorUtils.countChannels({1, 1, 1}))
    assertEqual("Black channels", 0, ColorUtils.countChannels({0, 0, 0}))
end

function TestColorUtils.test_findColorName()
    assertEqual("Find red", "red", ColorUtils.findColorName({1, 0, 0}))
    assertEqual("Find yellow", "yellow", ColorUtils.findColorName({1, 1, 0}))
    -- Note: findColorName implementation iterates pairs, so order isn't guaranteed if duplicates exist,
    -- but keys are unique strings mapped to unique values here hopefully.
end

function TestColorUtils.test_colorXor()
    local diff = ColorUtils.colorXor({1, 0, 0}, {0, 1, 0}) -- Red vs Green
    -- Expected: 1 vs 0 -> 1, 0 vs 1 -> 1, 0 vs 0 -> 0
    assertEqual("Xor Red", 1, diff.red)
    assertEqual("Xor Green", 1, diff.green)
    assertEqual("Xor Blue", 0, diff.blue)
    
    local same = ColorUtils.colorXor({1, 1, 1}, {1, 1, 1})
    assertEqual("Xor Same Red", 0, same.red)
    assertEqual("Xor Same Green", 0, same.green)
    assertEqual("Xor Same Blue", 0, same.blue)
end

function TestColorUtils.runAll()
    UnitTest.reset()
    
    TestColorUtils.test_isValidColor_true()
    TestColorUtils.test_isValidColor_false()
    TestColorUtils.test_getColor()
    TestColorUtils.test_colorToMask()
    TestColorUtils.test_maskToColor()
    TestColorUtils.test_countChannels()
    TestColorUtils.test_findColorName()
    TestColorUtils.test_colorXor()
    
    return UnitTest.getResults()
end

function TestColorUtils.getResults()
    return UnitTest.getResults()
end

return TestColorUtils
