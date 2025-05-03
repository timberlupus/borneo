import 'package:flutter/material.dart';

class IconProgressBar extends StatefulWidget {
  final Widget icon;
  final double size;
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final Duration? duration;

  const IconProgressBar({
    Key? key,
    required this.icon,
    this.size = 50.0,
    required this.progress,
    this.backgroundColor = Colors.grey,
    this.progressColor = Colors.blue,
    this.duration,
  }) : super(key: key);

  @override
  _IconProgressBarState createState() => _IconProgressBarState();
}

class _IconProgressBarState extends State<IconProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController? _controller;
  late Animation<double>? _progressAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.duration != null) {
      _controller = AnimationController(vsync: this, duration: widget.duration);
      _progressAnimation = Tween<double>(begin: 0, end: widget.progress).animate(_controller!);
      _controller!.repeat(reverse: false);
    } else {
      _controller = null;
      _progressAnimation = null;
    }
  }

  @override
  void didUpdateWidget(IconProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress || oldWidget.duration != widget.duration) {
      if (widget.duration != null) {
        // 有动画时更新
        if (_controller == null) {
          _controller = AnimationController(vsync: this, duration: widget.duration);
          _progressAnimation = Tween<double>(begin: 0, end: widget.progress).animate(_controller!);
          _controller!.repeat(reverse: true);
        } else {
          _controller!.duration = widget.duration;
          _progressAnimation = Tween<double>(begin: 0, end: widget.progress).animate(_controller!);
          if (!_controller!.isAnimating) {
            _controller!.repeat(reverse: true);
          }
        }
      } else {
        // 无动画时清理
        _controller?.dispose();
        _controller = null;
        _progressAnimation = null;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProgress = _progressAnimation?.value ?? widget.progress; // 无动画时直接用 progress
    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景图标（灰色）
        ColorFiltered(
          colorFilter: ColorFilter.mode(widget.backgroundColor, BlendMode.srcIn),
          child: SizedBox(width: widget.size, height: widget.size, child: widget.icon),
        ),
        // 进度图标（蓝色），从上到下裁剪
        ClipRect(
          clipper: ProgressClipper(progress: currentProgress),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(widget.progressColor, BlendMode.srcIn),
            child: SizedBox(width: widget.size, height: widget.size, child: widget.icon),
          ),
        ),
      ],
    );
  }
}

// 自定义裁剪器，控制从上到下的填充区域
class ProgressClipper extends CustomClipper<Rect> {
  final double progress;

  ProgressClipper({required this.progress});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(ProgressClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
