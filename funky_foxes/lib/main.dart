import 'package:flutter/material.dart';
import 'styles/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Funky Foxes',
      theme: AppTheme.themeData, 
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
