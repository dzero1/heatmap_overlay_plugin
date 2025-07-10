import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heatmap Overlay Plugin Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HeatmapExamplePage(),
    );
  }
}

class HeatmapExamplePage extends StatefulWidget {
  const HeatmapExamplePage({super.key});

  @override
  State<HeatmapExamplePage> createState() => _HeatmapExamplePageState();
}

class _HeatmapExamplePageState extends State<HeatmapExamplePage> {
  // Sample heatmap data points in normalized coordinates (0.0-1.0) and intensity
  List<HeatmapPoint> heatmapPoints = [
    HeatmapPoint(0.2, 0.2, 80.0),   // Top-left area
    HeatmapPoint(0.4, 0.5, 60.0),   // Center-left
    HeatmapPoint(0.6, 0.7, 90.0),   // Bottom-center
    HeatmapPoint(0.8, 0.3, 40.0),   // Top-right
    HeatmapPoint(0.5, 0.8, 70.0),   // Bottom-center
    HeatmapPoint(0.3, 0.4, 50.0),   // Center area
  ];

  // Control values
  double opacity = 0.7;
  double blurRadius = 20.0;
  double blurSigma = 6.5;
  double overallBlur = 0.0;
  double blurSigmaY = 0.0;
  HeatmapGradient selectedGradient = HeatmapGradient.jet;
  
  // Dynamic range controls
  double gamma = 1.0;
  double minVisibility = 0.0;
  bool useLogNormalization = true;
  
  // Key to force heatmap regeneration
  int _heatmapKey = 0;

  // Number of random points
  int numberOfRandomPoints = 100;
  TextEditingController numberOfRandomPointsController = TextEditingController(text: '100');

  void loadSampleData() {
    setState(() {
      heatmapPoints.clear();
      heatmapPoints.addAll([
        HeatmapPoint(0.2000, 0.2000, 10.0),
        HeatmapPoint(0.4000, 0.1000, 20.0),
        HeatmapPoint(0.8000, 0.7000, 90.0),
        HeatmapPoint(0.801, 0.701, 100.0),
        HeatmapPoint(0.802, 0.702, 100.0),
        HeatmapPoint(0.803, 0.703, 100.0),
        HeatmapPoint(0.804, 0.704, 100.0),
        HeatmapPoint(0.805, 0.705, 100.0),
        HeatmapPoint(0.806, 0.706, 100.0),
        HeatmapPoint(0.807, 0.707, 100.0),
        HeatmapPoint(0.808, 0.708, 100.0),
        HeatmapPoint(0.809, 0.709, 100.0),
        HeatmapPoint(0.810, 0.710, 100.0),
        HeatmapPoint(0.811, 0.711, 100.0),
        HeatmapPoint(0.812, 0.712, 100.0),
        HeatmapPoint(0.813, 0.713, 100.0),
        HeatmapPoint(0.814, 0.714, 100.0),
        HeatmapPoint(0.815, 0.715, 100.0),
        HeatmapPoint(0.816, 0.716, 100.0),
        HeatmapPoint(0.817, 0.717, 100.0),
        HeatmapPoint(0.818, 0.718, 100.0),
        HeatmapPoint(0.819, 0.719, 100.0),
        HeatmapPoint(0.820, 0.720, 100.0),
        HeatmapPoint(0.821, 0.721, 100.0),
        HeatmapPoint(0.822, 0.722, 100.0),
        HeatmapPoint(0.823, 0.723, 100.0),
        HeatmapPoint(0.824, 0.724, 100.0),
        HeatmapPoint(0.825, 0.725, 100.0),
        HeatmapPoint(0.826, 0.726, 100.0),
        HeatmapPoint(0.827, 0.727, 100.0),
        HeatmapPoint(0.828, 0.728, 100.0),
        HeatmapPoint(0.829, 0.729, 100.0),
      ]);
      // Force heatmap regeneration
      _heatmapKey++;
    });
  }

  @override
  void initState() {
    super.initState();

    // after first build, simulate a click on the sample data button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSampleData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('Heatmap Overlay Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Heatmap View (3/4 of screen)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Stack(
                        children: [
                          // Background
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: BackgroundPainter(),
                          ),
                          // Heatmap Overlay
                          HeatmapOverlay(
                            key: ValueKey(_heatmapKey),
                            imageProvider: const AssetImage('assets/sample.jpg'),
                            points: heatmapPoints,
                            blurRadius: blurRadius,
                            blurSigma: blurSigma, // still pass for kernel blur
                            gradient: selectedGradient,
                            opacity: opacity,
                            overallBlur: overallBlur,
                            gamma: gamma,
                            minVisibility: minVisibility,
                            useLogNormalization: useLogNormalization,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Controls Panel (1/4 of screen)
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controls',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Opacity Control
                    const Text('Opacity', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: opacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: opacity.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          opacity = value;
                        });
                      },
                    ),
                    Text('Value: ${opacity.toStringAsFixed(2)}'),
                    const SizedBox(height: 16),

                    // Blur Radius Control
                    const Text('Blur Radius', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: blurRadius,
                      min: 1.0,
                      max: 40.0,
                      label: blurRadius.toStringAsFixed(0),
                      onChanged: (value) {
                        setState(() {
                          blurRadius = value;
                        });
                      },
                    ),
                    Text('Value: ${blurRadius.toStringAsFixed(0)}'),
                    const SizedBox(height: 16),

                    // Blur Sigma Control
                    const Text('Blur Sigma', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: blurSigma,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      label: blurSigma.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          blurSigma = value;
                        });
                      },
                    ),
                    Text('Value: ${blurSigma.toStringAsFixed(1)}'),
                    const SizedBox(height: 16),

                    // Visual Blur Control
                    const Text('Visual Blur', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: overallBlur,
                      min: 0.0,
                      max: 30.0,
                      divisions: 30,
                      label: overallBlur.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          overallBlur = value;
                        });
                      },
                    ),
                    Text('Value: ${overallBlur.toStringAsFixed(1)}'),
                    const SizedBox(height: 16),

                    // Dynamic Range Controls
                    const Text('Dynamic Range Controls', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                    const SizedBox(height: 8),
                    
                    // Gamma Control
                    const Text('Gamma (Low Value Enhancement)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: gamma,
                      min: 0.1,
                      max: 2.0,
                      divisions: 19,
                      label: gamma.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          gamma = value;
                        });
                      },
                    ),
                    Text('Value: ${gamma.toStringAsFixed(1)} (Lower = brighter low values)'),
                    const SizedBox(height: 16),

                    // Minimum Visibility Control
                    const Text('Minimum Visibility', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: minVisibility,
                      min: 0.0,
                      max: 0.5,
                      divisions: 10,
                      label: minVisibility.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          minVisibility = value;
                        });
                      },
                    ),
                    Text('Value: ${minVisibility.toStringAsFixed(2)}'),
                    const SizedBox(height: 16),

                    // Log Normalization Toggle
                    Row(
                      children: [
                        Checkbox(
                          value: useLogNormalization,
                          onChanged: (value) {
                            setState(() {
                              useLogNormalization = value ?? true;
                            });
                          },
                        ),
                        const Text('Use Log Normalization (Better for mixed intensities)'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gradient Selection
                    const Text('Gradient', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButton<HeatmapGradient>(
                      value: selectedGradient,
                      isExpanded: true,
                      onChanged: (HeatmapGradient? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedGradient = newValue;
                          });
                        }
                      },
                      items: HeatmapGradient.values.map<DropdownMenuItem<HeatmapGradient>>((HeatmapGradient gradient) {
                        return DropdownMenuItem<HeatmapGradient>(
                          value: gradient,
                          child: Text(gradient.name.toUpperCase()),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Heatmap Points Info
                    const Text(
                      'Heatmap Points',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('Points: ${heatmapPoints.length}'),
                    Text('Coordinates: Normalized (0.0-1.0)'),
                    Text('Intensities: 0-100 range'),
                    const SizedBox(height: 16),

                    // Clear Points Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          heatmapPoints.clear();
                          // Force heatmap regeneration
                          _heatmapKey++;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                      ),
                      child: const Text('Clear Points'),
                    ),
                    const SizedBox(height: 16),

                    // Add Point Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Add a new random normalized point
                          heatmapPoints.add(HeatmapPoint(
                              0.1 + (heatmapPoints.length * 0.15) % 0.8,
                              0.1 + (heatmapPoints.length * 0.2) % 0.8,
                              50.0 + (heatmapPoints.length * 10) % 50,
                            ));
                          // Force heatmap regeneration
                          _heatmapKey++;
                        });
                      },
                      child: const Text('Add Heatmap Point'),
                    ),
                    const SizedBox(height: 8),

                    // Sample Data Button
                    ElevatedButton(
                      onPressed: loadSampleData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[100],
                      ),
                      child: const Text('Load Sample Data'),
                    ),
                    const SizedBox(height: 8),

                    // Dense Cluster Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          heatmapPoints.clear();
                          // Create a dense cluster of overlapping points
                          for (int i = 0; i < 15; i++) {
                            heatmapPoints.add(HeatmapPoint(
                              0.4 + (i * 0.02) % 0.2, // Cluster around center
                              0.4 + (i * 0.03) % 0.2,
                              30.0 + (i * 5) % 70, // Varying intensities
                            ));
                          }
                          // Force heatmap regeneration
                          _heatmapKey++;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                      ),
                      child: const Text('Create Dense Cluster'),
                    ),
                    const SizedBox(height: 8),

                    // Random Points Button
                    Wrap(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              heatmapPoints.clear();
                              // Create random points like the Python example
                              for (int i = 0; i < numberOfRandomPoints; i++) {
                                heatmapPoints.add(HeatmapPoint(
                                  math.Random().nextDouble(),
                                  math.Random().nextDouble(),
                                  [5.0, 25.0, 50.0, 100.0][math.Random().nextInt(4)],
                                ));
                              }
                              // Force heatmap regeneration
                              _heatmapKey++;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[100],
                          ),
                          child: const Text('Generate Random Points'),
                        ),
                        const SizedBox(width: 15),
                        SizedBox(
                          width: 120,
                          child: 
                            TextField(
                            controller: numberOfRandomPointsController,
                            decoration: InputDecoration(
                              labelText: 'Number of Points',
                            ),
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onTapOutside: (event) => numberOfRandomPointsController.text = numberOfRandomPoints.toString(),
                            onEditingComplete: () => numberOfRandomPointsController.text = numberOfRandomPoints.toString(),
                            onChanged: (value) {
                              setState(() {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0) {
                                  numberOfRandomPoints = parsed.clamp(1, 9999);
                                }
                              });
                            },
                          ),
                        ),
                      ]
                    ),
                    const SizedBox(height: 8),

                    // Test Normalization Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          heatmapPoints.clear();
                          // Test points at specific normalized coordinates
                          heatmapPoints.addAll([
                            HeatmapPoint(0.1, 0.1, 100.0),   // Top-left corner
                            HeatmapPoint(0.9, 0.1, 100.0),   // Top-right corner
                            HeatmapPoint(0.1, 0.9, 100.0),   // Bottom-left corner
                            HeatmapPoint(0.9, 0.9, 100.0),   // Bottom-right corner
                            HeatmapPoint(0.5, 0.5, 10.0),   // Center
                            HeatmapPoint(0.75, 0.25, 25.0), // Quarter from top-left
                            HeatmapPoint(0.25, 0.25, 50.0), // Quarter from top-left
                            HeatmapPoint(0.75, 0.75, 75.0), // Three-quarters from top-left
                            HeatmapPoint(0.25, 0.75, 100.0), // Three-quarters from top-left
                          ]);
                          // Force heatmap regeneration
                          _heatmapKey++;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[100],
                      ),
                      child: const Text('Test Normalization'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Create a gradient background
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue[200]!,
          Colors.green[200]!,
          Colors.purple[200]!,
          Colors.orange[200]!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Add some decorative elements
    for (int i = 0; i < 20; i++) {
      final circlePaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(
          (i * 50) % size.width,
          (i * 30) % size.height,
        ),
        20 + (i % 3) * 10,
        circlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
