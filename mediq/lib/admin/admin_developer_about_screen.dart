import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_drawer.dart';
import '../main.dart';

class AdminDeveloperAboutScreen extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? profileImageUrl; // Changed to profileImageUrl

  const AdminDeveloperAboutScreen({
    super.key,
    required this.userName,
    required this.userRole,
    this.profileImageUrl, // Updated parameter
  });

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

      drawer: AdminDrawer(
        userName: userName,
        userRole: userRole,
        profileImageBase64: null, // You might want to update AdminDrawer too
        onNavTap: (page) => Navigator.pop(context),
        onLogout: () => Navigator.pop(context),
      ),

      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu,
                color: AppColors.primaryPurple, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Developer About Me',
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // UPDATED HEADER WITH PROFILE PICTURE
            _buildHeaderCardWithProfile(),
            const SizedBox(height: 30),

            // Developer Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDeveloperImage(),
                  const SizedBox(height: 20),

                  // Name and Role
                  const Text(
                    "Malitha Tishamal",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Flutter Developer & UI/UX Designer",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  // Description
                  const Text(
                    "Passionate mobile app developer with expertise in Flutter framework. "
                    "Creating beautiful and functional applications with modern UI/UX design principles.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Social Media Links
                  _buildSocialIconsRow(_launchUrl),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Skills Section
            _buildSkillsSection(),

            const SizedBox(height: 25),

            // Contact Information
            _buildContactInfo(),

            const SizedBox(height: 30),

            // Footer
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Text(
                    '🚀 Built with Flutter & ❤️',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Developed By Malitha Tishamal',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '© ${DateTime.now().year} Medi-Q App',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // UPDATED HEADER CARD WITH PROFILE PICTURE - USING profileImageUrl
  Widget _buildHeaderCardWithProfile() {
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
          // PROFILE PICTURE - USING profileImageUrl
          _buildProfilePicture(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  userRole,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkText.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: AppColors.primaryPurple),
                      SizedBox(width: 4),
                      Text(
                        'Admin Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PROFILE PICTURE WIDGET - USING profileImageUrl FROM FIRESTORE
  Widget _buildProfilePicture() {
    Widget profileImageWidget;

    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      // Use NetworkImage for Cloudinary URL from Firestore
      profileImageWidget = Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryPurple.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            profileImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.primaryPurple,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading profile image: $error');
              return _buildDefaultProfileIcon();
            },
          ),
        ),
      );
    } else {
      profileImageWidget = _buildDefaultProfileIcon();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        profileImageWidget,
        // Add a subtle camera icon overlay to indicate it's a profile picture
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.photo_camera,
              size: 14,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
      ],
    );
  }

  // DEFAULT PROFILE ICON
  Widget _buildDefaultProfileIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.person,
        size: 35,
        color: AppColors.primaryPurple,
      ),
    );
  }

  // DEVELOPER IMAGE
  Widget _buildDeveloperImage() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withOpacity(0.3),
                    AppColors.primaryPurple.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.5),
                  width: 3,
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
          ],
        ),
        const SizedBox(height: 15),
        // Decorative stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 16, color: AppColors.primaryPurple.withOpacity(0.6)),
            const SizedBox(width: 5),
            Icon(Icons.star, size: 20, color: AppColors.primaryPurple),
            const SizedBox(width: 5),
            Icon(Icons.star, size: 16, color: AppColors.primaryPurple.withOpacity(0.6)),
          ],
        )
      ],
    );
  }

  // SOCIAL ICONS
  Widget _buildSocialIconsRow(Future<void> Function(String) launcher) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSocialIcon(
            FontAwesomeIcons.instagram,
            Colors.pink,
            'Instagram',
            () => launcher('https://www.instagram.com/malithatishamal/'),
          ),
          _buildSocialIcon(
            FontAwesomeIcons.facebookF,
            Colors.blue,
            'Facebook',
            () => launcher('https://www.facebook.com/malithatishamal/'),
          ),
          _buildSocialIcon(
            FontAwesomeIcons.linkedinIn,
            Colors.blue.shade800,
            'LinkedIn',
            () => launcher('https://www.linkedin.com/in/malitha-tishamal/'),
          ),
          _buildSocialIcon(
            Icons.email_outlined,
            Colors.red,
            'Email',
            () => launcher('mailto:malithatishamal@gmail.com?subject=Inquiry from Medi-Q App'),
          ),
          _buildSocialIcon(
            Icons.language,
            Colors.green,
            'Website',
            () => launcher('https://www.malithatishamal.42web.io/'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tooltip,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // SKILLS SECTION
  Widget _buildSkillsSection() {
    final skills = [
      {'icon': Icons.phone_iphone, 'name': 'Flutter Development', 'color': Colors.blue},
      {'icon': Icons.design_services, 'name': 'UI/UX Design', 'color': Colors.purple},
      {'icon': Icons.fireplace, 'name': 'Firebase', 'color': Colors.orange},
      {'icon': Icons.cloud, 'name': 'Cloudinary', 'color': Colors.green},
      {'icon': Icons.api, 'name': 'REST API', 'color': Colors.red},
      {'icon': Icons.code, 'name': 'Dart Programming', 'color': Colors.blue.shade700},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills & Expertise',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: skill['color'] as Color? ?? AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (skill['color'] as Color? ?? AppColors.primaryPurple).withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      skill['icon'] as IconData? ?? Icons.code,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      skill['name'] as String? ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // CONTACT INFORMATION
  Widget _buildContactInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get In Touch',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 15),
          _buildContactItem(
            Icons.email,
            'Email',
            'malithatishamal@gmail.com',
            () => _launchUrl('mailto:malithatishamal@gmail.com'),
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            Icons.phone,
            'Phone',
            '+94 78 553 0992',
            () => _launchUrl('tel:+94785530992'),
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            Icons.location_on,
            'Location',
            'Matara, Sri Lanka',
            () => _launchUrl('https://maps.google.com/?q=Matara,Sri+Lanka'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryPurple),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primaryPurple.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}