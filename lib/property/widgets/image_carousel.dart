import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'full_screen_gallery.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> images;

  const ImageCarousel({super.key, required this.images});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1,
            enableInfiniteScroll: false,
            onPageChanged: (i, _) {
              setState(() => index = i);
            },
          ),
          items: widget.images.map((url) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenGallery(
                      images: widget.images,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            );
          }).toList(),
        ),

        // DOT INDICATORS
        Positioned(
          bottom: 12,
          child: Row(
            children: widget.images.asMap().entries.map((entry) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == entry.key ? Colors.white : Colors.white54,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
