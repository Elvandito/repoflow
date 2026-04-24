import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk fitur Share/Copy ke Clipboard
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563eb)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), 
      ),
      home: GitHubService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
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
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('RepoFlow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Native GitHub Manager', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Personal Access Token',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Connect Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HOME SCREEN (REPOSITORIES) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _repos = [];
  bool _isLoading = true;

  // State untuk Fitur Multi-Selection
  Set<String> _selectedRepoIds = {};
  bool get _isSelectionMode => _selectedRepoIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    setState(() => _isLoading = true);
    try {
      final repos = await GitHubService.getRepos();
      setState(() { _repos = repos; _isLoading = false; _selectedRepoIds.clear(); });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String repoId) {
    setState(() {
      if (_selectedRepoIds.contains(repoId)) {
        _selectedRepoIds.remove(repoId);
      } else {
        _selectedRepoIds.add(repoId);
      }
    });
  }

  // Bagikan URL Repo ke Clipboard
  void _shareRepos(List<dynamic> reposToShare) {
    List<String> urls = reposToShare.map((r) => r['html_url'] as String).toList();
    Clipboard.setData(ClipboardData(text: urls.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${urls.length} link(s) copied to clipboard!'), backgroundColor: Colors.green),
    );
    setState(() => _selectedRepoIds.clear());
  }

  // Hapus Repo
  Future<void> _deleteRepos(List<dynamic> reposToDelete) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Repository?'),
        content: Text('Are you sure you want to permanently delete ${reposToDelete.length} repository(s)?\n\nThis cannot be undone!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              int successCount = 0;
              for (var r in reposToDelete) {
                try {
                  await GitHubService.deleteRepo(r['owner']['login'], r['name']);
                  successCount++;
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              }
              if (successCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount repo(s) deleted successfully'), backgroundColor: Colors.green));
              }
              _loadRepos();
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> selectedReposData = _repos.where((r) => _selectedRepoIds.contains(r['id'].toString())).toList();

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text('${_selectedRepoIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold))
          : const Text('Repositories', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedRepoIds.clear()))
          : null,
        actions: _isSelectionMode
          ? [
              IconButton(icon: const Icon(Icons.share), onPressed: () => _shareRepos(selectedReposData)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRepos(selectedReposData)),
            ]
          : [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRepos),
              IconButton(icon: const Icon(Icons.logout), onPressed: () async {
                await GitHubService.logout();
                if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }),
            ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _repos.length,
              itemBuilder: (context, index) {
                final repo = _repos[index];
                final String repoId = repo['id'].toString();
                final bool isSelected = _selectedRepoIds.contains(repoId);
                
                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), 
                    side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade200, width: isSelected ? 2 : 1)
                  ),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: _isSelectionMode
                        ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(repoId))
                        : Icon(repo['private'] ? Icons.lock : Icons.public, color: Colors.blue.shade600),
                    title: Text(repo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Row(
                      children: [
                        Text(repo['language'] ?? 'Mixed', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.star, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('${repo['stargazers_count']}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: _isSelectionMode 
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (val) {
                              if(val == 'share') _shareRepos([repo]);
                              if(val == 'delete') _deleteRepos([repo]);
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'share', child: Text('Share URL')),
                              const PopupMenuItem<String>(value: 'delete', child: Text('Delete Repo', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                    onLongPress: () => _toggleSelection(repoId),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(repoId);
                      } else {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ExplorerScreen(owner: repo['owner']['login'], repo: repo['name'], path: '', branch: repo['default_branch'] ?? 'main'),
                        ));
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- EXPLORER SCREEN (FILES) ---
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

  // State untuk Fitur Multi-Selection Files
  Set<String> _selectedFilePaths = {};
  bool get _isSelectionMode => _selectedFilePaths.isNotEmpty;

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
        if (a['type'] != 'dir' && b['type'] == 'dir') return 1;
        return a['name'].compareTo(b['name']);
      });
      setState(() { _contents = items; _isLoading = false; _selectedFilePaths.clear(); });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Dialog Pilihan Cabang (Branch Switcher)
  Future<void> _showBranchPicker() async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final branches = await GitHubService.getBranches(widget.owner, widget.repo);
      if(mounted) Navigator.pop(context); // Close loading
      
      if(mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (context) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final b = branches[index]['name'];
                return ListTile(
                  leading: const Icon(Icons.account_tree), // Perbaikan Icons.git_branch -> Icons.account_tree
                  title: Text(b, style: TextStyle(fontWeight: b == _currentBranch ? FontWeight.bold : FontWeight.normal)),
                  trailing: b == _currentBranch ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentBranch = b);
                    _loadContents();
                  },
                );
              },
            );
          }
        );
      }
    } catch(e) {
      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load branches')));
      }
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedFilePaths.contains(path)) {
        _selectedFilePaths.remove(path);
      } else {
        _selectedFilePaths.add(path);
      }
    });
  }

  void _shareFiles(List<dynamic> filesToShare) {
    List<String> urls = filesToShare.map((f) => f['html_url'] as String).toList();
    Clipboard.setData(ClipboardData(text: urls.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${urls.length} link(s) copied to clipboard!'), backgroundColor: Colors.green),
    );
    setState(() => _selectedFilePaths.clear());
  }

  Future<void> _deleteFiles(List<dynamic> filesToDelete) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Files?'),
        content: Text('Are you sure you want to permanently delete ${filesToDelete.length} item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              int successCount = 0;
              for (var f in filesToDelete) {
                // GitHub API tidak mendukung hapus folder langsung, harus per file. Kita skip dir untuk aman.
                if (f['type'] == 'dir') continue; 
                try {
                  await GitHubService.deleteFile(
                    owner: widget.owner, repo: widget.repo, path: f['path'], sha: f['sha'], branch: _currentBranch, message: 'Delete ${f['name']} via RepoFlow',
                  );
                  successCount++;
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              }
              if (successCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount file(s) deleted successfully'), backgroundColor: Colors.green));
              }
              _loadContents();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  void _openItem(Map<String, dynamic> item) {
    if (item['type'] == 'dir') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ExplorerScreen(owner: widget.owner, repo: widget.repo, path: item['path'], branch: _currentBranch),
      )).then((_) => _loadContents());
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => EditorScreen(
          owner: widget.owner, repo: widget.repo, path: item['path'], branch: _currentBranch, 
          fileName: item['name'], sha: item['sha'], contentBase64: item['content'] ?? '',
        ),
      )).then((_) => _loadContents());
    }
  }

  void _showCreateDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isFolder = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: RadioListTile<bool>(title: const Text('File'), value: false, groupValue: isFolder, onChanged: (v) => setDialogState(() => isFolder = v!))),
                      Expanded(child: RadioListTile<bool>(title: const Text('Folder'), value: true, groupValue: isFolder, onChanged: (v) => setDialogState(() => isFolder = v!))),
                    ],
                  ),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: isFolder ? 'Folder Name' : 'File Name (e.g. script.js)', border: const OutlineInputBorder())),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    Navigator.pop(context);
                    String fullPath = widget.path.isEmpty ? nameController.text : '${widget.path}/${nameController.text}';
                    if (isFolder) fullPath = '$fullPath/.gitkeep';
                    setState(() => _isLoading = true);
                    try {
                      await GitHubService.saveFile(owner: widget.owner, repo: widget.repo, path: fullPath, branch: _currentBranch, content: isFolder ? 'Auto-generated directory' : '', message: 'Create $fullPath');
                      _loadContents();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> selectedFilesData = _contents.where((f) => _selectedFilePaths.contains(f['path'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
          ? Text('${_selectedFilePaths.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.path.isEmpty ? widget.repo : widget.path.split('/').last, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: _showBranchPicker,
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree, size: 12, color: Colors.grey), // Perbaikan Icons.git_branch -> Icons.account_tree
                      const SizedBox(width: 4),
                      Text(_currentBranch, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
        backgroundColor: _isSelectionMode ? Colors.blue.shade50 : Colors.white, 
        elevation: 1,
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedFilePaths.clear()))
          : null,
        actions: _isSelectionMode
          ? [
              IconButton(icon: const Icon(Icons.share), onPressed: () => _shareFiles(selectedFilesData)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteFiles(selectedFilesData)),
            ]
          : [],
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
                    final String path = item['path'];
                    final bool isSelected = _selectedFilePaths.contains(path);

                    return ListTile(
                      tileColor: isSelected ? Colors.blue.shade50 : null,
                      leading: _isSelectionMode
                        ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(path))
                        : Icon(isDir ? Icons.folder : Icons.insert_drive_file, color: isDir ? Colors.blue : Colors.grey.shade500),
                      title: Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      trailing: _isSelectionMode
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (val) {
                              if(val == 'edit' && !isDir) _openItem(item);
                              if(val == 'share') _shareFiles([item]);
                              if(val == 'delete' && !isDir) _deleteFiles([item]);
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              if (!isDir) const PopupMenuItem<String>(value: 'edit', child: Text('Edit File')),
                              const PopupMenuItem<String>(value: 'share', child: Text('Share Link')),
                              if (!isDir) const PopupMenuItem<String>(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                      onLongPress: () => _toggleSelection(path),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(path);
                        } else {
                          _openItem(item);
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- FILE EDITOR SCREEN ---
class EditorScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final String path;
  final String branch;
  final String fileName;
  final String sha;
  final String contentBase64; 

  const EditorScreen({Key? key, required this.owner, required this.repo, required this.path, required this.branch, required this.fileName, required this.sha, required this.contentBase64}) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isMarkdown = false;
  late String _currentSha;

  @override
  void initState() {
    super.initState();
    _currentSha = widget.sha;
    _isMarkdown = widget.fileName.toLowerCase().endsWith('.md');
    _fetchFullContent();
  }

  Future<void> _fetchFullContent() async {
    try {
      final res = await GitHubService.getContents(widget.owner, widget.repo, widget.path, widget.branch);
      if (res.isNotEmpty) {
        String base64Str = res[0]['content'].replaceAll(RegExp(r'\s+'), '');
        String decoded = utf8.decode(base64Decode(base64Str));
        _contentController.text = decoded;
        _currentSha = res[0]['sha'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load content')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await GitHubService.saveFile(
        owner: widget.owner, repo: widget.repo, path: widget.path, branch: widget.branch, sha: _currentSha,
        content: _contentController.text, message: 'Update ${widget.fileName} via RepoFlow Native',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File saved successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _isMarkdown ? 2 : 1,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          backgroundColor: Colors.white, elevation: 1,
          actions: [
            _isSaving 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.save, color: Colors.blue), onPressed: _saveChanges),
          ],
          bottom: _isMarkdown 
            ? const TabBar(tabs: [Tab(text: 'Code'), Tab(text: 'Preview')]) 
            : null,
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _isMarkdown 
                ? TabBarView(children: [_buildEditor(), _buildPreview()])
                : _buildEditor(),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _contentController, maxLines: null, keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Write your code here...'),
      ),
    );
  }

  Widget _buildPreview() {
    return Markdown(data: _contentController.text, padding: const EdgeInsets.all(16.0));
  }
}
