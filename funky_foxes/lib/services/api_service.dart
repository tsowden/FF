import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.0.53:3000/api/game';

  /// Crée une nouvelle partie en envoyant le `playerName` au serveur
  Future<Map<String, dynamic>?> createGame(String playerName) async {
    final url = Uri.parse('$_baseUrl/create-game');
    print('Envoi de la requête POST à $url avec le nom du joueur : $playerName');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'playerName': playerName}),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody is Map<String, dynamic>) {
          print('Réponse du serveur pour createGame : $responseBody');
          return responseBody;
        } else {
          print('Erreur : Réponse inattendue du serveur pour createGame.');
          return null;
        }
      } else {
        print('Erreur HTTP (${response.statusCode}) : ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception lors de la requête createGame : $e');
      return null;
    }
  }

  /// Rejoint une partie existante avec le `gameId` et le `playerName`
  Future<Map<String, dynamic>?> joinGame(String gameId, String playerName) async {
    final url = Uri.parse('$_baseUrl/join-game');
    print('Envoi de la requête POST à $url avec gameId: $gameId et playerName: $playerName');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'gameId': gameId, 'playerName': playerName}),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody is Map<String, dynamic>) {
          print('Réponse du serveur pour joinGame : $responseBody');
          return responseBody;
        } else {
          print('Erreur : Réponse inattendue du serveur pour joinGame.');
          return null;
        }
      } else {
        print('Erreur HTTP (${response.statusCode}) : ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception lors de la requête joinGame : $e');
      return null;
    }
  }
}
