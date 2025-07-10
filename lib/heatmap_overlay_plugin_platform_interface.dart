import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'heatmap_overlay_plugin_method_channel.dart';

abstract class HeatmapOverlayPluginPlatform extends PlatformInterface {
  /// Constructs a HeatmapOverlayPluginPlatform.
  HeatmapOverlayPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static HeatmapOverlayPluginPlatform _instance = MethodChannelHeatmapOverlayPlugin();

  /// The default instance of [HeatmapOverlayPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelHeatmapOverlayPlugin].
  static HeatmapOverlayPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HeatmapOverlayPluginPlatform] when
  /// they register themselves.
  static set instance(HeatmapOverlayPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
