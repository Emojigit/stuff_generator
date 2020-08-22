-- minetest.add_item(pos, item)

local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function handle_give_command(cmd, giver, receiver, stackstring)
	core.log("action", giver .. " invoked " .. cmd
			.. ', stackstring="' .. stackstring .. '"')
	local itemstack = ItemStack(stackstring)
	if itemstack:is_empty() then
		return false, "Cannot give an empty item"
	elseif (not itemstack:is_known()) or (itemstack:get_name() == "unknown") then
		return false, "Cannot give an unknown item"
	-- Forbid giving 'ignore' due to unwanted side effects
	elseif itemstack:get_name() == "ignore" then
		return false, "Giving 'ignore' is not allowed"
	end
	local receiverref = core.get_player_by_name(receiver)
	if receiverref == nil then
		return false, receiver .. " is not a known player"
	end
	local leftover = receiverref:get_inventory():add_item("main", itemstack)
	local partiality
	if leftover:is_empty() then
		partiality = ""
	elseif leftover:get_count() == itemstack:get_count() then
		partiality = "could not be "
	else
		partiality = "partially "
	end
	-- The actual item stack string may be different from what the "giver"
	-- entered (e.g. big numbers are always interpreted as 2^16-1).
	stackstring = itemstack:to_string()
	if giver == receiver then
		local msg = "%q %sadded to inventory."
		return true, msg:format(stackstring, partiality)
	else
		core.chat_send_player(receiver, ("%q %sadded to inventory.")
				:format(stackstring, partiality))
		local msg = "%q %sadded to %s's inventory."
		return true, msg:format(stackstring, partiality, receiver)
	end
end

minetest.register_node("stuff_generator:generator",{
	description = "Stuff Generator",
	tiles = {"default_gold_block.png"},
	paramtype2 = "facedir",
	paramtype = "light",
	sunlight_propagates = true,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.3, -0.3, -0.3, 0.3, 0.3, 0.3},
		},
	},
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local node_pos = ""
		if pointed_thing.type == "node" then
			node_pos = minetest.get_pointed_thing_position(pointed_thing, pointed_thing.above)
		else
			return
		end
		if not(minetest.get_node(node_pos).name == "stuff_generator:generator") then
			return
		end
		local timer = minetest.get_node_timer(node_pos)
		local meta = minetest.get_meta(node_pos)
		local imeta = itemstack:get_meta()
		local need_item = imeta:get_string("need_item") or "air"
		meta:set_string("need_item", need_item)
		timer:start(1)
	end,
	on_timer = function(pos, elapsed)
		local fixedpos = shallowcopy(pos)
		-- local fixedpos.y = fixedpos.y - 1
		local meta = minetest.get_meta(pos)
		local need_item = meta:get_string("need_item") or "air"
		core.spawn_item(fixedpos, need_item)
		local timer = minetest.get_node_timer(pos)
		timer:start(1)
	end,
})

core.register_chatcommand("give_stuff_gen", {
	params = "<Name> <ItemString>",
	description = "Give stuff generator to player",
	privs = {give=true},
	func = function(name, param)
		local toname, itemstring = string.match(param, "^([^ ]+) +(.+)$")
		if not toname or not itemstring then
			return false, "Name and ItemString required"
		end
		if itemstring == "ignore" then
			return false, "You can't get ignore!"
		end
		local item = ItemStack()
		local meta = item:get_meta()
		meta:set_string("need_item", itemstring)
		return handle_give_command("/give_stuff_gen", name, toname, item)
	end,
})

core.register_chatcommand("giveme_stuff_gen", {
	params = "<ItemString>",
	description = "Give stuff generator to yourself",
	privs = {give=true},
	func = function(name, param)
		local itemstring = string.match(param, "(.+)$")
		if not itemstring then
			return false, "ItemString required"
		end
		if itemstring == "ignore" then
			return false, "You can't get ignore!"
		end
		local item = ItemStack("stuff_generator:generator")
		local meta = item:get_meta()
		meta:set_string("need_item", itemstring)
		return handle_give_command("/giveme_stuff_gen", name, name, item:to_string())
	end,
})


