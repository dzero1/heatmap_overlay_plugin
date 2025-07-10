import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmap_overlay_plugin/heatmap_overlay_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelHeatmapOverlayPlugin platform = MethodChannelHeatmapOverlayPlugin();
  const MethodChannel channel = MethodChannel('heatmap_overlay_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
