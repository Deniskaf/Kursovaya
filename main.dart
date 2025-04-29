import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'favorite_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Поиск рецептов',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.0, color: Colors.black),
          ),
        ),
      ),
      home: const MainTabScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabScreen extends StatelessWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Поиск рецептов',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.orange[200],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.search, color: Colors.black),
                text: 'Поиск',
              ),
              Tab(
                icon: Icon(Icons.favorite, color: Colors.black),
                text: 'Избранное',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SearchScreen(),
            FavoriteScreen(),
          ],
        ),
      ),
    );
  
  }
}