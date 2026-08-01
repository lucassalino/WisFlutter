import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

const _selectedGreen = Color(0xFF6EE7B7);

/// Criar ou editar um ministério — nome, cor e funções (catálogo +
/// personalizadas). O ícone deixou de ser escolhido pelo utilizador: a app
/// usa sempre a inicial do nome, a cores do ministério.
class MinistryFormScreen extends ConsumerStatefulWidget {
  const MinistryFormScreen({super.key, required this.orgId, this.ministry});

  final String orgId;
  final Ministry? ministry;

  @override
  ConsumerState<MinistryFormScreen> createState() => _MinistryFormScreenState();
}

class _MinistryFormScreenState extends ConsumerState<MinistryFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _customNameController;
  late String _icon;
  late String _color;
  late Set<String> _selectedFunctions;
  String _customEmoji = functionIconChoices.first;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.ministry != null;

  @override
  void initState() {
    super.initState();
    final ministry = widget.ministry;
    _nameController = TextEditingController(text: ministry?.name ?? '');
    _customNameController = TextEditingController();
    _icon = ministry?.icon ?? ministryIconChoices.first;
    _color = ministry?.color ?? ministryColorChoices.first;
    _selectedFunctions = {...?ministry?.functions};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  void _addCustomFunction() {
    final label = _customNameController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _selectedFunctions.add(encodeCustomFunction(_customEmoji, label));
      _customNameController.clear();
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Introduz um nome');
      return;
    }
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
    final catalogSelected = _selectedFunctions.where((f) => !isCustomFunction(f)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ministérios',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check, size: 14),
                      label: Text(_submitting ? 'A guardar...' : 'Guardar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      _isEditing ? 'Editar ministério' : 'Novo ministério',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _nameController,
                          builder: (context, value, _) {
                            final initial = value.text.trim().isNotEmpty
                                ? value.text.trim()[0].toUpperCase()
                                : '?';
                            return Container(
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: hexToColor(
                                  _color,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: hexToColor(_color),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Nome do ministério'),
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: 'Ex.: Louvor',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionEyebrow('COR'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final choice in ministryColorChoices)
                          InkWell(
                            onTap: () => setState(() => _color = choice),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hexToColor(choice),
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
                    const SizedBox(height: 24),
                    _SectionEyebrow('FUNÇÕES'),
                    const SizedBox(height: 6),
                    Text(
                      'Escolhe as funções deste ministério. Podes usar o '
                      'catálogo ou criar as tuas próprias.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final fn in memberFunctions)
                          _FunctionPill(
                            emoji: fn.emoji,
                            label: fn.label,
                            selected: _selectedFunctions.contains(fn.key),
                            onTap: () => setState(() {
                              if (_selectedFunctions.contains(fn.key)) {
                                _selectedFunctions.remove(fn.key);
                              } else {
                                _selectedFunctions.add(fn.key);
                              }
                            }),
                          ),
                        for (final key in customFunctions)
                          _FunctionPill(
                            emoji: functionEmoji(key),
                            label: functionLabel(key),
                            selected: true,
                            onTap: () {},
                            onDelete: () =>
                                setState(() => _selectedFunctions.remove(key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Criar função personalizada',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final choice in functionIconChoices)
                                InkWell(
                                  onTap: () =>
                                      setState(() => _customEmoji = choice),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _customEmoji == choice
                                            ? _selectedGreen
                                            : Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      choice,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customNameController,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Nome da função (ex: Data show)',
                                  ),
                                  onSubmitted: (_) => _addCustomFunction(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: _primaryButtonStyle,
                                onPressed: _addCustomFunction,
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Adicionar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${catalogSelected + customFunctions.length} '
                      'funç${catalogSelected + customFunctions.length == 1 ? 'ão' : 'ões'} selecionada'
                      '${catalogSelected + customFunctions.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFF87171)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class _FunctionPill extends StatelessWidget {
  const _FunctionPill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDelete == null ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _selectedGreen.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _selectedGreen.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? _selectedGreen
                    : Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 6),
            if (onDelete != null)
              InkWell(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: _selectedGreen.withValues(alpha: 0.8),
                ),
              )
            else if (selected)
              Icon(Icons.check, size: 14, color: _selectedGreen),
          ],
        ),
      ),
    );
  }
}
