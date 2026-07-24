import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/organizations_repository.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final org = await ref
          .read(organizationsRepositoryProvider)
          .createOrganization(_nameController.text.trim());

      ref.invalidate(myMembershipsProvider);
      final memberships = await ref.read(myMembershipsProvider.future);
      final membership = memberships.firstWhere(
        (m) => m.organization.id == org.id,
      );
      await ref.read(orgStoreProvider.notifier).setActive(membership);
      bumpRefreshTick(ref);
    } catch (_) {
      setState(
        () => _error = 'Não foi possível criar a organização. Tenta novamente.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar organização')),
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
                  const Text('Como se chama a tua igreja/organização?'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nome da organização',
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Introduz um nome'
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
                        : const Text('Criar e entrar'),
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
