import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/sprintify_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'pelatih@demo.sprintify');
  final _password = TextEditingController(text: 'demo');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.go('/dashboard');
  }

  void _googleDemo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo: Google Sign-In tidak tersedia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const SprintifyLogo(size: 72),
              const SizedBox(height: 32),
              Text(
                'Masuk',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Guru / pelatih / admin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Masuk'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _googleDemo,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Lanjut dengan Google'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Belum punya akun? Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
