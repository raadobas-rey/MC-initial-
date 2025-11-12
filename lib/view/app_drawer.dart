import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String? userName;
  final String? email;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.email,
    required this.onOpenProfile,
    required this.onOpenFavorites,
    required this.onOpenTrash,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account header with light green background
            Container(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9), // Light green background
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE8F5E9),
                    const Color(0xFFF1F8E9),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circle with green accent
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (userName ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName ?? 'User',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700]?.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Menu items
            _item(context, icon: Icons.person_outline, label: 'Account', onTap: onOpenProfile),
            _item(context, icon: Icons.favorite_border, label: 'Favorites', onTap: onOpenFavorites),
            _item(context, icon: Icons.delete_outline, label: 'Trash', onTap: onOpenTrash),
            _item(context, icon: Icons.settings_outlined, label: 'Settings', onTap: onOpenSettings),
            const Spacer(),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.green[100],
            ),
            _item(context, icon: Icons.logout, label: 'Log out', onTap: onLogout, isLogout: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext ctx, {required IconData icon, required String label, required VoidCallback onTap, bool isLogout = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout 
                ? Colors.red[50] 
                : Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon, 
            color: isLogout 
                ? Colors.red[700] 
                : Colors.green[700], 
            size: 22,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: isLogout 
                ? Colors.red[700] 
                : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.pop(ctx);
          onTap();
        },
        hoverColor: isLogout 
            ? Colors.red[50] 
            : Colors.green[50],
      ),
    );
  }
}
