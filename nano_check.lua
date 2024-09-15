local WIDGET_NAME = "Construction Turrets Range Check"
local WIDGET_VERSION = "1.3"

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

local INTERVAL = 15
local TURRETS = {"armnanotc", "cornanotc", "armnanotct2", "cornanotct2"}
local is_play = false
local counter = 0
local listening = false
local current_towers = {}
local new_orders = {}

local function make_set(t) -- coverts a table to a Set()-like
    for _, key in ipairs(t) do t[key] = true end
end

local function check_turret_range(uID)
    local x, y, z = Spring.GetUnitPosition(uID)
    --local build_distance = UnitDefs[Spring.GetUnitDefID(uID)].buildDistance
    local build_distance = Spring.GetUnitEffectiveBuildRange(uID, nil)
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
            -- NOTE this was slower than just directly calculating distance
            --local distance = Spring.GetUnitSeparation(uID, cmd.params[1], true)
            --if distance == nil then break end
            local tx, ty, tz = Spring.GetUnitPosition(cmd["params"][1])
            if tx == nil then break end
            local distance = math.sqrt((x-tx)^2+(y-ty)^2+(z-tz)^2)
            if distance < build_distance + Spring.GetUnitDefDimensions(Spring.GetUnitDefID(cmd.params[1])).radius then
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
        Spring.GiveOrderToUnit(uID, CMD.STOP, {}, {} ) -- clear
        if #new_cmds > 0 then
            table.insert(new_orders, {uID, new_cmds})
        end
    end
end

function widget:Initialize()
    is_play = Spring.GetSpectatingState()
    make_set(TURRETS)
end

function widget:GameFrame()
    if listening then
        counter = counter + 1

        if #new_orders > 0 then -- apply, on the next frame
            for _, order in ipairs(new_orders) do
                print("new_orders: " .. #order[2])
                Spring.GiveOrderArrayToUnit(order[1], order[2])
            end
            new_orders = {}
        end

        if counter >= INTERVAL then -- every x frames, as range checking is a bit more expensive
            counter = 0
            for _, tower in ipairs(current_towers) do
                check_turret_range(tower)
            end

            for _, uID in ipairs(current_towers) do
                if Spring.IsUnitSelected(uID) then
                    return -- don't reset if still selected
                end
            end -- reset
            listening = false
            current_towers = {}
        end
    end
end

function widget:SelectionChanged(selectedUnits)
    if is_play ~= false then return end
    local selected = false
    for _, unitID in ipairs(selectedUnits) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        if TURRETS[UnitDefs[unitDefID].name] then
            table.insert(current_towers, unitID)
            selected = true
        end
    end
    if selected then
        listening = true
    end
end