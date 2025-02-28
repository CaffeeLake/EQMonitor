import 'package:eqapi_types/eqapi_types.dart';
import 'package:eqmonitor/core/component/intenisty/intensity_icon_type.dart';
import 'package:eqmonitor/core/provider/config/theme/intensity_color/intensity_color_provider.dart';
import 'package:eqmonitor/core/provider/config/theme/intensity_color/model/intensity_color_model.dart';
import 'package:eqmonitor/gen/fonts.gen.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class JmaForecastIntensityWidget extends ConsumerWidget {
  const JmaForecastIntensityWidget({
    required this.intensity,
    this.type = IntensityIconType.filled,
    this.customText,
    this.colorModel,
    super.key,
    this.size = 50,
  });
  final JmaForecastIntensity intensity;
  final IntensityIconType type;
  final double size;
  final String? customText;
  final IntensityColorModel? colorModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intensityColorModel =
        (colorModel ?? ref.watch(intensityColorProvider))!;
    final colorScheme = intensityColorModel.fromJmaForecastIntensity(intensity);
    final (fg, bg) = (colorScheme.foreground, colorScheme.background);
    // 震度の整数部分
    final intensityMainText =
        intensity.type.replaceAll('-', '').replaceAll('+', '');
    // 震度の弱・強の表記
    final intensitySubText = intensity.type.contains('-')
        ? '弱'
        : intensity.type.contains('+')
            ? '強'
            : '';

    return SizedBox(
      height: size,
      width: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: type == IntensityIconType.filled ? bg : null,
          // 角丸にする
          borderRadius: BorderRadius.circular(size / 5),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (customText != null)
                  Text(
                    customText!,
                    style: TextStyle(
                      color: fg,
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      fontFamily: FontFamily.jetBrainsMono,
                    ),
                  )
                else if (intensity == JmaForecastIntensity.unknown)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      intensityMainText,
                      style: TextStyle(
                        color: fg,
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        fontFamily: FontFamily.notoSansJP,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    intensityMainText,
                    style: TextStyle(
                      color: fg,
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      fontFamily: FontFamily.jetBrainsMono,
                    ),
                  ),
                  Text(
                    intensitySubText,
                    style: TextStyle(
                      color: fg,
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      fontFamily: FontFamily.notoSansJP,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JmaForecastIntensityIcon extends ConsumerWidget {
  const JmaForecastIntensityIcon({
    required this.intensity,
    required this.type,
    this.customText,
    super.key,
    this.size = 50,
    this.showSuffix = true,
  });
  final JmaForecastIntensity intensity;
  final IntensityIconType type;
  final double size;
  final String? customText;
  final bool showSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intensityColorModel = ref.watch(intensityColorProvider);
    final colorScheme = intensityColorModel.fromJmaForecastIntensity(intensity);
    final (fg, bg) = (colorScheme.foreground, colorScheme.background);
    // 震度の整数部分
    final intensityMainText =
        intensity.type.replaceAll('-', '').replaceAll('+', '');
    // 震度の弱・強の表記
    final suffix = intensity.type.contains('-')
        ? '-'
        : intensity.type.contains('+')
            ? '+'
            : '';
    final intensitySubText = intensity.type.contains('-')
        ? '弱'
        : intensity.type.contains('+')
            ? '強'
            : '';
    final borderColor = Color.lerp(
      bg,
      fg,
      0.3,
    )!;
    return switch (type) {
      IntensityIconType.small => SizedBox(
          height: size,
          width: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(
                color: borderColor,
                width: 5,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intensityMainText,
                      style: TextStyle(
                        color: fg,
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        fontFamily: FontFamily.jetBrainsMono,
                      ),
                    ),
                    Text(
                      suffix,
                      style: TextStyle(
                        color: fg,
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        fontFamily: FontFamily.jetBrainsMono,
                        fontFamilyFallback: const [FontFamily.notoSansJP],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      IntensityIconType.smallWithoutText => SizedBox(
          height: size,
          width: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(
                color: borderColor,
                width: 5,
              ),
            ),
          ),
        ),
      IntensityIconType.filled => SizedBox(
          height: size,
          width: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              // 角丸にする
              borderRadius: BorderRadius.circular(size / 5),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (customText != null)
                      Text(
                        customText!,
                        style: TextStyle(
                          color: fg,
                          fontSize: 100,
                          fontWeight: FontWeight.w900,
                          fontFamily: FontFamily.jetBrainsMono,
                        ),
                      )
                    else ...[
                      Text(
                        intensityMainText,
                        style: TextStyle(
                          color: fg,
                          fontSize: 100,
                          fontWeight: FontWeight.w900,
                          fontFamily: FontFamily.jetBrainsMono,
                        ),
                      ),
                      if (showSuffix)
                        Text(
                          intensitySubText,
                          style: TextStyle(
                            color: fg,
                            fontSize: 50,
                            fontWeight: FontWeight.w900,
                            fontFamily: FontFamily.jetBrainsMono,
                            fontFamilyFallback: const [FontFamily.notoSansJP],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    };
  }
}
