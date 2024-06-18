local widget_name = "Idle Constructor Notifiaction"

function widget:GetInfo()
    return {
        name = widget_name,
        desc = "Audio queue and ping on idle cons appearing. alt+a move camera to latest idle and selects it until it's no longer idling; This will keep selecting idles in the same order as they appeared.",
        author = "Nehroz",
        date = "2024.3.x",
        license = "GPL v3",
        layer = 0,    
        enabled = true,
        version = "1.2b"
    }
end

local audio_queue = "LuaUI/Widgets/pipo.ogg"  -- sound player with ping, to differtiate audio queue.
local warning_audio = "LuaUI/Widgets/arere.ogg" -- sound played if idles are still idle.
local audio_volume = 0.85 -- how loud the audio queues should be
local exclude_names = {} -- excluded units that count as mobile builders.
local interval_to_check = 30 -- how many game ticks for a check for idle removal.
local time_out_minimal = 20 -- frames needed for a inuit to be recognized as idle.
local grouping_radius = 200
local regresive_collect = true -- if on will collect nearby idles that are not yet timed out as well and group them.
local include_com = false -- flag if commader's are detected.
local include_rez = false -- flag if rez bot's are detected.
local include_comando = false -- flag if commandos are detected.
local use_ping = true -- flag if using default game ping (only you can see this).

local is_play = false
local idles_timingout = {}
local idles = {}
local idles_not_being_processed = 0


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
    new = {}
    for i=1,#t1 do new[i] = t1[i] end
    offset = #new
    for i=1,#t2 do new[i+offset] = t2[i] end
    return new
end
local function has_value(t, v) -- checks if table has a value
    for i,tv in ipairs(t) do
        if v == tv then return true end 
    end
    return false
end

local function add_options() -- constructs options and adds them to the settings menu -- ! warning, if widget is reloaded repetility it bugs out the order.
    if WG["options"] then
        t = {}
        op = {
            widgetname = widget_name,
            name = "Idle update frequency",
            description = "Specify how many game frames (60 per s) it takes before executed the next iterration.",
            id = "idle_ticker",
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
            name = "Idle time out",
            description = "Specify many frames (60 per s) a con needs to be idle before being processed and pinged. Importent for grouping out of synch going idle units ex: after group move, so more likely grouping. Trade-off is a longer time until warning of the idle.",
            id = "idle_timer",
            value = time_out_minimal,
            type = "slider",
            min = 5,
            max = 120,
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
            id = "idle_radius",
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
            name = "Idle grouping fresh cons too",
            description = "Allows the script to collect not yet timmed out and fresh idling units to be grouped up.",
            id = "idle_regresive",
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
            description = "Will fire off a ping at location, else pops a chat message to you.",
            id = "message_type",
            value = use_ping,
            type = "bool",
            onchange = function(i,v)
                use_ping = v
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle includes Commanders",
            description = "Will also idle warn for commanders.",
            id = "idle_com",
            value = idle_com,
            type = "bool",
            onchange = function(i,v)
                include_com = v
                exclution_generator()
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle includes rezbots",
            description = "Will also pop idle warnings on rezbots.",
            id = "idle_rez",
            value = idle_rez,
            type = "bool",
            onchange = function(i,v)
                include_rez = v
                exclution_generator()
            end
        }
        table.insert(t, op)
        op = {
            widgetname = widget_name,
            name = "Idle includes comando",
            description = "Will also pop idle warnings on rezbots.",
            id = "idle_comando",
            value = idle_comando,
            type = "bool",
            onchange = function(i,v)
                idle_comando = v
                exclution_generator()
            end
        }
        table.insert(t, op)
        WG["options"].addOptions(t)
    end
end

local function del_options() -- deletes all options from settings mmenu
    if WG["options"] then
        WG["options"].removeOptions({"idle_ticker", "idle_timer", "idle_radius", "message_type", "idle_regresive", "message_type", "idle_com", "idle_rez", "idle_comando"})
    end
end

local function find_nearby(t_collector, t_search, unit)
    for i = #t_search, 1, -1 do
        if unit["uDefID"] == t_search[i]["uDefID"] then --identiy check
            if vec_len(unit["x"]-t_search[i]["x"], unit["y"]-t_search[i]["y"], unit["z"]-t_search[i]["z"]) < grouping_radius then
                table.insert(t_collector, t_search[i])
                table.remove(t_search, i)
            end
        end
    end
end

local function collect_nearby(t) -- will collect all idles nearby out of both lists, mergeing nearby idles.
    collection = {t[1]}
    table.remove(t, 1)
    if regresive_collect then
        i = 1
        while i <= #collection do 
            find_nearby(collection, idles_timingout, collection[i])
            i = i +1
        end
    end
    i = 1
    while i <= #collection do 
        find_nearby(collection, t, collection[i])
        i = i +1
    end
    return collection
end

local function still_idle(uID)
    cmds = Spring.GetUnitCommands(uID, 0)
    if cmds == nil then return nil end
    if cmds > 0 then return false
    else return true end 
end

local function ping_unit(x, y, z, text)
    Spring.PlaySoundFile(audio_queue, audio_volume, 'ui')
    if use_ping then
        Spring.MarkerAddPoint(x, y, z, text, true) --def.translatedHumanName
    else
        Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), text)
    end
end

local function exclution_generator()
    --Spring.Echo(tostring(include_com) .. " .. " .. tostring(include_rez))
    t = {}
    if include_com == false then
        table.insert(t, "armcom")
        table.insert(t, "corcom")
    end
    if include_rez == false then 
        table.insert(t, "armrectr")
        table.insert(t, "cornecro")
    end
    if include_comando == false then
        table.insert(t, "cormando")
    end
    exclude_names = t

    str = ""
    for _, v in pairs(t) do str = str .. tostring(v) end
    --Spring.Echo(str)
end

function widget:Initialize()
    -- check if file exists else use default spidy sounds.
    if VFS.FileExists("LuaUI/Widgets/pipo.ogg") == false then
        audio_queue = "Sounds/movement/arm-bot-at-sel.wav"
    end
    add_options()
    exclution_generator()
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
    if def.isMobileBuilder == false or has_value(exclude_names, def.name) then return end -- mobile builder + exlude units
    x, y, z = Spring.GetUnitPosition(uID)
    t, _ = Spring.GetGameFrame()
    unit = {["x"] = x, ["y"] = y, ["z"] = z, ["uID"] = uID, ["uDefID"] = uDefID, ["time"] = t}
    table.insert(idles_timingout, unit)
end

function widget:UnitDestroyed(uID, uDefID, uClan)
    if uClan == Spring.GetMyTeamID() then 
        if is_play ~= false then return end
        def = UnitDefs[uDefID]
        if def.isMobileBuilder == false or has_value(exclude_names, def.name) then return end
        idx = get_idx(idles_timingout, uID)
        if idx ~= nil then 
            table.remove(idles_timingout, idx)
            return
        end
        for i=#idles,1,-1 do
            idx = get_idx(idles[i], uID)
            if idx ~= nil then
                --Spring.Echo("Delted" .. tostring(uID))
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

function widget:KeyPress(key, mods, isRepeating)
    if key == 97 and mods.alt then -- a+alt
        if #idles < 1 then return end
        grp = idles[#idles]
        pu = grp[1]
        Spring.SetCameraTarget(pu["x"], pu["y"], pu["z"], 0.5)
        --Spring.MarkerErasePosition(pu["x"], pu["y"], pu["z"])
        sgrp = {}
        for i=#grp,1,-1 do table.insert(sgrp, grp[i]["uID"]) end
        Spring.SelectUnitArray(sgrp)
    end 
end

function widget:GameFrame(tick)
    if math.fmod(tick, interval_to_check) == 0 then 
        --checks if idle no longer are idle, removes element and marker
        for i=#idles,1,-1 do 
            for j=#idles[i], 1, -1 do
                if still_idle(idles[i][j]["uID"]) == false then
                    if use_ping then
                        Spring.MarkerErasePosition(idles[i][j]["x"], idles[i][j]["y"], idles[i][j]["z"])
                    end
                    table.remove(idles[i], j)
                else
                    idles_not_being_processed = idles_not_being_processed +1
                end
            end
            if #idles[i] < 1 then
                table.remove(idles, i)
            end
        end
        if #idles == 0 then
            idles_not_being_processed = 0
        end
        -- processing time outs
        t = {}
        for i = #idles_timingout,1,-1 do
            if still_idle(idles_timingout[i]["uID"]) == true then
                if tick - idles_timingout[i]["time"] >= time_out_minimal then
                    table.insert(t, idles_timingout[i])
                    table.remove(idles_timingout, i)
                end
            else
                table.remove(idles_timingout, i)
            end
        end
        while #t > 0 do
            grp = collect_nearby(t)
            pu = grp[1]
            str = "Idle "
            if #grp > 1 then
                str = str .. tostring(#grp) .. "x "
            end
            ping_unit(pu["x"], pu["y"], pu["z"], str.. UnitDefs[pu["uDefID"]].translatedHumanName .. "!")
            table.insert(idles, grp)
        end
    end
    -- play idler still idling sound
    if math.fmod(tick, interval_to_check*10) == 0 then
        if idles_not_being_processed >= 50 then -- DEV -- add this in as a settings variable
            Spring.PlaySoundFile(warning_audio, audio_volume, 'ui')
        end
    end
end

function widget:Shutdown() --removes options
    del_options()
end

function widget:GetConfigData() -- Retrevies settings on load.
    data = {}
    data.interval = interval_to_check
    data.timer = time_out_minimal
    data.radius = grouping_radius
    data.regresive = regresive_collect
    data.use_ping = use_ping
    data.com = include_com
    data.rez = include_rez
    data.comando = include_comando
    return data
end

function widget:SetConfigData(data) -- Stores settings to be recovered.
    if data.interval then interval_to_check = data.interval end
    if data.timer then time_out_minimal = data.timer end
    if data.radius then grouping_radius = data.radius end
    if data.regresive then regresive_collect = data.regresive end
    if data.use_ping then use_ping = data.use_ping end
    if data.com then include_com = data.com end
    if data.rez then include_rez = data.rez end
    if data.comando then include_comando = data.comando end
end