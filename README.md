# Heatmap Overlay Plugin

A Flutter plugin for creating heatmap overlays on images using CustomPaint. This plugin provides a reusable widget that can overlay heatmap data points on any image with customizable colors, gradients, opacity, blur, and intensity.

## Features

- 🎨 Overlay heatmap data points on any image
- 🎯 Customizable heatmap point radius and colors
- 🌈 Predefined gradient options (red, blue, green, yellow, purple, rainbow)
- 📊 Adjustable opacity, blur, and intensity controls
- 📐 Normalized coordinates (0.0-1.0) for responsive design
- 🔥 Individual intensity values (0-100) for each heatmap point
- 📱 Works on all Flutter platforms (Android, iOS, Web, Desktop)
- ⚡ Lightweight and performant using Flutter's CustomPaint
- 🔧 Easy to integrate and customize

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  heatmap_overlay_plugin: ^0.0.1
```

Then run:
```bash
flutter pub get
```

## Usage

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Sample heatmap data points in normalized coordinates (0.0-1.0)
    final List<Offset> heatmapPoints = [
      const Offset(0.2, 0.2),   // Top-left area
      const Offset(0.5, 0.5),   // Center
      const Offset(0.8, 0.8),   // Bottom-right
    ];

    // Intensity values for each point (0-100)
    final List<double> intensities = [
      80.0,  // High intensity
      60.0,  // Medium intensity
      90.0,  // Very high intensity
    ];

    return HeatmapOverlay(
      imageProvider: const AssetImage('assets/my_image.jpg'),
      heatmapPoints: heatmapPoints,
      intensities: intensities,
      radius: 40.0,
      color: Colors.red,
    );
  }
}
```

### Advanced Usage with All Controls

```dart
HeatmapOverlay(
  imageProvider: const NetworkImage('https://example.com/image.jpg'),
  heatmapPoints: [
    const Offset(0.1, 0.1),  // Normalized coordinates (0.0-1.0)
    const Offset(0.5, 0.5),
    const Offset(0.9, 0.9),
  ],
  intensities: [75.0, 50.0, 90.0],  // Intensity values (0-100)
  radius: 60.0, // Larger radius for more prominent heatmap points
  opacity: 0.7, // Control transparency (0.0 to 1.0)
  blur: 2.0, // Add blur effect (0.0 to 10.0)
  gradient: HeatmapGradient.rainbow, // Use predefined gradient
)
```

### Available Gradients

```dart
enum HeatmapGradient {
  red,      // Red gradient
  blue,     // Blue gradient
  green,    // Green gradient
  yellow,   // Yellow to orange gradient
  purple,   // Purple gradient
  rainbow,  // Multi-color rainbow gradient
}
```

## API Reference

### HeatmapOverlay Widget

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `imageProvider` | `ImageProvider` | Yes | - | The image to overlay the heatmap on |
| `heatmapPoints` | `List<Offset>` | Yes | - | List of points in normalized coordinates (0.0-1.0) |
| `intensities` | `List<double>` | No | `[]` | Intensity values for each point (0-100) |
| `radius` | `double` | No | `40.0` | Radius of each heatmap point |
| `color` | `Color` | No | `Colors.red` | Base color of the heatmap points |
| `opacity` | `double` | No | `0.5` | Transparency level (0.0 to 1.0) |
| `blur` | `double` | No | `0.0` | Blur effect intensity (0.0 to 10.0) |
| `gradient` | `HeatmapGradient` | No | `HeatmapGradient.red` | Predefined gradient style |

### Coordinate System

- **Normalized Coordinates**: All heatmap points use normalized coordinates (0.0-1.0)
  - `Offset(0.0, 0.0)` = Top-left corner of the image
  - `Offset(0.5, 0.5)` = Center of the image
  - `Offset(1.0, 1.0)` = Bottom-right corner of the image
- **Intensity Values**: Each point can have an individual intensity (0-100)
  - `0` = No heatmap effect
  - `50` = Medium intensity
  - `100` = Maximum intensity

### Supported Image Providers

- `AssetImage` - For images in your assets folder
- `NetworkImage` - For images from the internet
- `FileImage` - For images from local files
- `MemoryImage` - For images from memory/bytes

## Example

See the `example/` directory for a complete working example that demonstrates:

- Loading images from different sources
- Adding heatmap points with normalized coordinates
- Managing individual intensity values
- Real-time control of opacity, blur, and radius
- Gradient selection with dropdown
- Interactive UI with 3:1 layout (view:controls)

To run the example:

```bash
cd example
flutter run
```

## How It Works

The plugin uses Flutter's `CustomPaint` widget to:

1. Draw the base image using `paintImage`
2. Convert normalized coordinates (0.0-1.0) to actual image coordinates
3. Overlay radial gradients at each heatmap point
4. Apply individual intensity values (0-100) to each point
5. Apply opacity, blur, and gradient effects
6. Create smooth transitions using predefined gradient patterns

The heatmap points are drawn as radial gradients that fade from the specified color to transparent, creating a realistic heatmap effect. The blur effect uses `MaskFilter.blur` for additional visual enhancement.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

