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

local function is_obstacle_ahead(pos, yaw, stepheight)
	stepheight = stepheight or 2.0
	local dir = get_dir_vector(yaw)
	-- Check wall position directly in front of the car above stepheight
	local lookahead_dist = 3.0
	local front_wall = {
		x = pos.x + dir.x * lookahead_dist,
		y = pos.y + stepheight + 0.5,
		z = pos.z + dir.z * lookahead_dist,
	}
	return is_walkable(front_wall)
end

local function choose_new_direction(pos, current_yaw, stepheight)
	local left_yaw = (current_yaw + math.pi / 2) % (2 * math.pi)
	local right_yaw = (current_yaw - math.pi / 2) % (2 * math.pi)

	local left_blocked = is_obstacle_ahead(pos, left_yaw, stepheight)
	local right_blocked = is_obstacle_ahead(pos, right_yaw, stepheight)

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
		self.object:set_yaw(self.move_yaw)
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

		-- Pit & Fall Protection (despawn if falling out of world)
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
			x = pos.x + dir.x * 4.0,
			y = pos.y + 1.0,
			z = pos.z + dir.z * 4.0,
		}

		local objects_ahead = minetest.get_objects_inside_radius(lookahead_pos, 3.0)
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
			self.object:set_velocity({x = 0, y = math.min(vel.y, 0), z = 0})
			self.stuck_timer = 0
			return
		end

		-- Terrain Obstacle & Wall Avoidance
		local stepheight = 2.0
		if is_obstacle_ahead(pos, self.move_yaw, stepheight) then
			self.move_yaw = choose_new_direction(pos, self.move_yaw, stepheight)
			self.object:set_yaw(self.move_yaw)
			dir = get_dir_vector(self.move_yaw)
			self.stuck_timer = 0
		end

		-- Apply movement speed (2.5 nodes/sec)
		local speed = 2.5
		local y_vel = math.min(vel.y, 0)
		self.object:set_velocity({x = dir.x * speed, y = y_vel, z = dir.z * speed})

		-- Stuck Detection Timer (> 1.0 second low velocity)
		local h_speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
		if h_speed < 0.2 then
			self.stuck_timer = (self.stuck_timer or 0) + dtime
			if self.stuck_timer > 1.0 then
				self.move_yaw = choose_new_direction(pos, self.move_yaw, stepheight)
				self.object:set_yaw(self.move_yaw)
				self.stuck_timer = 0
			end
		else
			self.stuck_timer = 0
		end
	end,
})

-- Register Toy Car Spawner Block
minetest.register_node("toy_cars:spawner", {
	description = "Toy Car Spawner",
	tiles = {"toy_cars_spawner.png"},
	groups = {cracky = 2, oddly_breakable_by_hand = 2},
	paramtype = "light",
	sunlight_propagates = true,

	on_construct = function(pos)
		local timer = minetest.get_node_timer(pos)
		timer:start(5.0)
	end,

	on_timer = function(pos, elapsed)
		local spawn_pos = {x = pos.x, y = pos.y + 1.0, z = pos.z}

		-- Check if node above spawner is free
		local node_above = minetest.get_node_or_nil(spawn_pos)
		if node_above then
			local def = minetest.registered_nodes[node_above.name]
			if def and def.walkable then
				return true -- space blocked, retry next tick
			end
		end

		-- Check existing toy cars in 15 node radius
		local nearby_objects = minetest.get_objects_inside_radius(pos, 15.0)
		local car_count = 0
		for _, obj in ipairs(nearby_objects) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "toy_cars:car" then
				car_count = car_count + 1
			end
		end

		if car_count < 2 then
			local chosen_model = MODELS[math.random(#MODELS)]
			local chosen_yaw = CARDINALS[math.random(#CARDINALS)]
			local staticdata = minetest.serialize({
				model = chosen_model,
				move_yaw = chosen_yaw,
			})
			minetest.add_entity(spawn_pos, "toy_cars:car", staticdata)
		end

		return true
	end,
})

-- Craft Recipe for Spawner Block (if default mod exists)
if minetest.get_modpath("default") then
	minetest.register_craft({
		output = "toy_cars:spawner",
		recipe = {
			{"default:steel_ingot", "default:glass", "default:steel_ingot"},
			{"default:steel_ingot", "toy_cars:spawn_egg_racer", "default:steel_ingot"},
			{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		}
	})
end

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
