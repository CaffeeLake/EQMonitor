import 'dart:io';

import 'package:kyoshin_observation_point_converter_internal/kyoshin_observation_point_converter_internal.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : null;
  if (path == null || path.isEmpty) {
    print("Usage: kyoshin_observation_point_converter_internal <path>");
    return;
  }
  final converter = KyoshinObservationPointConverter();
  print("Loading GeoJSON...");
  final geojson = await converter.loadMap();
  print("Converting Kyoshin Observation Point...");
  final points = await converter.readFile(path);
  final table = await converter.convert(points, geojson);
  // delete output file if exists
  final file = (
    json: File("kyoshin_observation_point.json"),
    binary: File("kyoshin_observation_point.pb"),
  );
  if (await file.json.exists()) {
    await file.json.delete();
  }
  if (await file.binary.exists()) {
    await file.binary.delete();
  }

  // json
  await file.json.writeAsString(table.toBuilder().writeToJson());
  // binary
  await file.binary.writeAsBytes(table.writeToBuffer());

  print("Done.");
}
