import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'heatmap_overlay_plugin_platform_interface.dart';

/// An implementation of [HeatmapOverlayPluginPlatform] that uses method channels.
class MethodChannelHeatmapOverlayPlugin extends HeatmapOverlayPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('heatmap_overlay_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
