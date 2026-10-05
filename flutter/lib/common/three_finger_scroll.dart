import 'package:flutter_hbb/models/platform_model.dart';

const String kOptionThreeFingerScrollPercent = 'three-finger-scroll-percent';
const int kThreeFingerScrollPercentMin = 10;
const int kThreeFingerScrollPercentMax = 100;
const int kThreeFingerScrollPercentDefault = 35;

int? _percent;

int get threeFingerScrollPercent {
  final cached = _percent;
  if (cached != null) return cached;
  final saved =
      int.tryParse(bind.mainGetLocalOption(key: kOptionThreeFingerScrollPercent));
  return _percent = (saved ?? kThreeFingerScrollPercentDefault)
      .clamp(kThreeFingerScrollPercentMin, kThreeFingerScrollPercentMax)
      .toInt();
}

Future<void> setThreeFingerScrollPercent(int percent) async {
  _percent = percent;
  await bind.mainSetLocalOption(
      key: kOptionThreeFingerScrollPercent, value: percent.toString());
}

/// Pixels of finger travel per wheel step. 100% matches the original 4px.
double threeFingerScrollDivisor() => 400 / threeFingerScrollPercent;
