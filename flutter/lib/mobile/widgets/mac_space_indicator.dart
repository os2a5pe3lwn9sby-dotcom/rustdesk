import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/mac_spaces_model.dart';

/// One square per Space on the shown display; the current one is filled.
class MacSpaceIndicator extends StatelessWidget {
  final MacSpacesModel model;
  final int display;

  const MacSpaceIndicator(
      {Key? key, required this.model, required this.display})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MacSpaceGroup>>(
      valueListenable: model.groups,
      builder: (context, _, __) {
        final g = model.groupFor(display);
        if (g == null || g.count < 1) return const SizedBox.shrink();
        final size = g.count > 10 ? 10.0 : 14.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              g.count,
              (i) => Container(
                width: size,
                height: size,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == g.current ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
