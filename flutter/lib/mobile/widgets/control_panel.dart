import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const String _kOptionControlPanelPos = 'control-panel-pos';
const double _kHandleWidth = 60;
const double _kHandleHeight = 60;
const Duration _kOpenDelay = Duration(milliseconds: 100);
const double _kItemHeight = 52;
const double _kPanelGap = 8;
const Duration _kDoubleTapGap = Duration(milliseconds: 350);
const Duration _kTapMaxDuration = Duration(milliseconds: 250);
const double _kTapSlop = 12;

class ControlPanelItem {
  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  final Color color;
  const ControlPanelItem(this.icon, this.label, this.onSelect,
      {this.color = Colors.white});
}

/// A movable handle. Touch and hold to open the panel at once, slide to an
/// item and release to select it. Double-tap and keep the finger down to drag
/// the handle to another place; the place is remembered.
class ControlPanelHandle extends StatefulWidget {
  final List<ControlPanelItem> items;
  const ControlPanelHandle({Key? key, required this.items}) : super(key: key);

  @override
  State<ControlPanelHandle> createState() => _ControlPanelHandleState();
}

class _ControlPanelHandleState extends State<ControlPanelHandle> {
  // Position as a fraction of the free area, so it survives rotation.
  double _fx = 0;
  double _fy = 0.5;
  bool _open = false;
  bool _moving = false;
  int? _hover;
  final List<GlobalKey> _keys = [];

  DateTime? _lastTapUp;
  DateTime? _downAt;
  Offset? _downPos;
  int? _pointer;
  Timer? _openTimer;

  @override
  void initState() {
    super.initState();
    final parts = bind.mainGetLocalOption(key: _kOptionControlPanelPos).split(',');
    if (parts.length == 2) {
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      if (x != null && y != null) {
        _fx = x.clamp(0.0, 1.0).toDouble();
        _fy = y.clamp(0.0, 1.0).toDouble();
      }
    }
  }

  GlobalKey _keyAt(int i) {
    while (_keys.length <= i) {
      _keys.add(GlobalKey());
    }
    return _keys[i];
  }

  void _moveTo(Offset global) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(global);
    final area = box.size;
    final freeW = area.width - _kHandleWidth;
    final freeH = area.height - _kHandleHeight;
    setState(() {
      _fx = freeW <= 0
          ? 0
          : ((local.dx - _kHandleWidth / 2) / freeW).clamp(0.0, 1.0).toDouble();
      _fy = freeH <= 0
          ? 0
          : ((local.dy - _kHandleHeight / 2) / freeH).clamp(0.0, 1.0).toDouble();
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downAt = DateTime.now();
    _downPos = e.position;
    final last = _lastTapUp;
    if (last != null && _downAt!.difference(last) < _kDoubleTapGap) {
      HapticFeedback.mediumImpact();
      setState(() => _moving = true);
      return;
    }
    _openTimer = Timer(_kOpenDelay, () {
      HapticFeedback.mediumImpact();
      setState(() => _open = true);
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (_moving) {
      _moveTo(e.position);
    } else if (_open) {
      _updateHover(e.position);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _openTimer?.cancel();
    if (_moving) {
      _lastTapUp = null;
      setState(() => _moving = false);
      bind.mainSetLocalOption(
          key: _kOptionControlPanelPos,
          value: '${_fx.toStringAsFixed(4)},${_fy.toStringAsFixed(4)}');
      return;
    }
    if (_open) {
      _lastTapUp = null;
      _close(select: true);
      return;
    }
    final downAt = _downAt;
    final downPos = _downPos;
    final isTap = downAt != null &&
        downPos != null &&
        DateTime.now().difference(downAt) < _kTapMaxDuration &&
        (e.position - downPos).distance < _kTapSlop;
    _lastTapUp = isTap ? DateTime.now() : null;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _openTimer?.cancel();
    _lastTapUp = null;
    if (_moving) setState(() => _moving = false);
    if (_open) _close();
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

  Widget _handle() => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Container(
          width: _kHandleWidth,
          height: _kHandleHeight,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: _moving ? MyTheme.accent : Colors.black26,
                width: _moving ? 4 : 1),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 6),
            ],
          ),
          child: SvgPicture.asset('assets/icon.svg'),
        ),
      );

  Widget _panel() => Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              Container(
                key: _keyAt(i),
                height: _kItemHeight,
                constraints: const BoxConstraints(minWidth: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: _hover == i ? MyTheme.accent : Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.items[i].icon, color: widget.items[i].color),
                    const SizedBox(width: 12),
                    Text(widget.items[i].label,
                        style: TextStyle(
                            color: widget.items[i].color, fontSize: 16)),
                  ],
                ),
              ),
          ],
        ),
      );

  @override
  void dispose() {
    _openTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final left = _fx * (w - _kHandleWidth);
      final top = _fy * (h - _kHandleHeight);
      final panelHeight = widget.items.length * _kItemHeight;
      final panelTop = (top + _kHandleHeight / 2 - panelHeight / 2)
          .clamp(8.0, (h - panelHeight - 8).clamp(8.0, double.infinity))
          .toDouble();
      final opensRight = left + _kHandleWidth / 2 < w / 2;
      return Stack(children: [
        Positioned(left: left, top: top, child: _handle()),
        if (_open)
          Positioned(
            top: panelTop,
            left: opensRight ? left + _kHandleWidth + _kPanelGap : null,
            right: opensRight ? null : w - left + _kPanelGap,
            child: _panel(),
          ),
      ]);
    });
  }
}
