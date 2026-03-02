import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1,
              initialPage: index,
              onPageChanged: (i, _) {
                setState(() => index = i);
              },
            ),
            items: widget.images.map((url) {
              return InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              );
            }).toList(),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              "${index + 1} / ${widget.images.length}",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
