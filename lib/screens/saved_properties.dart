import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/favorites/favorite_button.dart';
import 'package:estatex_app/favorites/favorites_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedPropertiesScreen extends StatefulWidget {
  const SavedPropertiesScreen({super.key});

  @override
  State<SavedPropertiesScreen> createState() => _SavedPropertiesScreenState();
}

class _SavedPropertiesScreenState extends State<SavedPropertiesScreen> {
  final _service = FavoritesService();
  final _scrollController = ScrollController();

  final List<FavoritePropertyItem> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await _service.fetchFavoritesPage(lastDocument: _lastDoc);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load saved list: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
      _error = null;
    });
    await _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view saved properties')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Properties')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index == _items.length) {
              if (_isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                );
              }
              if (_items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(child: Text('No saved properties')),
                );
              }
              if (!_hasMore) {
                return const SizedBox(height: 12);
              }
              return const SizedBox.shrink();
            }

            final item = _items[index];
            if (item.isDeleted) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: const Text('Property unavailable'),
                  subtitle: Text('ID: ${item.propertyId}'),
                  trailing: FavoriteButton(propertyId: item.propertyId),
                ),
              );
            }

            final property = item.property ?? const <String, dynamic>{};

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text((property['title'] ?? 'Untitled').toString()),
                subtitle: Text(
                  '${property['city'] ?? '-'} • ₹${property['price'] ?? 0}',
                ),
                trailing: FavoriteButton(propertyId: item.propertyId),
              ),
            );
          },
        ),
      ),
    );
  }
}
