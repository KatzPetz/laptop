-----------------------------------------------------
-- Operating System class
-----------------------------------------------------
local os_class = {}
os_class.__index = os_class
laptop.class_lib.os = os_class

-- Swap the node
function os_class:swap_node(new_node_name)
	local node = minetest.get_node(self.pos)
	node.name = new_node_name
	minetest.swap_node(self.pos, node)
end

-- Power on the system and start the launcher
function os_class:power_on(new_node_name)
	if new_node_name then
		self:swap_node(new_node_name)
	end
	self:set_app() --launcher
end

-- Power on the system / and resume last running app
function os_class:resume(new_node_name)
	if new_node_name then
		self:swap_node(new_node_name)
	end
	self:set_app(self.appdata.os.current_app)
end

-- Power off the system
function os_class:power_off(new_node_name)
	if new_node_name then
		self:swap_node(new_node_name)
	end
	self.meta:set_string('formspec', "")
	self:save()
end

-- Set infotext for system
function os_class:set_infotext(infotext)
	self.meta:set_string('infotext', infotext)
end

-- Save the data
function os_class:save()
	self.appdata.os.custom_launcher = self.custom_launcher
	self.meta:set_string('laptop_appdata', minetest.serialize(self.appdata))
end

-- Get given or current theme
function os_class:get_theme(theme)
	local theme_sel = theme or self.appdata.os.theme
	local ret = table.copy(laptop.themes.default)
	if theme_sel and laptop.themes[theme_sel] then
		for k,v in pairs(laptop.themes[theme_sel]) do
			ret[k] = v
		end
		ret.name = theme_sel
	else
		ret.name = "default"
	end
	return ret
end

-- Set current theme
function os_class:set_theme(theme)
	if laptop.themes[theme] then
		self.appdata.os.theme = theme
		self.theme = self:get_theme()
		self:save()
	end
end

-- Add app to stack (before starting new)
function os_class:appstack_add(appname)
	table.insert(self.appdata.os.stack, appname)
end

-- Get last app from stack
function os_class:appstack_pop()
	local ret
	if #self.appdata.os.stack > 0 then
		ret = self.appdata.os.stack[#self.appdata.os.stack]
		table.remove(self.appdata.os.stack, #self.appdata.os.stack)
	end
	return ret
end

-- Free stack
function os_class:appstack_free()
	self.appdata.os.stack = {}
end

-- Get new app instance
function os_class:get_app(name)
	local template = laptop.apps[name]
	if not template then
		return
	end
	local app = setmetatable(table.copy(template), laptop.class_lib.app)
	app.name = name
	app.os = self
	return app
end

-- Activate the app
function os_class:set_app(appname)
	local launcher = self.custom_launcher or "launcher"
	local newapp = appname or launcher

	if newapp == launcher then
		self:appstack_free()
	elseif self.appdata.os.current_app and
			self.appdata.os.current_app ~= launcher and
			self.appdata.os.current_app ~= newapp then
		os_class:appstack_add(self.appdata.os.current_app)
	end

	self.appdata.os.current_app = newapp
	local app = self:get_app(newapp)
	self.meta:set_string('formspec', app:get_formspec())
	self:save()
end

-- Handle input processing
function os_class:receive_fields(fields, sender)
	local appname = self.appdata.os.current_app or self.custom_launcher or "launcher"
	local app = self:get_app(appname)
	app:receive_fields(fields, sender)
	self.appdata.os.last_player = sender:get_player_name()
	if self.appdata.os.current_app == appname then
		self.meta:set_string('formspec', app:get_formspec())
	end
	self:save()
end
-----------------------------------------------------
-- Get Operating system object
-----------------------------------------------------
function laptop.os_get(pos)
	local self = setmetatable({}, os_class)
	self.__index = os_class
	self.pos = pos
	self.meta = minetest.get_meta(pos)
	self.appdata = minetest.deserialize(self.meta:get_string('laptop_appdata')) or {}
	self.appdata.launcher = self.appdata.launcher or {}
	self.appdata.os = self.appdata.os or {}
	self.appdata.os.stack = self.appdata.os.stack or {}
	self.custom_launcher = self.appdata.os.custom_launcher
	self.theme = self:get_theme()
	return self
end
