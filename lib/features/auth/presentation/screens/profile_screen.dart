import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/bloc/auth_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('প্রোফাইল', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            final user = state.user;
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                      child: user.photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.sync),
                      title: Text('অটো ব্যাকআপ'),
                      subtitle: Text('সর্বদা গুগল ড্রাইভে সিঙ্ক থাকে'),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('লগ আউট'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
