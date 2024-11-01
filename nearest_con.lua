-- Customize these if you want to change things. (You can hover over a unit and hold "I" key to see it's internal name):
-- units on this list are ignored by the script.
local exlude_names = {"armcom", "corcom", "legcom", "armrectr", "cornecro", "cormando", "corfast", "armfark", "armconsul", "corforge", "corvac"}
-- Armada T1 and T2 constructors
local arm_t1_names = {"armck", "armcv", "armch", "armca", "armcs", "armcsa", "armbeaver"}
local arm_t2_names = {"armack", "armacv", "armaca", "armacsub"}
-- Cortex T1 and T2 constructors
local cor_t1_names = {"corck", "corcv", "corch", "corca", "corcs", "corcsa", "cormuskrat"}
local cor_t2_names = {"corack", "coracv", "coraca", "coracsub"}
-- Legion T1  and T2 constructors, may change; So if a legion change happens update these lists.
local leg_t1_names = {"legck", "legcv", "corch", "legca", "corcs", "corcsa", "cormuskrat"} 
local leg_t2_names = {"legack", "legaca", "legacv", "coracsub"}

function widget:GetInfo()
    return {
        name = "Select nearest Constructor of type",
        desc = "Selects nearest constructor on map, near mouse. T1 alt+q or T2 alt+w or alt+e to sellect all con's on map.",
        author = "Nehroz",
        date = "2024.3.x",
        license = "GPL v3",
        layer = 0,
        enabled = true,
        version = "1.1"
    }
end

-- init populated tables, later set-likes
local t1_names = {}
local t2_names = {}

local function vec_len(x,y,z) -- simple vector math
    return math.sqrt(x*x+y*y+z*z)
end

local function make_set(tab) -- coverts a table to a Set()-like
    for _, key in ipairs(tab) do tab[key] = true end
end

local function union(t1,t2) -- unifies two table into one.
    new = {}
    for i=1,#t1 do new[i] = t1[i] end
    offset = #new
    for i=1,#t2 do new[i+offset] = t2[i] end
    return new
end

local function get_all_cons() -- Returns table of all constructors qualifing.
    us = Spring.GetTeamUnits(Spring.GetMyTeamID())
    local cons = {}
    if us == nil then return end
    for _, uID in ipairs(us) do
        def = UnitDefs[Spring.GetUnitDefID(uID)]
        if def.isMobileBuilder == true then
            if exlude_names[def.name] ~= true then
                table.insert(cons, uID)
    end end end
    return cons
end

local function get_mouse_pos()
    x, y = Spring.GetMouseState()
    _, args = Spring.TraceScreenRay(x,y, true)
    if args == nil then return nil, nil, nil end
    return args[1], args[2], args[3]
end

local function find_nearest(t,kind) -- Takes table of all counstructors and a kind table that will act as filter. Returns the nearest unit of kind, nil if none.
    m_x, m_y, m_z = get_mouse_pos()
    if m_x == nil then return end -- break if out of map
    distance = math.huge
    nearest_uID = nil
    for _, uID in pairs(t) do
        if kind[UnitDefs[Spring.GetUnitDefID(uID)].name] == true then
            x, y, z = Spring.GetUnitPosition(uID)
            l = vec_len(x-m_x,y-m_y, z-m_z)
            if l < distance then
                distance = l
                nearest_uID = uID
    end end end
    return nearest_uID
end

function widget:Initialize()
    t1_names = union(arm_t1_names, cor_t1_names)
    t2_names = union(arm_t2_names, cor_t2_names)
    t1_names = union(t1_names, leg_t1_names)
    t2_names = union(t2_names, leg_t2_names)
    make_set(exlude_names)
    make_set(t1_names)
    make_set(t2_names)
end

function widget:KeyPress(key, mods, isRepeating)
    if key == 101 and mods.alt then --e+alt
        cons = get_all_cons()
        if cons ~= nil then Spring.SelectUnitArray(cons) end
    elseif key ==  113 and mods.alt then --q+alt
        con = find_nearest(get_all_cons(), t1_names)
        if con ~= nil then Spring.SelectUnit(con) end
    elseif key == 119 and mods.alt then --w+alt
        con = find_nearest(get_all_cons(), t2_names)
        if con ~= nil then Spring.SelectUnit(con) end
    end
end
