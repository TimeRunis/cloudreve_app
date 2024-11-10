// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cloudreve_view/common/util.dart';
import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/entity/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'user_cart.dart';

class MainDrawser extends StatefulWidget {
  final User user;

  const MainDrawser({super.key, required this.user});
  
  @override
  State<StatefulWidget> createState() {
    return _MainDrawserState();
  }
}

class _MainDrawserState extends State<MainDrawser>{
  @override
  Widget build(BuildContext context) {
    return Drawer(
      surfaceTintColor: Colors.white,
      child: Container(
        color: Theme.of(context).primaryColor,
        child: SafeArea(
          child: Column(
            children: [UserCart(user: widget.user), const Expanded(child: DrawerList())],
          ),
        ),
      ),
    );
  }
}

class DrawerList extends StatelessWidget {
  const DrawerList({super.key});

  @override
  Widget build(BuildContext context) {
    Controller controller = Get.find<Controller>();
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        children: [
          ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.folder_shared),
            childrenPadding: const EdgeInsets.fromLTRB(60, 0, 0, 0),
            title: Text(AppLocalizations.of(context)!.myFiles),
            children: [
              ListTile(
                leading: const Icon(Icons.video_collection),
                title: Text(AppLocalizations.of(context)!.fileTypeVideo),
              ),
              ListTile(
                leading: const Icon(Icons.photo_filter),
                title: Text(AppLocalizations.of(context)!.fileTypePicture),
              ),
              ListTile(
                leading: const Icon(Icons.music_video),
                title: Text(AppLocalizations.of(context)!.fileTypeMusic),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner),
                title: Text(AppLocalizations.of(context)!.fileTypeDocument),
              )
            ],
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.share),
            title: Text(AppLocalizations.of(context)!.myShares),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.cloud_download),
            title: Text(AppLocalizations.of(context)!.offlineDownload),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.computer),
            title: Text(AppLocalizations.of(context)!.connections),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.inventory),
            title: Text(AppLocalizations.of(context)!.processQueue),
          ),
          Divider(
            color: Theme.of(context).dividerColor,
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context)!.settings),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 0, 0),
            leading: const Icon(Icons.logout),
            title: Text(AppLocalizations.of(context)!.logout),
            onTap: (){
              controller.logout();
              Util.showSnackbar(context: context,message: AppLocalizations.of(context)!.logoutSuccess);
            },
          )
        ],
      ),
    );
  }
}
