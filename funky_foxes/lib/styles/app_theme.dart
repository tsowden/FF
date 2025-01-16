import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------
  // COULEURS
  // ---------------------------
  static const Color greenButton = Color(0xFF135836);
  static const Color darkerGreen = Color.fromARGB(255, 6, 37, 22);
  static const Color lightMint   = Color.fromARGB(255, 211, 248, 228);
  static const Color orangeTitle = Color.fromARGB(255, 240, 110, 10);
  static const Color white       = Colors.white;
  static const Color correctGreen  = Color(0xFF8BDD8E); 
  static const Color incorrectRed  = Color(0xFFF28080);

  // ---------------------------
  // IMAGE DE FOND
  // ---------------------------
  static const String backgroundImage = 'assets/images/fond2.png';

  // ---------------------------
  // THEME GLOBAL
  // ---------------------------
  static ThemeData themeData = ThemeData(
    primaryColor: greenButton,
    scaffoldBackgroundColor: Colors.transparent,
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
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: greenButton,
        textStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Nunito',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: lightMint,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton,
        fontFamily: 'Nunito',
      ),
      contentTextStyle: TextStyle(
        fontSize: 16,
        color: greenButton,
        fontFamily: 'Nunito',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: greenButton, width: 4),
      ),
    ),
  );

  // ---------------------------
  // BACKGROUND
  // ---------------------------
  static BoxDecoration backgroundDecoration() {
    return const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(backgroundImage),
        fit: BoxFit.cover,
      ),
    );
  }

  // ---------------------------
  // BOUTONS
  // ---------------------------
  static Widget customButton({
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    final Color bgColor = backgroundColor ?? greenButton;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 5,
            offset: const Offset(4, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: white,
          // Réduction de la hauteur du bouton
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Nunito',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(
              color: white,
              width: 2,
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  // ---------------------------
  // TEXT STYLES UTILES
  // ---------------------------

  // Petit style italic, ex. "About you:" ou "Turn:"
  static TextStyle topLabelStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: darkerGreen,
    );
  }

  // Style du rang
  static TextStyle rankStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: darkerGreen,
    );
  }

  // Style du nombre de berries dans le cercle
  static TextStyle circleNumberStyle(double circleSize) {
    return TextStyle(
      fontSize: circleSize * 0.2,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Nunito',
    );
  }

  // Style du message pop-up transitoire
  static BoxDecoration transientMessageBoxDecoration(double borderRadius) {
    return BoxDecoration(
      color: Colors.green[900],
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  static TextStyle transientMessageTextStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
  }

  // ...
  // Tu peux continuer à rajouter ici d'autres styles plus spécifiques
  // (par exemple pour cardName, description, etc.)
}
