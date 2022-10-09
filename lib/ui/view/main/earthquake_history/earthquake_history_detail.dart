import 'dart:developer';

import 'package:eqmonitor/model/setting/jma_intensity_color_model.dart';
import 'package:eqmonitor/provider/init/map_area_forecast_local_e.dart';
import 'package:eqmonitor/provider/init/parameter_earthquake.dart';
import 'package:eqmonitor/provider/theme_providers.dart';
import 'package:eqmonitor/schema/local/prefecture/map_polygon.dart';
import 'package:eqmonitor/schema/remote/dmdata/commonHeader.dart';
import 'package:eqmonitor/schema/remote/dmdata/eq-information/earthquake-information.dart';
import 'package:eqmonitor/schema/remote/dmdata/eq-information/earthquake-information/intensity/region.dart';
import 'package:eqmonitor/schema/remote/dmdata/eq-information/earthquake-information/intensity/station.dart';
import 'package:eqmonitor/schema/remote/dmdata/eq-information/earthquake.dart';
import 'package:eqmonitor/schema/remote/dmdata/parameter-earthquake/parameter-earthquake.dart';
import 'package:eqmonitor/ui/theme/jma_intensity.dart';
import 'package:eqmonitor/ui/view/widget/map/base_map.dart';
import 'package:eqmonitor/utils/map/map_global_offset.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

import '../../../../provider/setting/intensity_color_provider.dart';
import '../../../../schema/remote/supabase/telegram.dart';
import '../../../view/widget/intensity_widget.dart';

class EarthquakeHistoryDetailPage extends HookConsumerWidget {
  EarthquakeHistoryDetailPage({
    super.key,
    required this.telegrams,
  });

  List<Telegram> telegrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(jmaIntensityColorProvider);
    // 地震情報を解析していきます
    final vxse51Telegrams = <CommonHead>[];
    final vxse52Telegrams = <CommonHead>[];
    final vxse53Telegrams = <CommonHead>[];
    final vxse61Telegrams = <CommonHead>[];
    for (final e in telegrams) {
      switch (e.type) {
        case 'VXSE51':
          vxse51Telegrams.add(CommonHead.fromJson(e.data!));
          break;
        case 'VXSE52':
          vxse52Telegrams.add(CommonHead.fromJson(e.data!));
          break;
        case 'VXSE53':
          vxse53Telegrams.add(CommonHead.fromJson(e.data!));
          break;
        case 'VXSE61':
          vxse61Telegrams.add(CommonHead.fromJson(e.data!));
          break;
        default:
      }
    }

    final latestVxse51Head =
        (vxse51Telegrams.isEmpty) ? null : vxse51Telegrams.last;
    final latestVxse51Info = (latestVxse51Head == null)
        ? null
        : EarthquakeInformation.fromJson(latestVxse51Head.body);
    final latestVxse52Head =
        (vxse52Telegrams.isEmpty) ? null : vxse52Telegrams.last;
    final latestVxse52Info = (latestVxse52Head == null)
        ? null
        : EarthquakeInformation.fromJson(latestVxse52Head.body);
    final latestVxse53Head =
        (vxse53Telegrams.isEmpty) ? null : vxse53Telegrams.last;
    final latestVxse53Info = (latestVxse53Head == null)
        ? null
        : EarthquakeInformation.fromJson(latestVxse53Head.body);
    final latestVxse61Head =
        (vxse61Telegrams.isEmpty) ? null : vxse61Telegrams.last;
    final latestVxse61Info = (latestVxse61Head == null)
        ? null
        : EarthquakeInformation.fromJson(latestVxse61Head.body);

    /// 速報かどうか
    final isSokuhou = latestVxse61Head == null && latestVxse53Head == null;

    /// ## 震源要素
    /// VXSE61 -> VXSE53 -> VXSE52
    final component = latestVxse61Info?.earthquake ??
        latestVxse53Info?.earthquake ??
        latestVxse52Info?.earthquake;

    /// ## 各地の震度
    /// VXSE53 -> VXSE51
    final intensity =
        latestVxse53Info?.intensity ?? latestVxse51Info?.intensity;
    final maxInt = JmaIntensity.values.firstWhere(
      (e) => e.name == (intensity?.maxInt ?? ''),
      orElse: () => JmaIntensity.Unknown,
    );

    /// ## 最新のComment
    /// VXSE61 -> VXSE53 -> VXSE52 -> VXSE51
    final comment = latestVxse61Info?.comments ??
        latestVxse53Info?.comments ??
        latestVxse52Info?.comments ??
        latestVxse51Info?.comments;

    return Scaffold(
      appBar: AppBar(
        title: Text('地震${isSokuhou ? "速報" : "情報"}'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Card(
              color: maxInt.fromUser(colors).withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(),
                  // 発生時刻
                  Text(
                    '${DateFormat('yyyy/MM/dd HH:mm').format(component!.originTime.toLocal())}頃',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              const Text('最大震度'),
                              Row(
                                textBaseline: TextBaseline.alphabetic,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    maxInt.name
                                        .replaceAll(RegExp(r'[^0-9]'), ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 55,
                                    ),
                                  ),
                                  Text(
                                    maxInt.name
                                        .replaceAll(RegExp(r'[0-9]'), '')
                                        .replaceAll('+', '強')
                                        .replaceAll('-', '弱')
                                        .replaceAll('?', '不明'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(),
                      Flexible(
                        flex: 2,
                        child: Column(
                          children: [
                            // 震央地
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '震央地',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Text(
                                  component.hypoCenter.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30,
                                  ),
                                ),
                              ],
                            ),
                            FittedBox(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  // Magunitude
                                  if (component.magnitude.condition ==
                                      null) ...[
                                    const Text(
                                      'M',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      (component.magnitude.condition != null)
                                          ? component
                                              .magnitude.condition!.description
                                          : component.magnitude.value
                                              .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 45,
                                      ),
                                    ),
                                  ],
                                  const VerticalDivider(),
                                  // Depth
                                  if (component.hypoCenter.depth.condition ==
                                      null) ...[
                                    Text(
                                      component.hypoCenter.depth.type,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      (component.hypoCenter.depth.condition !=
                                              null)
                                          ? component.hypoCenter.depth
                                              .condition!.description
                                          : component.hypoCenter.depth.value
                                              .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 45,
                                      ),
                                    ),
                                    Text(
                                      component.hypoCenter.depth.unit,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  ] else ...[
                                    Text(
                                      component.hypoCenter.depth.type,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      component.hypoCenter.depth.condition!
                                          .description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 45,
                                      ),
                                    )
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Text(
            (StringBuffer()
                  ..writeAll(
                    <String>[
                      if (comment?.forecast?.text != null)
                        '${comment!.forecast!.text}\n',
                      if (comment?.comments?.text != null)
                        '${comment!.comments!.text}\n',
                      if (comment?.free != null) comment!.free!,
                    ],
                  ))
                .toString(),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ref.watch(themeProvider.notifier).isDarkMode
                    ? const Color.fromARGB(255, 22, 28, 45)
                    : const Color.fromARGB(255, 207, 219, 255),
              ),
              child: Stack(
                children: [
                  InteractiveViewer(
                    maxScale: 20,
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          // マップベース
                          const BaseMapWidget(),
                          // Region毎の震度
                          MapRegionIntensityWidget(
                            regions: intensity?.regions ?? <Region>[],
                            stations: intensity?.stations ?? <Station>[],
                          ),
                          // 震央位置
                          MapHypoCenterMapWidget(
                            component: component,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          for (final i in JmaIntensity.values)
                            if (i == JmaIntensity.over)
                              const SizedBox.shrink()
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IntensityWidget(
                                    intensity: i,
                                    size: 25,
                                    opacity: 1,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapRegionIntensityWidget extends ConsumerWidget {
  const MapRegionIntensityWidget({
    super.key,
    required this.regions,
    required this.stations,
  });
  final List<Region> regions;
  final List<Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapSource = ref.watch(mapAreaForecastLocalEProvider);
    final parameterEarthquake = ref.watch(parameterEarthquakeProvider);

    return CustomPaint(
      painter: MapRegionIntensityPainter(
        mapPolygons: mapSource,
        regions: regions,
        stations: stations,
        colors: ref.watch(jmaIntensityColorProvider),
        parameterEarthquake: parameterEarthquake,
      ),
      size: Size.infinite,
    );
  }
}

class MapRegionIntensityPainter extends CustomPainter {
  MapRegionIntensityPainter({
    required this.mapPolygons,
    required this.regions,
    required this.stations,
    required this.colors,
    required this.parameterEarthquake,
  });
  final List<MapPolygon> mapPolygons;
  final List<Region> regions;
  final List<Station> stations;
  final JmaIntensityColorModel colors;
  final ParameterEarthquake parameterEarthquake;

  @override
  void paint(Canvas canvas, Size size) {
    log('Redraw');
    // Regionの描画
    for (final region in regions) {
      // region.codeが一致するMapPolygonを探す
      try {
        final mapRegionPolygons = mapPolygons.where(
          (element) => element.code == region.code,
        );
        for (final mapPolygon in mapRegionPolygons) {
          canvas
            ..drawPath(
              mapPolygon.path,
              Paint()
                ..color = JmaIntensity.values
                    .firstWhere(
                      (e) => e.name == region.maxInt.toString(),
                      orElse: () => JmaIntensity.Error,
                    )
                    .fromUser(colors)
                ..isAntiAlias = true
                ..strokeCap = StrokeCap.round,
            )
            ..drawPath(
              mapPolygon.path,
              Paint()
                ..color = const Color.fromARGB(255, 255, 255, 255)
                ..isAntiAlias = true
                ..style = PaintingStyle.stroke,
            );
        }
      } on Exception catch (e) {
        Logger().e(e, region.code);
      }
    }
    // TODO(YumNumm): 観測点の描画実装
    /*for (final station in stations) {
      final param =
          parameterEarthquake.items.firstWhere((e) => e.code == station.code);
      final offset = MapGlobalOffset.latLonToGlobalPoint(
        LatLng(param.latitude, param.longitude),
      ).toLocalOffset(const Size(476, 927.4));
      canvas.drawCircle(
        offset,
        1,
        Paint()
          ..color = JmaIntensity.values
              .firstWhere((e) => e.name == station.intensity)
              .color
              .withBlue(100)
          ..isAntiAlias = true
          ..style = PaintingStyle.fill,
      );
    }
    */
  }

  @override
  bool shouldRepaint(MapRegionIntensityPainter oldDelegate) {
    return oldDelegate.mapPolygons != mapPolygons ||
        oldDelegate.regions != regions ||
        oldDelegate.colors != colors ||
        oldDelegate.parameterEarthquake != parameterEarthquake ||
        oldDelegate.stations != stations;
  }
}

class MapHypoCenterMapWidget extends StatelessWidget {
  const MapHypoCenterMapWidget({
    super.key,
    required this.component,
  });
  final EarthQuakeInformationComponent? component;

  @override
  Widget build(BuildContext context) {
    if (component == null) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: MapHypoCenterPainter(
        component: component!,
      ),
      size: Size.infinite,
    );
  }
}

class MapHypoCenterPainter extends CustomPainter {
  MapHypoCenterPainter({
    required this.component,
  });

  final EarthQuakeInformationComponent component;

  @override
  void paint(Canvas canvas, Size size) {
    {
      final offset = MapGlobalOffset.latLonToGlobalPoint(
        LatLng(
          component.hypoCenter.coordinateComponent.latitude!.value,
          component.hypoCenter.coordinateComponent.longitude!.value,
        ),
      ).toLocalOffset(const Size(476, 927.4));
      // ×印を描く
      {
        final textPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '×',
                style: TextStyle(
                  fontSize: 14,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = 1
                    ..color = const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            offset.dx - (textPainter.width / 2),
            offset.dy - (textPainter.height / 2),
          ),
        );
      }
      {
        final textPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '×',
                style: TextStyle(
                  fontSize: 14,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = 0.3
                    ..color = const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            offset.dx - (textPainter.width / 2),
            offset.dy - (textPainter.height / 2),
          ),
        );
      }
      {
        final textPainter = TextPainter(
          text: const TextSpan(
            children: [
              TextSpan(
                text: '×',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            offset.dx - (textPainter.width / 2),
            offset.dy - (textPainter.height / 2),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MapHypoCenterPainter oldDelegate) =>
      oldDelegate.component != component;
}

class MapStationIntensityWidget extends ConsumerWidget {
  const MapStationIntensityWidget({
    super.key,
    required this.stations,
  });
  final List<Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //final allParameterEarthquakeItem = ref.watch(parameterEarthquakeProvider);

    final widgets = <Widget>[];

    // 各観測点の処理
    for (final station in stations) {
      try {
        // 緯度経度を取得
        //final param = allParameterEarthquakeItem.items
        //    .firstWhere((e) => e.code == station.code);
        // final offset = MapGlobalOffset.latLonToGlobalPoint(
        //   LatLng(param.latitude, param.longitude),
        // ).toLocalOffset(const Size(476, 927.4));
        // widgets.add(
        //   DecoratedBox(
        //     decoration: BoxDecoration(
        //       border: Border.all(
        //         color: Colors.red,
        //       ),
        //     ),
        //     child: Positioned(
        //       left: offset.dx,
        //       top: offset.dy,
        //       child: IntensityWidget(
        //         intensity: JmaIntensity.values
        //             .firstWhere((e) => e.name == station.intensity),
        //         size: 2,
        //         opacity: 1,
        //       ),
        //     ),
        //   ),
        // );
      } on Exception catch (_) {}
    }

    return Stack(
      children: widgets,
    );
  }
}
