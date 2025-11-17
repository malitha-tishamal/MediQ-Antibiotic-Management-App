import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Assuming AppColors is defined in main.dart or a similar utility file
import 'main.dart'; 

class AdminDeveloperAboutScreen extends StatelessWidget {
  const AdminDeveloperAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF8D78F9), size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Developer About Me', 
            style: TextStyle(
                color: AppColors.darkText,
                fontWeight: FontWeight.bold,
                fontSize: 20
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF8D78F9), size: 28),
            onPressed: () {
              // Handle notifications tap
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // If you are using a consistent drawer, you'd add it here:
      // drawer: const AdminDrawer(...),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Header Card Section ---
            _buildHeaderCard(context),
            
            const SizedBox(height: 30),
            
            // --- Main Content Header ---
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
            
            // --- Developer Image ---
            _buildDeveloperImage(),
            
            const SizedBox(height: 40),
            
            // --- Social Media Icons ---
            _buildSocialIconsRow(),

            const SizedBox(height: 30),
            
            // --- Name and Title ---
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
                color: Color(0xFF8D78F9), // Use the primary color
              ),
            ),
            
            const SizedBox(height: 80),
            
            // --- Footer ---
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
  
  // --- UI Component Builders ---

  Widget _buildHeaderCard(BuildContext context) {
    // This replicates the header from the profile screen
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6D6F7), Color(0xFFE9D7FD)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D78F9).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Placeholder for Profile Icon (matching the screenshot's header)
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 30, color: Color(0xFF8D78F9)),
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
                    color: AppColors.darkText
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Administrator', 
                  style: TextStyle(
                    fontSize: 13.5, 
                    color: AppColors.darkText.withOpacity(0.7)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperImage() {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF8D78F9).withOpacity(0.5),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            // Use a placeholder or the actual asset path here
            image: const DecorationImage(
              image: AssetImage('assets/developer_photo.png'), // REPLACE with your actual image path
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Placeholder for the small sparkle/dot decoration above the icons
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSparkleDecorator(),
            const SizedBox(width: 80),
            _buildSparkleDecorator(),
          ],
        )
      ],
    );
  }
  
  Widget _buildSparkleDecorator() {
    return Icon(
      Icons.star_half_rounded, // Using a similar icon for a sparkle effect
      size: 20,
      color: const Color(0xFF8D78F9).withOpacity(0.6),
    );
  }

  Widget _buildSocialIconsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSocialIcon(FontAwesomeIcons.instagram, Colors.purple.shade400, () {}),
        _buildSocialIcon(FontAwesomeIcons.facebookF, Colors.blue.shade700, () {}),
        _buildSocialIcon(FontAwesomeIcons.linkedinIn, Colors.blue.shade900, () {}),
        _buildSocialIcon(Icons.email_outlined, Colors.red.shade700, () {}),
        _buildSocialIcon(Icons.language, Colors.green.shade600, () {}),
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
        child: Icon(
          icon,
          size: 24,
          color: color,
        ),
      ),
    );
  }
}