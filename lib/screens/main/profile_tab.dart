import 'package:flutter/material.dart';

/// The "Profile" tab: user info card + account settings actions. Purely
/// presentational — the bottom-sheet/dialog flows it triggers (edit
/// profile, change password, delete account) are owned by [MainScreen]
/// since they mutate shared state and are also reachable from the
/// navigation drawer, so they're passed in as callbacks.
class ProfileTab extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String userMobile;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;

  const ProfileTab({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userMobile,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onDeleteAccount,
  });

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF10B981)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Stunning Premium Profile Card with overlapping cover banner
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 8),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Section with Banner & Avatar Stack
                SizedBox(
                  height: 145,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Banner
                      Container(
                        height: 95,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withAlpha(200),
                              theme.colorScheme.secondary.withAlpha(200),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Decorative circle
                      Positioned(
                        right: -10,
                        top: -10,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withAlpha(25),
                        ),
                      ),
                      // Avatar positioned overlapping the banner
                      Positioned(
                        top: 45,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                userName.substring(0, userName.length > 1 ? 2 : 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rest of card details
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                  child: Column(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Personal Information Section
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'PERSONAL DETAILS',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          _buildProfileTile(Icons.phone, 'Mobile Number', userMobile.isNotEmpty ? userMobile : 'Not Provided'),
          _buildProfileTile(Icons.email, 'Email Address', userEmail),
          const SizedBox(height: 24),
          // Settings and Actions Section
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Edit Profile details action
          _buildSettingsTile(
            context,
            icon: Icons.edit_note,
            title: 'Edit Personal Details',
            subtitle: 'Update your name, email, and mobile',
            iconColor: theme.colorScheme.primary,
            onTap: onEditProfile,
          ),
          // Change password action
          _buildSettingsTile(
            context,
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Reset or secure your password details',
            iconColor: Colors.amber[700]!,
            onTap: onChangePassword,
          ),
          // Delete account action
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            title: 'Delete My Account',
            subtitle: 'Permanently close and delete your credentials',
            iconColor: Colors.red,
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
