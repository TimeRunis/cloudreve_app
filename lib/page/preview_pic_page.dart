// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudreve_view/common/api.dart';
import 'package:cloudreve_view/entity/file.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// ignore: must_be_immutable
class PreviewPicPage extends StatefulWidget {
  final List<File> list;
  int currentIndex;
  PreviewPicPage({Key? key, required this.list, this.currentIndex = 0})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PreviewPicPageState();
  }
}

class _PreviewPicPageState extends State<PreviewPicPage> {
  Map<String, String> map = {};
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.currentIndex);
    _loadInitialUrls();
  }

  void _loadInitialUrls() {
    if (widget.currentIndex > 0)
      getRealUrl(widget.list[widget.currentIndex - 1]);
    getRealUrl(widget.list[widget.currentIndex]);
    if (widget.list.length - 1 > widget.currentIndex)
      getRealUrl(widget.list[widget.currentIndex + 1]);
  }

  void getRealUrl(File file) async {
    if (!map.containsKey(file.id)) {
      try {
        String url = await Api()
            .getPreviewFileUrl(ApiConfig.filePreveiewBaseUrl + file.id);
        // print("获取到真实链接:${file.id}");
        if (mounted) {
          setState(() {
            map[file.id] = url;
          });
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: PhotoViewGallery.builder(
                itemCount: widget.list.length,
                pageController: pageController,
                onPageChanged: (index) {
                  if (index < widget.list.length - 1 &&
                      !map.containsKey(widget.list[index + 1].id))
                    getRealUrl(widget.list[index + 1]);
                  if (index > 0 && !map.containsKey(widget.list[index - 1].id))
                    getRealUrl(widget.list[index - 1]);
                  if (!map.containsKey(widget.list[index].id))
                    getRealUrl(widget.list[index]);
                  setState(() {
                    widget.currentIndex = index;
                  });
                },
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: map.containsKey(widget.list[index].id)
                        ? CachedNetworkImageProvider(
                            map[widget.list[index].id]!)
                        : const AssetImage('assets/images/pic.png')
                            as ImageProvider,
                    // imageProvider: FadeInImage(
                    //   image: NetworkImage(ApiConfig.filePreveiewBaseUrl +
                    //       widget.list[index].id),
                    //   imageErrorBuilder: (context, error, stackTrace) {
                    //     return Icon(Icons.error);
                    //   },
                    //   placeholder: AssetImage('assets/images/pic.png'),
                    // ).image,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    onTapUp: (context, details, controllerValue) {
                      Navigator.pop(context);
                    },
                  );
                },
                loadingBuilder: (context, event) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: event == null
                          ? null
                          : event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ?? 1),
                    ),
                  );
                },
                scrollPhysics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                backgroundDecoration: const BoxDecoration(color: Colors.black)),
          ),
          Container(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                "${widget.list[widget.currentIndex].name}",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
          Container(
            child: Text(
              "${widget.currentIndex + 1}/${widget.list.length}",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
