import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';

/// Criar ou editar um ministério — nome, ícone, cor e funções (catálogo +
/// personalizadas), espelhando MinistryFormPanel.tsx.
class MinistryFormScreen extends ConsumerStatefulWidget {
  const MinistryFormScreen({super.key, required this.orgId, this.ministry});

  final String orgId;
  final Ministry? ministry;

  @override
  ConsumerState<MinistryFormScreen> createState() => _MinistryFormScreenState();
}

class _MinistryFormScreenState extends ConsumerState<MinistryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _icon;
  late String _color;
  late Set<String> _selectedFunctions;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.ministry != null;

  @override
  void initState() {
    super.initState();
    final ministry = widget.ministry;
    _nameController = TextEditingController(text: ministry?.name ?? '');
    _icon = ministry?.icon ?? ministryIconChoices.first;
    _color = ministry?.color ?? ministryColorChoices.first;
    _selectedFunctions = {...?ministry?.functions};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addCustomFunction() async {
    final labelController = TextEditingController();
    var emoji = functionIconChoices.first;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova função personalizada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Nome da função'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                width: 280,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemCount: functionIconChoices.length,
                  itemBuilder: (context, index) {
                    final choice = functionIconChoices[index];
                    return InkWell(
                      onTap: () => setDialogState(() => emoji = choice),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: emoji == choice
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          choice,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) return;
                Navigator.of(
                  context,
                ).pop(encodeCustomFunction(emoji, labelController.text));
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedFunctions.add(result));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final payload = MinistryPayload(
      name: _nameController.text.trim(),
      icon: _icon,
      color: _color,
      functions: _selectedFunctions.toList(),
    );
    try {
      final repo = ref.read(ministriesRepositoryProvider);
      if (_isEditing) {
        await repo.updateMinistry(widget.ministry!.id, payload);
      } else {
        await repo.createMinistry(widget.orgId, payload);
      }
      bumpRefreshTick(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'Não foi possível guardar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customFunctions = _selectedFunctions.where(isCustomFunction).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar ministério' : 'Novo ministério'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Introduz um nome'
                  : null,
            ),
            const SizedBox(height: 20),
            Text('Ícone', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in ministryIconChoices)
                  ChoiceChip(
                    label: Text(choice, style: const TextStyle(fontSize: 18)),
                    selected: _icon == choice,
                    onSelected: (_) => setState(() => _icon = choice),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Cor', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in ministryColorChoices)
                  InkWell(
                    onTap: () => setState(() => _color = choice),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse('FF${choice.substring(1)}', radix: 16),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == choice
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Funções', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final fn in memberFunctions)
                  FilterChip(
                    label: Text('${fn.emoji} ${fn.label}'),
                    selected: _selectedFunctions.contains(fn.key),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedFunctions.add(fn.key);
                      } else {
                        _selectedFunctions.remove(fn.key);
                      }
                    }),
                  ),
                for (final key in customFunctions)
                  InputChip(
                    label: Text('${functionEmoji(key)} ${functionLabel(key)}'),
                    onDeleted: () =>
                        setState(() => _selectedFunctions.remove(key)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Personalizada'),
                  onPressed: _addCustomFunction,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
