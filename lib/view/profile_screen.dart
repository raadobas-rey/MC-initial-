import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  bool _loading = true;
  bool _saving = false;
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      _email = user.email ?? '';
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _name = (doc.data()?['name'] ?? '') as String;
        _photoBase64 = doc.data()?['photoBase64'] as String?;
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateName(String newName) async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'name': newName});
        setState(() => _name = newName);
        if (mounted) Navigator.pop(context, newName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPhotoBase64(String? b64) async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoBase64': b64});
        setState(() => _photoBase64 = b64);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted) status = await Permission.camera.request();
      return status.isGranted;
    } else {
      if (Platform.isIOS) {
        var status = await Permission.photos.status;
        if (!status.isGranted && !status.isLimited) {
          status = await Permission.photos.request();
        }
        // On iOS, "limited" still allows picking; treat it as allowed.
        return status.isGranted || status.isLimited;
      } else {
        // Android: for gallery picking, ImagePicker does not require runtime storage
        // permission on Android 13+ (Photo Picker) and generally works without it.
        // Let the picker handle permissions internally.
        return true;
      }
    }
  }

  Future<void> _pickPhoto({ImageSource? forcedSource}) async {
    final picker = ImagePicker();
    ImageSource? source = forcedSource;
    source ??= await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.photo),
                label: const Text('Pick from gallery'),
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              TextButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take a photo'),
                onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
    if (source == null) return;
    // Runtime permission check
    if (!await _requestPermission(source)) {
      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Permission Required'), content: Text(
          source == ImageSource.camera
              ? 'Camera permission is required to take a photo.'
              : 'Photos permission is required to pick an image.',
        ), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
      }
      return;
    }
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final decodedImg = img.decodeImage(bytes);
      Uint8List processedBytes = bytes;
      if (decodedImg != null) {
        final resized = img.copyResize(decodedImg, width: 150, height: 150);
        final jpg = img.encodeJpg(resized, quality: 80);
        processedBytes = Uint8List.fromList(jpg);
      }
      final base64str = base64Encode(processedBytes);
      await _setPhotoBase64(base64str);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    }
  }

  Future<void> _removePhoto() async {
    await _setPhotoBase64(null);
  }

  Future<void> _showEditName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit full name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Full name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != _name) {
      await _updateName(result);
    }
  }

  void _showPasswordInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change password'),
        content: const Text('We will send a password reset link to your email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = FirebaseAuth.instance.currentUser;
              final email = user?.email;
              if (email != null) {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset email sent. Check your inbox.')),
                  );
                }
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('This will permanently delete your account and notes. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) Navigator.pushReplacementNamed(context, '/signup');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to delete account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
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

  Widget _item({required String label, required String value, String? actionLabel, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onTap, child: Text(actionLabel))
          else
            IconButton(onPressed: onTap, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7),
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFFE9F5EC),
                            backgroundImage: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                                ? MemoryImage(base64Decode(_photoBase64!))
                                : null,
                            child: (_photoBase64 == null || _photoBase64!.isEmpty)
                                ? Text(
                                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                  onPressed: () => _pickPhoto(),
                                  child: const Text('Edit photo'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Color(0xFFFECACA)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                  onPressed: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                                      ? _removePhoto
                                      : null,
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _sectionTitle('Personal details'),
                      _item(label: 'Full name', value: _name, actionLabel: 'Edit', onTap: _showEditName),
                      _item(label: 'Password', value: '••••••••', actionLabel: 'Edit', onTap: _showPasswordInfo),
                      _item(label: 'Email address', value: _email, actionLabel: 'Edit', onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email changes are not supported yet.')),
                        );
                      }),
                      _sectionTitle('Other'),
                      _item(label: 'Delete account', value: '', onTap: _showDeleteAccount),
                      if (_saving) const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
