import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/tokens.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailC = TextEditingController();
  bool _sent = false;

  @override
  void dispose() { _emailC.dispose(); super.dispose(); }

  void _send() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email'), backgroundColor: AppColors.danger));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset email'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24),
        Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(_sent ? 'Check your email for the password reset link.' : 'Enter your email to receive a password reset link.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        if (!_sent) ...[
          TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          SizedBox(height: 48, child: ElevatedButton(onPressed: _send, child: const Text('Send Reset Link'))),
        ],
      ])),
    );
  }
}
