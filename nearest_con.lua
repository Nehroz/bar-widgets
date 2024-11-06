---@diagnostic disable: duplicate-set-field
---@alias set {[string]: boolean} A set like table, with only true boolean; returns nil or true.
---@alias str_arr string[] A array of type string.

local HARDCODE_ENABLED = false -- enables hardcoded keys.

--- units on this list are ignored by the script.
local EXCLUDED_NAMES = {"armcom", "corcom", "legcom", "armrectr", "cornecro", "cormando", "corfast", "armfark", "armconsul", "corforge", "corvac"} --- @type str_arr
-- Armada T1 and T2 constructors
local ARM_T1_NAMES = {"armck", "armcv", "armch", "armca", "armcs", "armcsa", "armbeaver"} --- @type str_arr
local ARM_T2_NAMES = {"armack", "armacv", "armaca", "armacsub"} --- @type str_arr
-- Cortex T1 and T2 constructors
local COR_T1_NAMES = {"corck", "corcv", "corch", "corca", "corcs", "corcsa", "cormuskrat"} --- @type str_arr
local COR_T2_NAMES = {"corack", "coracv", "coraca", "coracsub"} --- @type str_arr
-- Legion T1  and T2 constructors, may change; So if a legion change happens update these lists.
local LEG_T1_NAMES = {"legck", "legcv", "corch", "legca", "corcs", "corcsa", "cormuskrat"} --- @type str_arr
local LEG_T2_NAMES = {"legack", "legaca", "legacv", "coracsub"} --- @type str_arr

function widget:GetInfo()
    return {
        name = "Select nearest Constructor of type",
        desc = "Selects nearest constructor on map, near mouse. T1 alt+q or T2 alt+w or alt+e to select all con's on map.",
        author = "Nehroz",
        date = "2024.3.x",
        license = "GPL v3",
        layer = 0,
        enabled = true,
        handler = true,
        version = "1.1β"
    }
end

-- init populated tables, later set-likes
local exc_names = {} ---@type set
local t1_names = {} ---@type set
local t2_names = {} ---@type set

--- Returns Vector length
--- @param x number
--- @param y number
--- @param z number
--- @return number
local function vec_len(x,y,z)
    return math.sqrt(x*x+y*y+z*z)
end

---Converts a array of strings to a set-like.
---@param arr str_arr
---@return set
local function make_set(arr)
    local new_set = {} ---@type set
    for _, key in ipairs(arr) do new_set[key] = true end
    return new_set
end

---Unifies two arrays into one.
---@param t1 any[]
---@param t2 any[]
---@return any[]
local function union(t1,t2)
    local new = {}
    for i=1,#t1 do new[i] = t1[i] end
    local offset = #new
    for i=1,#t2 do new[i+offset] = t2[i] end
    return new
end

--- Returns table of all constructors qualifing.
local function get_all_cons()
    local my_units = Spring.GetTeamUnits(Spring.GetMyTeamID()) ---@type integer[] | nil
    local cons = {} ---@type integer[]
    if my_units == nil then return end
    for _, uID in ipairs(my_units) do
        local def = UnitDefs[Spring.GetUnitDefID(uID)] ---@type table
        if def.isMobileBuilder == true then
            if exc_names[def.name] ~= true then
                table.insert(cons, uID)
    end end end
    return cons
end

--- Returns current mouse position as tuple
local function get_mouse_pos()
    local x, y = Spring.GetMouseState() ---@type number, number
    local _, args = Spring.TraceScreenRay(x,y, true) ---@type nil | string, integer | integer[]
    if args == nil then return nil, nil, nil end
    return args[1], args[2], args[3]
end

--- Takes array of all counstructor IDs and a set that will act as filter. Returns the nearest unit or nil.
---@param arr integer[]
---@param kind set
local function find_nearest(arr,kind)
    local m_x, m_y, m_z = get_mouse_pos()
    if m_x == nil then return end -- break if out of map
    local distance = math.huge
    local nearest_uID = nil
    for _, uID in pairs(arr) do
        if kind[UnitDefs[Spring.GetUnitDefID(uID)].name] == true then
            local x, y, z = Spring.GetUnitPosition(uID) ---@type number, number, number
            local l = vec_len(x-m_x,y-m_y, z-m_z)
            if l < distance then
                distance = l
                nearest_uID = uID
    end end end
    return nearest_uID
end

function widget:Initialize()
    local t1n = union(ARM_T1_NAMES, COR_T1_NAMES) ---@type str_arr
    local t2n = union(ARM_T2_NAMES, COR_T2_NAMES) ---@type str_arr
    t1n = union(t1n, LEG_T1_NAMES) ---@type str_arr
    t2n = union(t2n, LEG_T2_NAMES) ---@type str_arr

    exc_names = make_set(EXCLUDED_NAMES)
    t1_names = make_set(t1n)
    t2_names = make_set(t2n)

    if HARDCODE_ENABLED then return end
    widgetHandler.actionHandler:AddAction(self, "select_nearest_t1_constructor", Select_Nearest_T1_Constructor, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "select_nearest_t2_constructor", Select_Nearest_T2_Constructor, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "select_all_constructors", Select_All_Constructors, nil, "p")
end


function Select_Nearest_T1_Constructor()
    local cons = get_all_cons()
    if cons == nil then return end
    local con = find_nearest(cons, t1_names)
    if con ~= nil then Spring.SelectUnit(con) end
end

function Select_Nearest_T2_Constructor()
    local cons = get_all_cons()
    if cons == nil then return end
    local con = find_nearest(cons, t2_names)
    if con ~= nil then Spring.SelectUnit(con) end
end

function Select_All_Constructors()
    local cons = get_all_cons()
    if cons ~= nil then Spring.SelectUnitArray(cons) end
end

--- Old Hardcoded, integrated for old users
--- @deprecated
--- @param key any
--- @param mods any
--- @param isRepeating any
function widget:KeyPress(key, mods, isRepeating)
    if HARDCODE_ENABLED == false then return end
    if key == 101 and mods.alt then --e+alt
        Select_All_Constructors()
    elseif key ==  113 and mods.alt then --q+alt
        Select_Nearest_T1_Constructor()
    elseif key == 119 and mods.alt then --w+alt
        Select_Nearest_T2_Constructor()
    end
end