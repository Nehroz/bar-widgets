function widget:GetInfo()
    return {
        name = "Idle Constructor Notifiaction",
        desc = "Audio queue and ping on idle cons appearing. alt+a move camera to latest idle and selects it until it's no longer idling; This will keep selecting idles in the same order as they appeared.",
        author = "Nehroz",
        date = "2024.3.x",
        license = "GPL v3",
        layer = 0,    
        enabled = true,
        version = "1.1"  --I may later add functioanlity to the option menu.
    }
end

-- configurables
local audio_queue = "Sounds/movement/arm-bot-at-sel.wav"  -- sound player with ping, to differtiate audio queue.
local exlude_names = {"armcom", "corcom", "armrectr", "cornecro", "cormando"} -- excluded units that count as mobile builders.
local interval_to_check = 30 -- how many game ticks for a check for idle removal.

local is_play = false
local idles = {}


function get_idx(tab, val)
    local idx = nil
    for i,v in ipairs(tab) do
        if (v == val) then
            idx = i
            break
    end end
    return idx
end


function widget:Initialize()
    for _, v in pairs(exlude_names) do exlude_names[v] = true end -- setup for check
    widget:Update()
    Spring.Echo("Idle notificaiton loaded.")
end

function widget:Update()
    is_play = Spring.GetSpectatingState()
end

function widget:UnitIdle(uID, uDefID, uClan)
    if is_play ~= false then return end
    if Spring.GetUnitIsDead(uID) ~= false then return end --supress idle detection on dead units.
    if uClan ~= Spring.GetMyTeamID() then return end -- check if it's your unit before further checks.
    def = UnitDefs[uDefID]
    if def.isMobileBuilder == false or exlude_names[def.name] == true then return end -- mobile builder + exlude units
    Spring.PlaySoundFile(audio_queue, 0.75, 'ui')
    x, y, z = Spring.GetUnitPosition(uID)
    Spring.MarkerAddPoint(x, y, z, "Idle ".. def.translatedHumanName .. "!" , true)
    unit = {["x"] = x, ["y"] = y, ["z"] = z, ["uID"] = uID, ["uDefID"] = uDefID}
    table.insert(idles, unit)
end

function widget:UnitDestroyed(uID, uDefID, uClan)
    if uClan == Spring.GetMyTeamID() then 
        idx = get_idx(idles, uID)
        if idx ~= nil then table.remove(idles, idx) end
    end
end

function widget:KeyPress(key, mods, isRepeating)
    if key == 97 and mods.alt then -- a+alt
        if #idles < 1 then return end
        idle = idles[#idles]
        if Spring.GetUnitIsDead(idle["uID"]) ~= false then return end
        Spring.SetCameraTarget(idle["x"], idle["y"], idle["z"], 0.5)
        Spring.SelectUnit(idle["uID"])
        Spring.MarkerErasePosition(idle["x"], idle["y"], idle["z"])
end end

function widget:GameFrame(tick)
    if math.fmod(tick, interval_to_check) == 0 then 
        for i=#idles,1,-1 do --checks if idle no longer are idle, removes element and marker
            cmds = Spring.GetUnitCommands(idles[i]["uID"], 0)
            if cmds ~= nil then
                if cmds > 0 then
                    Spring.MarkerErasePosition(idles[i]["x"], idles[i]["y"], idles[i]["z"])
                    table.remove(idles, i)
end end end end end
