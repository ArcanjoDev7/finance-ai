import 'package:flutter/widgets.dart';

class AppFadeIn extends StatelessWidget {
  const AppFadeIn({super.key, required this.child, this.duration = const Duration(milliseconds: 220)});
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: duration,
        builder: (_, value, child) => Opacity(opacity: value, child: child), child: child,
      );
}
