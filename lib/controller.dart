import 'package:cloudreve_view/common/constants.dart';
import 'package:cloudreve_view/entity/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Controller extends GetxController {
  // 主题
  var lightTheme = ThemeData.light().copyWith(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    focusColor: Colors.blue,
    dialogBackgroundColor: Colors.blue,
    dividerColor: Color.fromRGBO(227, 227, 227,1),
    appBarTheme: const AppBarTheme(
        color: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 22)),
  );

  var darkTheme = ThemeData.dark().copyWith(
    brightness: Brightness.dark,
    focusColor: Colors.white,
    appBarTheme: const AppBarTheme(
        color: Colors.black,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 22)),
    scaffoldBackgroundColor: const Color.fromARGB(255, 50, 50, 50),
  );

  var isDarkMode = false.obs;

  // 用户数据
  User? user;
  // cookie
  String session ="";
  late SharedPreferences storage;

  var isStoregeReady = false.obs;

  // 初始化
  onInit(){
    super.onInit();
    SharedPreferences.getInstance().then((data) {
      storage = data;
      isDarkMode.value =
          storage.getBool(Constants.appConfig['isDarkMode']!) ?? false;
      var tUser = storage.getString(Constants.appConfig['userInfo']!);
      session = storage.getString(Constants.appConfig['session']!)??"";
      if(tUser!=null){
        user = User.fromJson(tUser);
      }
      isStoregeReady.value = true;
    });
  }

  void changeTheme() {
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.light : ThemeMode.dark);
    isDarkMode.value = !isDarkMode.value;
    storage.setBool(Constants.appConfig['isDarkMode']!,isDarkMode.value);
  }

  void setUser(User? user) {
    this.user = user;
    if(user!=null){
      storage.setString(Constants.appConfig['userInfo']!,user.toJson());
    }else{
      storage.remove(Constants.appConfig['userInfo']!);
    }
  }

  void setSession(String session) {
    this.session = session;
    storage.setString(Constants.appConfig['session']!,session);
  }

  void logout(){
    setSession("");
    setUser(null);
    Get.toNamed("/login");
  }
}
