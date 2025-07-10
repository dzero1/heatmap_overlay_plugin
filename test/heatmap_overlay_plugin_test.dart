import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin_platform_interface.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin_method_channel.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin_web.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHeatmapOverlayPluginPlatform
    with MockPlatformInterfaceMixin
    implements HeatmapOverlayPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HeatmapOverlayPluginPlatform initialPlatform = HeatmapOverlayPluginPlatform.instance;

  test('$MethodChannelHeatmapOverlayPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHeatmapOverlayPlugin>());
  });

  test('getPlatformVersion', () async {
    HeatmapOverlayPluginWeb heatmapOverlayPlugin = HeatmapOverlayPluginWeb();
    MockHeatmapOverlayPluginPlatform fakePlatform = MockHeatmapOverlayPluginPlatform();
    HeatmapOverlayPluginPlatform.instance = fakePlatform;

    expect(await heatmapOverlayPlugin.getPlatformVersion(), '42');
  });
}
