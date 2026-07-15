import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label ?? 'Carregando',
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
}

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.isLoading, required this.child});
  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: AppLoadingIndicator(),
              ),
            ),
        ],
      );
}
