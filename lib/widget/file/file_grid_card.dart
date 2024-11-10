// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/common/api.dart';
import 'package:cloudreve_view/common/constants.dart';
import 'package:cloudreve_view/entity/file.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FileGridCard extends StatelessWidget {
  final File file;
  final Function onTap;

  const FileGridCard({
    Key? key,
    required this.file,
    this.onTap = _voidFunction,
  }) : super(key: key);

  static void _voidFunction() {}

  @override
  Widget build(BuildContext context) {
    String suffix = file.name.split(".").last;
    final fileTypeMap = {'zip': Icons.folder_zip};
    double iconSize = 40;
    return GestureDetector(
      onTap: () => onTap(file),
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: Theme.of(context).dividerColor,
            )),
        child: file.type == Constants.fileType["dir"]
            ? Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: Icon(Icons.folder, size: iconSize),
                  ),
                  Expanded(
                      child: Container(
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 1))),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Text(
                          file.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ))
                ],
              )
            : Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: file.thumb
                        ? ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                            child: FadeInImage(
                                fit: BoxFit.cover,
                                imageErrorBuilder:
                                    (context, error, stackTrace) {
                                  return Icon(
                                    Icons.insert_drive_file,
                                    size: iconSize,
                                  );
                                },
                                width: double.infinity,
                                placeholder:
                                    AssetImage("assets/images/pic.png"),
                                image: NetworkImage(
                                    "${ApiConfig.fileThumbBaseUrl}${file.id}",
                                    headers: {
                                      "Cookie": Get.find<Controller>().session
                                    })),
                          )
                        : Icon(fileTypeMap[suffix] ?? Icons.file_copy,
                            size: iconSize),
                  ),
                  Expanded(
                      child: Container(
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 1))),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Text(
                          file.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ))
                ],
              ),
      ),
    );
  }
}
