import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  int _customMinutes = 0;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    setState(() {
      _isFavorite = favorites.contains(widget.recipe['title']);
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    
    setState(() {
      _isFavorite = !_isFavorite;
      if (_isFavorite) {
        favorites.add(widget.recipe['title']);
      } else {
        favorites.remove(widget.recipe['title']);
      }
    });
    
    await prefs.setStringList('favorites', favorites);
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Установите таймер'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Минуты',
              suffixText: 'мин',
            ),
            onChanged: (value) {
              _customMinutes = int.tryParse(value) ?? 0;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_customMinutes > 0) {
                  _startTimer(_customMinutes);
                }
              },
              child: const Text('Старт'),
            ),
          ],
        );
      },
    );
  }

  void _startTimer(int minutes) {
    setState(() {
      _remainingSeconds = minutes * 60;
      _isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isTimerRunning = false;
          timer.cancel();
          _showTimerCompleteAlert();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _remainingSeconds = 0;
    });
  }

  void _showTimerCompleteAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Таймер завершен!'),
        content: const Text('Шаг приготовления завершён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = List<Map<String, dynamic>>.from(widget.recipe['ingredients']);
    final instructions = (widget.recipe['instructions'] as String)
        .split('\n')
        .where((step) => step.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe['title']),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Таймер
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _remainingSeconds > 0 || _isTimerRunning
                          ? _formatTime(_remainingSeconds)
                          : 'Таймер не активен',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.timer),
                          color: Colors.orange,
                          onPressed: _showTimerDialog,
                        ),
                        if (_remainingSeconds > 0) ...[
                          if (!_isTimerRunning)
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              color: Colors.green,
                              onPressed: () => _startTimer(_remainingSeconds ~/ 60),
                            ),
                          if (_isTimerRunning)
                            IconButton(
                              icon: const Icon(Icons.pause),
                              color: Colors.blue,
                              onPressed: _pauseTimer,
                            ),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            color: Colors.red,
                            onPressed: _resetTimer,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _buildSection(
              title: 'Ингредиенты',
              child: Column(
                children: ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('${ing['name']}', style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(ing['quantity'].toString(), 
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            
            _buildSection(
              title: 'Инструкции',
              child: Column(
                children: instructions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.orange.shade100, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${index + 1}. ', 
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(step)),
                            ],
                          ),
                          if (step.toLowerCase().contains('минут'))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.timer, color: Colors.orange),
                                label: const Text('Таймер', 
                                    style: TextStyle(color: Colors.orange)),
                                onPressed: () {
                                  final timeMatch = RegExp(r'(\d+)\s*минут').firstMatch(step);
                                  if (timeMatch != null) {
                                    _customMinutes = int.parse(timeMatch.group(1)!);
                                    _showTimerDialog();
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            _buildSection(
              title: 'Информация',
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.local_fire_department, 
                    '${widget.recipe['calories_per_100g']} ккал'),
                  _buildInfoChip(Icons.kitchen, 
                    '${widget.recipe['total_weight']} г'),
                  _buildInfoChip(Icons.category, 
                    widget.recipe['category']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.orange),
      label: Text(text),
      backgroundColor: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.orange),
      ),
    );
  }
}