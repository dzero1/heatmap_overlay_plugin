import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heatmap_overlay_plugin/utils.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;

class HeatmapConstants {
  static const double defaultKernelSigma = 8.0;
  static const double defaultKernelRadius = 20.0;
  static const int maxKernelSize = 101;
  static const double kernelThreshold = 0.00001;
  static const double minVisibleDensityRatio = 0.01;
  static const double minVisibleDensityFallback = 0.001;
  static const int colorLutSize = 256;
  static const Duration debounceDelay = Duration(milliseconds: 100);
  static const double sizeChangeThreshold = 1.0;

  // Colormap constants
  static const double jetQuarter = 0.25;
  static const double jetHalf = 0.5;
  static const double jetThreeQuarters = 0.75;
  static const double hotThird = 0.33;
  static const double hotTwoThirds = 0.66;
  static const double viridisHalf = 0.5;

  // Pre-calculated multipliers
  static const double jetScale = 4.0;
  static const double hotScale1 = 3.030303; // 1/0.33
  static const double hotScale2 = 2.941176; // 1/0.34
  static const double viridisScale = 2.0;
}

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
  final double
      resolution; // Grid resolution for heatmap quality (lower = higher quality)

  const HeatmapOverlay({
    super.key,
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
    this.resolution = 4.0, // Default resolution (lower = higher quality)
  });

  @override
  State<HeatmapOverlay> createState() => _HeatmapOverlayState();
}

class _HeatmapOverlayState extends State<HeatmapOverlay> {
  ui.Image? _image;
  ui.Image? _heatmapImage;
  Timer? _debounceTimer;
  String? _lastHash;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _image?.dispose();
    _heatmapImage?.dispose();
    super.dispose();
  }

  // Add this method to safely replace heatmap images
  void _replaceHeatmapImage(ui.Image newImage) {
    _heatmapImage?.dispose();
    _heatmapImage = newImage;
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
      _image?.dispose();
      _image = image;
    });
    _generateHeatmap();
  }

  void _generateHeatmap([Size? currentSize]) {
    if (_image == null || widget.points.isEmpty) return;

    // Check if size has changed significantly
    if (currentSize != null && _lastSize != null) {
      final sizeDiff = (currentSize.width - _lastSize!.width).abs() +
          (currentSize.height - _lastSize!.height).abs();
      if (sizeDiff < HeatmapConstants.sizeChangeThreshold)
        return; // Size hasn't changed significantly
    }

    // Create a hash of current parameters to check if we need to regenerate
    final currentHash = _createParameterHash(currentSize);
    if (currentHash == _lastHash &&
        _heatmapImage != null &&
        currentSize == null) return;

    // Debounce rapid changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(HeatmapConstants.debounceDelay, () {
      _generateHeatmapImage(currentSize).then((heatmapImage) {
        if (mounted) {
          setState(() {
            _replaceHeatmapImage(heatmapImage);
            _lastHash = currentHash;
            _lastSize = currentSize;
          });
        }
      });
    });
  }

  String _createParameterHash([Size? currentSize]) {
    final pointsHash = _createPointsHash(widget.points);
    final intensitiesHash = _createIntensitiesHash(widget.points);
    final sizeHash = _createSizeHash(currentSize);
    final parametersHash = _createParametersHash();

    return '${pointsHash}_${intensitiesHash}_${parametersHash}$sizeHash';
  }

  String _createPointsHash(List<HeatmapPoint> points) {
    return points
        .map((point) =>
            '${point.x.toStringAsFixed(3)},${point.y.toStringAsFixed(3)}')
        .join('|');
  }

  String _createIntensitiesHash(List<HeatmapPoint> points) {
    return points.map((point) => point.intensity.toString()).join(',');
  }

  String _createSizeHash(Size? size) {
    return size != null ? '_${size.width.toInt()}x${size.height.toInt()}' : '';
  }

  String _createParametersHash() {
    return '${widget.blurRadius}_${widget.blurSigma}_${widget.gradient.name}_${widget.opacity}_${widget.gamma}_${widget.minVisibility}_${widget.useLogNormalization}_${widget.resolution}';
  }

  double _calculateKernelSigma() {
    return widget.blurSigma > 0
        ? widget.blurSigma
        : HeatmapConstants.defaultKernelSigma;
  }

  double _calculateKernelRadius() {
    return widget.blurRadius > 0
        ? widget.blurRadius
        : HeatmapConstants.defaultKernelRadius;
  }

  int _calculateKernelSize(double kernelRadius) {
    return math.min(
        (kernelRadius * 2 + 1).round(), HeatmapConstants.maxKernelSize);
  }

  (int, int) _normalizePointToGrid(
      HeatmapPoint point, int gridWidth, int gridHeight) {
    final normalizedX = point.x.clamp(0.0, 1.0);
    final normalizedY = point.y.clamp(0.0, 1.0);
    final gridX = (normalizedX * (gridWidth - 1)).round();
    final gridY = (normalizedY * (gridHeight - 1)).round();
    return (gridX, gridY);
  }

  bool _isKernelOutOfBounds(
      int centerX, int centerY, int halfKernel, int gridWidth, int gridHeight) {
    return centerX + halfKernel < 0 ||
        centerX - halfKernel >= gridWidth ||
        centerY + halfKernel < 0 ||
        centerY - halfKernel >= gridHeight;
  }

  ({int startX, int endX, int startY, int endY}) _calculateKernelBounds(
      int centerX, int centerY, int halfKernel, int gridWidth, int gridHeight) {
    return (
      startX: math.max(0, centerX - halfKernel),
      endX: math.min(gridWidth, centerX + halfKernel + 1),
      startY: math.max(0, centerY - halfKernel),
      endY: math.min(gridHeight, centerY + halfKernel + 1),
    );
  }

  void _applyKernelToGrid(
    Float32List densityArray,
    Float32List kernel,
    List<List<bool>> kernelMask,
    ({int startX, int endX, int startY, int endY}) bounds,
    int centerX,
    int centerY,
    int halfKernel,
    int kernelSize,
    int gridWidth,
    double intensity,
  ) {
    for (int gridY = bounds.startY; gridY < bounds.endY; gridY++) {
      final kernelRowOffset = (gridY - centerY + halfKernel) * kernelSize;
      final densityRowOffset = gridY * gridWidth;

      for (int gridX = bounds.startX; gridX < bounds.endX; gridX++) {
        final kernelIndex = kernelRowOffset + (gridX - centerX + halfKernel);
        final densityIndex = densityRowOffset + gridX;

        if (_isValidKernelApplication(
            kernelIndex, kernel.length, kernelSize, kernelMask)) {
          densityArray[densityIndex] += kernel[kernelIndex] * intensity;
        }
      }
    }
  }

  bool _isValidKernelApplication(int kernelIndex, int kernelLength,
      int kernelSize, List<List<bool>> kernelMask) {
    return kernelIndex >= 0 &&
        kernelIndex < kernelLength &&
        kernelMask[kernelIndex ~/ kernelSize][kernelIndex % kernelSize];
  }

  Future<ui.Image> _generateHeatmapImage([Size? currentSize]) async {
    final imageWidth = currentSize?.width.toInt() ?? _image!.width;
    final imageHeight = currentSize?.height.toInt() ?? _image!.height;

    final double gridResolution = widget.resolution;
    final int heatmapGridWidth = (imageWidth / gridResolution).round();
    final int heatmapGridHeight = (imageHeight / gridResolution).round();

    print(
        'Heatmap: Image size: ${imageWidth}x${imageHeight}, Grid size: ${heatmapGridWidth}x$heatmapGridHeight');
    print(
        'Heatmap: Resolution: $gridResolution, Points count: ${widget.points.length}');

    final List<HeatmapPoint> points = widget.points;

    // Use flat array instead of nested lists
    final densityArray = Float32List(heatmapGridWidth * heatmapGridHeight);

    // Optimized kernel stamping
    final kernelSigma = _calculateKernelSigma();
    final kernelRadius = _calculateKernelRadius();
    final kernelSize = _calculateKernelSize(kernelRadius);

    final kernel =
        KernelCache.getFlatKernel(kernelSize, kernelSigma, kernelRadius);
    final kernelMask = KernelCache.getKernelMask(kernelSize, kernelSigma,
        kernelRadius, HeatmapConstants.kernelThreshold);
    final halfKernel = kernelSize ~/ 2;

    // Optimized kernel application
    for (final point in points) {
      final (pointGridX, pointGridY) =
          _normalizePointToGrid(point, heatmapGridWidth, heatmapGridHeight);

      // Early bounds check: skip if kernel is fully outside grid
      if (_isKernelOutOfBounds(pointGridX, pointGridY, halfKernel,
          heatmapGridWidth, heatmapGridHeight)) {
        continue;
      }

      // Calculate kernel application bounds
      final kernelBounds = _calculateKernelBounds(pointGridX, pointGridY,
          halfKernel, heatmapGridWidth, heatmapGridHeight);

      _applyKernelToGrid(
          densityArray,
          kernel,
          kernelMask,
          kernelBounds,
          pointGridX,
          pointGridY,
          halfKernel,
          kernelSize,
          heatmapGridWidth,
          point.intensity);
    }

    // Find max value efficiently
    double maxValue = 0.0;
    for (int i = 0; i < densityArray.length; i++) {
      if (densityArray[i] > maxValue) maxValue = densityArray[i];
    }

    // Normalize array in place
    _normalizeFlatArray(densityArray, maxValue);

    print('Heatmap: Max value: ${maxValue.toStringAsFixed(2)}');

    return _flatArrayToImage(densityArray, heatmapGridWidth, heatmapGridHeight,
        imageWidth, imageHeight);
  }

  void _normalizeFlatArray(Float32List array, double maxValue) {
    if (maxValue <= 0.0) return;

    // Find minimum non-zero value
    double minNonZeroValue = maxValue;
    for (int i = 0; i < array.length; i++) {
      final value = array[i];
      if (value > 0.0 && value < minNonZeroValue) {
        minNonZeroValue = value;
      }
    }

    // Normalize in place
    for (int i = 0; i < array.length; i++) {
      final value = array[i];
      if (value <= 0.0) continue;

      double normalized;
      if (widget.useLogNormalization) {
        final logMax = math.log(maxValue + 1.0);
        final logMin = math.log(minNonZeroValue + 1.0);
        final logRange = logMax - logMin;
        final logValue = math.log(value + 1.0);
        normalized = (logValue - logMin) / logRange;
      } else {
        normalized = value / maxValue;
      }

      final gammaCorrected = math.pow(normalized, widget.gamma).toDouble();
      array[i] = math.max(gammaCorrected, widget.minVisibility);
    }
  }

  Future<ui.Image> _flatArrayToImage(Float32List array, int gridWidth,
      int gridHeight, int targetWidth, int targetHeight) async {
    final bytes = Uint8List(targetWidth * targetHeight * 4);

    // Pre-calculate scaling factors
    final scaleX = gridWidth / targetWidth;
    final scaleY = gridHeight / targetHeight;

    // Find max density for visibility threshold (vectorized)
    double maxDensity = 0.0;
    for (int i = 0; i < array.length; i++) {
      if (array[i] > maxDensity) maxDensity = array[i];
    }
    final minVisibleDensity = maxDensity > 0
        ? maxDensity * HeatmapConstants.minVisibleDensityRatio
        : HeatmapConstants.minVisibleDensityFallback;

    // Pre-compute color lookup table for better performance
    final colorLUT = _buildColorLUT(HeatmapConstants.colorLutSize);

    // Direct pixel manipulation with optimized loops
    int pixelByteIndex = 0;
    for (int imageY = 0; imageY < targetHeight; imageY++) {
      final gridY = (imageY * scaleY).floor().clamp(0, gridHeight - 1);
      final gridRowOffset = gridY * gridWidth;

      for (int imageX = 0; imageX < targetWidth; imageX++) {
        final correspondingGridX =
            (imageX * scaleX).floor().clamp(0, gridWidth - 1);
        final pixelDensity = array[gridRowOffset + correspondingGridX];

        _setPixelColor(
            bytes, pixelByteIndex, pixelDensity, minVisibleDensity, colorLUT);

        pixelByteIndex += 4;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, targetWidth, targetHeight,
        ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  void _setPixelColor(Uint8List bytes, int byteIndex, double density,
      double minVisibleDensity, List<Color> colorLUT) {
    if (density > minVisibleDensity) {
      final colorIntensityIndex =
          (density * (HeatmapConstants.colorLutSize - 1))
              .round()
              .clamp(0, HeatmapConstants.colorLutSize - 1);
      final pixelColor = colorLUT[colorIntensityIndex];

      bytes[byteIndex] = pixelColor.red;
      bytes[byteIndex + 1] = pixelColor.green;
      bytes[byteIndex + 2] = pixelColor.blue;
      bytes[byteIndex + 3] = pixelColor.alpha;
    }
    // else bytes remain 0 (transparent) - no need to set explicitly
  }

  List<Color> _buildColorLUT(int size) {
    final lut = List<Color>.filled(size, Colors.transparent);
    for (int i = 0; i < size; i++) {
      final t = i / (size - 1);
      lut[i] = _getColorFromDensity(t);
    }
    return lut;
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
    final alpha = (255 * widget.opacity).round();

    if (t < HeatmapConstants.jetQuarter) {
      final s = t * HeatmapConstants.jetScale;
      return Color.fromARGB(alpha, 0, 0, (127 + 128 * s).round());
    } else if (t < HeatmapConstants.jetHalf) {
      final s = (t - HeatmapConstants.jetQuarter) * HeatmapConstants.jetScale;
      return Color.fromARGB(alpha, 0, (255 * s).round(), 255);
    } else if (t < HeatmapConstants.jetThreeQuarters) {
      final s = (t - HeatmapConstants.jetHalf) * HeatmapConstants.jetScale;
      return Color.fromARGB(
          alpha, (255 * s).round(), 255, (255 * (1 - s)).round());
    } else {
      final s =
          (t - HeatmapConstants.jetThreeQuarters) * HeatmapConstants.jetScale;
      return Color.fromARGB(alpha, 255, (255 * (1 - s)).round(), 0);
    }
  }

  Color _hotColormap(double t) {
    final alpha = (255 * widget.opacity).round();

    if (t < HeatmapConstants.hotThird) {
      final s = t * HeatmapConstants.hotScale1;
      return Color.fromARGB(alpha, (255 * s).round(), 0, 0);
    } else if (t < HeatmapConstants.hotTwoThirds) {
      final s = (t - HeatmapConstants.hotThird) * HeatmapConstants.hotScale1;
      return Color.fromARGB(alpha, 255, (255 * s).round(), 0);
    } else {
      final s =
          (t - HeatmapConstants.hotTwoThirds) * HeatmapConstants.hotScale2;
      return Color.fromARGB(alpha, 255, 255, (255 * s).round());
    }
  }

  Color _coolColormap(double t) {
    final alpha = (255 * widget.opacity).round();
    return Color.fromARGB(
        alpha, (255 * t).round(), (255 * (1 - t)).round(), 255);
  }

  Color _viridisColormap(double t) {
    final alpha = (255 * widget.opacity).round();

    if (t < HeatmapConstants.viridisHalf) {
      final s = t * HeatmapConstants.viridisScale;
      return Color.fromARGB(
          alpha, 0, (100 + 155 * s).round(), (200 + 55 * s).round());
    } else {
      final s =
          (t - HeatmapConstants.viridisHalf) * HeatmapConstants.viridisScale;
      return Color.fromARGB(alpha, (200 * s).round(), (255 - 100 * s).round(),
          (255 - 200 * s).round());
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

        // Generate heatmap on first build or size change
        if (_heatmapImage == null ||
            _lastSize == null ||
            (currentSize.width - _lastSize!.width).abs() >
                HeatmapConstants.sizeChangeThreshold ||
            (currentSize.height - _lastSize!.height).abs() >
                HeatmapConstants.sizeChangeThreshold) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _image != null) {
              _generateHeatmap(currentSize);
            }
          });
        }

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
        oldWidget.resolution != widget.resolution) {
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
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return oldDelegate.heatmapImage != heatmapImage ||
        oldDelegate.opacity != opacity;
  }
}

enum HeatmapGradient {
  jet, // Blue -> Cyan -> Green -> Yellow -> Red
  hot, // Black -> Red -> Yellow -> White
  cool, // Cyan -> Magenta
  viridis, // Purple -> Blue -> Green -> Yellow
}
