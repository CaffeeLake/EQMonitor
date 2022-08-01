// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:eqmonitor/const/kmoni/jma_intensity.dart';
import 'package:eqmonitor/schema/dmdata/eq-information/earthquake-information/hypocenter/depth/depth_condition.dart';
import 'package:eqmonitor/schema/dmdata/eq-information/earthquake-information/magnitude/magnitude_condition.dart';

///                                            テーブル"public.telegram"
///         列          |           タイプ            | 照合順序 | Null 値を許容 |            デフォルト
///---------------------+-----------------------------+----------+---------------+----------------------------------
/// id                  | bigint                      |          | not null      | generated by default as identity
/// type                | text                        |          | not null      |
/// time                | timestamp without time zone |          | not null      |
/// url                 | text                        |          | not null      |
/// image_url           | text                        |          |               |
/// headline            | text                        |          |               |
/// data                | jsonb                       |          |               |
/// maxint              | text                        |          |               |
/// magnitude           | real                        |          |               |
/// magnitude_condition | text                        |          |               |
/// depth               | integer                     |          |               |
/// lat                 | real                        |          |               |
/// lon                 | real                        |          |               |
/// serial_no           | integer                     |          |               |
/// event_id            | text                        |          |               |
/// hypo_name           | text                        |          |               |
/// hash                | text                        |          | not null      |
/// depth_condition     | text                        |          |               |
///
///インデックス:
///    "telegram_pkey" PRIMARY KEY, btree (id, hash)
///    "telegram_event_id_idx" btree (event_id)
///    "telegram_hash_key" UNIQUE CONSTRAINT, btree (hash)
///    "telegram_magnitude_idx" btree (magnitude)
///    "telegram_maxint_idx" btree (maxint)
///    "telegram_serial_no_idx" btree (serial_no)
///    "telegram_type_idx" btree (type)
///ポリシー:
///    POLICY "Enable read access for all users" FOR SELECT
///      USING (true)

class Telegram {
  Telegram({
    required this.id,
    required this.hash,
    required this.type,
    required this.time,
    required this.url,
    required this.imageUrl,
    required this.headline,
    required this.data,
    required this.maxint,
    required this.magnitude,
    required this.magnitudeCondition,
    required this.depth,
    required this.lat,
    required this.lon,
    required this.serialNo,
    required this.eventId,
    required this.depthCondition,
    required this.hypoName,
  });

  factory Telegram.fromJson(Map<String, dynamic> j) => Telegram(
        id: int.parse(j['id'].toString()),
        hash: j['hash'].toString(),
        type: j['type'].toString(),
        time: DateTime.parse(j['time'].toString()),
        url: j['url'].toString(),
        imageUrl: j['image_url'] as String?,
        headline: j['headline'] as String?,
        data: (j['data'] == null)
            ? null
            : json.decode(j['data'].toString()) as Map<String, dynamic>,
        maxint: (j['maxint'] == null)
            ? null
            : JmaIntensity.values.firstWhere(
                (e) => e.name == j['maxint'].toString(),
                orElse: () => JmaIntensity.Error,
              ),
        magnitude: double.tryParse(j['magnitude'].toString()),
        magnitudeCondition: (j['magnitude_condition'] == null)
            ? null
            : MagnitudeCondition.values.firstWhere(
                (e) => e.description == j['magnitude_condition']?.toString(),
                orElse: () => MagnitudeCondition.unknown,
              ),
        depth: int.tryParse(j['depth'].toString()),
        depthCondition: (j['depth_condition'] == null)
            ? null
            : DepthCondition.values.firstWhere(
                (e) => e.description == j['depth_condition'].toString(),
                orElse: () => DepthCondition.unknown,
              ),
        lat: double.tryParse(j['lat'].toString()),
        lon: double.tryParse(j['lon'].toString()),
        serialNo: int.tryParse(j['serial_no'].toString()),
        eventId: j['event_id'] as String?,
        hypoName: j['hypo_name']?.toString(),
      );

  Map<String, dynamic> toSqlBody() => <String, dynamic>{
        if (id != null) 'id': id,
        'hash': hash,
        'type': type,
        'time': time.toIso8601String(),
        'url': url,
        if (imageUrl != null) 'image_url': imageUrl,
        if (headline != null) 'headline': headline,
        if (data != null) 'data': jsonEncode(data),
        if (maxint != null) 'maxint': maxint?.name,
        if (magnitude != null) 'magnitude': magnitude,
        if (magnitudeCondition != null)
          if (magnitudeCondition != null)
            'magnitude_condition': magnitudeCondition?.description,
        if (depth != null) 'depth': depth,
        if (depthCondition != null)
          'depth_condition': depthCondition?.description,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (serialNo != null) 'serial_no': serialNo,
        if (eventId != null) 'event_id': eventId,
        if (hypoName != null) 'hypo_name': hypoName
      };

  ///	連番(PK)
  final int? id;

  /// [data]のSHA384ハッシュ値(PK)
  final String hash;

  ///	電文のデータ種類コード
  final String type;

  /// 地震発生時刻もしくは地震検知時刻
  final DateTime time;

  ///	電文データへのURL
  final String url;

  ///	震度分布画像へのURL
  final String? imageUrl;

  /// 情報の見出し、無い場合はNullとする
  final String? headline;

  /// WebSocketのdataを解凍したJSONデータ、バイナリデータの場合はNullとなる
  final Map<String, dynamic>? data;

  /// 最大震度を1, 2, 3, 4, 5-, 5+, 6-, 6+, 7 で記載する
  final JmaIntensity? maxint;

  /// マグニチュードの数値。不明時またはM8以上の巨大地震と推測される場合は Null とする
  final double? magnitude;

  /// マグニチュードの数値が求まらない事項を記載。Ｍ不明 又は Ｍ８を超える巨大地震 が入る
  final MagnitudeCondition? magnitudeCondition;

  /// 震源の深さ。不明時は Null とする
  final int? depth;

  /// 緯度を表現
  final double? lat;

  /// 経度を表現
  final double? lon;

  /// 現象ごとに割り振られたイベントIDの発表番号、無い場合はNullとする
  final int? serialNo;

  /// 現象ごとに割り振られたイベントID、無い場合はNullとする
  final String? eventId;

  /// 震央地名 不明な場合はNullとする
  final String? hypoName;

  final DepthCondition? depthCondition;
}
