// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cloudreve_view/entity/file.dart';
import 'package:cloudreve_view/widget/file/file_grid_card.dart';
import 'package:flutter/material.dart';

class FileGridView extends StatelessWidget {
  final List<File> fileList;
  final Function onTap;
  final Function onDoubleTap;

  const FileGridView({
    Key? key,
    required this.fileList,
    this.onTap=_voidFunction,
    this.onDoubleTap = _voidFunction
  }) : super(key: key);

  static void _voidFunction(File file){}

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
        itemCount: fileList.length,
        gridDelegate:
            SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(6.0),
            child: FileGridCard(file: fileList[index],onTap: onTap,onDoubleTap: onDoubleTap,),
          );
        });
  }
}
