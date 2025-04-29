import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe_detail_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> _allRecipes = [];
  List<dynamic> _filteredRecipes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _selectedCategory;
  List<String> _allIngredients = [];
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  final List<String> _popularCategories = ['блюдо', 'напиток', 'салат', 'завтрак'];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/recipes.json');
      final jsonData = json.decode(jsonString);
      if (jsonData is List) {
        setState(() {
          _allRecipes = jsonData;
          _filteredRecipes = jsonData;
          _allIngredients = _extractUniqueIngredients(_allRecipes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки рецептов: $e');
      setState(() => _isLoading = false);
    }
  }

  List<String> _extractUniqueIngredients(List<dynamic> recipes) {
    final ingredients = <String>[];
    for (final recipe in recipes) {
      for (final ing in recipe['ingredients']) {
        if (!ingredients.contains(ing['name'])) {
          ingredients.add(ing['name']);
        }
      }
    }
    return ingredients;
  }

  int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (var j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return matrix[a.length][b.length];
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipes = _allRecipes.where((recipe) {
        // Фильтр по поисковому запросу
        final matchesSearch = query.isEmpty ||
            recipe['title'].toString().toLowerCase().contains(query) ||
            recipe['ingredients'].any((ing) {
              final ingName = ing['name'].toString().toLowerCase();
              return ingName.contains(query) || _levenshteinDistance(ingName, query) <= 2;
            });

        // Фильтр по категории
        final matchesCategory = _selectedCategory == null || 
            recipe['category']?.toLowerCase() == _selectedCategory?.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _showSuggestions = false);
      return;
    }

    setState(() {
      _suggestions = _allIngredients.where((ing) {
        final lowerIng = ing.toLowerCase();
        final lowerQuery = query.toLowerCase();
        return lowerIng.contains(lowerQuery) || _levenshteinDistance(lowerIng, lowerQuery) <= 2;
      }).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _handleCategorySelect(String? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    _filterRecipes();
  }

  Future<bool> _isFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    return favorites.contains(title);
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    
    setState(() {
      if (favorites.contains(title)) {
        favorites.remove(title);
      } else {
        favorites.add(title);
      }
    });
    
    await prefs.setStringList('favorites', favorites);
    _filterRecipes();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _allRecipes
        .map((r) => r['category'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Поле поиска
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Введите ингредиенты или название',
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _showSuggestions = false;
                              });
                              _filterRecipes();
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) {
                    _updateSuggestions(query);
                    _filterRecipes();
                  },
                  onTap: () {
                    setState(() => _showSuggestions = _searchController.text.isNotEmpty);
                  },
                ),

                // Подсказки
                if (_showSuggestions) _buildSuggestionsList(),

                const SizedBox(height: 16),

                // Популярные категории
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Популярные категории:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _popularCategories.map((category) {
                        return ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (_) => _handleCategorySelect(category),
                          selectedColor: Colors.orange,
                          labelStyle: TextStyle(
                            color: _selectedCategory == category 
                                ? Colors.white 
                                : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Все категории
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Все'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => _handleCategorySelect(null),
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: _selectedCategory == null 
                              ? Colors.white 
                              : Colors.black,
                        ),
                      ),
                      ...categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(category!),
                            selected: _selectedCategory == category,
                            onSelected: (_) => _handleCategorySelect(category),
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: _selectedCategory == category 
                                  ? Colors.white 
                                  : Colors.black,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Список рецептов
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredRecipes.isEmpty
                    ? const Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = _filteredRecipes[index];
                          return _buildRecipeCard(recipe);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return FutureBuilder<bool>(
      future: _isFavorite(recipe['title']),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade200, width: 1),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(recipe['title']),
                      ),
                    ],
                  ),
                  if (recipe['category'] != null && recipe['category'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(recipe['category']),
                        backgroundColor: Colors.orange.shade50,
                        labelStyle: const TextStyle(color: Colors.orange),
                      ),
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
    );
  }

  Widget _buildSuggestionsList() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            return ListTile(
              title: Text(suggestion),
              onTap: () {
                setState(() {
                  _searchController.text = suggestion;
                  _showSuggestions = false;
                });
                _filterRecipes();
              },
            );
          },
        ),
      ),
    );
  }
} 