# Toy Cars Mod (`toy_cars`)

A Luanti (Minetest) mod that spawns autonomous, non-controllable NPC toy cars into the world.

## Features

- **Large Vehicle Scale**: Toy cars are scaled to 5.0 × 5.0 × 5.0 nodes (`visual_size = {x = 5.0, y = 5.0, z = 5.0}`, `collisionbox = {-2.5, 0.0, -2.5, 2.5, 3.5, 2.5}`).
- **Step Height & Terrain Navigation**: `stepheight = 2.0` allows cars to step up terrain obstacles up to 2 nodes high smoothly without flying or getting stuck.
- **Randomized Models**: Automatically selects randomly from 8 provided 3D vehicle models (`vehicle-drag-racer.obj`, `vehicle-monster-truck.obj`, `vehicle-racer-low.obj`, `vehicle-racer.obj`, `vehicle-speedster.obj`, `vehicle-suv.obj`, `vehicle-truck.obj`, `vehicle-vintage-racer.obj`) using shared color textures (`colormap.png`).
- **Autonomous AI & Forward Movement**:
  - Moves forward along cardinal horizontal axes in the direction the model is facing.
  - **Traffic Avoidance**: Stops and waits when players or other toy cars are directly ahead.
  - **Terrain Obstacle Avoidance**: Inspects nodes ahead above `stepheight` and turns left or right when encountering high walls or obstacles.
  - **Stuck Detection**: Detects when movement is blocked (< 0.2 speed for > 1.0 second) and turns to find an open path.
  - **Pit & Fall Protection**: Despawns toy cars if they fall off the world or into deep ravines (> 35 nodes fall distance).
- **Toy Car Spawner Block**:
  - Place `toy_cars:spawner` ("Toy Car Spawner") anywhere in the world.
  - Automatically spawns toy cars above the spawner block every 5 seconds (up to 2 active toy cars per spawner within a 15-node radius).
- **Spawn Eggs**: Craft items available for each vehicle type (`toy_cars:spawn_egg_<type>`), using the corresponding vehicle PNG image as inventory icon. Right-click on a node to manually spawn that specific toy car model.
- **One-Punch Destroy**:
  - Toy cars have `armor_groups = {fleshy = 100}` so players can punch and destroy them directly.

## Chat Commands

Admin cleanup commands (requires `server` privilege):

- `/clear_cars` - Removes all active toy cars in the world and resets the active car counter.
- `/clear_all_cars` - Alias for `/clear_cars`.
- `/delete_cars` - Alias for `/clear_cars`.
- `/remove_cars` - Alias for `/clear_cars`.

## License

Code licensed under MIT.
