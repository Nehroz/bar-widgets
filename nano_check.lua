local WIDGET_NAME = "Construction Turrets Range Check"
local WIDGET_VERSION = "1.1"

function widget:GetInfo()
    return {
        name = WIDGET_NAME,
        desc = "Stops construction turrets from being assinged to constructions out of reach.",
        author = "Nehroz",
        date = "2024.9.13", -- update date.
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

local function make_set(t) -- coverts a table to a Set()-like
    for _, key in ipairs(t) do t[key] = true end
end

local function check_turret_range(uID)
    local build_distance = UnitDefs[Spring.GetUnitDefID(uID)].buildDistance
    local cmds = Spring.GetUnitCommands(uID, -1)
    for _, cmd in ipairs(cmds) do
        if (cmd.id == CMD.REPAIR
        or cmd.id == CMD.GUARD
        or cmd.id == CMD.RECLAIM
        or cmd.id == CMD.ATTACK) then
            local distance = Spring.GetUnitSeparation(uID, cmd.params[1], true)
            if distance > build_distance then
                Spring.GiveOrderToUnit(uID, CMD.STOP, {}, {})
            end
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

