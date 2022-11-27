import 'package:eqmonitor/ui/view/main/kmoni_map/map/eew_hypocenter_assuming.dart';
import 'package:eqmonitor/ui/view/main/kmoni_map/map/eew_hypocenter_normal.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../provider/earthquake/eew_provider.dart';

/// 緊急地震速報関連のWidget
class EewHypocentersWidget extends ConsumerWidget {
  const EewHypocentersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eews = ref.watch(eewProvider.select((value) => value.showEews));

    return Stack(
      children: <Widget>[
        for (final eew in eews)
          if (eew.eew.earthquake?.condition == '仮定震源要素' ||
              eew.eew.earthquake?.hypocenter.accuracy.epicenters[0] == 1)
            EewHypocenterAssumingMapWidget(
              eew: eew,
            )
          else
            EewHypocenterNormalMapWidget(
              eew: eew,
            ),
      ],
    );
  }
}
