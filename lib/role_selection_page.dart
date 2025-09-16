// lib/role_selection_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'auth_service.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, UserRole> roles = {
      'เจ้าของ (Owner)': UserRole.owner,
      'ผู้จัดการ (Manager)': UserRole.manager,
      'พนักงาน (Employee)': UserRole.employee,
      'ฝึกงาน (Intern)': UserRole.intern,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: roles.entries.map((entry) {
                  return _RoleButton(
                    title: entry.key,
                    onPressed: () {
                      Provider.of<AuthService>(
                        context,
                        listen: false,
                      ).login(entry.value);
                      // FIX: Use go_router to navigate
                      context.go('/floorplan');
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Image.asset(
                'assets/images/company_logo2.png',
                height: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _RoleButton({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Text(title, textAlign: TextAlign.center),
      ),
    );
  }
}
