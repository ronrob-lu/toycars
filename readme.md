# Toy Cars Mod (`toy_cars`)

A Luanti (Minetest) mod that spawns autonomous, non-controllable NPC toy cars into the world.

## Features

- **Half-Block Miniature Scale**: Toy cars are scaled to approximately 0.5 × 0.5 × 0.5 nodes (`visual_size = {x = 0.5, y = 0.5, z = 0.5}`, `collisionbox = {-0.25, 0.0, -0.25, 0.25, 0.35, 0.25}`).
- **Low Step Height**: `stepheight = 0.2` prevents toy cars from driving over full 1-block steps or large obstacles, behaving like real miniature toy vehicles.
- **Randomized Models**: Automatically selects randomly from 8 provided 3D vehicle models (`vehicle-drag-racer.obj`, `vehicle-monster-truck.obj`, `vehicle-racer-low.obj`, `vehicle-racer.obj`, `vehicle-speedster.obj`, `vehicle-suv.obj`, `vehicle-truck.obj`, `vehicle-vintage-racer.obj`) using shared color textures (`colormap.png`).
- **Autonomous AI & Movement**:
  - Moves along cardinal horizontal axes.
  - **Traffic Avoidance**: Stops and waits when players or other toy cars are directly ahead.
  - **Terrain Obstacle Avoidance**: Inspects nodes ahead and turns 90 degrees left or right when encountering walls or obstacles (> 0.5 blocks high).
  - **Stuck Detection**: Detects when movement is blocked (< 0.2 speed for > 1.0 second) and turns to find an open path.
  - **Pit & Fall Protection**: Despawns toy cars if they fall into deep ravines or pits (> 3.5 nodes fall distance) to prevent lag and pileups.
- **Dynamic Spawning & Visibility**:
  - Dynamically spawns toy cars in a ring around online players (20 to 80 blocks away) on solid walkable ground.
  - Enforces out-of-line-of-sight spawning (`minetest.line_of_sight`) and minimum player distance (> 20 nodes) to avoid visible pop-in.
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
