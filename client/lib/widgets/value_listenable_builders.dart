import 'package:flutter/widgets.dart';

class MultiValueListenableBuilder<T> extends StatefulWidget {
  final List<ValueNotifier<T>> valueNotifiers;
  final Widget Function(BuildContext context, List<T> values, Widget? child)
      builder;
  final Widget? child;

  const MultiValueListenableBuilder({
    super.key,
    required this.valueNotifiers,
    required this.builder,
    this.child,
  });

  @override
  MultiValueListenableBuilderState<T> createState() =>
      MultiValueListenableBuilderState<T>();
}

class MultiValueListenableBuilderState<T>
    extends State<MultiValueListenableBuilder<T>> {
  late final Listenable mergedListenable;

  @override
  void initState() {
    super.initState();
    mergedListenable = Listenable.merge(widget.valueNotifiers);
    mergedListenable.addListener(_update);
  }

  @override
  void dispose() {
    mergedListenable.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final values =
        widget.valueNotifiers.map((notifier) => notifier.value).toList();
    return widget.builder(context, values, widget.child);
  }
}
