import 'package:estatex_app/favorites/favorites_controller.dart';
import 'package:estatex_app/favorites/favorites_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.propertyId,
    this.iconSize = 24,
  });

  final String propertyId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(propertyId));
    final isPending = ref.watch(favoriteActionPendingProvider(propertyId));

    return IconButton(
      onPressed: isPending
          ? null
          : () async {
              final controller = ref.read(favoritesControllerProvider.notifier);
              if (controller is! FavoritesController) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please login to save properties')),
                );
                return;
              }

              await controller.toggle(propertyId);

              if (!context.mounted) return;
              final error = ref.read(favoritesControllerProvider).errorMessage;
              if (error != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(error)));
              }
            },
      icon: isPending
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey,
              size: iconSize,
            ),
    );
  }
}
