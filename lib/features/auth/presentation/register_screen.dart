import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/wis_logo.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _confirmEmailSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      setState(() => _confirmEmailSent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível registar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmEmailSent) {
      return AuthScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WisLogo(size: 72),
            const SizedBox(height: 24),
            const Text(
              'Confirma o teu email',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Enviámos um link de confirmação para ${_emailController.text.trim()}. '
              'Abre-o para ativares a tua conta e depois entra normalmente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ir para o login'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: WisLogo(size: 72)),
            const SizedBox(height: 20),
            const Text(
              'Criar conta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Preenche os teus dados para começar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                hintText: 'João Silva',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Introduz o teu nome'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'email@exemplo.com',
              ),
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Introduz um email válido'
                  : null,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.length < 6)
                  ? 'Mínimo de 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirmController,
              label: 'Confirmar password',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => (value != _passwordController.text)
                  ? 'As passwords não coincidem'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Criar conta'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Já tens conta? ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
                InkWell(
                  onTap: () => context.push('/login'),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
