import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'recipe_detail_screen.dart';
import 'dart:convert';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<String> _favorites = [];
  List<dynamic> _allRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFavorites(),
      _loadRecipes(),
    ]);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _loadRecipes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/recipes.json');
      final jsonData = json.decode(jsonString);
      if (jsonData is List) {
        setState(() {
          _allRecipes = jsonData;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки рецептов: $e');
    }
  }

  Map<String, dynamic>? _findRecipeByTitle(String title) {
    return _allRecipes.firstWhere(
      (recipe) => recipe['title'] == title,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранные рецепты'),
        backgroundColor: Colors.orange,
      ),
      body: _favorites.isEmpty
          ? const Center(
              child: Text(
                'Нет избранных рецептов',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final recipe = _findRecipeByTitle(_favorites[index]);
                if (recipe == null) return const SizedBox();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange[200]!, width: 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(recipe: recipe),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipe['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () async {
                                  await _toggleFavorite(recipe['title']);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Категория: ${recipe['category']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ингредиенты: ${recipe['ingredients'].map((i) => i['name']).join(', ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
      } else {
        _favorites.add(title);
      }
    });
    await prefs.setStringList('favorites', _favorites);
  }
}