import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  String _fontSize = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _darkMode = data?['darkMode'] ?? false;
          _fontSize = data?['fontSize'] ?? 'Medium';
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({key: value});
    } catch (_) {
      // ignore
    }
  }


  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About NoteNest'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
            Text('NoteNest v1.0.0'),
            SizedBox(height: 8),
            Text('A modern note-taking app with AI-powered features.'),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Smart note organization'),
            Text('• AI-powered summarization'),
            Text('• Study assistant'),
            Text('• Quiz generation'),
            Text('• Cloud sync'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
                    ),
                  ],
                ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.6,
              ),
      ),
    );
  }

  Widget _settingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
                  children: [
          _sectionTitle('Appearance'),
          _settingTile(
            title: 'Dark Mode',
            subtitle: 'Switch to dark theme',
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                _saveSetting('darkMode', v);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme change requires app restart')),
                );
              },
            ),
          ),
          _settingTile(
            title: 'Font Size',
            subtitle: _fontSize,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Font Size'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Small', 'Medium', 'Large'].map((size) {
                      return RadioListTile<String>(
                        title: Text(size),
                        value: size,
                        groupValue: _fontSize,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fontSize = v);
                            _saveSetting('fontSize', v);
                            Navigator.pop(context);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          _sectionTitle('About'),
          _settingTile(
            title: 'About NoteNest',
            subtitle: 'Version 1.0.0',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
          _settingTile(
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon')),
              );
            },
          ),
          _settingTile(
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service coming soon')),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

