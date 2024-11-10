import 'package:cloudreve_view/controller.dart';
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
}
