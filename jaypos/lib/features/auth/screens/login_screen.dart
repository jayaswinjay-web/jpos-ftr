import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const LoginScreen({super.key, this.initialEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) _emailC.text = widget.initialEmail!;
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    ref.read(authControllerProvider.notifier).clearError();

    final error = await ref.read(authControllerProvider.notifier).login(
      _emailC.text.trim(),
      _passwordC.text,
    );

    setState(() => _loading = false);
    if (error == null && mounted) {
      context.go('/dashboard');
    } else if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: AppSpacing.sm),
                  Text('JayPOS', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontSize: 32)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Sign in to your store', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xxl),
                  TextFormField(
                    controller: _emailC,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordC,
                    decoration: InputDecoration(
                      labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(auth.error!, style: const TextStyle(color: AppColors.danger))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () async {
                      final err = await ref.read(authControllerProvider.notifier).resetPassword(_emailC.text.trim());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Reset email sent')));
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
