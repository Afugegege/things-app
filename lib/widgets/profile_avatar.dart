import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/user/user_profile_screen.dart';

class ProfileAvatar extends StatelessWidget {
  final double radius; // <--- ADDED THIS to fix the error

  const ProfileAvatar({
    super.key, 
    this.radius = 20, // Default size is 20 (Total width 40)
  });

  @override
  Widget build(BuildContext context) {
    // Watch user provider to show correct initials
    final user = Provider.of<UserProvider>(context).user;

    return GestureDetector(
      onTap: () {
        // Navigate to Profile Screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
        );
      },
      child: Container(
        // Remove 'margin' so the parent widget controls spacing
        width: radius * 2,  // <--- USE RADIUS HERE
        height: radius * 2, // <--- USE RADIUS HERE
        decoration: BoxDecoration(
          color: Colors.amber, 
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10)
          ],
        ),
        child: Center(
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8, // <--- SCALES FONT WITH SIZE
            ),
          ),
        ),
      ),
    );
  }
}