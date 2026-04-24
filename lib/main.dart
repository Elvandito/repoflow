import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GitHubService.init();
  runApp(const RepoFlowApp());
}

class RepoFlowApp extends StatelessWidget {
  const RepoFlowApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepoFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563eb),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
      ),
      home: GitHubService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// --- 1. LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_tokenController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await GitHubService.saveToken(_tokenController.text.trim());
      await GitHubService.getUser(); // Validate token
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Personal Access Token')),
        );
      }
      await GitHubService.logout();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('RepoFlow Pro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Native GitHub Manager', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Personal Access Token',
                  hintText: 'ghp_xxxxxxxx...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Connect Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. HOME SCREEN (Repo List) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _repos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    try {
      final repos = await GitHubService.getRepos();
      setState(() {
        _repos = repos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await GitHubService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositories', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _repos.length,
              itemBuilder: (context, index) {
                final repo = _repos[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200)
                  ),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Icon(
                      repo['private'] ? Icons.lock : Icons.public,
                      color: Colors.blue.shade600,
                    ),
                    title: Text(repo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(repo['language'] ?? 'Mixed', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExplorerScreen(
                            owner: repo['owner']['login'], 
                            repo: repo['name'], 
                            path: ''
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- 3. EXPLORER SCREEN (File Browser) ---
class ExplorerScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final String path;

  const ExplorerScreen({Key? key, required this.owner, required this.repo, required this.path}) : super(key: key);

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  List<dynamic> _contents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    try {
      final items = await GitHubService.getContents(widget.owner, widget.repo, widget.path);
      // Sort: Folders first
      items.sort((a, b) {
        if (a['type'] == 'dir' && b['type'] != 'dir') return -1;
        if (a['type'] != 'dir' && b['type'] == 'dir') return 1;
        return a['name'].compareTo(b['name']);
      });
      setState(() {
        _contents = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openItem(Map<String, dynamic> item) {
    if (item['type'] == 'dir') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExplorerScreen(
            owner: widget.owner,
            repo: widget.repo,
            path: item['path'],
          ),
        ),
      );
    } else {
      // Show snackbar for file tap (Native Editor can be implemented here)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected file: ${item['name']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.isEmpty ? widget.repo : widget.path.split('/').last, 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contents.isEmpty
              ? const Center(child: Text('Directory is empty', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: _contents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = _contents[index];
                    final isDir = item['type'] == 'dir';
                    return ListTile(
                      leading: Icon(
                        isDir ? Icons.folder : Icons.insert_drive_file,
                        color: isDir ? Colors.blue : Colors.grey.shade500,
                      ),
                      title: Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      trailing: isDir ? const Icon(Icons.chevron_right, size: 20) : null,
                      onTap: () => _openItem(item),
                    );
                  },
                ),
    );
  }
}