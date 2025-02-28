// ignore_for_file: provider_dependencies
import 'dart:developer';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:eqapi_types/eqapi_types.dart';
import 'package:eqmonitor/core/provider/capture/intensity_icon_render.dart';
import 'package:eqmonitor/core/provider/config/theme/intensity_color/intensity_color_provider.dart';
import 'package:eqmonitor/core/provider/config/theme/intensity_color/model/intensity_color_model.dart';
import 'package:eqmonitor/core/provider/eew/eew_alive_telegram.dart';
import 'package:eqmonitor/core/provider/estimated_intensity/provider/estimated_intensity_provider.dart';
import 'package:eqmonitor/core/provider/kmoni_observation_points/model/kmoni_observation_point.dart';
import 'package:eqmonitor/core/provider/map/map_style.dart';
import 'package:eqmonitor/core/provider/travel_time/provider/travel_time_provider.dart';
import 'package:eqmonitor/feature/home/features/eew_settings/eew_settings_notifier.dart';
import 'package:eqmonitor/feature/home/features/eew_settings/model/eew_setitngs_model.dart';
import 'package:eqmonitor/feature/home/features/kmoni/provider/kmoni_view_model.dart';
import 'package:eqmonitor/feature/home/features/kmoni/viewmodel/kmoni_settings.dart';
import 'package:eqmonitor/feature/home/features/map/model/main_map_viewmodel_state.dart';
import 'package:eqmonitor/feature/shake_detection/model/shake_detection_kmoni_merged_event.dart';
import 'package:eqmonitor/feature/shake_detection/provider/shake_detection_provider.dart';
import 'package:extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lat_lng/lat_lng.dart' as lat_lng;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre_gl;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synchronized/synchronized.dart';

part 'main_map_viewmodel.freezed.dart';
part 'main_map_viewmodel.g.dart';

@Riverpod(
  keepAlive: true,
)
class MainMapViewModel extends _$MainMapViewModel {
  @override
  MainMapViewmodelState build() {
    ref
      ..listen(
        kmoniViewModelProvider,
        (_, value) {
          final analyzedPoints = value.analyzedPoints;
          if (analyzedPoints == null) {
            return;
          }
          _onKmoniStateChanged(analyzedPoints);
        },
      )
      ..listen(
        eewAliveTelegramProvider,
        (_, value) => _onEewStateChanged(value ?? []),
      )
      ..listen(
        kmoniSettingsProvider,
        (_, value) => _onKmoniSettingsChanged(value: value),
      )
      ..listen(
        shakeDetectionKmoniPointsMergedProvider,
        (_, value) => _onShakeDetectionStateChanged(value.valueOrNull ?? []),
      )
      ..listen(
        eewSettingsNotifierProvider,
        (_, value) => _onEewSettingsChanged(value),
      )
      ..listen(
        estimatedIntensityRegionProvider,
        (_, state) {
          final eewSettings = ref.read(eewSettingsNotifierProvider);
          if (!eewSettings.showCalculatedRegionIntensity) {
            return;
          }

          if (state case AsyncData(:final value)) {
            _onEstimatedIntensityRegionChanged(value);
          }
        },
      )
      ..listen(
        estimatedIntensityCityProvider,
        (_, state) {
          final eewSettings = ref.read(eewSettingsNotifierProvider);
          if (!eewSettings.showCalculatedCityIntensity) {
            return;
          }

          if (state case AsyncData(:final value)) {
            _onEstimatedIntensityCityChanged(value);
          }
        },
      )
      ..listen(eewSettingsNotifierProvider, (_, next) {
        _onEewSettingsChanged(next);
      });
    _lastKmoniSettingsState = ref.read(kmoniSettingsProvider);
    return MainMapViewmodelState(
      isHomePosition: true,
      homeBoundary: defaultBoundary,
    );
  }

  static LatLngBounds defaultBoundary = LatLngBounds(
    southwest: const LatLng(30, 128.8),
    northeast: const LatLng(45.8, 145.1),
  );

  MapLibreMapController? _controller;

  /// 実行前に `travelTimeDepthMapProvider`, `hypocenterIconRenderProvider`,
  /// `hypocenterLowPreciseIconRenderProvider` が初期化済みであることを確認すること
  Future<void> onMapControllerRegistered() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    _kmoniObservationPointService = _KmoniObservationPointService(
      controller: controller,
    );
    _eewHypocenterService = _EewHypocenterService(
      controller: controller,
    );
    _eewPsWaveService = _EewPsWaveService(
      controller: controller,
      travelTimeMap: ref.read(travelTimeDepthMapProvider).requireValue,
    );
    _eewEstimatedIntensityService = _EewEstimatedIntensityService(
      controller: controller,
    );
    _shakeDetectionBorderService = _ShakeDetectionBorderService(
      controller: controller,
      intensityColorModel: ref.watch(intensityColorProvider),
    );
    _eewEstimatedIntensityCalculatedRegionService =
        _EewEstimatedIntensityCalculatedRegionService(
      controller: controller,
    );
    _eewEstimatedIntensityCalculatedCityService =
        _EewEstimatedIntensityCalculatedCityService(
      controller: controller,
    );
    _currentLocationIconService = _CurrentLocationIconService(
      controller: controller,
    );

    await (
      _kmoniObservationPointService!.init(),
      _eewPsWaveService!.init(),
      _eewEstimatedIntensityService.init(
        ref.read(intensityColorProvider),
      ),
      _shakeDetectionBorderService!.init(
        ref.read(shakeDetectionKmoniPointsMergedProvider).valueOrNull ?? [],
      ),
      _eewEstimatedIntensityCalculatedRegionService!.init(
        ref.read(intensityColorProvider),
      ),
      _eewEstimatedIntensityCalculatedCityService!.init(
        ref.read(intensityColorProvider),
      ),
    ).wait;
    await _eewHypocenterService!.init(
      hypocenterIcon: ref.read(hypocenterIconRenderProvider)!,
      hypocenterLowPreciseIcon:
          ref.read(hypocenterLowPreciseIconRenderProvider)!,
    );
    await _currentLocationIconService!.init();

    // 地図の移動を監視
    controller.addListener(() {
      final position = controller.cameraPosition;
      if (position != null && state.isHomePosition) {
        state = state.copyWith(
          isHomePosition: false,
        );
      }
    });
    ref.onDispose(() async {
      await (
        _kmoniObservationPointService!.dispose(),
        _eewHypocenterService!.dispose(),
        _eewPsWaveService!.dispose(),
        _eewEstimatedIntensityService.dispose(),
        _shakeDetectionBorderService!.dispose(),
        _currentLocationIconService!.dispose(),
      ).wait;
    });
    log('_onEewStateChanged called!', name: 'MainMapViewModel');

    final aliveEews = ref.read(eewAliveTelegramProvider);
    if (aliveEews != null && aliveEews.isNotEmpty) {
      await _onEewStateChanged(
        ref.read(eewAliveTelegramProvider) ?? [],
      );
    } else {
      await moveToHomeBoundary();
    }
  }

  Future<void> onTick(DateTime now) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await (
        _eewPsWaveService?.tick(now: now) ?? Future.value(),
        _eewHypocenterService?.tick() ?? Future.value(),
        _shakeDetectionBorderService?.tick() ?? Future.value(),
      ).wait;
      // ignore: avoid_catches_without_on_clauses, empty_catches
    } catch (e) {}
  }

  // *********** EEW Related ***********
  bool _isEewInitialized = false;

  _EewHypocenterService? _eewHypocenterService;
  _EewPsWaveService? _eewPsWaveService;
  late _EewEstimatedIntensityService _eewEstimatedIntensityService;
  _EewEstimatedIntensityCalculatedCityService?
      _eewEstimatedIntensityCalculatedCityService;

  _EewEstimatedIntensityCalculatedRegionService?
      _eewEstimatedIntensityCalculatedRegionService;

  _CurrentLocationIconService? _currentLocationIconService;

  Future<void> _onEewStateChanged(List<EewV1> values) async {
    // 初期化が終わっていない場合は何もしない
    if (!_isEewInitialized) {
      log('not initialized!', name: 'MainMapViewModel');
      return;
    }
    final aliveBodies = values
        .where(
          (e) => !e.isCanceled && e.latitude != null && e.longitude != null,
        )
        .toList();
    final normalEews = aliveBodies
        .where((e) => !(e.isIpfOnePoint || e.isLevelEew || (e.isPlum ?? false)))
        .map(
      (eew) {
        final isWarning =
            eew.isWarning ?? eew.headline?.contains('強い揺れ') ?? false;
        return (eew, isWarning);
      },
    ).toList();
    _eewPsWaveService!.update(normalEews);
    await _eewHypocenterService!.update(aliveBodies);
    final transformed = _EewEstimatedIntensityService.transform(
      aliveBodies.map((e) => e.regions).whereNotNull().flattened.toList(),
    );
    await _eewEstimatedIntensityService.update(transformed);
  }

  Future<void> _onEewSettingsChanged(EewSetitngs value) async {
    final colorModel = ref.read(intensityColorProvider);
    if (value.showCalculatedRegionIntensity) {
      _eewEstimatedIntensityCalculatedRegionService ??=
          _EewEstimatedIntensityCalculatedRegionService(
        controller: _controller!,
      );
      await _eewEstimatedIntensityCalculatedRegionService!.init(colorModel);
    } else {
      await _eewEstimatedIntensityCalculatedRegionService?.dispose();
      _eewEstimatedIntensityCalculatedRegionService = null;
    }

    if (value.showCalculatedCityIntensity) {
      _eewEstimatedIntensityCalculatedCityService ??=
          _EewEstimatedIntensityCalculatedCityService(
        controller: _controller!,
      );
      await _eewEstimatedIntensityCalculatedCityService!.init(colorModel);
    } else {
      await _eewEstimatedIntensityCalculatedCityService?.dispose();
      _eewEstimatedIntensityCalculatedCityService = null;
    }
  }

  Future<void> _onEstimatedIntensityRegionChanged(
    Map<String, double> value,
  ) async =>
      _eewEstimatedIntensityCalculatedRegionService?.update(
        _EewEstimatedIntensityCalculatedRegionService.transform(value),
      );

  Future<void> _onEstimatedIntensityCityChanged(
    Map<String, double> value,
  ) async =>
      _eewEstimatedIntensityCalculatedCityService?.update(
        _EewEstimatedIntensityCalculatedCityService.transform(value),
      );

  // *********** Kyoshin Monitor Related ***********
  _KmoniObservationPointService? _kmoniObservationPointService;
  _ShakeDetectionBorderService? _shakeDetectionBorderService;
  Future<void> _onKmoniStateChanged(
    List<AnalyzedKmoniObservationPoint> values,
  ) async {
    if (_controller == null) {
      return;
    }
    if (!ref.read(kmoniSettingsProvider).useKmoni) {
      await _kmoniObservationPointService?.update(
        points: [],
        isInEew: false,
        markerType: ref.read(kmoniSettingsProvider).kmoniMarkerType,
      );
      return;
    }

    await _kmoniObservationPointService?.update(
      points: values,
      isInEew: ref.read(eewAliveTelegramProvider)?.isNotEmpty ?? false,
      markerType: ref.read(kmoniSettingsProvider).kmoniMarkerType,
    );
  }

  Future<void> _onShakeDetectionStateChanged(
    List<ShakeDetectionKmoniMergedEvent> values,
  ) async {
    if (_shakeDetectionBorderService == null) {
      return;
    }
    await _shakeDetectionBorderService?.update(values);
  }

  KmoniSettingsState? _lastKmoniSettingsState;

  Future<void> _onKmoniSettingsChanged({
    required KmoniSettingsState value,
  }) async {
    if (_lastKmoniSettingsState == value) {
      return;
    }
    if (_lastKmoniSettingsState?.useKmoni != value.useKmoni) {
      if (value.useKmoni) {
        await _kmoniObservationPointService?.dispose();
        _kmoniObservationPointService = _KmoniObservationPointService(
          controller: _controller!,
        );
        await _kmoniObservationPointService?.init();
      } else {
        await _kmoniObservationPointService?.dispose();
        _kmoniObservationPointService = null;
      }
    }
    if (_lastKmoniSettingsState?.kmoniMarkerType != value.kmoniMarkerType) {
      await _kmoniObservationPointService?.update(
        points: ref.read(kmoniViewModelProvider).analyzedPoints ?? [],
        isInEew: ref.read(eewAliveTelegramProvider)?.isNotEmpty ?? false,
        markerType: value.kmoniMarkerType,
      );
    }
    if (_lastKmoniSettingsState?.showCurrentLocationMarker !=
        value.showCurrentLocationMarker) {
      if (value.showCurrentLocationMarker) {
        await _currentLocationIconService?.dispose();
        await _currentLocationIconService?.init();
      } else {
        await _currentLocationIconService?.dispose();
      }
    }
    _lastKmoniSettingsState = value;
  }

  Future<void> startUpdateEew() async {
    if (_isEewInitialized || _controller == null) {
      return;
    }

    _isEewInitialized = true;
    // 初回EEW State更新
    await _onEewStateChanged(
      ref.read(eewAliveTelegramProvider) ?? [],
    );
  }

  Future<void> onLocationChanged(double lat, double lng) async =>
      _currentLocationIconService?.update(
        (lat, lng),
      );

  // *********** Utilities ***********
  Future<void> updateImage({
    required String name,
    required Uint8List bytes,
  }) async {
    log('updateImage $name');
    await _controller?.addImage(name, bytes);
  }

  // ignore: use_setters_to_change_properties
  void registerMapController(MapLibreMapController controller) {
    // ignore: void_checks
    _controller = controller;
  }

  bool isMapControllerRegistered() => _controller != null;

  Future<void> moveCameraToDefaultPosition({
    double bottom = 0,
    double left = 0,
    double right = 0,
    double top = 0,
  }) async {
    if (_controller == null) {
      throw Exception('MapLibreMapController is null');
    }
    await _controller!.moveCamera(
      CameraUpdate.newLatLngBounds(
        defaultBoundary,
        bottom: bottom,
        left: left,
        right: right,
        top: top,
      ),
    );
  }

  Future<void> animateCameraToDefaultPosition({
    double bottom = 50,
    Duration duration = const Duration(
      milliseconds: 250,
    ),
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw Exception('MapLibreMapController is null');
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        defaultBoundary,
        bottom: bottom,
      ),
      duration: duration,
    );
  }

  // *********** Map Boundary Utilities ***********
  Future<void> changeHomeBoundaryWithAnimation({
    required LatLngBounds bounds,
    double bottom = 50,
    double left = 20,
    double right = 20,
    double top = 20,
    Duration duration = const Duration(
      milliseconds: 250,
    ),

    /// 現在の表示領域を破棄し、強制的に新しい表示領域を適用するかどうか
    bool isForce = false,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw Exception('MapLibreMapController is null');
    }
    // 現在のホームポジションから変更がない場合は何もしない
    if (!isForce && state.isHomePosition && state.homeBoundary == bounds) {
      return;
    }
    // 強制移動 もしくは ホームから移動していない場合(=isHomePosition == true)の場合は
    // アニメーションを実行する
    if (isForce || state.isHomePosition) {
      state = state.copyWith(
        homeBoundary: bounds,
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          bottom: bottom,
          left: left,
          right: right,
          top: top,
        ),
        duration: duration,
      );
      state = state.copyWith(
        isHomePosition: true,
      );
    } else {
      state = state.copyWith(
        homeBoundary: bounds,
      );
    }
  }

  Future<void> animateToHomeBoundary({
    double bottom = 150,
    double left = 10,
    double right = 10,
    double top = 10,
    Duration duration = const Duration(
      milliseconds: 250,
    ),
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw Exception('MapLibreMapController is null');
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        state.homeBoundary,
        bottom: bottom,
        left: left,
        right: right,
        top: top,
      ),
      duration: duration,
    );
    state = state.copyWith(
      isHomePosition: true,
    );
  }

  Future<void> moveToHomeBoundary({
    double bottom = 100,
    double left = 10,
    double right = 10,
    double top = 10,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw Exception('MapLibreMapController is null');
    }
    await controller.moveCamera(
      CameraUpdate.newLatLngBounds(
        state.homeBoundary,
        bottom: bottom,
        left: left,
        right: right,
        top: top,
      ),
    );
    state = state.copyWith(
      isHomePosition: true,
    );
  }
}

class _KmoniObservationPointService {
  _KmoniObservationPointService({
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> init() async {
    await dispose();
    await controller.addGeoJsonSource(
      layerId,
      {
        'type': 'FeatureCollection',
        'features': <void>[],
      },
    );
    await controller.addCircleLayer(
      layerId,
      layerId,
      CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          3,
          1,
          10,
          10,
        ],
        circleColor: [
          'get',
          'color',
        ],
        circleStrokeColor: Colors.grey.toHexStringRGB(),
        circleStrokeOpacity: [
          'get',
          'strokeOpacity',
        ],
        circleStrokeWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          3,
          0.2,
          10,
          1,
        ],
        circleSortKey: [
          'get',
          'intensity',
        ],
      ),
      sourceLayer: layerId,
      belowLayerId: _EewHypocenterService.sourceLayerId,
    );
  }

  Future<void> update({
    required List<AnalyzedKmoniObservationPoint> points,
    required bool isInEew,
    required KmoniMarkerType markerType,
  }) =>
      controller.setGeoJsonSource(
        layerId,
        createGeoJson(
          points: points,
          isInEew: isInEew,
          markerType: markerType,
        ),
      );

  Future<void> dispose() async {
    await controller.removeLayer(layerId);
    await controller.removeSource(layerId);
  }

  static const String layerId = 'kmoni-circle';

  Map<String, dynamic> createGeoJson({
    required List<AnalyzedKmoniObservationPoint> points,
    required bool isInEew,
    required KmoniMarkerType markerType,
  }) =>
      {
        'type': 'FeatureCollection',
        'features': points
            .where((e) => e.intensityValue != null)
            .map(
              (e) => {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    e.point.location.longitude,
                    e.point.location.latitude,
                  ],
                },
                'properties': {
                  'color': e.intensityValue != null
                      ? e.intensityColor?.toHexStringRGB()
                      : null,
                  'intensity': e.intensityValue,
                  'name': e.point.name,
                  'strokeOpacity': switch (markerType) {
                    KmoniMarkerType.always => 1.0,
                    KmoniMarkerType.onlyEew when isInEew => 1.0,
                    _ => 0.0,
                  },
                },
              },
            )
            .toList(),
      };
}

class _EewEstimatedIntensityService {
  _EewEstimatedIntensityService({required this.controller});

  final MapLibreMapController controller;
  Future<void> init(IntensityColorModel colorModel) async {
    await dispose();
    await [
      // 各予想震度ごとにFill Layerを追加
      for (final intensity in JmaForecastIntensity.values)
        controller.addLayer(
          'eqmonitor_map',
          getFillLayerId(intensity),
          FillLayerProperties(
            fillColor: colorModel
                .fromJmaForecastIntensity(intensity)
                .background
                .toHexStringRGB(),
          ),
          filter: [
            'in',
            ['get', 'code'],
            [
              'literal',
              <String>[],
            ]
          ],
          sourceLayer: 'areaForecastLocalE',
          belowLayerId: BaseLayer.areaForecastLocalELine.name,
        ),
    ].wait;
  }

  /// 予想震度を更新する
  /// [areas] は Map{予想震度, 地域コード[]}
  Future<void> update(Map<JmaForecastIntensity, List<String>> areas) => [
        // 各予想震度ごとにFill Layerを追加
        for (final intensity in JmaForecastIntensity.values)
          controller.setFilter(
            getFillLayerId(intensity),
            [
              'in',
              ['get', 'code'],
              [
                'literal',
                areas[intensity] ?? [],
              ]
            ],
          ),
      ].wait;

  Future<void> dispose() => [
        for (final intensity in JmaForecastIntensity.values)
          controller.removeLayer(getFillLayerId(intensity)),
      ].wait;

  Future<void> onIntensityColorModelChanged(IntensityColorModel model) =>
      dispose().then(
        (_) => init(model),
      );
  static Map<JmaForecastIntensity, List<String>> transform(
    List<EstimatedIntensityRegion> regions,
  ) {
    // 同じ地域をまとめる
    final regionsGrouped = regions.groupListsBy(
      (e) => e.code,
    );
    // 予想震度が最も大きいものを取り出す
    final regionsIntensityMax = <String, ForecastMaxInt>{};
    for (final entry in regionsGrouped.entries) {
      final max = entry.value
          .map((e) => e.forecastMaxInt)
          .whereType<ForecastMaxInt>()
          .reduce(
            (value, element) => value.toDisplayMaxInt().maxInt >
                    element.toDisplayMaxInt().maxInt
                ? value
                : element,
          );
      regionsIntensityMax[entry.key] = max;
    }
    // Map<予想震度, List<地域コード>> に変換する
    final regionsIntensityGrouped = <JmaForecastIntensity, List<String>>{};
    for (final entry in regionsIntensityMax.entries) {
      final key = entry.value.toDisplayMaxInt().maxInt;
      if (!regionsIntensityGrouped.containsKey(key)) {
        regionsIntensityGrouped[key] = [];
      }
      regionsIntensityGrouped[key]!.add(entry.key);
    }
    return regionsIntensityGrouped;
  }

  static String getFillLayerId(JmaForecastIntensity intensity) {
    final base = intensity.type
        .replaceAll('-', 'low')
        .replaceAll('+', 'high')
        .replaceAll('不明', 'unknown');
    return '$_EewEstimatedIntensityService-fill-$base';
  }
}

class _EewHypocenterService {
  _EewHypocenterService({required this.controller});

  final MapLibreMapController controller;

  bool hasInitialized = false;

  Future<void> init({
    required Uint8List hypocenterIcon,
    required Uint8List hypocenterLowPreciseIcon,
  }) async {
    await (
      controller.addImage(
        hypocenterIconId,
        hypocenterIcon,
      ),
      controller.addImage(
        hypocenterLowPreciseIconId,
        hypocenterLowPreciseIcon,
      ),
    ).wait;
    await controller.removeSource(sourceLayerId);
    await controller.addGeoJsonSource(
      sourceLayerId,
      createGeoJson([]),
    );

    // adding Symbol Layers
    await (
      controller.addSymbolLayer(
        sourceLayerId,
        hypocenterIconId,
        SymbolLayerProperties(
          iconImage: hypocenterIconId,
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            3,
            0.3,
            20,
            2,
          ],
          iconOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            6,
            1.0,
            10,
            0.5,
          ],
          iconAllowOverlap: true,
        ),
        filter: [
          '==',
          ['get', 'isLowPrecise'],
          false,
        ],
        sourceLayer: sourceLayerId,
      ),
      controller.addSymbolLayer(
        sourceLayerId,
        hypocenterLowPreciseIconId,
        SymbolLayerProperties(
          iconImage: hypocenterLowPreciseIconId,
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            3,
            0.3,
            20,
            2,
          ],
          iconOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            6,
            1.0,
            10,
            0.5,
          ],
          iconAllowOverlap: true,
        ),
        // where isLowPrecise == true
        filter: [
          '==',
          ['get', 'isLowPrecise'],
          true,
        ],
        sourceLayer: sourceLayerId,
      ),
    ).wait;
    hasInitialized = true;
  }

  Future<void> update(List<EewV1> items) => controller.setGeoJsonSource(
        sourceLayerId,
        createGeoJson(items),
      );

  double _lastOpacity = 0;

  Future<void> _changeOpacity(double opacity) async {
    _lastOpacity = opacity;
    await (
      controller.setLayerProperties(
        hypocenterIconId,
        SymbolLayerProperties(
          iconOpacity: opacity,
        ),
      ),
      controller.setLayerProperties(
        hypocenterLowPreciseIconId,
        SymbolLayerProperties(
          iconOpacity: opacity,
        ),
      ),
    ).wait;
  }

  Future<void> tick() async {
    if (!hasInitialized) {
      return;
    }
    final milliseconds = DateTime.now().millisecondsSinceEpoch;
    if (milliseconds % 1000 < 500) {
      if (_lastOpacity == 1.0) {
        return;
      }
      await _changeOpacity(1);
    } else {
      if (_lastOpacity == 0.5) {
        return;
      }
      _lastOpacity = 0.5;
      await _changeOpacity(0.5);
    }
  }

  Future<void> dispose() async {
    await controller.removeLayer(sourceLayerId);
    await controller.removeSource(sourceLayerId);
    hasInitialized = false;
  }

  static Map<String, dynamic> createGeoJson(List<EewV1> items) =>
      <String, dynamic>{
        'type': 'FeatureCollection',
        'features': items
            .map(
              (e) => {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    e.longitude,
                    e.latitude,
                  ],
                },
                'properties': _EewHypocenterProperties(
                  depth: e.depth ?? 0,
                  magnitude: e.magnitude ?? 0,
                  isLowPrecise:
                      e.isIpfOnePoint || e.isLevelEew || (e.isPlum ?? false),
                ).toJson(),
              },
            )
            .toList(),
      };

  static String get hypocenterIconId => 'hypocenter';
  static String get hypocenterLowPreciseIconId => 'hypocenter-low-precise';

  static String get sourceLayerId => 'hypocenter';
}

class _EewPsWaveService {
  _EewPsWaveService({
    required this.controller,
    required this.travelTimeMap,
  }) : _children = (
          _EewPWaveLineService(controller: controller),
          _EewSWaveLineService(controller: controller),
          //  _EewPWaveFillService(controller: controller),
          _EewSWaveFillService(controller: controller),
        );

  final MapLibreMapController controller;
  final TravelTimeDepthMap travelTimeMap;

  late final (
    _EewPWaveLineService,
    _EewSWaveLineService,
    // _EewPWaveFillService,
    _EewSWaveFillService
  ) _children;

  Future<void> init() async {
    // datasource
    await controller.removeSource(sourceId);
    await controller.addGeoJsonSource(
      sourceId,
      createGeoJson([]),
    );
    // line
    await (
      _children.$1.init(),
      _children.$2.init(),
    ).wait;
    // fill
    await _children.$3.init();
    //_children.$4.init(),
  }

  List<(EewV1, bool isWarning)> _cachedEews = [];

  /// 表示するEEWが0件になってから GeoJSON Sourceを更新したかどうか
  bool didUpdatedSinceZero = false;

  Future<void> tick({
    required DateTime now,
  }) async {
    final results = <(TravelTimeResult, lat_lng.LatLng, bool isWarning)>[];
    // 表示EEWが1件以上だったら、didUpdatedSinceZeroをfalseにする
    if (_cachedEews.isNotEmpty) {
      didUpdatedSinceZero = false;
    }
    // 表示EEWが0件 かつ GeoJSON Sourceを更新したことがある場合は何もしない
    if (_cachedEews.isEmpty && didUpdatedSinceZero) {
      return;
    }
    for (final e in _cachedEews) {
      final eew = e.$1;
      final depth = eew.depth;
      final originTime = eew.originTime;
      final (lat, lng) = (eew.latitude, eew.longitude);

      if (lat == null || lng == null || depth == null || originTime == null) {
        continue;
      }
      final travel = travelTimeMap.getTravelTime(
        depth,
        //  as sec
        now
                .difference(
                  originTime,
                )
                .inMilliseconds /
            1000,
      );
      results.add(
        (travel, lat_lng.LatLng(lat, lng), e.$2),
      );
    }
    // update GeoJSON
    final geoJson = createGeoJson(results);
    await controller.setGeoJsonSource(
      sourceId,
      geoJson,
    );
    if (results.isEmpty) {
      didUpdatedSinceZero = true;
    }
  }

  // ignore: use_setters_to_change_properties
  void update(List<(EewV1, bool isWarning)> items) => _cachedEews = items;

  static Map<String, dynamic> createGeoJson(
    List<(TravelTimeResult, lat_lng.LatLng, bool isWarning)> results,
  ) =>
      {
        'type': 'FeatureCollection',
        'features': [
          // S-wave
          for (final type in _WaveType.values)
            for (final result in results)
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [
                    [
                      // 0...360
                      for (final bearing
                          in List<int>.generate(91, (index) => index * 4))
                        () {
                          final latLng = const latlong2.Distance().offset(
                            latlong2.LatLng(
                              result.$2.lat,
                              result.$2.lon,
                            ),
                            ((type == _WaveType.sWave
                                        ? result.$1.sDistance ?? 0
                                        : result.$1.pDistance ?? 0) *
                                    1000)
                                .toInt(),
                            bearing,
                          );
                          return [latLng.longitude, latLng.latitude];
                        }(),
                    ]
                  ],
                },
                'properties': {
                  'is_warning': result.$3,
                  'type': type.name,
                },
              },
        ],
      };

  Future<void> dispose() => (
        controller.removeLayer(sourceId),
        _children.$1.dispose(),
        _children.$2.dispose(),
      ).wait.then(
            (_) => controller.removeSource(sourceId),
          );

  static String get sourceId => 'ps-wave';
}

enum _WaveType {
  pWave,
  sWave,
  ;
}

class _EewPWaveLineService {
  _EewPWaveLineService({
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> init() async {
    await dispose();
    await controller.addLineLayer(
      _EewPsWaveService.sourceId,
      layerId,
      LineLayerProperties(
        lineColor: Colors.blueAccent.toHexStringRGB(),
        lineCap: 'round',
      ),
      filter: [
        '==',
        'type',
        _WaveType.pWave.name,
      ],
    );
  }

  Future<void> dispose() => controller.removeLayer(layerId);

  static String get layerId => 'p-wave-line';
}

class _EewSWaveLineService {
  _EewSWaveLineService({
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> init() async {
    await dispose();
    await controller.addLineLayer(
      _EewPsWaveService.sourceId,
      layerId(isWarning: true),
      LineLayerProperties(
        lineColor: Colors.redAccent.toHexStringRGB(),
        lineWidth: 2,
        lineCap: 'round',
      ),
      filter: [
        'all',
        ['==', 'type', _WaveType.sWave.name],
        ['==', 'is_warning', true],
      ],
    );

    await controller.addLineLayer(
      _EewPsWaveService.sourceId,
      layerId(isWarning: false),
      LineLayerProperties(
        lineColor: Colors.orangeAccent.toHexStringRGB(),
        lineWidth: 2,
        lineCap: 'round',
      ),
      filter: [
        'all',
        ['==', 'type', _WaveType.sWave.name],
        ['==', 'is_warning', false],
      ],
    );
  }

  Future<void> dispose() => (
        controller.removeLayer(layerId(isWarning: true)),
        controller.removeLayer(layerId(isWarning: false)),
      ).wait;

  static String layerId({required bool isWarning}) => 's-wave-line-$isWarning';
}
/*
class _EewPWaveFillService {
  _EewPWaveFillService({
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> init() async {
    await dispose();
    await controller.addFillLayer(
      _EewPsWaveService.sourceId,
      layerId,
      FillLayerProperties(
        fillColor: Colors.blue.toHexStringRGB(),
        fillOpacity: 0.2,
      ),
      filter: [
        '==',
        'type',
        _WaveType.pWave.name,
      ],
      belowLayerId: _EewPWaveLineService.layerId,
    );
  }

  Future<void> dispose() => controller.removeLayer(layerId);

  static String get layerId => 'p-wave-fill';
}*/

class _EewSWaveFillService {
  _EewSWaveFillService({
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> init() async {
    await dispose();
    await controller.addFillLayer(
      _EewPsWaveService.sourceId,
      layerId(isWarning: true),
      FillLayerProperties(
        fillColor: Colors.red.toHexStringRGB(),
        fillOpacity: 0.2,
      ),
      filter: [
        '==',
        'type',
        _WaveType.sWave.name,
      ],
      belowLayerId: BaseLayer.countriesFill.name,
    );
    await controller.addFillLayer(
      _EewPsWaveService.sourceId,
      layerId(isWarning: false),
      FillLayerProperties(
        fillColor: Colors.orangeAccent.toHexStringRGB(),
        fillOpacity: 0.2,
      ),
      filter: [
        '==',
        'type',
        _WaveType.sWave.name,
      ],
      belowLayerId: BaseLayer.countriesFill.name,
    );
  }

  Future<void> dispose() => (
        controller.removeLayer(layerId(isWarning: true)),
        controller.removeLayer(layerId(isWarning: false)),
      ).wait;

  static String layerId({
    required bool isWarning,
  }) =>
      's-wave-fill-$isWarning';
}

class _ShakeDetectionBorderService {
  _ShakeDetectionBorderService({
    required this.controller,
    required this.intensityColorModel,
  });

  final MapLibreMapController controller;
  final IntensityColorModel intensityColorModel;

  Future<void> init(List<ShakeDetectionKmoniMergedEvent> events) async {
    await dispose();
    await controller.addGeoJsonSource(
      sourceId,
      createGeoJson(events),
    );
    const allLevels = ShakeDetectionLevel.values;
    for (final level in allLevels) {
      await controller.addLineLayer(
        sourceId,
        layerId(level: level),
        LineLayerProperties(
          lineColor: level.color.toHexStringRGB(),
          lineWidth: [
            'interpolate',
            ['linear'],
            ['zoom'],
            3,
            2,
            20,
            10,
          ],
          lineCap: 'round',
          lineSortKey: level.index,
        ),
        filter: [
          '==',
          'level',
          level.name,
        ],
      );
    }
  }

  Future<void> dispose() async {
    for (final level in ShakeDetectionLevel.values) {
      await controller.removeLayer(layerId(level: level));
    }
    await controller.removeSource(sourceId);
  }

  Future<void> update(List<ShakeDetectionKmoniMergedEvent> events) async {
    final geoJson = createGeoJson(events);
    await controller.setGeoJsonSource(
      sourceId,
      geoJson,
    );
  }

  Map<String, dynamic> createGeoJson(
    List<ShakeDetectionKmoniMergedEvent> events,
  ) {
    final grids = createGrids(events);
    final json = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': [
        for (final grid in grids)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [
                  grid.topLeft.lon,
                  grid.topLeft.lat,
                ],
                [
                  grid.topLeft.lon + gridSize,
                  grid.topLeft.lat,
                ],
                [
                  grid.topLeft.lon + gridSize,
                  grid.topLeft.lat + gridSize,
                ],
                [
                  grid.topLeft.lon,
                  grid.topLeft.lat + gridSize,
                ],
                [
                  grid.topLeft.lon,
                  grid.topLeft.lat,
                ],
              ],
            },
            'properties': {
              'level': grid.level.name,
            },
          },
      ],
    };
    return json;
  }

  Future<void> setVisibility({required bool isVisible}) async {
    if (isVisible) {
      _isVisible = true;
      await [
        for (final level in ShakeDetectionLevel.values)
          controller.setLayerVisibility(
            layerId(level: level),
            true,
          ),
      ].wait;
    } else {
      _isVisible = false;
      await [
        for (final level in ShakeDetectionLevel.values)
          controller.setLayerVisibility(
            layerId(level: level),
            false,
          ),
      ].wait;
    }
  }

  bool _isVisible = true;

  Future<void> tick() async {
    final milliseconds = DateTime.now().millisecondsSinceEpoch;
    if (milliseconds % 1000 < 500) {
      if (_isVisible) {
        return;
      }
      await setVisibility(isVisible: true);
    } else {
      if (!_isVisible) {
        return;
      }
      await setVisibility(isVisible: false);
    }
  }

  static const gridSize = 0.75;

  List<
      ({
        lat_lng.LatLng bottomRight,
        lat_lng.LatLng topLeft,
        ShakeDetectionLevel level,
      })> createGrids(
    List<ShakeDetectionKmoniMergedEvent> events,
  ) {
    // 境界を作成し、内包するグリッドを取得する
    final grids = <({
      lat_lng.LatLng topLeft,
      lat_lng.LatLng bottomRight,
      ShakeDetectionLevel level,
    })>[];
    for (final event in events
        .map((e) => e.regions)
        .flattened
        .map((e) => e.points)
        .flattened) {
      final latLng = event.point.location;
      final lat = latLng.latitude;
      final lng = latLng.longitude;

      final latCount = lat ~/ gridSize;
      final lngCount = lng ~/ gridSize;

      final topLeft = lat_lng.LatLng(
        latCount * gridSize,
        lngCount * gridSize,
      );
      final bottomRight = lat_lng.LatLng(
        (latCount + 1) * gridSize,
        (lngCount + 1) * gridSize,
      );
      final level =
          ShakeDetectionLevel.fromJmaForecastIntensity(event.intensity);

      final existingIndex = grids.indexWhereOrNull(
        (e) => e.topLeft == topLeft && e.bottomRight == bottomRight,
      );
      if (existingIndex == null) {
        grids.add(
          (
            topLeft: topLeft,
            bottomRight: bottomRight,
            level: level,
          ),
        );
      } else {
        final existing = grids[existingIndex];
        if (existing.level < level) {
          grids[existingIndex] = (
            topLeft: topLeft,
            bottomRight: bottomRight,
            level: level,
          );
        }
      }
    }
    return grids;
  }

  static String layerId({required ShakeDetectionLevel level}) =>
      'shake-detection-border-${level.name}';

  static String get sourceId => 'shake-detection-border';
}

class _EewEstimatedIntensityCalculatedRegionService {
  _EewEstimatedIntensityCalculatedRegionService({required this.controller})
      : lock = Lock();

  final MapLibreMapController controller;
  final Lock lock;

  Future<void> init(IntensityColorModel colorModel) async => lock.synchronized(
        () async {
          await dispose();
          await [
            // 各予想震度ごとにFill Layerを追加
            for (final intensity in JmaForecastIntensity.values)
              controller.addLayer(
                'eqmonitor_map',
                getFillLayerId(intensity),
                FillLayerProperties(
                  fillColor: colorModel
                      .fromJmaForecastIntensity(intensity)
                      .background
                      .toHexStringRGB(),
                ),
                filter: [
                  'in',
                  ['get', 'code'],
                  [
                    'literal',
                    <String>[],
                  ]
                ],
                sourceLayer: 'areaForecastLocalE',
                belowLayerId: BaseLayer.areaForecastLocalELine.name,
              ),
          ].wait;
        },
        timeout: const Duration(seconds: 5),
      );

  /// 予想震度を更新する
  /// [areas] は Map{予想震度, 地域コード[]}
  Future<void> update(Map<JmaForecastIntensity, List<String>> areas) => [
        // 各予想震度ごとにFill Layerを追加
        for (final intensity in JmaForecastIntensity.values)
          controller.setFilter(
            getFillLayerId(intensity),
            [
              'in',
              ['get', 'code'],
              [
                'literal',
                areas[intensity] ?? [],
              ]
            ],
          ),
      ].wait;

  Future<void> dispose() => [
        for (final intensity in JmaForecastIntensity.values)
          controller.removeLayer(getFillLayerId(intensity)),
      ].wait;

  Future<void> onIntensityColorModelChanged(IntensityColorModel model) =>
      dispose().then(
        (_) => init(model),
      );

  static Map<JmaForecastIntensity, List<String>> transform(
    Map<String, double> regions,
  ) {
    // Map<予想震度, List<地域コード>> に変換する
    final regionsIntensityGrouped = <JmaForecastIntensity, List<String>>{};
    for (final entry in regions.entries) {
      final intensity = JmaForecastIntensity.fromRealtimeIntensity(entry.value);
      if (intensity == null) {
        continue;
      }
      if (!regionsIntensityGrouped.containsKey(intensity)) {
        regionsIntensityGrouped[intensity] = [entry.key];
      } else {
        regionsIntensityGrouped[intensity]!.add(entry.key);
      }
    }
    return regionsIntensityGrouped;
  }

  static String getFillLayerId(JmaForecastIntensity intensity) {
    final base = intensity.type
        .replaceAll('-', 'low')
        .replaceAll('+', 'high')
        .replaceAll('不明', 'unknown');
    return '$_EewEstimatedIntensityCalculatedRegionService-fill-$base';
  }
}

class _EewEstimatedIntensityCalculatedCityService {
  _EewEstimatedIntensityCalculatedCityService({required this.controller})
      : lock = Lock();

  final MapLibreMapController controller;
  final Lock lock;

  Future<void> init(IntensityColorModel colorModel) => lock.synchronized(
        () async {
          await dispose();
          await [
            // 各予想震度ごとにFill Layerを追加
            for (final intensity in JmaForecastIntensity.values)
              controller.addLayer(
                'eqmonitor_map',
                getFillLayerId(intensity),
                FillLayerProperties(
                  fillColor: colorModel
                      .fromJmaForecastIntensity(intensity)
                      .background
                      .toHexStringRGB(),
                ),
                filter: [
                  'in',
                  ['get', 'regioncode'],
                  [
                    'literal',
                    <String>[],
                  ]
                ],
                sourceLayer: 'areaInformationCityQuake',
                belowLayerId: BaseLayer.areaForecastLocalELine.name,
              ),
          ].wait;
        },
        timeout: const Duration(seconds: 5),
      );

  /// 予想震度を更新する
  /// [areas] は Map{予想震度, 地域コード[]}
  Future<void> update(Map<JmaForecastIntensity, List<String>> areas) => [
        // 各予想震度ごとにFill Layerを追加
        for (final intensity in JmaForecastIntensity.values)
          controller.setFilter(
            getFillLayerId(intensity),
            [
              'in',
              ['get', 'regioncode'],
              [
                'literal',
                areas[intensity] ?? [],
              ]
            ],
          ),
      ].wait;

  Future<void> dispose() => [
        for (final intensity in JmaForecastIntensity.values)
          controller.removeLayer(getFillLayerId(intensity)),
      ].wait;

  Future<void> onIntensityColorModelChanged(IntensityColorModel model) =>
      dispose().then(
        (_) => init(model),
      );

  static Map<JmaForecastIntensity, List<String>> transform(
    Map<String, double> regions,
  ) {
    // Map<予想震度, List<地域コード>> に変換する
    final regionsIntensityGrouped = <JmaForecastIntensity, List<String>>{};
    for (final entry in regions.entries) {
      final intensity = JmaForecastIntensity.fromRealtimeIntensity(entry.value);
      if (intensity == null) {
        continue;
      }
      if (!regionsIntensityGrouped.containsKey(intensity)) {
        regionsIntensityGrouped[intensity] = [entry.key];
      } else {
        regionsIntensityGrouped[intensity]!.add(entry.key);
      }
    }
    return regionsIntensityGrouped;
  }

  static String getFillLayerId(JmaForecastIntensity intensity) {
    final base = intensity.type
        .replaceAll('-', 'low')
        .replaceAll('+', 'high')
        .replaceAll('不明', 'unknown');
    return '$_EewEstimatedIntensityCalculatedCityService-fill-$base';
  }
}

class _CurrentLocationIconService {
  _CurrentLocationIconService({required this.controller});

  final MapLibreMapController controller;

  Future<void> init() async {
    await controller.addGeoJsonSource(
      layerId,
      {
        'type': 'FeatureCollection',
        'features': <void>[],
      },
    );

    await controller.addSymbolLayer(
      layerId,
      layerId,
      const SymbolLayerProperties(
        iconImage: 'current-location',
        iconSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          3,
          0.1,
          20,
          1,
        ],
        iconAllowOverlap: true,
      ),
      sourceLayer: layerId,
    );
  }

  Future<void> dispose() async {
    await controller.removeLayer(layerId);
    await controller.removeSource(layerId);
  }

  Future<void> update((double lat, double lng) position) async {
    await controller.setGeoJsonSource(
      layerId,
      {
        'type': 'FeatureCollection',
        'features': <void>[
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                position.$2,
                position.$1,
              ],
            },
          },
        ],
      },
    );
  }

  static String get layerId => 'current-location';
}

@freezed
class _EewHypocenterProperties with _$EewHypocenterProperties {
  const factory _EewHypocenterProperties({
    required int depth,
    required double magnitude,
    required bool isLowPrecise,
  }) = __EewHypocenterProperties;

  // ignore: unused_element
  factory _EewHypocenterProperties.fromJson(Map<String, dynamic> json) =>
      _$$_EewHypocenterPropertiesImplFromJson(json);
}

extension ListLatLngEx on List<lat_lng.LatLng> {
  LatLngBounds get toBounds {
    final latLngs = this;
    final latLngsSorted = latLngs.sorted(
      (a, b) => a.lat.compareTo(b.lat),
    );
    final latMin = latLngsSorted.first.lat;
    final latMax = latLngsSorted.last.lat;
    final lngs = latLngsSorted.where(
      (e) => e.lat == latMin || e.lat == latMax,
    );
    final lngsSorted = lngs.sorted(
      (a, b) => a.lon.compareTo(b.lon),
    );
    final lngMin = lngsSorted.first.lon;
    final lngMax = lngsSorted.last.lon;
    return LatLngBounds(
      southwest: LatLng(
        latMin,
        lngMin,
      ),
      northeast: LatLng(
        latMax,
        lngMax,
      ),
    );
  }
}
