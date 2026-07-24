import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/organizations_repository.dart';

class JoinOrgScreen extends ConsumerStatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  ConsumerState<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends ConsumerState<JoinOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final orgId = await ref
          .read(organizationsRepositoryProvider)
          .joinOrganizationByCode(_codeController.text.trim());

      ref.invalidate(myMembershipsProvider);
      final memberships = await ref.read(myMembershipsProvider.future);
      final membership = memberships.firstWhere(
        (m) => m.organization.id == orgId,
      );
      await ref.read(orgStoreProvider.notifier).setActive(membership);
      bumpRefreshTick(ref);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () =>
            _error = 'Não foi possível entrar na organização. Tenta novamente.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar numa organização')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Introduz o código de convite que recebeste da tua igreja.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Código de convite',
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Introduz o código'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
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
