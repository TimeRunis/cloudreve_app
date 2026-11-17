import 'package:flutter/material.dart';

import '../../models/user.dart';

/// 右上角用户头像：圆形底色 + 昵称首字母。
class UserAvatar extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const UserAvatar({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user?.nickname ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          initial,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
