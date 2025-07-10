
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

class ClusteredPoint {
  final double x;
  final double y;
  final double intensity;
  final int pointCount;
  const ClusteredPoint(this.x, this.y, this.intensity, this.pointCount);
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
  final double clusteringThreshold; // Distance threshold for clustering (0.0 to 1.0)
  final bool enableClustering; // Whether to enable point clustering

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
    this.clusteringThreshold = 0.02, // 2% of viewport size
    this.enableClustering = true,
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
    return '${points}_${intensities}_${widget.blurRadius}_${widget.blurSigma}_${widget.gradient.name}_${widget.opacity}_${widget.gamma}_${widget.minVisibility}_${widget.useLogNormalization}_${widget.clusteringThreshold}_${widget.enableClustering}$sizeHash';
  }

  /// Clusters nearby points into single islands based on distance threshold
  List<ClusteredPoint> _clusterPoints(List<HeatmapPoint> points, double threshold) {
    if (points.isEmpty) return [];
    
    // For small datasets, use simple clustering
    if (points.length <= 100) {
      return _simpleClusterPoints(points, threshold);
    }
    
    // For large datasets, use grid-based clustering for better performance
    return _gridClusterPoints(points, threshold);
  }
  
  /// Simple clustering algorithm for small datasets
  List<ClusteredPoint> _simpleClusterPoints(List<HeatmapPoint> points, double threshold) {
    final List<ClusteredPoint> clusters = [];
    final List<bool> visited = List.filled(points.length, false);
    
    for (int i = 0; i < points.length; i++) {
      if (visited[i]) continue;
      
      // Start a new cluster
      final List<int> clusterIndices = [i];
      visited[i] = true;
      
      // Find all points within threshold distance
      bool foundNewPoint;
      do {
        foundNewPoint = false;
        for (int j = 0; j < points.length; j++) {
          if (visited[j]) continue;
          
          // Check if point j is within threshold of any point in current cluster
          for (final clusterIndex in clusterIndices) {
            final distance = _calculateDistance(points[j], points[clusterIndex]);
            if (distance <= threshold) {
              clusterIndices.add(j);
              visited[j] = true;
              foundNewPoint = true;
              break;
            }
          }
        }
      } while (foundNewPoint);
      
      // Calculate cluster centroid and total intensity
      double totalX = 0.0;
      double totalY = 0.0;
      double totalIntensity = 0.0;
      
      for (final index in clusterIndices) {
        totalX += points[index].x;
        totalY += points[index].y;
        totalIntensity += points[index].intensity;
      }
      
      final centroidX = totalX / clusterIndices.length;
      final centroidY = totalY / clusterIndices.length;
      
      // Create clustered point with weighted intensity (can be adjusted based on cluster size)
      final clusteredIntensity = totalIntensity * (1.0 + 0.1 * (clusterIndices.length - 1));
      
      clusters.add(ClusteredPoint(
        centroidX,
        centroidY,
        clusteredIntensity,
        clusterIndices.length,
      ));
    }
    
    return clusters;
  }
  
  /// Grid-based clustering algorithm for large datasets (better performance)
  List<ClusteredPoint> _gridClusterPoints(List<HeatmapPoint> points, double threshold) {
    // Create a grid with cell size equal to threshold
    final int gridSize = (1.0 / threshold).ceil();
    final Map<String, List<int>> grid = {};
    
    // Assign points to grid cells
    for (int i = 0; i < points.length; i++) {
      final gridX = (points[i].x / threshold).floor();
      final gridY = (points[i].y / threshold).floor();
      final cellKey = '$gridX,$gridY';
      
      grid.putIfAbsent(cellKey, () => []).add(i);
    }
    
    final List<ClusteredPoint> clusters = [];
    final List<bool> visited = List.filled(points.length, false);
    
    // Process each grid cell
    for (final cellPoints in grid.values) {
      if (cellPoints.isEmpty) continue;
      
      // Find clusters within this cell and neighboring cells
      final Set<String> processedCells = {};
      
      for (final pointIndex in cellPoints) {
        if (visited[pointIndex]) continue;
        
        // Start a new cluster
        final List<int> clusterIndices = [pointIndex];
        visited[pointIndex] = true;
        
        // Find all points within threshold distance in this and neighboring cells
        final int gridX = (points[pointIndex].x / threshold).floor();
        final int gridY = (points[pointIndex].y / threshold).floor();
        
        // Check current cell and 8 neighboring cells
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            final neighborKey = '${gridX + dx},${gridY + dy}';
            if (processedCells.contains(neighborKey)) continue;
            processedCells.add(neighborKey);
            
            final neighborPoints = grid[neighborKey];
            if (neighborPoints == null) continue;
            
            for (final neighborIndex in neighborPoints) {
              if (visited[neighborIndex]) continue;
              
              // Check if point is within threshold of any point in current cluster
              for (final clusterIndex in clusterIndices) {
                final distance = _calculateDistance(points[neighborIndex], points[clusterIndex]);
                if (distance <= threshold) {
                  clusterIndices.add(neighborIndex);
                  visited[neighborIndex] = true;
                  break;
                }
              }
            }
          }
        }
        
        // Calculate cluster centroid and total intensity
        double totalX = 0.0;
        double totalY = 0.0;
        double totalIntensity = 0.0;
        
        for (final index in clusterIndices) {
          totalX += points[index].x;
          totalY += points[index].y;
          totalIntensity += points[index].intensity;
        }
        
        final centroidX = totalX / clusterIndices.length;
        final centroidY = totalY / clusterIndices.length;
        
        // Create clustered point with weighted intensity
        final clusteredIntensity = totalIntensity * (1.0 + 0.1 * (clusterIndices.length - 1));
        
        clusters.add(ClusteredPoint(
          centroidX,
          centroidY,
          clusteredIntensity,
          clusterIndices.length,
        ));
      }
    }
    
    return clusters;
  }
  
  /// Calculate Euclidean distance between two points (normalized coordinates)
  double _calculateDistance(HeatmapPoint p1, HeatmapPoint p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Get dynamic clustering threshold based on viewport scale
  double _getDynamicClusteringThreshold(Size? currentSize) {
    if (currentSize == null) return widget.clusteringThreshold;
    
    // Base threshold on viewport size - smaller viewports get more aggressive clustering
    final viewportArea = currentSize.width * currentSize.height;
    final baseArea = 800 * 600; // Reference viewport size
    
    // Adjust threshold based on viewport scale
    final scaleFactor = math.sqrt(baseArea / viewportArea).clamp(0.5, 2.0);
    final dynamicThreshold = widget.clusteringThreshold * scaleFactor;
    
    // Ensure minimum and maximum bounds
    return dynamicThreshold.clamp(0.001, 0.2);
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
    
    // Apply clustering if enabled with dynamic threshold adjustment
    final dynamicThreshold = _getDynamicClusteringThreshold(currentSize);
    final List<ClusteredPoint> clusteredPoints = widget.enableClustering 
        ? _clusterPoints(widget.points, dynamicThreshold)
        : widget.points.map((p) => ClusteredPoint(p.x, p.y, p.intensity, 1)).toList();
    
    print('Heatmap: Clustered points count: ${clusteredPoints.length}');
    if (widget.enableClustering) {
      print('Heatmap: Dynamic clustering threshold: ${dynamicThreshold.toStringAsFixed(4)} (base: ${widget.clusteringThreshold.toStringAsFixed(4)})');
    }
    
    // 1. Create density array at high resolution
    final densityArray = List.generate(
      gridHeight,
      (y) => List<double>.filled(gridWidth, 0.0),
    );
    
    // 2. For each clustered point, stamp a Gaussian kernel onto the density array (optimized)
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
    
    for (final point in clusteredPoints) {
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
        oldWidget.useLogNormalization != widget.useLogNormalization ||
        oldWidget.clusteringThreshold != widget.clusteringThreshold ||
        oldWidget.enableClustering != widget.enableClustering) {
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
