# Godot 4 Simple 3D Smooth Destructible Terrain

A very basic demonstration of procedural terrain generator implemented in Godot. It uses simplex noise and heightmap with ArrayMesh to generate varied and natural-looking terrain in real time, and allows for digging and modifying the terrain. The world generation is done in around 100 lines of code.

![Preview](https://github.com/alpapaydin/Godot4-3D-Smooth-Destructible-Terrain/blob/master/preview.gif?raw=true)

## Features

- Procedural terrain generation using simplex noise
- Real-time terrain modification
- Efficient chunk-based system for managing terrain
- Cool terrain shader
- Cool diamond pickaxe

## How It Works

The terrain is divided into chunks of a fixed size. Each chunk's heightmap is generated using simplex noise. The noise parameters (frequency, octaves, lacunarity, and gain) can be adjusted to change the appearance of the terrain.

To manage memory and performance, only the chunks around the player are loaded. When the player moves, new chunks are generated and old chunks that are too far from the player are unloaded.

The terrain can be modified by "digging" into it. When a chunk is modified, it is regenerated to show the changes.

## Usage

To use this project:

1. Clone the repository.
2. Open the project in Godot.
3. Run the `main.tscn`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
