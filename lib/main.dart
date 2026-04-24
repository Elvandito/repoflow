import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563eb),
          primary: const Color(0xFF2563eb),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: GitHubService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// --- HELPER: LANGUAGE COLOR MAP ---
Color getLangColor(String? lang) {
  switch (lang?.toLowerCase()) {
    case 'dart': return Colors.cyan;
    case 'javascript': return Colors.amber;
    case 'html': return Colors.orange;
    case 'python': return Colors.blue;
    case 'css': return Colors.deepPurple;
    default: return Colors.grey;
  }
}

// --- LOGIN SCREEN ---
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
      await GitHubService.getUser(); 
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      await GitHubService.logout();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Hero(
                  tag: 'logo',
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: const Icon(Icons.flash_on, color: Colors.white, size: 45),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('RepoFlow', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const Text('Professional GitHub Manager', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 48),
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Personal Access Token',
                    prefixIcon: const Icon(Icons.key_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 64,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                      elevation: 8, shadowColor: Colors.blue.withOpacity(0.4),
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _repos = [];
  List<dynamic> _filteredRepos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRepos();
    _searchController.addListener(_filterList);
  }

  Future<void> _loadRepos() async {
    setState(() => _isLoading = true);
    try {
      final repos = await GitHubService.getRepos();
      setState(() { _repos = repos; _filteredRepos = repos; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRepos = _repos.where((r) => r['name'].toString().toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded, size: 22), onPressed: () async {
            await GitHubService.logout();
            if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search repositories...',
              elevation: MaterialStateProperty.all(0),
              backgroundColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
              leading: const Icon(Icons.search, color: Colors.grey),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRepos,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredRepos.isEmpty 
                  ? const Center(child: Text('No repositories found'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredRepos.length,
                      itemBuilder: (context, index) {
                        final repo = _filteredRepos[index];
                        return _RepoCard(repo: repo);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  final dynamic repo;
  const _RepoCard({required this.repo});

  @override
  Widget build(BuildContext context) {
    final String defaultBranch = repo['default_branch'] ?? 'main';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExplorerScreen(owner: repo['owner']['login'], repo: repo['name'], path: '', branch: defaultBranch),
        )),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(repo['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ),
                  Icon(repo['private'] ? Icons.lock_outline : Icons.public_outlined, size: 18, color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: getLangColor(repo['language'])),
                  ),
                  const SizedBox(width: 8),
                  Text(repo['language'] ?? 'Mixed', style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.star_rounded, size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text('${repo['stargazers_count']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExplorerScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final String path;
  final String branch;
  const ExplorerScreen({Key? key, required this.owner, required this.repo, required this.path, required this.branch}) : super(key: key);

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  List<dynamic> _contents = [];
  bool _isLoading = true;
  late String _currentBranch;

  @override
  void initState() {
    super.initState();
    _currentBranch = widget.branch;
    _loadContents();
  }

  Future<void> _loadContents() async {
    setState(() => _isLoading = true);
    try {
      final items = await GitHubService.getContents(widget.owner, widget.repo, widget.path, _currentBranch);
      items.sort((a, b) {
        if (a['type'] == 'dir' && b['type'] != 'dir') return -1;
        return a['name'].compareTo(b['name']);
      });
      setState(() { _contents = items; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showCommits() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => _CommitHistoryView(owner: widget.owner, repo: widget.repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.path.isEmpty ? widget.repo : widget.path.split('/').last, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('branch: $_currentBranch', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded), onPressed: _showCommits),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadContents,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contents.isEmpty
              ? const Center(child: Text('Directory is empty'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _contents.length,
                  itemBuilder: (context, index) {
                    final item = _contents[index];
                    final isDir = item['type'] == 'dir';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded, color: isDir ? Colors.blue : Colors.blueGrey),
                      title: Text(item['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.blueGrey),
                      onTap: () {
                        if (isDir) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ExplorerScreen(owner: widget.owner, repo: widget.repo, path: item['path'], branch: _currentBranch),
                          ));
                        }
                      },
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, 
        label: const Text('New'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _CommitHistoryView extends StatelessWidget {
  final String owner;
  final String repo;
  const _CommitHistoryView({required this.owner, required this.repo});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<dynamic>>(
          future: GitHubService.getCommits(owner, repo),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final commits = snapshot.data!;
            return Column(
              children: [
                Container(
                  width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Commit History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: commits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final c = commits[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: Text(c['commit']['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('${c['commit']['author']['name']} • ${c['sha'].toString().substring(0, 7)}', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
