# Toy Cars Mod (`toy_cars`)

A Luanti (Minetest) mod that spawns autonomous, non-controllable NPC toy cars into the world.

## Features

- **Large Vehicle Scale**: Toy cars are scaled to 5.0 × 5.0 × 5.0 nodes (`visual_size = {x = 5.0, y = 5.0, z = 5.0}`, `collisionbox = {-2.5, 0.0, -2.5, 2.5, 3.5, 2.5}`).
- **Step Height**: `stepheight = 2.0` allows cars to step up obstacles up to 2 nodes high.
- **Randomized Models**: Automatically selects randomly from 8 provided 3D vehicle models (`vehicle-drag-racer.obj`, `vehicle-monster-truck.obj`, `vehicle-racer-low.obj`, `vehicle-racer.obj`, `vehicle-speedster.obj`, `vehicle-suv.obj`, `vehicle-truck.obj`, `vehicle-vintage-racer.obj`) using shared color textures (`colormap.png`).
- **Autonomous AI & Movement**:
  - Moves along cardinal horizontal axes.
  - **Traffic Avoidance**: Stops and waits when players or other toy cars are directly ahead.
  - **Terrain Obstacle Avoidance**: Inspects nodes ahead and turns 90 degrees left or right when encountering walls or obstacles (> 0.5 blocks high).
  - **Stuck Detection**: Detects when movement is blocked (< 0.2 speed for > 1.0 second) and turns to find an open path.
  - **Pit & Fall Protection**: Despawns toy cars if they fall into deep ravines or pits (> 35 nodes fall distance) to prevent lag and pileups.
- **Spawn Eggs**: Craft items available for each vehicle type (`toy_cars:spawn_egg_<type>`), using the corresponding vehicle PNG image as inventory icon. Right-click on a node to manually spawn that specific toy car model.
- **Dynamic Spawning & Visibility**:
  - Dynamically spawns toy cars in a ring around online players (10 to 45 blocks away) on solid walkable ground.
- **Automatic Despawning**:
  - Periodically checks distance to online players and despawns any toy car farther than 150 blocks from all players.
- **One-Punch Destroy**:
  - Toy cars have `armor_groups = {fleshy = 100}` so players can punch and destroy them directly without clutter.

## Settings

The mod supports the following `minetest.conf` setting:

- `toy_cars_max_cars` (default: `100`): Maximum number of active toy cars allowed in the world at any time.

Example `minetest.conf` entry:
```
toy_cars_max_cars = 50
```

## Chat Commands

Admin cleanup commands (requires `server` privilege):

- `/clear_cars` - Removes all active toy cars in the world and resets the active car counter.
- `/clear_all_cars` - Alias for `/clear_cars`.
- `/delete_cars` - Alias for `/clear_cars`.
- `/remove_cars` - Alias for `/clear_cars`.

## License

Code licensed under MIT.
