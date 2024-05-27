function widget:GetInfo()
    return {
        name = "Select nearest Constructor of type",
        desc = "Selects nearest constructor on map, near mouse. T1 alt+q or T2 alt+w or alt+e to sellect all con's on map.",
        author = "Nehroz",
        date = "2024.3.x",
        license = "GPL v3",
        layer = 0,
        enabled = true,
		handler = true,
        version = "1.0" --I may later add functioanlity to the option menu.
    }
end

local exlude_names = {"armcom", "corcom", "armrectr", "cornecro", "cormando", "corfast", "armfark", "armconsul"} -- units on this list are ignored by the script.
local arm_t1_names = {'armck', 'armcv', 'armch', 'armca', 'armcs', 'armcsa', 'armbeaver'} -- Armada T1 constuctor names
local cor_t1_names = {'corck', 'corcv', 'corch', 'corca', 'corcs', 'corcsa', 'cormuskrat'} -- Cortex T1 constructor names
local arm_t2_names = {'armack', 'armacv', 'armaca', 'armacsub'} -- Armada T2
local cor_t2_names = {'corack', 'coracv', 'coraca', 'coracsub'} -- Cortex T2
local t1_names = {} -- init populated lists
local t2_names = {}

function widget:Initialize()
    t1_names = union(arm_t1_names, cor_t1_names)
    t2_names = union(arm_t2_names, cor_t2_names)
    make_set(exlude_names)
    make_set(t1_names)
    make_set(t2_names)

	widgetHandler.actionHandler:AddAction(self, "select_nearest_t1_constructor", select_nearest_t1_constructor, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "select_nearest_t2_constructor", select_nearest_t2_constructor, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "select_all_constructors", select_all_constructors, nil, "p")
end

function vec_len(x,y,z) return math.sqrt(x*x+y*y+z*z) end -- simple vector math
function make_set(tab) for _, key in ipairs(tab) do tab[key] = true end end -- coverts a table to a Set()-like
function union(t1,t2) -- unifies two table into one.
    new = {}
    for i=1,#t1 do new[i] = t1[i] end
    offset = #new
    for i=1,#t2 do new[i+offset] = t2[i] end
    return new
end

--- Get all qualifying constructors
-- Returns a table of all qualifying constructors.
function get_all_cons()
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

function get_mouse_pos()
    x, y = Spring.GetMouseState()
    _, args = Spring.TraceScreenRay(x,y, true)
    if args == nil then return nil, nil, nil end
    return args[1], args[2], args[3]
end

---  Find nearest constructor
-- Takes table of all counstructors and a kind table that will act as filter.
-- Returns the nearest unit of kind, nil if none.
function find_nearest(t,kind)
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

function select_nearest_t1_constructor()
	con = find_nearest(get_all_cons(), t1_names)
	if con ~= nil then Spring.SelectUnit(con) end
end

function select_nearest_t2_constructor()
	con = find_nearest(get_all_cons(), t2_names)
	if con ~= nil then Spring.SelectUnit(con) end
end

function select_all_constructors()
	cons = get_all_cons()
	if cons ~= nil then Spring.SelectUnitArray(cons) end
end
