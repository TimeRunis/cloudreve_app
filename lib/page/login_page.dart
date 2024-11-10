import 'package:cloudreve_view/common/api.dart';
import 'package:cloudreve_view/common/util.dart';
import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/entity/user.dart';
import 'package:cloudreve_view/widget/common/theme_change_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _LoginPage();
  }
}

class _LoginPage extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late String _email;
  late String _password;

  @override
  Widget build(BuildContext context) {
    Controller controller = Get.find<Controller>();
    if(controller.user!=null){
      Future.microtask((){
        Navigator.pushNamed(context, "/");
      });
      return Container(); 
    }
    return PopScope(
      canPop: false,
      onPopInvoked :(didPop) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Form(
        key: _formKey,
        child: Scaffold(
          appBar: AppBar(
            title: Builder(
              builder: (context) {
                return Text(AppLocalizations.of(context)!.loginPageTitle);
              },
            ),
            actions: const [
              ThemeChangeBtn(
                size: 30,
              )
            ],
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 登录卡片头
                      const Center(
                        child: Icon(Icons.lock),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                        child: Center(
                          child: Text(
                            "${AppLocalizations.of(context)!.loginPageTitle} ${AppLocalizations.of(context)!.mainPageTitle}",
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      // 邮箱
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                        child: TextFormField(
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !value.isEmail) {
                                return AppLocalizations.of(context)!
                                    .invalidEmail;
                              }
                              return null;
                            },
                            onSaved:(newValue) {
                              _email = newValue!;
                            },
                            decoration: InputDecoration(
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(10)),
                                    borderSide: BorderSide(
                                        color: Theme.of(context).focusColor)),
                                label: Text(
                                    "${AppLocalizations.of(context)!.email}:"),
                                border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(10))))),
                      ),
                      // 密码
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                        child: TextFormField(
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty || value.length <6) {
                                return AppLocalizations.of(context)!.invalid;
                              }
                              return null;
                            },
                            onSaved:(newValue) {
                              _password = newValue!;
                            },
                            decoration: InputDecoration(
                                label: Text(
                                    "${AppLocalizations.of(context)!.password}:"),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(10)),
                                    borderSide: BorderSide(
                                        color: Theme.of(context).focusColor)),
                                border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(10))))),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
                              child: TextButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      backgroundColor:
                                          Theme.of(context).primaryColor),
                                  onPressed: () {
                                    var form = _formKey.currentState;
                                    form!.save();
                                    if(form.validate()){
                                      Api().login(email: _email,password: _password).then((resp){
                                        if(resp.data["code"]==0) {
                                          Util.showSnackbar(context: context,message: AppLocalizations.of(context)!.loginSuccess);
                                          Get.offAllNamed("/");
                                        }else{
                                          Util.showErrorSnackbar(context: context,message: resp.data['msg']);
                                        }
                                      });
                                      Util.showSnackbar(context: context);
                                    }
                                  },
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .loginPageTitle,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .appBarTheme
                                            .titleTextStyle!
                                            .color),
                                  )),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
