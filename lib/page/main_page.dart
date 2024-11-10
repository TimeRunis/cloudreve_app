import 'package:cloudreve_view/common/api.dart';
import 'package:cloudreve_view/common/constants.dart';
import 'package:cloudreve_view/common/util.dart';
import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/entity/file.dart';
import 'package:cloudreve_view/page/preview_pic_page.dart';
import 'package:cloudreve_view/widget/file/file_grid_view.dart';
import 'package:cloudreve_view/widget/common/main_drawser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainPageState();
  }
}

class _MainPageState extends State<MainPage> {
  Controller controller = Get.find<Controller>();
  bool isGridMode = false;
  int _backCount = 0;
  List<String> path = [];

  void goPath(name) {
    path.add("/$name");
  }

  void backPath() {
    path.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.user == null) {
      Future.microtask(() {
        Navigator.pushNamed(context, "/login");
      });
      return Container();
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (flag) {
        if (path.isEmpty) {
          _backCount++;
          if (_backCount >= 2) SystemNavigator.pop();
          Util.showSnackbar(
              context: context,
              message: AppLocalizations.of(context)!.confirmExit);
          Future.delayed(Duration(seconds: 2), () {
            _backCount = 0;
          });
        }
        setState(() {
          backPath();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Builder(
            builder: (context) {
              return Text(AppLocalizations.of(context)!.mainPageTitle);
            },
          ),
        ),
        drawer: MainDrawser(user: controller.user!),
        body: Column(
          children: [
            Row(),
            FutureBuilder(
                key: ValueKey<String>(path.join()),
                future: Api().directory(path: path.join()),
                builder: (context, builder) {
                  if (builder.hasData && builder.data!.data['code'] == 0) {
                    List<File> fileList = List.empty(growable: true);
                    List<File> picList = List.empty(growable: true);
                    for (var i in builder.data!.data['data']['objects']) {
                      fileList.add(File.fromMap(i));
                    }
                    fileList.forEach((file) {
                      if (Constants.canPrePicSet
                          .contains(file.name.split(".").last)) {
                        picList.add(file);
                      }
                    });
                    return Expanded(
                        child: FileGridView(
                      fileList: fileList,
                      onTap: (File file) {
                        if (file.type == Constants.fileType["dir"]) {
                          setState(() {
                            goPath(file.name);
                          });
                        } else if (Constants.canPrePicSet
                            .contains(file.name.split(".").last)) {
                          int index = picList.indexOf(file);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PreviewPicPage(
                                      list: picList,
                                      currentIndex: index,
                                    )),
                          );
                        }
                      },
                    ));
                  }
                  return Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).highlightColor,
                        value: null,
                      ),
                    ),
                  );
                  ;
                })
          ],
        ),
      ),
    );
  }
}
