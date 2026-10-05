import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';

class ControlPanelItem {
  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  const ControlPanelItem(this.icon, this.label, this.onSelect);
}

/// A handle on the screen edge. Long-press to open the panel, slide to an
/// item and release to select it.
class ControlPanelHandle extends StatefulWidget {
  final List<ControlPanelItem> items;
  const ControlPanelHandle({Key? key, required this.items}) : super(key: key);

  @override
  State<ControlPanelHandle> createState() => _ControlPanelHandleState();
}

class _ControlPanelHandleState extends State<ControlPanelHandle> {
  bool _open = false;
  int? _hover;
  final List<GlobalKey> _keys = [];

  GlobalKey _keyAt(int i) {
    while (_keys.length <= i) {
      _keys.add(GlobalKey());
    }
    return _keys[i];
  }

  void _updateHover(Offset global) {
    int? hit;
    for (var i = 0; i < widget.items.length; i++) {
      final box = _keyAt(i).currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.size.contains(box.globalToLocal(global))) {
        hit = i;
        break;
      }
    }
    if (hit != _hover) {
      if (hit != null) HapticFeedback.selectionClick();
      setState(() => _hover = hit);
    }
  }

  void _close({bool select = false}) {
    final hover = _hover;
    setState(() {
      _open = false;
      _hover = null;
    });
    if (select && hover != null && hover < widget.items.length) {
      widget.items[hover].onSelect();
    }
  }

  Widget _handle() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) {
          HapticFeedback.mediumImpact();
          setState(() => _open = true);
        },
        onLongPressMoveUpdate: (d) => _updateHover(d.globalPosition),
        onLongPressEnd: (_) => _close(select: true),
        onLongPressCancel: () => _close(),
        child: Container(
          width: 28,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14)),
          ),
          child: const Icon(Icons.drag_indicator, color: Colors.white70),
        ),
      );

  Widget _panel() => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                Container(
                  key: _keyAt(i),
                  height: 52,
                  constraints: const BoxConstraints(minWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: _hover == i ? MyTheme.accent : Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.items[i].icon, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(widget.items[i].label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_handle(), if (_open) _panel()],
      ),
    );
  }
}
