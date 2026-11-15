import 'package:flutter/material.dart';

/// Lightweight, built-in motion helpers used across non-scanning screens.
/// Scroll-triggered entrance/press animations are kept zero-overhead so
/// scrolling and tab switches stay completely smooth.

/// Renders [child] directly without entrance opacity/translation passes.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.duration = const Duration(milliseconds: 360),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) => child;
}

/// Pass-through wrapper preserved for API compatibility without scroll-fighting
/// pointer listeners or per-frame scale transforms.
class Pressable extends StatelessWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) => child;
}

/// IndexedStack that keeps every child's state lazily mounted and repaints
/// isolated per tab without offscreen transition layers.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> {
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: RepaintBoundary(
              child: _visited.contains(i)
                  ? widget.children[i]
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
