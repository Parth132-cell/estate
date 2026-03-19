import 'dart:async';

import 'package:estatex_app/favorites/favorites_cache.dart';
import 'package:estatex_app/favorites/favorites_controller.dart';
import 'package:estatex_app/favorites/favorites_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements FavoritesRepository {
  final StreamController<Set<String>> streamController =
      StreamController<Set<String>>.broadcast();

  bool shouldThrow = false;
  final Map<String, bool> writes = {};

  @override
  Future<FavoritePage> fetchFavoritesPage({lastDocument, int limit = 12}) {
    throw UnimplementedError();
  }

  @override
  Future<void> setFavorite({required String propertyId, required bool isFavorite}) async {
    if (shouldThrow) {
      throw Exception('network');
    }
    writes[propertyId] = isFavorite;
  }

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
  test('loads cache and then syncs from realtime stream', () async {
    final repo = _FakeRepo();
    final cache = _FakeCache()..cached = {'p1'};

    final controller = FavoritesController(
      service: repo,
      cache: cache,
      userId: 'u1',
    );

    await controller.initialize();
    expect(controller.state.favoriteIds, {'p1'});

    repo.streamController.add({'p2', 'p3'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.favoriteIds, {'p2', 'p3'});
    expect(cache.cached, {'p2', 'p3'});

    controller.dispose();
  });

  test('optimistic toggle reverts on failure', () async {
    final repo = _FakeRepo()..shouldThrow = true;
    final cache = _FakeCache()..cached = {'p1'};

    final controller = FavoritesController(
      service: repo,
      cache: cache,
      userId: 'u1',
    );

    await controller.initialize();
    await controller.toggle('p2');

    expect(controller.state.favoriteIds, {'p1'});
    expect(controller.state.errorMessage, isNotNull);

    controller.dispose();
  });
}
