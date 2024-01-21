import 'dart:convert';

import 'package:eqmonitor/core/component/intenisty/jma_forecast_intensity_icon.dart';
import 'package:eqmonitor/core/extension/double_to_jma_forecast_intensity.dart';
import 'package:eqmonitor/core/provider/app_lifecycle.dart';
import 'package:eqmonitor/core/provider/capture/intensity_icon_render.dart';
import 'package:eqmonitor/core/provider/map/map_style.dart';
import 'package:eqmonitor/feature/home/features/debugger/debugger_provider.dart';
import 'package:eqmonitor/feature/home/features/estimated_intensity/provider/estimated_intensity_provider.dart';
import 'package:eqmonitor/feature/home/features/map/viewmodel/main_map_viewmodel.dart';
import 'package:eqmonitor/feature/home/features/travel_time/provider/travel_time_provider.dart';
import 'package:eqmonitor/gen/fonts.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MainMapView extends HookConsumerWidget {
  const MainMapView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = useState(Theme.of(context).brightness == Brightness.dark);
    ref.listen(appLifeCycleProvider, (_, value) {
      if (value == AppLifecycleState.resumed) {
        isDark.value = Theme.of(context).brightness == Brightness.dark;
      }
    });
    final mapStyle = ref.watch(mapStyleProvider);
    final stylePath = useState<String?>(null);
    final getStyleJsonFuture = useMemoized(
      () async {
        final path = await mapStyle.getStyle(isDark: isDark.value);
        stylePath.value = path;
      },
      [isDark.value],
    );
    useFuture(
      getStyleJsonFuture,
    );
    final cameraPosition = useState<String>('');

    final controller = useAnimationController(
      duration: const Duration(microseconds: 1000),
    );
    useAnimation(controller);
    useEffect(
      () {
        controller
          ..repeat()
          ..addListener(
            () => ref
                .read(mainMapViewModelProvider.notifier)
                .onTick(DateTime.now()),
          );
        return null;
      },
      [],
    );

    // 震央画像 / 震度アイコンの登録
    final images = (
      intenistyIcon: ref.watch(intensityIconRenderProvider),
      intensityIconFill: ref.watch(intensityIconFillRenderProvider),
      hypocenterIcon: ref.watch(hypocenterIconRenderProvider),
      hypocenterLowPreciseIcon:
          ref.watch(hypocenterLowPreciseIconRenderProvider),
    );
    final hasTravelTimeDepthMapValue = ref.watch(
      travelTimeDepthMapProvider
          .select((e) => e.valueOrNull?.isNotEmpty ?? false),
    );
    // 初回描画が終わるまで待つ
    if (stylePath.value == null ||
        images.hypocenterIcon == null ||
        images.hypocenterLowPreciseIcon == null ||
        !images.intenistyIcon.isAllRendered() ||
        !images.intensityIconFill.isAllRendered() ||
        !hasTravelTimeDepthMapValue) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    final mapController = useState<MaplibreMapController?>(null);

    ref.watch(mainMapViewModelProvider);

    final map = RepaintBoundary(
      child: MaplibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.681236, 139.767125),
          zoom: 3,
        ),
        styleString: 'https://map.eqmonitor.app/tiles/style_old.json',
        onMapCreated: (controller) {
          mapController.value = controller;

          controller.addListener(
            () {
              final position = controller.cameraPosition;
              if (position != null) {
                try {
                  cameraPosition.value = const JsonEncoder.withIndent(' ')
                      .convert(position.toMap());
                  // ignore: avoid_catching_errors
                } on JsonUnsupportedObjectError {
                  // ignore: avoid_print
                  print(position);
                }
              }
            },
          );
        },
        onStyleLoadedCallback: () async {
          final controller = mapController.value;
          await controller?.setSymbolIconAllowOverlap(true);
          await controller?.setSymbolIconIgnorePlacement(true);
          final notifier = ref.read(mainMapViewModelProvider.notifier)
            ..registerMapController(
              controller!,
            );

          await notifier.updateImage(
            name: 'hypocenter',
            bytes: images.hypocenterIcon!,
          );
          await notifier.updateImage(
            name: 'hypocenter-low-precise',
            bytes: images.hypocenterLowPreciseIcon!,
          );
          for (final MapEntry(:key, :value) in images.intenistyIcon.entries) {
            await notifier.updateImage(
              name: 'intensity-${key.type}',
              bytes: value,
            );
          }
          for (final MapEntry(:key, :value)
              in images.intensityIconFill.entries) {
            await notifier.updateImage(
              name: 'intensity-fill-${key.type}',
              bytes: value,
            );
          }
          await notifier.onMapControllerRegistered();
          await notifier.startUpdateEew();
          await notifier.moveCameraToDefaultPosition(
            bottom: 100,
            left: 10,
            right: 10,
          );
        },
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        trackCameraPosition: true,
      ),
    );
    return Stack(
      children: [
        map,
        if (ref
            .watch(debuggerProvider.select((value) => value.isDebugger))) ...[
          _MapDebugWidget(cameraPosition: cameraPosition),
        ],
      ],
    );
  }
}

class _MapDebugWidget extends HookConsumerWidget {
  const _MapDebugWidget({
    required this.cameraPosition,
  });

  final ValueNotifier<String> cameraPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = useState(false);
    if (!isExpanded.value) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.tonalIcon(
              onPressed: () => isExpanded.value = true,
              label: const Text(
                'Debug',
                style: TextStyle(
                  fontFamily: FontFamily.jetBrainsMono,
                ),
              ),
              icon: const Icon(Icons.bug_report),
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => isExpanded.value = false,
        child: Card(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cameraPosition.value,
                  style: const TextStyle(
                    fontSize: 8,
                    fontFamily: FontFamily.jetBrainsMono,
                  ),
                ),
                const _EewEstimatedIntensityMax(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EewEstimatedIntensityMax extends ConsumerWidget {
  const _EewEstimatedIntensityMax({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(estimatedIntensityProvider).firstOrNull;
    if (state == null) {
      return const SizedBox.shrink();
    }
    final intensity = state.intensityValue?.toJmaForecastIntensity;
    if (intensity == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        const Text('距離減衰式による推定最大震度'),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            JmaForecastIntensityWidget(
              intensity: intensity,
              size: 36,
            ),
            const SizedBox(width: 8),
            Text(
              '${state.point.prefecture} ${state.point.name}: ${state.intensityValue}',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: FontFamily.jetBrainsMono,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
