
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;

class HeatmapPoint {
  final double x;
  final double y;
  final double intensity;
  const HeatmapPoint(this.x, this.y, this.intensity);
}

class HeatmapOverlay extends StatefulWidget {
  final ImageProvider imageProvider;
  final List<HeatmapPoint> points; // List of HeatmapPoint (x, y, intensity)
  final double blurRadius;
  final double blurSigma;
  final HeatmapGradient gradient;
  final double opacity;
  final double overallBlur;
  final double gamma;
  final double minVisibility;
  final bool useLogNormalization;

  const HeatmapOverlay({
    Key? key,
    required this.imageProvider,
    required this.points,
    this.blurRadius = 50.0,
    this.blurSigma = 0.0,
    this.gradient = HeatmapGradient.jet,
    this.opacity = 0.7,
    this.overallBlur = 10.0,
    this.gamma = 0.5,
    this.minVisibility = 0.1,
    this.useLogNormalization = true,
  }) : super(key: key);

  @override
  State<HeatmapOverlay> createState() => _HeatmapOverlayState();
}

class _HeatmapOverlayState extends State<HeatmapOverlay> {
  ui.Image? _image;
  ui.Image? _heatmapImage;
  Timer? _debounceTimer;
  String? _lastHash;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final completer = Completer<ui.Image>();
    final stream = widget.imageProvider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    final image = await completer.future;
    setState(() {
      _image = image;
    });
    _generateHeatmap();
  }

  void _generateHeatmap([Size? currentSize]) {
    if (_image == null || widget.points.isEmpty) return;
    
    // Create a hash of current parameters to check if we need to regenerate
    final currentHash = _createParameterHash(currentSize);
    if (currentHash == _lastHash && _heatmapImage != null && currentSize == null) return;
    
    // Debounce rapid changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _generateHeatmapImage(currentSize).then((heatmapImage) {
        if (mounted) {
          setState(() {
            _heatmapImage = heatmapImage;
            _lastHash = currentHash;
          });
        }
      });
    });
  }

  String _createParameterHash([Size? currentSize]) {
    final points = widget.points.map((p) => '${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)}').join('|');
    final intensities = widget.points.map((p) => p.intensity.toString()).join(',');
    final sizeHash = currentSize != null ? '_${currentSize.width.toInt()}x${currentSize.height.toInt()}' : '';
    return '${points}_${intensities}_${widget.blurRadius}_${widget.blurSigma}_${widget.gradient.name}_${widget.opacity}_${widget.gamma}_${widget.minVisibility}_${widget.useLogNormalization}$sizeHash';
  }

  Future<ui.Image> _generateHeatmapImage([Size? currentSize]) async {
    final width = currentSize?.width.toInt() ?? _image!.width;
    final height = currentSize?.height.toInt() ?? _image!.height;
    
    // Use high grid resolution for smoothness
    const double resolution = 4; // Finer grid for smooth blobs
    final int gridWidth = (width / resolution).round();
    final int gridHeight = (height / resolution).round();
    
    // Debug: Print grid dimensions
    print('Heatmap: Image size:  [32m${width}x${height} [0m, Grid size:  [32m${gridWidth}x$gridHeight [0m');
    print('Heatmap: Resolution: $resolution, Cell size: ~${(width/gridWidth).round()}x${(height/gridHeight).round()} pixels');
    print('Heatmap: Points count: ${widget.points.length}');
    
    // 1. Create density array at high resolution
    final densityArray = List.generate(
      gridHeight,
      (y) => List<double>.filled(gridWidth, 0.0),
    );
    
    // 2. For each point, stamp a Gaussian kernel onto the density array (optimized)
    final kernelSigma = widget.blurSigma > 0 ? widget.blurSigma : 8.0;
    final kernelRadius = widget.blurRadius > 0 ? widget.blurRadius : 20.0;
    final int maxKernelSize = 101;
    final kernelSize = math.min((kernelRadius * 2 + 1).round(), maxKernelSize);
    final kernel = _createGaussianKernel(kernelSize, kernelSigma);
    final halfKernel = kernelSize ~/ 2;
    // Precompute mask for negligible kernel values
    final double kernelThreshold = 0.00001;
    final List<List<bool>> kernelMask = List.generate(
      kernelSize,
      (y) => List.generate(kernelSize, (x) => kernel[y][x] >= kernelThreshold),
    );
    
    for (final point in widget.points) {
      final normalizedX = point.x.clamp(0.0, 1.0);
      final normalizedY = point.y.clamp(0.0, 1.0);
      final gridX = (normalizedX * (gridWidth - 1)).round();
      final gridY = (normalizedY * (gridHeight - 1)).round();
      // Early bounds check: skip if kernel is fully outside grid
      if (gridX + halfKernel < 0 || gridX - halfKernel >= gridWidth ||
          gridY + halfKernel < 0 || gridY - halfKernel >= gridHeight) {
        continue;
      }
      for (int ky = 0; ky < kernelSize; ky++) {
        for (int kx = 0; kx < kernelSize; kx++) {
          if (!kernelMask[ky][kx]) continue; // skip negligible values
          final sy = gridY + ky - halfKernel;
          final sx = gridX + kx - halfKernel;
          if (sy >= 0 && sy < gridHeight && sx >= 0 && sx < gridWidth) {
            densityArray[sy][sx] += kernel[ky][kx] * point.intensity;
          }
        }
      }
    }
    
    // 3. Normalize array
    final maxValue = _findMaxValue(densityArray);
    final normalizedArray = _normalizeArray(densityArray, maxValue);
    
    // Debug: Print normalization info
    print('Heatmap: Max value:  [32m${maxValue.toStringAsFixed(2)} [0m, Normalized max:  [32m${_findMaxValue(normalizedArray).toStringAsFixed(3)} [0m');
    
    // Ensure we always generate an image, even if max value is 0
    if (maxValue <= 0.0 && widget.points.isNotEmpty) {
      print('Heatmap: Warning - Max value is 0 but points exist. This might indicate an issue with coordinate conversion.');
    }
    
    // 4. Convert to image with colormap - use full image size for output
    return _arrayToImage(normalizedArray, gridWidth, gridHeight, width, height);
  }

  List<List<double>> _createGaussianKernel(int size, double sigma) {
    final kernel = List.generate(
      size,
      (y) => List<double>.filled(size, 0.0),
    );
    
    final center = size ~/ 2;
    double sum = 0.0;
    
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = math.sqrt(dx * dx + dy * dy);
        final value = math.exp(-(distance * distance) / (2 * sigma * sigma));
        kernel[y][x] = value;
        sum += value;
      }
    }
    
    // Normalize kernel
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        kernel[y][x] /= sum;
      }
    }
    
    return kernel;
  }

  double _findMaxValue(List<List<double>> array) {
    double maxValue = 0.0;
    for (final row in array) {
      for (final value in row) {
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue;
  }

  List<List<double>> _normalizeArray(List<List<double>> array, double maxValue) {
    if (maxValue <= 0.0) return array;
    
    // Find minimum non-zero value for better dynamic range
    double minNonZeroValue = maxValue;
    for (final row in array) {
      for (final value in row) {
        if (value > 0.0 && value < minNonZeroValue) {
          minNonZeroValue = value;
        }
      }
    }
    
    return array.map((row) {
      return row.map((value) {
        if (value <= 0.0) return 0.0;
        
        double normalized;
        
        if (widget.useLogNormalization) {
          // Use logarithmic normalization for better dynamic range
          final logMax = math.log(maxValue + 1.0);
          final logMin = math.log(minNonZeroValue + 1.0);
          final logRange = logMax - logMin;
          
          final logValue = math.log(value + 1.0);
          normalized = (logValue - logMin) / logRange;
        } else {
          // Linear normalization
          normalized = value / maxValue;
        }
        
        // Apply gamma correction to enhance low values (gamma < 1 makes low values brighter)
        final gammaCorrected = math.pow(normalized, widget.gamma).toDouble();
        
        // Ensure minimum visibility for any non-zero value
        return math.max(gammaCorrected, widget.minVisibility);
      }).toList();
    }).toList();
  }

  Future<ui.Image> _arrayToImage(List<List<double>> array, int gridWidth, int gridHeight, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Calculate cell dimensions to fill the entire target image
    final cellWidth = targetWidth / gridWidth;
    final cellHeight = targetHeight / gridHeight;
    
    // Find the maximum density to ensure we draw something
    final maxDensity = _findMaxValue(array);
    final minVisibleDensity = maxDensity > 0 ? maxDensity * 0.01 : 0.001; // Show even very low values
    
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final density = array[y][x];
        if (density > minVisibleDensity) {
          final color = _getColorFromDensity(density);
          final paint = Paint()..color = color;
          
          // Draw cell at the correct position to fill the entire image
          canvas.drawRect(
            Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth,
              cellHeight,
            ),
            paint,
          );
        }
      }
    }
    
    final picture = recorder.endRecording();
    return await picture.toImage(targetWidth, targetHeight);
  }

  Color _getColorFromDensity(double density) {
    switch (widget.gradient) {
      case HeatmapGradient.jet:
        return _jetColormap(density);
      case HeatmapGradient.hot:
        return _hotColormap(density);
      case HeatmapGradient.cool:
        return _coolColormap(density);
      case HeatmapGradient.viridis:
        return _viridisColormap(density);
    }
  }

  Color _jetColormap(double t) {
    // Jet colormap: blue -> cyan -> green -> yellow -> red
    if (t < 0.25) {
      final s = t / 0.25;
      return Color.fromARGB(
        (255 * widget.opacity).round(), // Apply opacity to alpha
        0,
        0,
        (255 * (0.5 + 0.5 * s)).round(),
      );
    } else if (t < 0.5) {
      final s = (t - 0.25) / 0.25;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        0,
        (255 * s).round(),
        255,
      );
    } else if (t < 0.75) {
      final s = (t - 0.5) / 0.25;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        (255 * s).round(),
        255,
        (255 * (1 - s)).round(),
      );
    } else {
      final s = (t - 0.75) / 0.25;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        180,
        (255 * (1 - s)).round(),
        0,
      );

      // Color.fromARGB(255, 180, 0, 0);
    }
  }

  Color _hotColormap(double t) {
    // Hot colormap: black -> red -> yellow -> white
    if (t < 0.33) {
      final s = t / 0.33;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        (255 * s).round(),
        0,
        0,
      );
    } else if (t < 0.66) {
      final s = (t - 0.33) / 0.33;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        255,
        (255 * s).round(),
        0,
      );
    } else {
      final s = (t - 0.66) / 0.34;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        255,
        255,
        (255 * s).round(),
      );
    }
  }

  Color _coolColormap(double t) {
    // Cool colormap: cyan -> magenta
    return Color.fromARGB(
      (255 * widget.opacity).round(),
      (255 * t).round(),
      (255 * (1 - t)).round(),
      255,
    );
  }

  Color _viridisColormap(double t) {
    // Simplified viridis colormap
    if (t < 0.5) {
      final s = t / 0.5;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        0,
        (100 + 155 * s).round(),
        (200 + 55 * s).round(),
      );
    } else {
      final s = (t - 0.5) / 0.5;
      return Color.fromARGB(
        (255 * widget.opacity).round(),
        (200 * s).round(),
        (255 - 100 * s).round(),
        (255 - 200 * s).round(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Regenerate heatmap if size changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _image != null) {
            _generateHeatmap(currentSize);
          }
        });
        
        return SizedBox(
          width: currentSize.width,
          height: currentSize.height,
          child: Stack(
            children: [
              // Background image (no blur, no opacity)
              Positioned.fill(
                child: Image(
                  image: widget.imageProvider,
                  fit: BoxFit.fill,
                  width: currentSize.width,
                  height: currentSize.height,
                ),
              ),
              // Heatmap overlay (with blur/opacity)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: widget.overallBlur,
                    sigmaY: widget.overallBlur,
                  ),
                  child: CustomPaint(
                    painter: HeatmapPainter(
                      _heatmapImage,
                      widget.opacity,
                    ),
                    size: currentSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(HeatmapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.blurRadius != widget.blurRadius ||
        oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.gradient != widget.gradient ||
        oldWidget.opacity != widget.opacity ||
        oldWidget.overallBlur != widget.overallBlur ||
        oldWidget.gamma != widget.gamma ||
        oldWidget.minVisibility != widget.minVisibility ||
        oldWidget.useLogNormalization != widget.useLogNormalization) {
      _generateHeatmap();
    }
  }
}

class HeatmapPainter extends CustomPainter {
  final ui.Image? heatmapImage;
  final double opacity;

  HeatmapPainter(this.heatmapImage, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw heatmap overlay - opacity is already applied in the colors
    if (heatmapImage != null && opacity > 0.0) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: heatmapImage!,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum HeatmapGradient {
  jet,     // Blue -> Cyan -> Green -> Yellow -> Red
  hot,     // Black -> Red -> Yellow -> White
  cool,    // Cyan -> Magenta
  viridis, // Purple -> Blue -> Green -> Yellow
}
