import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  Flushbar(
    message: message,
    duration: const Duration(seconds: 3),
    backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    margin: const EdgeInsets.all(8),
    borderRadius: BorderRadius.circular(8),
    flushbarPosition: FlushbarPosition.TOP,
  ).show(context);
}
