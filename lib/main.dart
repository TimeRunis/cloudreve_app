import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/page/login_page.dart';
import 'package:cloudreve_view/page/main_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  MainApp({super.key});
  @override
  State<StatefulWidget> createState() {
    return _MainAppState();
  }
}

class _MainAppState extends State<MainApp> {
  Controller controller = Get.put(Controller());
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isStoregeReady.value) {
        return GetMaterialApp(
          title: "TimeRunisの宝库",
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale.fromSubtags(languageCode: 'zh'),
            Locale.fromSubtags(languageCode: 'en'), // English
          ],
          theme: controller.isDarkMode.value?controller.darkTheme:controller.lightTheme,
          darkTheme: controller.darkTheme,
          themeMode: ThemeMode.light,
          routes: {
            "/login": (context) => const LoginPage(),
            "/": (context) => const MainPage()
          },
          initialRoute: '/login',
        );
      } else {
        return LoadingScreen();
      }
    });
  }
}

class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset("assets/images/start_bg.gif")
    );
  }
}
