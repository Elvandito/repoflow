import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GitHubService {
  static const String baseUrl = 'https://api.github.com';
  static String? _token;

  // Initialize and load token from device storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('gh_token');
  }

  // Save new token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gh_token', token);
    _token = token;
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gh_token');
    _token = null;
  }

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  // Helper for API Headers
  static Map<String, String> get _headers {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github.v3+json',
    };
  }

  // Get current User Profile
  static Future<Map<String, dynamic>> getUser() async {
    final res = await http.get(Uri.parse('$baseUrl/user'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to authenticate. Invalid Token.');
    }
  }

  // Get Repositories
  static Future<List<dynamic>> getRepos() async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/repos?sort=updated&per_page=100'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to load repositories');
    }
  }

  // Get File/Folder Contents
  static Future<List<dynamic>> getContents(String owner, String repo, String path) async {
    final url = path.isEmpty 
        ? '$baseUrl/repos/$owner/$repo/contents' 
        : '$baseUrl/repos/$owner/$repo/contents/$path';
        
    final res = await http.get(Uri.parse(url), headers: _headers);
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [data];
    } else if (res.statusCode == 404) {
      return []; // Empty directory
    } else {
      throw Exception('Failed to load contents');
    }
  }
}