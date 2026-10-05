import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/three_finger_scroll.dart';

class ThreeFingerScrollSetting extends StatefulWidget {
  const ThreeFingerScrollSetting({Key? key}) : super(key: key);

  @override
  State<ThreeFingerScrollSetting> createState() =>
      _ThreeFingerScrollSettingState();
}

class _ThreeFingerScrollSettingState extends State<ThreeFingerScrollSetting> {
  late double _value = threeFingerScrollPercent.toDouble();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('三本指スクロールの感度 (${_value.round()}%)'),
        Slider(
          min: kThreeFingerScrollPercentMin.toDouble(),
          max: kThreeFingerScrollPercentMax.toDouble(),
          divisions: (kThreeFingerScrollPercentMax -
                  kThreeFingerScrollPercentMin) ~/
              5,
          value: _value,
          onChanged: (v) => setState(() => _value = v),
          onChangeEnd: (v) => setThreeFingerScrollPercent(v.round()),
        ),
      ],
    );
  }
}
