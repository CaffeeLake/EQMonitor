// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint, duplicate_ignore

part of 'shake_detection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fetchShakeDetectionEventsHash() =>
    r'c7a8c166b5fbb423b855af2eb2d6e49ebc4b7d77';

/// See also [_fetchShakeDetectionEvents].
@ProviderFor(_fetchShakeDetectionEvents)
final _fetchShakeDetectionEventsProvider =
    FutureProvider<List<ShakeDetectionEvent>>.internal(
  _fetchShakeDetectionEvents,
  name: r'_fetchShakeDetectionEventsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fetchShakeDetectionEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _FetchShakeDetectionEventsRef
    = FutureProviderRef<List<ShakeDetectionEvent>>;
String _$shakeDetectionHash() => r'b54028a1050a826cf92e29ce9e33ada581634836';

/// See also [ShakeDetection].
@ProviderFor(ShakeDetection)
final shakeDetectionProvider =
    AsyncNotifierProvider<ShakeDetection, List<ShakeDetectionEvent>>.internal(
  ShakeDetection.new,
  name: r'shakeDetectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shakeDetectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ShakeDetection = AsyncNotifier<List<ShakeDetectionEvent>>;
String _$shakeDetectionKmoniPointsMergedHash() =>
    r'06d31cd0761e6d90bfd490fe6a6a546fee9d17e4';

/// See also [ShakeDetectionKmoniPointsMerged].
@ProviderFor(ShakeDetectionKmoniPointsMerged)
final shakeDetectionKmoniPointsMergedProvider =
    AutoDisposeAsyncNotifierProvider<ShakeDetectionKmoniPointsMerged,
        List<ShakeDetectionKmoniMergedEvent>>.internal(
  ShakeDetectionKmoniPointsMerged.new,
  name: r'shakeDetectionKmoniPointsMergedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shakeDetectionKmoniPointsMergedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ShakeDetectionKmoniPointsMerged
    = AutoDisposeAsyncNotifier<List<ShakeDetectionKmoniMergedEvent>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
