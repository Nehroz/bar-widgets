-- configurables, you can change these variables here,
-- but changes in the in-game settings will overwrite these, for the more common ones.
-- audio file paths need to be changed here; they are not in the in-game settings.
-- if you want to change hotkeys change the keycodes in widget:KeyPress().
local audio_queue = "LuaUI/Widgets/Sounds/idling_unit.wav"  -- sound player with ping, to differtiate audio queue.
local warning_audio = {"LuaUI/Widgets/Sounds/overtime_having_idles.wav", "LuaUI/Widgets/Sounds/overtime_idles_remain.wav", "LuaUI/Widgets/Sounds/overtime_queue_not_empty.wav", "LuaUI/Widgets/Sounds/overtime_unmanaged_units.wav"} -- sound played if idles are still idle after some time.
local com_warning = "LuaUI/Widgets/Sounds/idling_com.wav" -- sound played when idle is a Commander
local con_warning = "LuaUI/Widgets/Sounds/idling_con.wav" -- sound played when idle is a Constructor
local rez_warning = "LuaUI/Widgets/Sounds/idling_rezbot.wav" -- sound played when idle is a Rez bot
local fac_warning = "LuaUI/Widgets/Sounds/idle_lab.wav" -- sound played when idle is a Factory
local substitution_audio = "Sounds/movement/arm-bot-at-sel.wav" -- internal sound used when files missing.

-- game has 30 ticks per second, as example if you want something to play every 3 seconds, set it to 3*30 = 90
local audio_volume = 0.85 -- how loud the audio queues should be
local always_exclude_names = {"corvacct", "armantiship", "corantiship"} -- excluded units that count as mobile builders. (corvacct is the turret inside the printer, it's not the printer itself!)
local interval_to_check = 10 -- how many game ticks for a check for idle removal. (30 = 1 second)
local audio_timer = 20 -- how many ticks have to pass before a new audio bit can be played; To avoid spamming.
local still_idle_warning = 120 -- factor of interval_to_check, will start secundary warn sound.
local still_idle_repeat = 120 -- factor of interval_to_check between secundary warn sounds.
local time_out_minimal = 90 -- frames needed for a inuit to be recognized as idle.
local grouping_radius = 200 -- radius in which idles will be grouped; only applies if the unit is the same unit type.
local regresive_collect = true -- if on will collect nearby idles within grouping_radius that are not yet timed out and group them as one package.
local include_com = false -- flag if commader's are detected.
local include_rez = false -- flag if rez bot's are detected.
local factory_idle = false -- flag if factories are detected; Factories have a own queue and don't evoke a map ping; Simply audio warning + text, use alt+s to get first. This those not trigger when a factory is manually dequeued; only if it finishes the production queue.
local include_commando = false -- flag if commandos are detected.
local use_ping = true -- flag if using default game ping (only you, the player, can see this).

local widget_name = "Idle Constructor Notification"
local widget_version = "1.4g β"
function widget:GetInfo()
    return {
        name = widget_name,
        desc = "Audio queue and ping on idle cons appearing. `select_latest_idle_unit` moves the camera to the latest idle unit and selects it; This will keep selecting idles in the same order as they appeared.",
        author = "Nehroz",
        date = "2024.9.2", -- update date.
        license = "GPL v3",
        layer = 0,
        enabled = true,
        handler = true,
        version = widget_version
    }
end
-- used by script; keys
local com = {"armcom", "corcom", "legcom"}
local rez = {"armrectr", "cornecro", "armrecl", "correcl"} --TODO: add Legion Rez when Legion gets there own (currently cornecro)
local special = {"cormando"} -- for now this is just the commando
-- used by script; variables
local is_play = false
local exclude_names = {}
local idles_timingout = {}
local idles = {}
local mark_stack = {}
local idles_not_being_processed = 0
local idle_factoies_timingout = {}
local idle_factoies = {}
local time_since_last_sound = 0 -- ticks up when a sound is played. Blocks audio spamming.
local time_since_last_warning = 0 -- ticks up when a warning is played. Blocks audio spamming.
local first_warn = true

local function dump_table(t) -- converts table to string
    local s = ""
    if type(t) == "table" then
        for k,v in pairs(t) do
            if type(v) == "table" then
                v = dump_table(v)
            end
            s = s .. "[" .. tostring(k) .. "] = " .. tostring(v) .. ", "
        end
        s = "{" .. s .. "}"
        return s
    else
        return tostring(t)
    end
end

local function print(str) -- debug print
    local s = dump_table(str)
    Spring.Echo(s)
end

local function vec_len(x,y,z) -- simple vector math, gives length
    return math.sqrt(x*x+y*y+z*z)
end

local function get_idx(tab, uID) -- figures out index of a unit with uID
    local idx = nil
    for i,v in ipairs(tab) do
        if (v["uID"] == uID) then
            idx = i
            break
        end
    end
    return idx
end

local function union(t1, t2) -- executes a union between two tables
    local new = {}
    for i=1,#t1 do new[i] = t1[i] end
    local offset = #new
    for i=1,#t2 do new[i+offset] = t2[i] end
    return new
end

local function has_value(t, v) -- checks if table has a value
    for _,tv in ipairs(t) do
        if v == tv then return true end 
    end
    return false
end

local function add_options() -- constructs options and adds them to the settings menu -- ! warning, if widget is reloaded repetility it bugs out the order.
    if WG["options"] then
        local t = {}
        local op = {
            widgetname = widget_name,
            name = "Idle update freq.",
            description = "Specify how many game frames (30 per s) it takes before executed the next iteration.",
            id = "Idle_Ticker",
            value = interval_to_check,
            type = "slider",
            min = 5,
            max = 120,
            step = 5,
            onchange = function(i,v)
                interval_to_check = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Sec. warning time",
            description = "Specify how many intervals of updates it will take to trigger the secundary warning. Reminding you that you have still idles.",
            id = "Still_Idle_Warn",
            value = still_idle_warning,
            type = "slider",
            min = 10,
            max = 300,
            step = 5,
            onchange = function(i,v)
                still_idle_warning = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Sec. warning repeat time",
            description = "Specify how many how many updates it will take to trigger the secundary warning ones again.",
            id = "Idle_Warn_Rep",
            value = still_idle_repeat,
            type = "slider",
            min = 10,
            max = 300,
            step = 5,
            onchange = function(i,v)
                still_idle_repeat = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle timeout",
            description = "Specify many frames (30 per s) a con needs to be idle before being processed and pinged. Important for grouping out of synch going idle units ex: after group move, so more likely grouping. Trade-off is a longer time until warning of the idle.",
            id = "Idle_Timer",
            value = time_out_minimal,
            type = "slider",
            min = 5,
            max = 300,
            step = 5,
            onchange = function(i,v)
                time_out_minimal = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle grouping radius",
            description = "Select range used to detect nearby idles to be grouped up into one selection and ping.",
            id = "Idle_Radius",
            value = grouping_radius,
            type = "slider",
            min = 20,
            max = 500,
            step = 20,
            onchange = function(i,v)
                grouping_radius = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle group newly idle cons too",
            description = "Allows the script to collect not yet timmed out and fresh idling units to be grouped up.",
            id = "Idle_Regresive",
            value = regresive_collect,
            type = "bool",
            onchange = function(i,v)
                regresive_collect = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Use a ping",
            description = "Will fire off a ping at location of idle unit. If turned off will simply warn you by audio queue and a lua.console message.",
            id = "Message_Type",
            value = use_ping,
            type = "bool",
            onchange = function(i,v)
                use_ping = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Do Factories idles",
            description = "Will pop idle sound on factories without a ping (no matter the \"Use a ping\" setting.) The factory queue is isolated from the other idles and can be worked off by using alt+s in the order they went idle. Factories that where manually dequeued will not trigger this.",
            id = "Idle_Fact",
            value = factory_idle,
            type = "bool",
            onchange = function(i,v)
                factory_idle = v
                idle_factoies = {} -- soft reset
                idle_factoies_timingout = {}
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Include Commanders",
            description = "Will also idle warn for commanders.",
            id = "Idle_Com",
            value = include_com,
            type = "bool",
            onchange = function(i,v)
                include_com = v
                Exclution_Generator()
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Include rezbots",
            description = "Will also pop idle warnings on rezbots.",
            id = "Idle_Rez",
            value = include_rez,
            type = "bool",
            onchange = function(i,v)
                include_rez = v
                Exclution_Generator()
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Include Commando",
            description = "Will also pop idle warnings on rezbots.",
            id = "Idle_Commando",
            value = include_commando,
            type = "bool",
            onchange = function(i,v)
                include_commando = v
                Exclution_Generator()
            end
        }
        table.insert(t, op)
        WG["options"].addOptions(t)
    end
end

local function del_options() -- deletes all options from settings mmenu
    if WG["options"] then
        WG["options"].removeOptions({"Idle_Ticker", "Still_Idle_Warn", "Idle_Warn_Rep", "Idle_Timer", "Idle_Radius", "Message_Type", "Idle_Regresive", "Idle_Fact", "Idle_Com", "Idle_Rez", "Idle_Commando"})
    end
end

local function find_nearby(t_collector, t_search, unit)
    for i = #t_search, 1, -1 do
        if unit["uDefID"] == t_search[i]["uDefID"] then --identify check
            if vec_len(unit["x"]-t_search[i]["x"], unit["y"]-t_search[i]["y"], unit["z"]-t_search[i]["z"]) < grouping_radius then
                table.insert(t_collector, t_search[i])
                table.remove(t_search, i)
            end
        end
    end
end

local function collect_nearby(t) -- will collect all idles nearby out of both lists, mergeing nearby idles.
    local collection = {t[1]}
    table.remove(t, 1)
    if regresive_collect then
        local i = 1
        while i <= #collection do
            find_nearby(collection, idles_timingout, collection[i])
            i = i +1
        end
    end
    local i = 1
    while i <= #collection do
        find_nearby(collection, t, collection[i])
        i = i +1
    end
    return collection
end

local function still_idle(uID, _type) -- checks if unit is still idle, returns true if unit has no commands (nil if error)
    local hp = Spring.GetUnitHealth(uID)
    if type(hp) == "number" then -- in case of nil
        if Spring.GetUnitHealth(uID) <= 0 then return false end  -- dead units are well dead, needed because aircraft doesn't trigger "isDead" while falling from sky.
    end
    local cmds = 0
    if _type == 0 then
      cmds = Spring.GetUnitCommands(uID, 0)
    elseif _type == 1 then
      cmds = Spring.GetFactoryCommands(uID, 0)
    end
    if cmds == nil then return nil end
    if cmds > 0 then return false
    else return true end
end

local function play_sound(path) -- plays audio and returns true if sound is played
    if time_since_last_sound > audio_timer then
        Spring.PlaySoundFile(path, audio_volume, 'ui')
        time_since_last_sound = 0
        return true
    end
    return false
end

local function ping_unit(x, y, z, text, udef) -- plays audio sound and pings if use_ping is true
    if has_value(com, udef.name) then -- if it's a commander
        play_sound(com_warning)
    elseif has_value(rez, udef.name) then -- if it's a rezbots
        play_sound(rez_warning)
    elseif udef.isFactory then -- if it's a factory
        play_sound(fac_warning)
        Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), text) -- REVISE better way?
        return
    else -- anything else; cons
        play_sound(con_warning)
    end

    if use_ping then
        Spring.MarkerAddPoint(x, y, z, text, true) --def.translatedHumanName
    else
        Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), text) -- REVISE: better way?
    end
end

function Exclution_Generator() -- Generates and unions table for exclude_names. (Is global so options WG can call it.)
    local t = {}
    if include_com == false then
        t = union(t, com)
    end
    if include_rez == false then
        t = union(t, rez)
    end
    if include_commando == false then
        t = union(t, special)
    end
    exclude_names = union(always_exclude_names, t)
end

function widget:Initialize()
    -- check if file exists else use default spidy sounds.
    local current_substitution_audio = substitution_audio
    if VFS.FileExists(audio_queue) == false then
        audio_queue = current_substitution_audio
    else
        current_substitution_audio = audio_queue -- use default ping wav if audio_queue exists
    end
    local t = {}
    for k in pairs(warning_audio) do
        if VFS.FileExists(k) == false then
            table.insert(t, substitution_audio)
        else
            table.insert(t, k)
        end
    end
    if VFS.FileExists(com_warning) == false then
        com_warning = current_substitution_audio
    end
    if VFS.FileExists(con_warning) == false then
        con_warning = current_substitution_audio
    end
    if VFS.FileExists(rez_warning) == false then
        rez_warning = current_substitution_audio
    end
    if VFS.FileExists(fac_warning) == false then
        fac_warning = current_substitution_audio
    end

    add_options()
    Exclution_Generator()
    widget:Update()
    print(widget_name .. " V" .. widget_version .. " loaded.")

    widgetHandler.actionHandler:AddAction(self, "select_latest_idle_unit", select_latest_idle_unit, nil, "p")
    widgetHandler.actionHandler:AddAction(self, "select_latest_idle_factory", select_latest_idle_factory, nil, "p")
    widgetHandler.actionHandler:AddAction(self, "dismiss_idles", dismiss_idles, nil, "p")
end

function select_latest_idle_unit()
    if #idles < 1 then return end
    local grp = idles[#idles]
    local pu = grp[1]
    Spring.SetCameraTarget(pu["x"], pu["y"], pu["z"], 0.5)
    local sgrp = {}
    for i=#grp,1,-1 do table.insert(sgrp, grp[i]["uID"]) end
    Spring.SelectUnitArray(sgrp)
end

function select_latest_idle_factory()
    if factory_idle == false then return end
    if #idle_factoies < 1 then return end
    local u = idle_factoies[1]
    Spring.SetCameraTarget(u["x"], u["y"], u["z"], 0.5)
    Spring.SelectUnitArray({u["uID"]})
end

function dismiss_idles()
    idles = {}
    idle_factoies = {}
    first_warn = true
    idles_not_being_processed = 0
end

function widget:Update()
    is_play = Spring.GetSpectatingState()
end

function widget:UnitIdle(uID, uDefID, uClan)
    if is_play ~= false then return end
    if Spring.GetUnitIsDead(uID) ~= false then return end --suppress idle detection on dead units.
    if uClan ~= Spring.GetMyTeamID() then return end -- check if it's your unit before further checks.
    local def = UnitDefs[uDefID]
    if def.isFactory == true and factory_idle then -- if it's a fac, add it to it's table.
        local x, y, z = Spring.GetUnitPosition(uID)
        local t, _ = Spring.GetGameFrame()
        table.insert(idle_factoies_timingout, {["x"] = x, ["y"] = y, ["z"] = z, ["uID"] = uID, ["uDefID"] = uDefID, ["time"] = t})
        return
    end
    if def.isMobileBuilder == false or has_value(exclude_names, def.name) then return end -- mobile builder + exclude units
    local x, y, z = Spring.GetUnitPosition(uID)
    local t, _ = Spring.GetGameFrame()
    local unit = {["x"] = x, ["y"] = y, ["z"] = z, ["uID"] = uID, ["uDefID"] = uDefID, ["time"] = t}
    table.insert(idles_timingout, unit)
end

function widget:UnitDestroyed(uID, uDefID, uClan)
    if uClan == Spring.GetMyTeamID() then
        if is_play ~= false then return end
        local def = UnitDefs[uDefID]
        if def.isMobileBuilder == false or has_value(exclude_names, def.name) then return end
        local idx = get_idx(idles_timingout, uID)
        if idx ~= nil then
            table.remove(idles_timingout, idx)
            return
        end
        for i=#idles,1,-1 do
            idx = get_idx(idles[i], uID)
            if idx ~= nil then
                if use_ping then
                    Spring.MarkerErasePosition(idles[i][idx]["x"], idles[i][idx]["y"], idles[i][idx]["z"])
                end
                table.remove(idles[i], idx)
                if #idles[i] < 1 then table.remove(idles, i) end -- clena up empty table
                return
            end
        end
    end
end

-- function widget:KeyPress(key, mods, isRepeating)
--     if key == 97 and mods.alt then -- a+alt
--         if #idles < 1 then return end
--         local grp = idles[#idles]
--         local pu = grp[1]
--         Spring.SetCameraTarget(pu["x"], pu["y"], pu["z"], 0.5)
--         local sgrp = {}
--         for i=#grp,1,-1 do table.insert(sgrp, grp[i]["uID"]) end
--         Spring.SelectUnitArray(sgrp)
--     elseif key == 115 and mods.alt then -- s+alt
--         if factory_idle == false then return end
--         if #idle_factoies < 1 then return end
--         local u = idle_factoies[1]
--         Spring.SetCameraTarget(u["x"], u["y"], u["z"], 0.5)
--         Spring.SelectUnitArray({u["uID"]})
--     elseif key == 100 and mods.alt then -- d+alt (dismiss idle warning)
--         idles = {}
--         idle_factoies = {}
--         first_warn = true
--         idles_not_being_processed = 0
--     end
-- end

function widget:GameFrame(tick)
    time_since_last_sound = time_since_last_sound + 1
    local idle_existing = false
    if math.fmod(tick, interval_to_check) == 0 then
        -- SECTION 1: Unit handling
        --checks if idle no longer are idle, removes element and marker
        for i=#idles,1,-1 do
            local first_uID = idles[i][1]["uID"]
            for j=#idles[i], 1, -1 do
                if still_idle(idles[i][j]["uID"], 0) == false then
                    if use_ping then
                        Spring.MarkerErasePosition(mark_stack[first_uID].x, mark_stack[first_uID].y, mark_stack[first_uID].z)
                    end
                    table.remove(idles[i], j)
                else
                    idle_existing = true
                end
            end
            if #idles[i] < 1 then
                table.remove(idles, i)
            end
        end
        -- processing time outs
        local t = {}
        for i = #idles_timingout,1,-1 do
            if still_idle(idles_timingout[i]["uID"], 0) == true then
                if tick - idles_timingout[i]["time"] >= time_out_minimal then
                    table.insert(t, idles_timingout[i])
                    table.remove(idles_timingout, i)
                end
            else
                table.remove(idles_timingout, i)
            end
        end
        while #t > 0 do -- processing for grouping_radius
            local grp = collect_nearby(t)
            local pu = grp[1]
            local str = "Idle "
            if #grp > 1 then
                str = str .. tostring(#grp) .. "x "
            end
            local coords = {x = pu["x"], y = pu["y"], z = pu["z"]}
            ping_unit(coords["x"], coords["y"], coords["z"], str.. UnitDefs[pu["uDefID"]].translatedHumanName .. "!", UnitDefs[pu["uDefID"]])
            local marker_packed = {x = pu["x"], y = pu["y"], z = pu["z"]}
            mark_stack[pu["uID"]] = marker_packed
            table.insert(idles, grp)
        end
        -- !SECTION
        -- SECTION 2: Factory handling
        if factory_idle then
            --checks if idle no longer are idle, removes element and marker
            for i=#idle_factoies,1,-1 do
                if still_idle(idle_factoies[i]["uID"], 1) == false then
                    table.remove(idle_factoies, i)
                else
                    idle_existing = true
                end
            end
            -- processing time outs
            for i=#idle_factoies_timingout,1,-1 do
                local fac = idle_factoies_timingout[i]
                if still_idle(fac["uID"], 1) == true then
                    if tick - fac["time"] >= time_out_minimal then
                        table.insert(idle_factoies, fac)
                        ping_unit(fac["x"], fac["y"], fac["z"], "Idle " ..  UnitDefs[fac["uDefID"]].translatedHumanName .. "!", UnitDefs[fac["uDefID"]])
                        table.remove(idle_factoies_timingout, i)
                    end
                else
                    table.remove(idle_factoies_timingout, i)
                end
            end
        end
        -- !SECTION
        if #idles == 0 and #idle_factoies == 0 then
            idles_not_being_processed = 0
            first_warn = true
        elseif idle_existing == true then
            idles_not_being_processed = idles_not_being_processed + 1
        end
    end
    -- play idler still idling sound
    if math.fmod(tick, interval_to_check) == 0 then
        if idles_not_being_processed >= still_idle_warning then -- checks if threshold is reached
            if first_warn == true then -- ensure it warns ones
                time_since_last_warning = still_idle_repeat
            else
                time_since_last_warning = time_since_last_warning + 1
            end
        end
        if time_since_last_warning >= still_idle_repeat then -- checks if enough time has passed since last warning
            local sound_bit = warning_audio[math.random(1,#warning_audio)]
            local played = play_sound(sound_bit)
            if played then
                first_warn = false
                time_since_last_sound = 0
                time_since_last_warning = 0
            end
        end
    end
end

function widget:Shutdown() --removes options
    del_options()
    for group in pairs(idles) do -- removes all markers
        for unit in pairs(idles[group]) do
            Spring.MarkerErasePosition(idles[group][unit]["x"], idles[group][unit]["y"], idles[group][unit]["z"])
        end
    end
end

function widget:GetConfigData() -- Retrevies settings on load.
    local data = {}
    data.interval = interval_to_check
    data.still = still_idle_warning
    data.timer = time_out_minimal
    data.radius = grouping_radius
    data.regresive = regresive_collect
    data.use_ping = use_ping
    data.com = include_com
    data.rez = include_rez
    data.spezial = include_commando
    data.factory = factory_idle
    data.sir = still_idle_repeat
    return data
end

function widget:SetConfigData(data) -- Stores settings to be recovered.
    if data.interval ~= nil then interval_to_check = data.interval end
    if data.still ~= nil then still_idle_warning = data.still end
    if data.timer ~= nil then time_out_minimal = data.timer end
    if data.radius ~= nil then grouping_radius = data.radius end
    if data.regresive ~= nil then regresive_collect = data.regresive end
    if data.use_ping ~= nil then use_ping = data.use_ping end
    if data.com ~= nil then include_com = data.com end
    if data.rez ~= nil then include_rez = data.rez end
    if data.spezial ~= nil then include_commando = data.spezial end
    if data.factory ~= nil then factory_idle = data.factory end
    if data.sir ~= nil then still_idle_repeat = data.sir end
end