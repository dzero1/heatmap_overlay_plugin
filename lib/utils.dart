import 'dart:math' as math;
import 'dart:typed_data';

class KernelCache {
  static final Map<String, List<List<double>>> _cache = {};
  static final Map<String, List<List<bool>>> _maskCache = {};
  static final Map<String, Float32List> _flatKernelCache = {};
  static const int maxCacheSize = 20;
  
  static String _createKey(int size, double sigma, double radius) {
    return '${size}_${sigma.toStringAsFixed(2)}_${radius.toStringAsFixed(2)}';
  }
  
  static List<List<double>> getKernel(int size, double sigma, double radius) {
    final key = _createKey(size, sigma, radius);
    return _cache.putIfAbsent(key, () => _createGaussianKernel(size, sigma, radius));
  }
  
  static Float32List getFlatKernel(int size, double sigma, double radius) {
    final key = _createKey(size, sigma, radius);
    
    if (_flatKernelCache.containsKey(key)) {
      return _flatKernelCache[key]!;
    }
    
    // LRU eviction
    if (_flatKernelCache.length >= maxCacheSize) {
      _flatKernelCache.remove(_flatKernelCache.keys.first);
    }
    
    final kernel = _createFlatGaussianKernel(size, sigma, radius);
    _flatKernelCache[key] = kernel;
    return kernel;
  }
  
  static List<List<bool>> getKernelMask(int size, double sigma, double radius, double threshold) {
    final key = '${_createKey(size, sigma, radius)}_${threshold.toStringAsFixed(5)}';
    return _maskCache.putIfAbsent(key, () {
      final kernel = getKernel(size, sigma, radius);
      return List.generate(size, (y) => List.generate(size, (x) => kernel[y][x] >= threshold));
    });
  }
  
  static Float32List _createFlatGaussianKernel(int size, double sigma, double radius) {
    final kernel = Float32List(size * size);
    final center = size ~/ 2;
    double sum = 0.0;
    
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = math.sqrt(dx * dx + dy * dy);
        
        final index = y * size + x;
        if (distance > radius) {
          kernel[index] = 0.0;
        } else {
          final value = math.exp(-(distance * distance) / (2 * sigma * sigma));
          kernel[index] = value;
          sum += value;
        }
      }
    }
    
    // Normalize
    if (sum > 0.0) {
      for (int i = 0; i < kernel.length; i++) {
        kernel[i] /= sum;
      }
    }
    
    return kernel;
  }
  
  static List<List<double>> _createGaussianKernel(int size, double sigma, double radius) {
    final kernel = List.generate(size, (y) => List<double>.filled(size, 0.0));
    final center = size ~/ 2;
    double sum = 0.0;
    
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = math.sqrt(dx * dx + dy * dy);
        
        if (distance > radius) {
          kernel[y][x] = 0.0;
          continue;
        }
        
        final value = math.exp(-(distance * distance) / (2 * sigma * sigma));
        kernel[y][x] = value;
        sum += value;
      }
    }
    
    if (sum > 0.0) {
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          kernel[y][x] /= sum;
        }
      }
    }
    
    return kernel;
  }
  
  static void clearCache() {
    _cache.clear();
    _maskCache.clear();
    _flatKernelCache.clear();
  }
}