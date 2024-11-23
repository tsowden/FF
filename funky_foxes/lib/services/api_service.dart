import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.0.53:3000/api/game';

Future<Map<String, String>?> createGame(String playerName) async {
    final url = Uri.parse('$_baseUrl/create-game');
    print('Envoi de la requête POST à $url avec le nom du joueur : $playerName');
    final response = await http.post(
      Uri.parse('$_baseUrl/create-game'),
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

  Future<bool> joinGame(String gameId, String playerName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/join-game'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'gameId': gameId, 'playerName': playerName}),
    );
    print('Réponse reçue : ${response.statusCode}');
    print('Corps de la réponse : ${response.body}');

    if (response.statusCode == 200) {
      return true;
    } else {
        print('Erreur lors de la création de la partie : ${response.statusCode}');
        print('Message d\'erreur : ${response.body}');
        return false;
    }
  }
}
