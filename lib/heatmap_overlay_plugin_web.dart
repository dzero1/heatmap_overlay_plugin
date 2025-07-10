// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'heatmap_overlay_plugin_platform_interface.dart';

/// A web implementation of the HeatmapOverlayPluginPlatform of the HeatmapOverlayPlugin plugin.
class HeatmapOverlayPluginWeb extends HeatmapOverlayPluginPlatform {
  /// Constructs a HeatmapOverlayPluginWeb
  HeatmapOverlayPluginWeb();

  static void registerWith(Registrar registrar) {
    HeatmapOverlayPluginPlatform.instance = HeatmapOverlayPluginWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }
}
