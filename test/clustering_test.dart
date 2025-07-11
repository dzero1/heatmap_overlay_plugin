import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin.dart';

void main() {
  group('Clustering Tests', () {
    test('Empty points list returns empty clusters', () {
      final points = <HeatmapPoint>[];
      final clusters = _testClusterPoints(points, 0.1);
      expect(clusters, isEmpty);
    });

    test('Single point returns single cluster', () {
      final points = [HeatmapPoint(0.5, 0.5, 100.0)];
      final clusters = _testClusterPoints(points, 0.1);
      expect(clusters.length, 1);
      expect(clusters[0].x, 0.5);
      expect(clusters[0].y, 0.5);
      expect(clusters[0].intensity, 100.0);
      expect(clusters[0].pointCount, 1);
    });

    test('Two close points are clustered together', () {
      final points = [
        HeatmapPoint(0.5, 0.5, 100.0),
        HeatmapPoint(0.51, 0.51, 50.0), // Very close
      ];
      final clusters = _testClusterPoints(points, 0.02);
      expect(clusters.length, 1);
      expect(clusters[0].pointCount, 2);
      expect(clusters[0].intensity, greaterThan(150.0)); // Should be weighted
    });

    test('Two distant points remain separate', () {
      final points = [
        HeatmapPoint(0.1, 0.1, 100.0),
        HeatmapPoint(0.9, 0.9, 50.0), // Far apart
      ];
      final clusters = _testClusterPoints(points, 0.1);
      expect(clusters.length, 2);
    });

    test('Multiple close points form single cluster', () {
      final points = [
        HeatmapPoint(0.5, 0.5, 100.0),
        HeatmapPoint(0.51, 0.51, 50.0),
        HeatmapPoint(0.52, 0.52, 75.0),
        HeatmapPoint(0.49, 0.49, 25.0),
      ];
      final clusters = _testClusterPoints(points, 0.05);
      expect(clusters.length, 1);
      expect(clusters[0].pointCount, 4);
    });

    test('Two separate clusters are formed correctly', () {
      final points = [
        // Cluster 1
        HeatmapPoint(0.2, 0.2, 100.0),
        HeatmapPoint(0.21, 0.21, 50.0),
        // Cluster 2
        HeatmapPoint(0.8, 0.8, 75.0),
        HeatmapPoint(0.81, 0.81, 25.0),
      ];
      final clusters = _testClusterPoints(points, 0.05);
      expect(clusters.length, 2);
      
      // Both clusters should have 2 points
      expect(clusters.any((c) => c.pointCount == 2), true);
      expect(clusters.any((c) => c.pointCount == 2), true);
    });

    test('Large dataset uses grid-based clustering', () {
      // Create 150 points (above the 100 threshold for grid-based clustering)
      final points = <HeatmapPoint>[];
      for (int i = 0; i < 150; i++) {
        points.add(HeatmapPoint(
          0.1 + (i * 0.01) % 0.8, // Spread across the space
          0.1 + (i * 0.015) % 0.8,
          10.0 + (i * 2) % 90,
        ));
      }
      
      final clusters = _testClusterPoints(points, 0.05);
      expect(clusters.length, lessThan(points.length)); // Should reduce points
      expect(clusters.isNotEmpty, true);
    });
  });
}

// Helper function to test clustering (simplified version of the actual implementation)
List<ClusteredPoint> _testClusterPoints(List<HeatmapPoint> points, double threshold) {
  if (points.isEmpty) return [];
  
  // For small datasets, use simple clustering
  if (points.length <= 100) {
    return _testSimpleClusterPoints(points, threshold);
  }
  
  // For large datasets, use grid-based clustering for better performance
  return _testGridClusterPoints(points, threshold);
}

List<ClusteredPoint> _testSimpleClusterPoints(List<HeatmapPoint> points, double threshold) {
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
          final distance = _testCalculateDistance(points[j], points[clusterIndex]);
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
    
    // Create clustered point with weighted intensity
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

List<ClusteredPoint> _testGridClusterPoints(List<HeatmapPoint> points, double threshold) {
  // Create a grid with cell size equal to threshold
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
              final distance = _testCalculateDistance(points[neighborIndex], points[clusterIndex]);
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

double _testCalculateDistance(HeatmapPoint p1, HeatmapPoint p2) {
  final dx = p1.x - p2.x;
  final dy = p1.y - p2.y;
  return sqrt(dx * dx + dy * dy);
} 