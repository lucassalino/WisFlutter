import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/wis_logo.dart';
import '../data/auth_repository.dart';

/// Ecrã aberto via deep link depois de um convite ou de "recuperar password" —
/// nesse ponto já existe uma sessão de recuperação ativa, só falta definir
/// a password nova.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
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
          .updatePassword(_passwordController.text);
      ref.read(passwordRecoveryPendingProvider.notifier).clear();
      if (mounted) context.go('/org-selection');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Não foi possível definir a password. Tenta novamente.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: WisLogo(size: 72)),
            const SizedBox(height: 20),
            const Text(
              'Definir nova password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),
            PasswordField(
              controller: _passwordController,
              label: 'Nova password',
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
                  : const Text('Guardar e entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
