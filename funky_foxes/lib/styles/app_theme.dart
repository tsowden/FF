import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales
  static const Color greenButton = Color(0xFF135836); // Vert foncé
  static const Color lightMint = Color.fromARGB(255, 211, 248, 228); // Vert clair presque blanc
  static const Color orangeTitle = Color.fromARGB(255, 240, 110, 10);
  static const Color white = Colors.white;

  // Image de fond par défaut
  static const String backgroundImage = 'assets/images/fond2.png';

  // Thème global
  static ThemeData themeData = ThemeData(
    primaryColor: greenButton,
    scaffoldBackgroundColor: Colors.transparent,

    // Police par défaut
    fontFamily: 'Nunito',
    textTheme: const TextTheme(
      headline1: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        fontFamily: 'PermanentMarker',
        color: orangeTitle,
        shadows: [
          Shadow(
            color: Colors.black38, // Couleur de l'ombre
            blurRadius: 6, // Rayon de flou
            offset: Offset(2, 4), // Position de l'ombre (horizontal, vertical)
          ),
        ],
      ),
      headline6: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: greenButton,
      ),
      bodyText1: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: greenButton,
      ),
      bodyText2: TextStyle(
        fontSize: 14,
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
        foregroundColor: greenButton, // Texte vert foncé
        textStyle: const TextStyle(
          fontSize: 18, // Taille du texte
          fontWeight: FontWeight.bold,
          fontFamily: 'Nunito',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Bords arrondis
        ),
      ),
    ),

    // Thème des Dialogs
    dialogTheme: DialogTheme(
      backgroundColor: lightMint, // Couleur de fond clair (vert clair presque blanc)
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton, // Texte vert foncé
        fontFamily: 'Nunito',
      ),
      contentTextStyle: TextStyle(
        fontSize: 16,
        color: greenButton, // Texte vert foncé
        fontFamily: 'Nunito',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Bords arrondis
        side: BorderSide(color: greenButton, width: 4), // Bordure verte foncée
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
            color: Colors.black.withOpacity(0.8), // Couleur de l'ombre
            blurRadius: 5, // Rayon de flou compact
            offset: Offset(4, 7), // Position de l'ombre (horizontal, vertical)
          ),
        ],
        borderRadius: BorderRadius.circular(25), // Rayon de la bordure
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
