import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/avatars.dart';
import '../config/constants.dart';
import '../models/user.dart';

/// Round picture of a user : their photo, else their plant avatar, else the first letter of their name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 40});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    final avatar = user.avatar;

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                // skips the ngrok warning page when the API is exposed with ngrok
                headers: const {'ngrok-skip-browser-warning': 'true'},
                errorBuilder: (_, _, _) => _initial(),
                loadingBuilder: (_, child, progress) => progress == null ? child : _initial(),
              )
            : avatar != null && Avatars.codes.contains(avatar)
            ? SvgPicture.asset(Avatars.asset(avatar), fit: BoxFit.cover)
            : _initial(),
      ),
    );
  }

  Widget _initial() {
    final name = user.displayName;
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0],
          style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
      ),
    );
  }
}
