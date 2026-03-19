import 'dart:async';

import 'package:estatex_app/favorites/favorite_button.dart';
import 'package:estatex_app/favorites/favorites_cache.dart';
import 'package:estatex_app/favorites/favorites_controller.dart';
import 'package:estatex_app/favorites/favorites_providers.dart';
import 'package:estatex_app/favorites/favorites_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements FavoritesRepository {
  final StreamController<Set<String>> streamController =
      StreamController<Set<String>>.broadcast();

  @override
  Future<FavoritePage> fetchFavoritesPage({lastDocument, int limit = 12}) {
    throw UnimplementedError();
  }

  @override
  Future<void> setFavorite({required String propertyId, required bool isFavorite}) async {}

  @override
  Stream<Set<String>> watchFavoriteIds() => streamController.stream;
}

class _FakeCache implements FavoritesCache {
  Set<String> cached = {};

  @override
  Future<Set<String>> read(String userId) async => cached;

  @override
  Future<void> write(String userId, Set<String> favorites) async {
    cached = Set<String>.from(favorites);
  }
}

void main() {
  testWidgets('FavoriteButton toggles icon state', (tester) async {
    final controller = FavoritesController(
      service: _FakeRepo(),
      cache: _FakeCache(),
      userId: 'u1',
    );
    await controller.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoriteButton(propertyId: 'p1'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
