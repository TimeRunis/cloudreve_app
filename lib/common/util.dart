import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

abstract class Util {
  static bool isEmail(email) {
    final RegExp emailRegExp = RegExp(
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');
    return emailRegExp.hasMatch(email);
  }

  static void showSnackbar({required context, title, message}) {
    Get.showSnackbar(GetSnackBar(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      title: title ?? AppLocalizations.of(context)!.tipTitle,
      message: message ?? AppLocalizations.of(context)!.submitting,
      duration: const Duration(seconds: 1),
    ));
  }

  static void showErrorSnackbar({required context, title, message}) {
    Get.showSnackbar(GetSnackBar(
      backgroundColor: Colors.red,
      title: title ?? AppLocalizations.of(context)!.tipTitle,
      message: message ?? AppLocalizations.of(context)!.submitting,
      duration: const Duration(seconds: 1),
    ));
  }

  static AnimationController showTopSheet(
      {required context, required vsync, child, duration, offset}) {
    final overlay = Overlay.of(context);
    final controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: vsync,
    );
    final animation = Tween<Offset>(
      begin: Offset(0, offset ?? -5),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    final overlayEntry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: animation,
            child: Material(
              elevation: 10,
              child: child,
            ),
          ),
        ),
        child: SafeArea(
          child: child,
        ),
      ),
    );

    overlay.insert(overlayEntry);
    controller.forward();

    return controller;
  }
}
