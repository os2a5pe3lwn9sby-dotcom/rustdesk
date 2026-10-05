import 'package:flutter/foundation.dart';

class MacSpaceGroup {
  /// RustDesk display index, or -1 when the Mac shares Spaces across displays.
  final int display;
  final int count;
  final int current;
  const MacSpaceGroup(this.display, this.count, this.current);
}

/// Mission Control Spaces reported by a patched macOS peer, one group per
/// display.
class MacSpacesModel {
  final groups = ValueNotifier<List<MacSpaceGroup>>([]);

  void update(String value) {
    final result = <MacSpaceGroup>[];
    for (final part in value.split(',')) {
      final f = part.split(':').map(int.tryParse).toList();
      if (f.length != 3 || f.contains(null)) return;
      result.add(MacSpaceGroup(f[0]!, f[1]!, f[2]!));
    }
    groups.value = result;
  }

  void clear() => groups.value = [];

  int _indexFor(List<MacSpaceGroup> list, int display) {
    if (list.length == 1) return 0;
    return list.indexWhere((g) => g.display == display);
  }

  MacSpaceGroup? groupFor(int display) {
    final list = groups.value;
    final i = _indexFor(list, display);
    return i < 0 ? null : list[i];
  }

  /// Moves the highlight right away; the next report from the Mac confirms it.
  void nudge(int display, bool left) {
    final list = groups.value;
    final i = _indexFor(list, display);
    if (i < 0) return;
    final g = list[i];
    if (g.count < 1) return;
    final next = (g.current + (left ? -1 : 1)).clamp(0, g.count - 1);
    if (next == g.current) return;
    groups.value = List.of(list)
      ..[i] = MacSpaceGroup(g.display, g.count, next);
  }
}
