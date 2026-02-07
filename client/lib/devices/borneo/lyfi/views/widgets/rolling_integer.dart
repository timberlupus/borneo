import 'package:flutter/material.dart';

class RollingInteger extends StatefulWidget {
  final int value;
  final TextStyle? textStyle;
  final Duration duration;

  const RollingInteger({
    super.key,
    required this.value,
    this.textStyle,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  _RollingIntegerState createState() => _RollingIntegerState();
}

class _RollingIntegerState extends State<RollingInteger> with SingleTickerProviderStateMixin {
  late int _oldValue;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = _ctrl.drive(Tween(begin: 0.0, end: 1.0));
  }

  @override
  void didUpdateWidget(covariant RollingInteger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _oldValue = oldWidget.value;
      _ctrl.duration = widget.duration;
      _ctrl
        ..stop()
        ..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int newValue = widget.value;
    final textStyle = widget.textStyle ?? DefaultTextStyle.of(context).style;
    final double fontSize = textStyle.fontSize ?? 24;
    return SizedBox(
      width: fontSize * 0.6,
      height: fontSize * 1.25,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_anim.value);
          // 1 => down (increase), -1 => up (decrease)
          final direction = newValue >= _oldValue ? 1.0 : -1.0;
          final offset = direction * t;

          return Stack(
            alignment: Alignment.center,
            children: [
              // old value
              FractionalTranslation(
                translation: Offset(0, offset),
                child: Opacity(
                  opacity: 1.0 - t,
                  child: Text(_oldValue.toString(), style: textStyle),
                ),
              ),
              // new value
              FractionalTranslation(
                translation: Offset(0, offset - direction),
                child: Opacity(
                  opacity: t,
                  child: Text(newValue.toString(), style: textStyle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
