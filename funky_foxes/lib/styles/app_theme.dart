import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales
  static const Color greenButton = Color(0xFF135836);
  // static const Color darkerGreen = Color.fromARGB(255, 10, 52, 31);
  static const Color darkerGreen = Color.fromARGB(255, 6, 37, 22);
  static const Color lightMint = Color.fromARGB(255, 211, 248, 228);
  static const Color orangeTitle = Color.fromARGB(255, 240, 110, 10);
  static const Color white = Colors.white;

  // Image de fond par défaut
  static const String backgroundImage = 'assets/images/fond2.png';

  // Thème global
  static ThemeData themeData = ThemeData(
    primaryColor: greenButton,
    scaffoldBackgroundColor: Colors.transparent,

    // Police par défaut
    fontFamily: 'Nunito-bold',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        fontFamily: 'PermanentMarker',
        color: orangeTitle,
        shadows: [
          Shadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(2, 4),
          ),
        ],
      ),
      titleLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: greenButton,
      ),
      bodyLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: greenButton,
      ),
      bodySmall: TextStyle(
        fontSize: 18,
        color: greenButton,
      ),
    ),

    // AppBar par défaut
    appBarTheme: const AppBarTheme(
      color: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: white,
      ),
    ),

    // Thème des boutons TextButton (Annuler/Confirmer par défaut)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: greenButton,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Nunito',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    // Thème des Dialogs
    dialogTheme: DialogTheme(
      backgroundColor: lightMint,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton,
        fontFamily: 'Nunito',
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        color: greenButton,
        fontFamily: 'Nunito',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: greenButton, width: 4),
      ),
    ),
  );

  // Widget pour les boutons avec BoxShadow
  static Widget customButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 5,
            offset: const Offset(4, 7)
          ),
        ],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: greenButton,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
          textStyle: const TextStyle(
            fontSize: 22, // Taille de police
            fontWeight: FontWeight.bold,
            fontFamily: 'Nunito',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(
              color: white, // Bordure blanche
              width: 2,
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  // Widget pour le fond commun
  static BoxDecoration backgroundDecoration() {
    return const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(backgroundImage),
        fit: BoxFit.cover,
      ),
    );
  }
}
