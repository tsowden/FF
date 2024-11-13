import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.0.53:3000/api';

  Future<Map<String, String>?> createGame(String playerName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/game/create-game'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'playerName': playerName}),
    );

    if (response.statusCode == 200) {
      return Map<String, String>.from(json.decode(response.body));
    } else {
      print('Erreur lors de la création de la partie: ${response.statusCode}');
      print('Réponse du serveur : ${response.body}');
      return null;
    }
  }

  Future<String?> joinGame(String gameId, String playerName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/game/join-game'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'gameId': gameId, 'playerName': playerName}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['playerId'];
    } else {
      print('Erreur lors de la connexion à la partie');
      return null;
    }
  }
}
