import 'dart:async';

import 'package:estatex_app/favorites/favorites_cache.dart';
import 'package:estatex_app/favorites/favorites_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class FavoritesState {
  const FavoritesState({
    this.favoriteIds = const <String>{},
    this.pendingIds = const <String>{},
    this.isInitialized = false,
    this.errorMessage,
  });

  final Set<String> favoriteIds;
  final Set<String> pendingIds;
  final bool isInitialized;
  final String? errorMessage;

  bool isFavorite(String propertyId) => favoriteIds.contains(propertyId);
  bool isPending(String propertyId) => pendingIds.contains(propertyId);

  FavoritesState copyWith({
    Set<String>? favoriteIds,
    Set<String>? pendingIds,
    bool? isInitialized,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FavoritesState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      pendingIds: pendingIds ?? this.pendingIds,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController({
    required FavoritesRepository service,
    required FavoritesCache cache,
    required String userId,
  }) : _service = service,
       _cache = cache,
       _userId = userId,
       super(const FavoritesState());

  final FavoritesRepository _service;
  final FavoritesCache _cache;
  final String _userId;

  StreamSubscription<Set<String>>? _remoteSub;

  Future<void> initialize() async {
    final cached = await _cache.read(_userId);
    state = state.copyWith(
      favoriteIds: cached,
      isInitialized: true,
      clearError: true,
    );

    _remoteSub?.cancel();
    _remoteSub = _service.watchFavoriteIds().listen((remoteIds) async {
      state = state.copyWith(favoriteIds: remoteIds, clearError: true);
      await _cache.write(_userId, remoteIds);
    });
  }

  Future<void> toggle(String propertyId) async {
    final previous = state;
    final currentlyFavorite = previous.favoriteIds.contains(propertyId);
    final nextFavorite = !currentlyFavorite;

    final nextIds = Set<String>.from(previous.favoriteIds);
    if (nextFavorite) {
      nextIds.add(propertyId);
    } else {
      nextIds.remove(propertyId);
    }

    final nextPending = Set<String>.from(previous.pendingIds)..add(propertyId);
    state = state.copyWith(
      favoriteIds: nextIds,
      pendingIds: nextPending,
      clearError: true,
    );

    try {
      await _cache.write(_userId, nextIds);
      await _service.setFavorite(
        propertyId: propertyId,
        isFavorite: nextFavorite,
      );
      final cleared = Set<String>.from(state.pendingIds)..remove(propertyId);
      state = state.copyWith(pendingIds: cleared, clearError: true);
    } catch (_) {
      final cleared = Set<String>.from(previous.pendingIds)..remove(propertyId);
      state = previous.copyWith(
        pendingIds: cleared,
        errorMessage: 'Unable to update favorite. Please retry.',
      );
    }
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    super.dispose();
  }
}
