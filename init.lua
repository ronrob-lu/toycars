-- toy_cars mod for Luanti (Minetest)
-- Adds non-controllable miniature NPC toy cars to the world

local VEHICLES = {
	{ id = "drag_racer", name = "Drag Racer", model = "vehicle-drag-racer.obj", texture = "vehicle-drag-racer.png" },
	{ id = "monster_truck", name = "Monster Truck", model = "vehicle-monster-truck.obj", texture = "vehicle-monster-truck.png" },
	{ id = "racer_low", name = "Racer Low", model = "vehicle-racer-low.obj", texture = "vehicle-racer-low.png" },
	{ id = "racer", name = "Racer", model = "vehicle-racer.obj", texture = "vehicle-racer.png" },
	{ id = "speedster", name = "Speedster", model = "vehicle-speedster.obj", texture = "vehicle-speedster.png" },
	{ id = "suv", name = "SUV", model = "vehicle-suv.obj", texture = "vehicle-suv.png" },
	{ id = "truck", name = "Truck", model = "vehicle-truck.obj", texture = "vehicle-truck.png" },
	{ id = "vintage_racer", name = "Vintage Racer", model = "vehicle-vintage-racer.obj", texture = "vehicle-vintage-racer.png" },
}

local MODELS = {}
for _, v in ipairs(VEHICLES) do
	table.insert(MODELS, v.model)
end

local CARDINALS = {
	0,                  -- +Z
	math.pi / 2,        -- +X
	math.pi,            -- -Z
	3 * math.pi / 2,    -- -X
}

local active_cars = {}

local function count_active_cars()
	local count = 0
	for obj, _ in pairs(active_cars) do
		if obj and obj:get_pos() then
			count = count + 1
		else
			active_cars[obj] = nil
		end
	end
	return count
end

local function get_dir_vector(yaw)
	return {
		x = math.sin(yaw),
		y = 0,
		z = math.cos(yaw),
	}
end

local function is_walkable(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node or node.name == "ignore" then
		return true
	end
	local def = minetest.registered_nodes[node.name]
	return def and def.walkable or false
end

local function is_obstacle_ahead(pos, yaw)
	local dir = get_dir_vector(yaw)
	-- Check ground level step and head level block in front
	local front_step = {
		x = pos.x + dir.x * 6.0,
		y = pos.y + 3.0,
		z = pos.z + dir.z * 6.0,
	}
	local front_head = {
		x = pos.x + dir.x * 6.0,
		y = pos.y + 8.0,
		z = pos.z + dir.z * 6.0,
	}
	return is_walkable(front_step) or is_walkable(front_head)
end

local function choose_new_direction(pos, current_yaw)
	local left_yaw = (current_yaw + math.pi / 2) % (2 * math.pi)
	local right_yaw = (current_yaw - math.pi / 2) % (2 * math.pi)

	local left_blocked = is_obstacle_ahead(pos, left_yaw)
	local right_blocked = is_obstacle_ahead(pos, right_yaw)

	if not left_blocked and right_blocked then
		return left_yaw
	elseif not right_blocked and left_blocked then
		return right_yaw
	elseif not left_blocked and not right_blocked then
		return math.random() > 0.5 and left_yaw or right_yaw
	else
		-- Turn around if both sides are blocked
		return (current_yaw + math.pi) % (2 * math.pi)
	end
end

minetest.register_entity("toy_cars:car", {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-2.5, 0.0, -2.5, 2.5, 3.5, 2.5},
		visual = "mesh",
		mesh = MODELS[1],
		textures = {"colormap.png"},
		visual_size = {x = 5.0, y = 5.0, z = 5.0},
		stepheight = 2.0,
		hp_max = 1,
		armor_groups = {fleshy = 100},
	},

	on_activate = function(self, staticdata, dtime_s)
		active_cars[self.object] = true
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})

		local data = (staticdata and staticdata ~= "") and minetest.deserialize(staticdata) or nil
		if type(data) ~= "table" then data = {} end

		if data.model and type(data.model) == "string" then
			self.model = data.model
		else
			self.model = MODELS[math.random(#MODELS)]
		end

		if data.move_yaw and type(data.move_yaw) == "number" then
			self.move_yaw = data.move_yaw
		else
			self.move_yaw = CARDINALS[math.random(#CARDINALS)]
		end

		self.object:set_properties({
			mesh = self.model,
			textures = {"colormap.png"},
		})
		self.object:set_yaw(self.move_yaw + math.pi)
		self.stuck_timer = 0
		self.fall_start_y = nil
	end,

	get_staticdata = function(self)
		return minetest.serialize({
			model = self.model,
			move_yaw = self.move_yaw,
		})
	end,

	on_deactivate = function(self, removal)
		active_cars[self.object] = nil
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		active_cars[self.object] = nil
		self.object:remove()
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		local vel = self.object:get_velocity() or {x = 0, y = 0, z = 0}

		-- Pit & Fall Protection
		if vel.y < -1.5 then
			if not self.fall_start_y then
				self.fall_start_y = pos.y
			end
			local fall_dist = self.fall_start_y - pos.y
			if fall_dist > 35.0 then
				active_cars[self.object] = nil
				self.object:remove()
				return
			end
		else
			self.fall_start_y = nil
		end

		-- Ensure move_yaw is set
		if not self.move_yaw then
			self.move_yaw = CARDINALS[1]
		end

		local dir = get_dir_vector(self.move_yaw)

		-- Traffic & Entity Obstacle Avoidance
		local lookahead_pos = {
			x = pos.x + dir.x * 8.0,
			y = pos.y + 2.0,
			z = pos.z + dir.z * 8.0,
		}

		local objects_ahead = minetest.get_objects_inside_radius(lookahead_pos, 6.0)
		local traffic_stop = false

		for _, obj in ipairs(objects_ahead) do
			if obj ~= self.object then
				if obj:is_player() then
					traffic_stop = true
					break
				else
					local ent = obj:get_luaentity()
					if ent and ent.name == "toy_cars:car" then
						traffic_stop = true
						break
					end
				end
			end
		end

		if traffic_stop then
			-- Stop and wait patiently
			self.object:set_velocity({x = 0, y = vel.y, z = 0})
			self.stuck_timer = 0
			return
		end

		-- Terrain Obstacle & Wall Avoidance
		if is_obstacle_ahead(pos, self.move_yaw) then
			self.move_yaw = choose_new_direction(pos, self.move_yaw)
			self.object:set_yaw(self.move_yaw + math.pi)
			dir = get_dir_vector(self.move_yaw)
			self.stuck_timer = 0
		end

		-- Apply movement speed (2.5 nodes/sec)
		local speed = 2.5
		self.object:set_velocity({x = dir.x * speed, y = vel.y, z = dir.z * speed})

		-- Stuck Detection Timer (> 1.0 second low velocity)
		local h_speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
		if h_speed < 0.2 then
			self.stuck_timer = (self.stuck_timer or 0) + dtime
			if self.stuck_timer > 1.0 then
				self.move_yaw = choose_new_direction(pos, self.move_yaw)
				self.object:set_yaw(self.move_yaw + math.pi)
				self.stuck_timer = 0
			end
		else
			self.stuck_timer = 0
		end
	end,
})

-- Dynamic Spawning Loop (~every 3s)
local spawn_timer = 0
minetest.register_globalstep(function(dtime)
	spawn_timer = spawn_timer + dtime
	if spawn_timer < 3.0 then
		return
	end
	spawn_timer = 0

	local max_cars = tonumber(minetest.settings:get("toy_cars_max_cars")) or 100
	local current_cars = count_active_cars()
	if current_cars >= max_cars then
		return
	end

	local players = minetest.get_connected_players()
	if #players == 0 then
		return
	end

	local player = players[math.random(#players)]
	local ppos = player:get_pos()
	if not ppos then return end

	for _ = 1, 10 do
		local dist = math.random(10, 45)
		local angle = math.random() * 2 * math.pi
		local sx = ppos.x + dist * math.sin(angle)
		local sz = ppos.z + dist * math.cos(angle)

		local found_y = nil
		local start_y = math.floor(ppos.y) + 10
		local end_y = math.floor(ppos.y) - 15

		for y = start_y, end_y, -1 do
			local p_ground = {x = math.floor(sx) + 0.5, y = y, z = math.floor(sz) + 0.5}
			local p_above1 = {x = math.floor(sx) + 0.5, y = y + 1, z = math.floor(sz) + 0.5}
			local p_above2 = {x = math.floor(sx) + 0.5, y = y + 2, z = math.floor(sz) + 0.5}

			local node_ground = minetest.get_node_or_nil(p_ground)
			local node_above1 = minetest.get_node_or_nil(p_above1)
			local node_above2 = minetest.get_node_or_nil(p_above2)

			if node_ground and node_above1 and node_above2 then
				local def_ground = minetest.registered_nodes[node_ground.name]
				local def_above1 = minetest.registered_nodes[node_above1.name]
				local def_above2 = minetest.registered_nodes[node_above2.name]

				if def_ground and def_ground.walkable
				   and def_above1 and not def_above1.walkable and not def_above1.liquidtype
				   and def_above2 and not def_above2.walkable and not def_above2.liquidtype
				   and node_ground.name ~= "ignore" then
					found_y = y + 0.5
					break
				end
			end
		end

		if found_y then
			local spawn_pos = {x = math.floor(sx) + 0.5, y = found_y + 0.1, z = math.floor(sz) + 0.5}

			local dist_ok = true
			for _, p in ipairs(players) do
				local pos = p:get_pos()
				if pos and vector.distance(pos, spawn_pos) < 8 then
					dist_ok = false
					break
				end
			end

			if dist_ok then
				minetest.add_entity(spawn_pos, "toy_cars:car")
				break
			end
		end
	end
end)

-- Periodic Despawning Loop (~every 2s)
local despawn_timer = 0
minetest.register_globalstep(function(dtime)
	despawn_timer = despawn_timer + dtime
	if despawn_timer < 2.0 then
		return
	end
	despawn_timer = 0

	local players = minetest.get_connected_players()
	for obj, _ in pairs(active_cars) do
		if obj and obj:get_pos() then
			local pos = obj:get_pos()
			local near_player = false
			for _, player in ipairs(players) do
				local ppos = player:get_pos()
				if ppos and vector.distance(ppos, pos) <= 150 then
					near_player = true
					break
				end
			end
			if not near_player then
				obj:remove()
				active_cars[obj] = nil
			end
		else
			active_cars[obj] = nil
		end
	end
end)

-- Admin Cleanup Chatcommands
local clear_cmd_def = {
	description = "Remove all active toy cars from the world",
	privs = {server = true},
	func = function(name, param)
		local count = 0
		for obj, _ in pairs(active_cars) do
			if obj and obj:get_pos() then
				obj:remove()
				count = count + 1
			end
			active_cars[obj] = nil
		end
		if minetest.luaentities then
			for _, luaent in pairs(minetest.luaentities) do
				if luaent and luaent.name == "toy_cars:car" and luaent.object then
					luaent.object:remove()
					count = count + 1
				end
			end
		end
		return true, "Removed " .. count .. " active toy car(s)."
	end,
}

minetest.register_chatcommand("clear_cars", clear_cmd_def)
minetest.register_chatcommand("clear_all_cars", clear_cmd_def)
minetest.register_chatcommand("delete_cars", clear_cmd_def)
minetest.register_chatcommand("remove_cars", clear_cmd_def)

-- Register Spawn Eggs for each Vehicle
for _, v in ipairs(VEHICLES) do
	minetest.register_craftitem("toy_cars:spawn_egg_" .. v.id, {
		description = "Toy " .. v.name .. " Spawn Egg",
		inventory_image = v.texture,
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end

			local pos = pointed_thing.above
			local player_name = placer and placer:is_player() and placer:get_player_name() or ""
			if minetest.is_protected and minetest.is_protected(pos, player_name) then
				return itemstack
			end

			local spawn_pos = {x = pos.x, y = pos.y + 0.1, z = pos.z}
			local staticdata = minetest.serialize({
				model = v.model,
			})
			local obj = minetest.add_entity(spawn_pos, "toy_cars:car", staticdata)

			if obj then
				local creative = minetest.is_creative_enabled and player_name ~= "" and minetest.is_creative_enabled(player_name)
				if not creative then
					itemstack:take_item()
				end
			end
			return itemstack
		end,
	})
end
