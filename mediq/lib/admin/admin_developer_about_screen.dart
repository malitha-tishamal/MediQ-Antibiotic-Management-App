import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_drawer.dart';
import '../main.dart';

class AdminDeveloperAboutScreen extends StatelessWidget {
  const AdminDeveloperAboutScreen({super.key});

  // URL Launcher Function
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,

      // ⭐ FIXED: AdminDrawer now includes all required parameters
      drawer: AdminDrawer(
        userName: "Malitha Tishamal",
        userRole: "Administrator",
        onNavTap: (page) {
          Navigator.pop(context);
        },
        onLogout: () {
          Navigator.pop(context);
        },
      ),

      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu,
                  color: AppColors.primaryPurple, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),

        title: const Text(
          'Developer About Me',
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none,
                color: AppColors.primaryPurple, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 30),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Developer About Me',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildDeveloperImage(),

            const SizedBox(height: 40),

            _buildSocialIconsRow(_launchUrl),

            const SizedBox(height: 30),

            const Text(
              'Malitha Tishamal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Full Stack-Developer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryPurple,
              ),
            ),

            const SizedBox(height: 80),

            const Text(
              'Developed By Malitha Tishamal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // HEADER CARD
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.2),
            AppColors.primaryPurple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person,
                size: 30, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Malitha Tishamal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.darkText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // DEVELOPER IMAGE
  Widget _buildDeveloperImage() {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.5),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assets/developer/developer_photo.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.star_half_rounded, size: 20, color: AppColors.primaryPurple),
            SizedBox(width: 80),
            Icon(Icons.star_half_rounded, size: 20, color: AppColors.primaryPurple),
          ],
        )
      ],
    );
  }

  // SOCIAL ICONS
  Widget _buildSocialIconsRow(Future<void> Function(String) launcher) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSocialIcon(FontAwesomeIcons.instagram, Colors.purple, () {
          launcher('https://www.instagram.com/malithatishamal/');
        }),

        _buildSocialIcon(FontAwesomeIcons.facebookF, Colors.blue, () {
          launcher('https://www.facebook.com/malithatishamal/');
        }),

        _buildSocialIcon(FontAwesomeIcons.linkedinIn, Colors.blue.shade900, () {
          launcher('https://www.linkedin.com/in/malitha-tishamal/');
        }),

        _buildSocialIcon(Icons.email_outlined, Colors.red, () {
          launcher(
              'mailto:malithatishamal@gmail.com?subject=Inquiry from Medi-Q App');
        }),

        _buildSocialIcon(Icons.language, Colors.green, () {
          launcher('https://www.malithatishamal.42web.io/');
        }),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}
