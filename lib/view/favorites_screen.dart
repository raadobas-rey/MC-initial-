import 'package:flutter/material.dart';
import '../model/note.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Note> favorites;
  final void Function(Note) onToggleFavorite;

  const FavoritesScreen({super.key, required this.favorites, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: favorites.isEmpty
          ? const Center(child: Text('No favorites yet'))
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final note = favorites[i];
                return ListTile(
                  title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.redAccent),
                    tooltip: 'Remove from favorites',
                    onPressed: () {
                      onToggleFavorite(note);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}
