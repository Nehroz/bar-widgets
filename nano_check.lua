local WIDGET_NAME = "Construction Turrets Range Check"
local WIDGET_VERSION = "1.4c"
-- ### VERSIONS ###
-- 1.0 - initial release, basic
-- 1.1 - added more command types (reclaim, attack)
-- 1.2 - added support for queued commands to be processed
-- 1.3 - fixed a range difiation caused by the game adding model radius
-- 1.4a - optimization, added LRU cache to reduce the number of calls to the engine
-- 1.4b - optimization, changed the listening methode to await a command instead of polling x'th frame
-- 1.4c - optimization, added a command limit to prevent the engine from ignoring commands

function widget:GetInfo()
    return {
        name = WIDGET_NAME,
        desc = "Stops construction turrets from being assinged to constructions out of reach.",
        author = "Nehroz",
        date = "2024.9.15", -- update date.
        license = "GPL v3",
        layer = 0,
        version = WIDGET_VERSION
    }
end

-- SECTION OOP
-- SECTION LRU Cache class
LRUCache = {}
LRUCache.__index = LRUCache

-- Constructor
function LRUCache:new(max_size)
    local cache = {
        max_size = max_size or 10, -- Default max size to 10 if not specified
        cache = {},                -- Key-Value store (uID -> value = radius)
        order = {}                 -- To track the order of use (most recent at the end)
    }
    setmetatable(cache, LRUCache)
    return cache
end

-- Get a value by uID
function LRUCache:get(uID)
    local value = self.cache[uID]
    if value then
        -- Move the accessed uID to the end to mark it as most recently used
        self:moveToEnd(uID)
        return value
    else
        return nil -- uID not found
    end
end

-- Put a uID and value into the cache
function LRUCache:put(uID, value)
    if self.cache[uID] then
        -- If uID already exists, just update and mark it as recently used (should never be the case)
        self.cache[uID] = value
        self:moveToEnd(uID)
    else
        -- Add new uID-value pair
        if #self.order >= self.max_size then
            -- Cache is full, remove the least recently used item
            local lru = table.remove(self.order, 1)
            self.cache[lru] = nil
        end
        table.insert(self.order, uID)
        self.cache[uID] = value
    end
end

-- Helper function to move uID to the end of the order list
function LRUCache:moveToEnd(uID)
    for i, id in ipairs(self.order) do
        if id == uID then
            table.remove(self.order, i)
            break
        end
    end
    table.insert(self.order, uID)
end
-- !SECTION LRU Cache
-- !SECTION OOP

-- SECTION Settings and other variables
local DELAY = 15 -- Delay between command given to processing
local TURRETS = {"armnanotc", "cornanotc", "armnanotct2", "cornanotct2"} -- names of nano turrets names
local COMMAND_LIMIT = 20 -- Maximum number of commands to be processed in a single frame, blocking
local is_play = false
local counter = 0
local listening = false
local processed = false
local current_towers = {}
local command_budget = 0
local to_be_cleared = {}
local new_orders = {}
local lru_cache = LRUCache:new(10)
-- !SECTION Settings and other variables

-- converts a table to a Set()-like
local function make_set(t) -- coverts a table to a Set()-like
    for _, key in ipairs(t) do t[key] = true end
end

local function check_turret_range(uID)
    local x, y, z = Spring.GetUnitPosition(uID)
    local build_distance = Spring.GetUnitEffectiveBuildRange(uID, nil) -- Same as UnitDef.buildDistance; Not ambigous
    local is_changed = false
    local is_first_cmd = true
    local cmds = Spring.GetUnitCommands(uID, -1)
    local new_cmds = {}
    for i = #cmds, 1, -1  do
        local cmd = cmds[i]
        if (cmd.id == CMD.REPAIR
        or cmd.id == CMD.GUARD
        or cmd.id == CMD.RECLAIM
        or cmd.id == CMD.ATTACK) then
            local tuID = cmd.params[1]
            local tx, ty, tz = Spring.GetUnitPosition(tuID)
            if tx == nil then break end
            -- NOTE equal to Spring.GetUnitSeparation(u1, u2, false, false) Uses 3D distance not 2D
            -- This is faster then synch reading from the engine; jumping between threats.
            -- In case there is any range errors look here and see if using 2D (ignoring Z).
            -- I can't find if Nano's use 2D or 3D.
            local distance = math.sqrt((x-tx)^2+(y-ty)^2+(z-tz)^2)
            -- LRU caching of model radius
            local radius = lru_cache:get(tuID)
            if not radius then
                radius = Spring.GetUnitDefDimensions(Spring.GetUnitDefID(tuID)).radius
                lru_cache:put(tuID, radius)
            end
            if distance < build_distance + radius then
                if is_first_cmd then
                    cmd.options.shift = false
                    is_first_cmd = false
                else
                    cmd.options.shift = true
                end
                table.insert(new_cmds, {cmd.id, cmd.params, cmd.options})
            else
                is_changed = true
            end
        end
    end
    if is_changed then
        if #new_cmds > 0 then
            table.insert(new_orders, {uID, new_cmds}) -- schedule for new order
        else
            table.insert(to_be_cleared, uID) -- schedule for clear
        end
    end
end

function widget:Initialize()
    is_play = Spring.GetSpectatingState()
    make_set(TURRETS)
end

function widget:GameFrame()
    if listening then -- only as long as turret is selection and one post-frame after selection drop.
        counter = counter + 1
        command_budget = COMMAND_LIMIT

        -- apply scheduled orders, on the next frame
        if #to_be_cleared > 0 then
            for i= #to_be_cleared, 1, -1 do
                Spring.GiveOrderToUnit(to_be_cleared[i], CMD.STOP, {}, {} ) -- clear nano
                table.remove(to_be_cleared, i) -- pop
                command_budget = command_budget - 1
                if command_budget <= 0 then
                    break
                end
            end
        end

        if #new_orders > 0 and #to_be_cleared == 0 then
            for i= #new_orders, 1, -1 do
                Spring.GiveOrderArrayToUnit(new_orders[i][1], new_orders[i][2])
                table.remove(new_orders, i) -- pop
                command_budget = command_budget - 1
                if command_budget <= 0 then
                    break
                end
            end
        end

        if #to_be_cleared == 0 and #new_orders == 0 then
            if  processed then
                listening = false
            elseif counter >= DELAY then -- after x frames the check is done
                counter = 0
                for _, tower in ipairs(current_towers) do
                    check_turret_range(tower)
                end
                processed = true
            end
        end
    end
end

-- Grabs any nano in selection and stores it in the list
function widget:SelectionChanged(selectedUnits)
    if is_play ~= false then return end
    current_towers = {}
    for _, unitID in ipairs(selectedUnits) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        if TURRETS[UnitDefs[unitDefID].name] then
            table.insert(current_towers, unitID)
        end
    end
end

function widget:UnitCommand(uID, _, _, _, _, _, _)
    if is_play ~= false then return end
    for _, nano in ipairs(current_towers) do
        if uID == nano then
            listening = true
            counter = 0
            processed = false
            break
        end
    end
end