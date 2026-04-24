import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GitHubService {
  static const String baseUrl = 'https://api.github.com';
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('gh_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gh_token', token);
    _token = token;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gh_token');
    _token = null;
  }

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Map<String, String> get _headers {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'RepoFlow-App', 
    };
  }

  static Future<Map<String, dynamic>> getUser() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/user'), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body);
      if (res.statusCode == 401) throw Exception('Invalid Personal Access Token');
      throw Exception('GitHub Error: ${res.statusCode}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<List<dynamic>> getRepos() async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/repos?sort=updated&per_page=100'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load repositories');
  }

  static Future<List<dynamic>> getBranches(String owner, String repo) async {
    final res = await http.get(
      Uri.parse('$baseUrl/repos/$owner/$repo/branches'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load branches');
  }

  static Future<List<dynamic>> getContents(String owner, String repo, String path, String branch) async {
    final url = path.isEmpty 
        ? '$baseUrl/repos/$owner/$repo/contents?ref=$branch' 
        : '$baseUrl/repos/$owner/$repo/contents/$path?ref=$branch';
        
    final res = await http.get(Uri.parse(url), headers: _headers);
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [data];
    } else if (res.statusCode == 404) {
      return []; 
    }
    throw Exception('Failed to load contents');
  }

  static Future<void> saveFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String message,
    required String branch,
    String? sha, 
  }) async {
    final url = '$baseUrl/repos/$owner/$repo/contents/$path';
    final bytes = utf8.encode(content);
    final base64Content = base64Encode(bytes);

    final body = {
      'message': message,
      'content': base64Content,
      'branch': branch,
    };
    if (sha != null) body['sha'] = sha;

    final res = await http.put(Uri.parse(url), headers: _headers, body: jsonEncode(body));
    if (res.statusCode != 200 && res.statusCode != 201) {
      final errorData = jsonDecode(res.body);
      throw Exception(errorData['message'] ?? 'Failed to save file');
    }
  }

  static Future<void> deleteFile({
    required String owner,
    required String repo,
    required String path,
    required String sha,
    required String message,
    required String branch,
  }) async {
    final url = '$baseUrl/repos/$owner/$repo/contents/$path';
    final body = {
      'message': message,
      'sha': sha,
      'branch': branch,
    };

    final res = await http.delete(Uri.parse(url), headers: _headers, body: jsonEncode(body));
    if (res.statusCode != 200) {
      final errorData = jsonDecode(res.body);
      throw Exception(errorData['message'] ?? 'Failed to delete file');
    }
  }

  // FITUR BARU: Menghapus Repository
  static Future<void> deleteRepo(String owner, String repo) async {
    final url = '$baseUrl/repos/$owner/$repo';
    final res = await http.delete(Uri.parse(url), headers: _headers);
    
    if (res.statusCode != 204) { // GitHub API merespon 204 No Content untuk sukes delete repo
      final errorData = jsonDecode(res.body);
      String errMsg = errorData['message'] ?? 'Failed to delete repository';
      // Tambahkan info jika token kekurangan permissions
      if (res.statusCode == 403 || res.statusCode == 404) {
        errMsg += ' (Make sure your token has "delete_repo" scope)';
      }
      throw Exception(errMsg);
    }
  }
}
