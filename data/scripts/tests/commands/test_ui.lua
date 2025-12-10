--[[
    UI Library Unit Tests
    
    Run with: /unittests ui
    
    Tests cover:
    - Instance creation
    - Size updates
    - Padding updates
    - Position calculations (topLeft/bottomRight)
    - Rect generation
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/commands/?.lua"

local UI = include("ui")

local TestUI = {}

-- Test results accumulator
local results = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- Mocks
-- We need to mock vec2 and Rect because they are game specific, unless we are running in game.
-- Assuming these tests run in-game where vec2/Rect exist. 
-- If they don't exist (e.g. CLI test runner), we'd need mocks. 
-- Since we use /unittests command in-game, they should exist.

-- Helper: Assert equality
local function assertEqual(name, expected, actual)
    if expected == actual then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = tostring(expected),
            actual = tostring(actual)
        })
        return false
    end
end

-- Helper: Assert vec2 equality
local function assertVec2(name, expected, actual)
    if not actual then
        return assertEqual(name, "vec2", "nil")
    end
    -- tolerance for float
    local match = math.abs(expected.x - actual.x) < 0.001 and math.abs(expected.y - actual.y) < 0.001
    if match then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = string.format("(%s, %s)", expected.x, expected.y),
            actual = string.format("(%s, %s)", actual.x, actual.y)
        })
        return false
    end
end

-- Reset results between runs
function TestUI.reset()
    results = {passed = 0, failed = 0, tests = {}}
end

-- ============================================================================
-- TEST: Basics
-- ============================================================================

function TestUI.test_new_creates_instance()
    local el = UI:new("TestEl")
    assertEqual("instance created", "TestEl", el.name)
end

function TestUI.test_default_padding()
    local el = UI:new("TestEl")
    assertEqual("default padding left", 10, el.padding.left)
    assertEqual("default padding top", 10, el.padding.top)
end

-- ============================================================================
-- TEST: Updates
-- ============================================================================

function TestUI.test_update_size()
    local el = UI:new("TestEl")
    el:updateSize(100, 50)
    assertEqual("width updated", 100, el.width)
    assertEqual("height updated", 50, el.height)
end

function TestUI.test_update_padding_number()
    local el = UI:new("TestEl")
    el:updatePadding(5)
    assertEqual("padding all sides", 5, el.padding.left)
    assertEqual("padding all sides", 5, el.padding.top)
end

function TestUI.test_update_padding_table()
    local el = UI:new("TestEl")
    el:updatePadding({left = 1, top = 2})
    assertEqual("padding left updated", 1, el.padding.left)
    assertEqual("padding top updated", 2, el.padding.top)
    assertEqual("padding right unchanged", 10, el.padding.right) -- default
end

-- ============================================================================
-- TEST: Calculations
-- ============================================================================

function TestUI.test_calc_bottomRight_from_topLeft()
    local el = UI:new("TestEl")
    el:updateSize(100, 50) -- content size? No, logic seems to imply outer size logic in calcPosition
    -- Looking at ui.lua:
    -- width = bottomRight.x - topLeft.x - (padding.left + padding.right) NO wait code says:
    -- width = bottomRight.x - topLeft.x - (padding.top + padding.bottom) <-- BUG in calcSize line 153/154 possible?
    -- Line 153: width = .. - (padding.top + padding.bottom) -> Wait, width uses top/bottom padding? That's wrong.
    -- Let's test what it does currently.
    
    el:updatePadding(0)
    el:updatePosition(vec2(0,0), nil)
    
    -- If padding is 0.
    -- bottomRight = topLeft + width + padding...
    -- Let's see code.
    -- calcPosition: bottomRight = topLeft.x + width + left + right
    
    local pos = el:getPositions()
    -- If logic is correct: 0 + 100 + 0 + 0 = 100
    assertVec2("bottomRight calculation", vec2(100, 50), pos.bottomRight)
end

function TestUI.test_calc_topLeft_from_bottomRight()
    local el = UI:new("TestEl")
    el:updateSize(100, 50)
    el:updatePadding(0)
    el:updatePosition(nil, vec2(100, 50))
    
    local pos = el:getPositions()
    assertVec2("topLeft calculation", vec2(0, 0), pos.topLeft)
end

function TestUI.test_getRect_applies_padding()
    local el = UI:new("TestEl")
    el:updateSize(100, 100)
    el:updatePadding(10)
    el:updatePosition(vec2(0,0), nil)
    
    -- Size is 100x100. Padding 10.
    -- Total outer size = 100 + 10+10 = 120?
    -- Looking at calcPosition:
    -- bottomRight = topLeft + width + left + right
    -- So outer box is 0,0 to 120,120?
    
    -- getRect returns:
    -- topLeft + left, topLeft + top
    -- bottomRight - right, bottomRight - bottom
    
    -- If outer is 0,0 to 120,120
    -- Inner calculation:
    -- topL = 0+10, 0+10 = 10,10
    -- botR = 120-10, 120-10 = 110,110
    -- Size = 100x100.
    
    local rect = el:getRect()
    assertVec2("Rect topLeft", vec2(10, 10), rect.lower)
    assertVec2("Rect bottomRight", vec2(110, 110), rect.upper)
end

-- ============================================================================
-- TEST: Layout Engine
-- ============================================================================

function TestUI.test_vertical_split_fixed()
    -- 100x100 area
    local rect = Rect(vec2(0,0), vec2(100,100))
    
    -- Split: 20px, Rest (80px)
    local rects = UI:verticalSplit(rect, {20, 0})
    
    assertEqual("Split count", 2, #rects)
    
    -- Top rect (20px high)
    local r1 = rects[1]
    assertVec2("R1 lower", vec2(0,0), r1.lower)
    assertVec2("R1 upper", vec2(100,20), r1.upper)
    
    -- Bottom rect (Rest)
    local r2 = rects[2]
    assertVec2("R2 lower", vec2(0,20), r2.lower)
    assertVec2("R2 upper", vec2(100,100), r2.upper)
end

function TestUI.test_horizontal_split_equal()
    -- 100x100 area
    local rect = Rect(vec2(0,0), vec2(100,100))
    
    -- Split: Rest, Rest (50/50)
    local rects = UI:horizontalSplit(rect, {0, 0})
    
    local r1 = rects[1]
    assertVec2("R1 upper", vec2(50, 100), r1.upper)
    
    local r2 = rects[2]
    assertVec2("R2 lower", vec2(50, 0), r2.lower)
    assertVec2("R2 upper", vec2(100, 100), r2.upper)
end

function TestUI.test_split_with_padding_spacing()
    -- 100x100
    local rect = Rect(vec2(0,0), vec2(100,100))
    
    -- 2 items, equal size. 
    -- Total spacing = 10 (1 gap).
    -- Available = 90. Each = 45.
    -- Padding = 5 inside each.
    
    local rects = UI:horizontalSplit(rect, {0, 0}, 5, 10)
    
    local r1 = rects[1]
    -- X: 0 to 45. Inner with padding 5: 5 to 40.
    -- Width = 35.
    assertVec2("R1 lower", vec2(5, 5), r1.lower)
    assertVec2("R1 upper", vec2(40, 95), r1.upper) -- Y padding also applied
    
    local r2 = rects[2]
    -- X start: 45 + 10 = 55.
    -- X end: 55 + 45 = 100.
    -- Inner X: 60 to 95.
    assertVec2("R2 lower", vec2(60, 5), r2.lower)
    assertVec2("R2 upper", vec2(95, 95), r2.upper)
end

function TestUI.test_grid_layout()
    local rect = Rect(vec2(0,0), vec2(100,100))
    
    -- 2x2 grid
    local grid = UI:grid(rect, 2, 2)
    
    -- Should be table of tables
    assertEqual("Row count", 2, #grid)
    assertEqual("Col count", 2, #grid[1])
    
    -- Top Left (Row 1, Col 1) -> 0,0 to 50,50
    assertVec2("0,0", vec2(0,0), grid[1][1].lower)
    assertVec2("50,50", vec2(50,50), grid[1][1].upper)
    
    -- Bottom Right (Row 2, Col 2) -> 50,50 to 100,100
    assertVec2("50,50", vec2(50,50), grid[2][2].lower)
    assertVec2("100,100", vec2(100,100), grid[2][2].upper)
end


-- Run all tests
function TestUI.runAll()
    TestUI.reset()
    
    TestUI.test_new_creates_instance()
    TestUI.test_default_padding()
    
    TestUI.test_update_size()
    TestUI.test_update_padding_number()
    TestUI.test_update_padding_table()
    
    TestUI.test_calc_bottomRight_from_topLeft()
    TestUI.test_calc_topLeft_from_bottomRight()
    TestUI.test_getRect_applies_padding()
    
    -- Layout Engine
    TestUI.test_vertical_split_fixed()
    TestUI.test_horizontal_split_equal()
    TestUI.test_split_with_padding_spacing()
    TestUI.test_grid_layout()
    
    return results
end

return TestUI
