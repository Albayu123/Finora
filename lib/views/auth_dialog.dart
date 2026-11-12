import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/transaction_viewmodel.dart';

/// Dialog autentikasi sederhana (Masuk / Daftar) untuk sinkronisasi Firestore.
class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = _isRegisterMode
        ? await authVm.register(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await authVm.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (success && mounted) {
      context.read<TransactionViewModel>().clearSyncMessage();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final authVm = context.watch<AuthViewModel>();
    final currentUser = authVm.currentUser;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.divider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: currentUser != null
              ? _SignedInView(
                  email: currentUser.email,
                  isBusy: authVm.isBusy,
                  onSignOut: () async {
                    await authVm.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pop(false);
                    }
                  },
                  onClose: () => Navigator.of(context).pop(false),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isRegisterMode
                                  ? 'Daftar Akun Finora'
                                  : 'Masuk ke Akun Finora',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup dialog',
                            onPressed: authVm.isBusy
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Akun digunakan untuk mencadangkan catatan Anda',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Example@gmail.com',
                        ),
                        validator: (value) {
                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty || !trimmed.contains('@')) {
                            return 'Masukkan alamat email yang valid.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(authVm),
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi',
                          hintText: 'Minimal 6 karakter',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Tampilkan kata sandi'
                                : 'Sembunyikan kata sandi',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').length < 6) {
                            return 'Kata sandi minimal 6 karakter.';
                          }
                          return null;
                        },
                      ),
                      if (authVm.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.expenseSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.expense),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: colors.expense,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authVm.errorMessage!,
                                  style: TextStyle(color: colors.expense),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: authVm.isBusy ? null : () => _submit(authVm),
                        child: Text(
                          authVm.isBusy
                              ? 'Memproses...'
                              : (_isRegisterMode
                                    ? 'Buat Akun'
                                    : 'Masuk Sekarang'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: authVm.isBusy
                            ? null
                            : () {
                                authVm.clearError();
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                });
                              },
                        child: Text(
                          _isRegisterMode
                              ? 'Sudah punya akun? Masuk di sini'
                              : 'Belum punya akun? Daftar baru',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({
    required this.email,
    required this.isBusy,
    required this.onSignOut,
    required this.onClose,
  });

  final String email;
  final bool isBusy;
  final VoidCallback onSignOut;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Akun Terhubung',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tutup dialog',
              onPressed: isBusy ? null : onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masuk sebagai',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: isBusy ? null : onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(isBusy ? 'Keluar...' : 'Keluar dari Akun'),
        ),
      ],
    );
  }
}
