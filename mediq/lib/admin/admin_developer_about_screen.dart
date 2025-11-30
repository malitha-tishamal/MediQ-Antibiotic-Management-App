import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_drawer.dart';
import '../main.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  
  // Header gradient colors matching Factory Owner Dashboard - BLUE THEME
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

class AdminDeveloperAboutScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String? profileImageUrl;

  const AdminDeveloperAboutScreen({
    super.key,
    required this.userName,
    required this.userRole,
    this.profileImageUrl,
  });

  @override
  State<AdminDeveloperAboutScreen> createState() => _AdminDeveloperAboutScreenState();
}

class _AdminDeveloperAboutScreenState extends State<AdminDeveloperAboutScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // URL Launcher Function
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  // 🌟 FIXED HEADER - Profile Image Loading Issue Solved
  Widget _buildDashboardHeader(BuildContext context) {
    // Debug print to check the profile image URL
    if (widget.profileImageUrl != null) {
      debugPrint('🖼️ Profile Image URL: ${widget.profileImageUrl}');
    } else {
      debugPrint('❌ No Profile Image URL provided');
    }

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // 🎯 FIXED Profile Picture with proper network image loading
              _buildProfilePicture(),
              
              const SizedBox(width: 15),
              
              // User Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  // Role
                  Text(
                    'Logged in as: ${widget.userName} \n(${widget.userRole})',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          
          // Page Title
          Text(
            'Developer About Me',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 FIXED Profile Picture Widget with better error handling
  Widget _buildProfilePicture() {
    // Check if profileImageUrl is valid
    bool hasValidImageUrl = widget.profileImageUrl != null && 
                           widget.profileImageUrl!.isNotEmpty && 
                           widget.profileImageUrl!.startsWith('http');

    if (!hasValidImageUrl) {
      debugPrint('⚠️ Invalid profile image URL: ${widget.profileImageUrl}');
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasValidImageUrl 
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2764E7), Color(0xFF457AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2764E7).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: hasValidImageUrl
          ? ClipOval(
              child: Image.network(
                widget.profileImageUrl!,
                fit: BoxFit.cover,
                width: 70,
                height: 70,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    debugPrint('✅ Profile image loaded successfully');
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Error loading profile image: $error');
                  debugPrint('🔄 Stack trace: $stackTrace');
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2764E7), Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            )
          : const Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: widget.userName,
        userRole: widget.userRole,
        onNavTap: (page) => Navigator.pop(context),
        onLogout: () => Navigator.pop(context),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 🌟 FIXED HEADER with Profile Image Solution
                _buildDashboardHeader(context),
                
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),

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