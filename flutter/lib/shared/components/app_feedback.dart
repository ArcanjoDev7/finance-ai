import 'package:flutter/material.dart';

abstract final class AppFeedback {
  static Future<T?> dialog<T>(BuildContext context, Widget content) => showDialog<T>(
        context: context,
        builder: (_) => AlertDialog(content: content),
      );

  static Future<T?> bottomSheet<T>(BuildContext context, Widget content) => showModalBottomSheet<T>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(child: content),
      );

  static void snackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
