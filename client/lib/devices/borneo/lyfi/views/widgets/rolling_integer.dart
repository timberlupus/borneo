import 'package:flutter/material.dart';

class RollingInteger extends StatefulWidget {
  final int value;
  final TextStyle? textStyle;
  final Duration duration;

  const RollingInteger({
    Key? key,
    required this.value,
    this.textStyle,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

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
    return SizedBox(
      height: (textStyle.fontSize ?? 24) * 1.25,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_anim.value);
          // -1 => up (increase), 1 => down (decrease)
          final direction = newValue >= _oldValue ? -1.0 : 1.0;
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
