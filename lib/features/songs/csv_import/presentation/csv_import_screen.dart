import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/state/refresh_tick.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../data/csv_import_repository.dart';
import '../data/csv_reader.dart';
import '../domain/csv_import_schema.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

enum _ImportStep { upload, mapping, preview }

/// Wizard de 3 passos — Carregar, Mapear colunas, Pré-visualizar e importar
/// — espelha o importador de CSV do ServiceFlow (ver ESPECImportadorCSV.md).
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  _ImportStep _step = _ImportStep.upload;
  ParsedCsv? _parsed;
  ColumnMapping _mapping = emptyMapping();
  List<SongDraft> _drafts = [];
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final parsed = await pickAndParseCsv();
      if (parsed == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _parsed = parsed;
        _mapping = autoMap(parsed.headers);
        _step = _ImportStep.mapping;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível ler o ficheiro. Confirma que é um CSV válido.';
        _busy = false;
      });
    }
  }

  void _goToPreview() {
    final parsed = _parsed;
    if (parsed == null) return;
    final drafts = [
      for (final row in parsed.rows)
        if (rowToDraft(row, _mapping) != null) rowToDraft(row, _mapping)!,
    ];
    setState(() {
      _drafts = drafts;
      _step = _ImportStep.preview;
    });
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(csvImportRepositoryProvider)
          .importSongs(widget.orgId, _drafts);
      bumpRefreshTick(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.createdCount} música(s) criada(s), '
            '${result.matchedCount} já existiam no repertório.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _error = 'Não foi possível importar. Tenta novamente.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar CSV')),
      body: switch (_step) {
        _ImportStep.upload => _buildUploadStep(),
        _ImportStep.mapping => _buildMappingStep(),
        _ImportStep.preview => _buildPreviewStep(),
      },
    );
  }

  Widget _buildUploadStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Escolhe um ficheiro CSV com o teu repertório. A primeira linha '
          'deve ter os cabeçalhos das colunas (ex.: Nome, Artista, Tom, BPM). '
          'Só a coluna com o nome da música é obrigatória.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          style: _primaryButtonStyle,
          onPressed: _busy ? null : _pickFile,
          icon: _busy
              ? const SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.upload_file_outlined, size: 14),
          label: Text(_busy ? 'A ler…' : 'Escolher ficheiro CSV'),
        ),
      ],
    );
  }

  Widget _buildMappingStep() {
    final parsed = _parsed!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${parsed.rows.length} linha(s) encontrada(s). Associa cada '
                'coluna do teu ficheiro ao campo correspondente.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              for (final field in targetFields) ...[
                DropdownButtonFormField<String>(
                  initialValue: _mapping[field.key],
                  decoration: InputDecoration(
                    labelText: field.required
                        ? '${field.label} *'
                        : field.label,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— nenhuma —')),
                    for (final header in parsed.headers)
                      DropdownMenuItem(value: header, child: Text(header)),
                  ],
                  onChanged: (value) =>
                      setState(() => _mapping[field.key] = value),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        _buildFooter(
          onBack: () => setState(() => _step = _ImportStep.upload),
          onNext: isMappingValid(_mapping) ? _goToPreview : null,
          nextLabel: 'Pré-visualizar',
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFF87171)),
            ),
          ),
        Expanded(
          child: _drafts.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma linha com nome preenchido.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _drafts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (draft.artist != null)
                                  Text(
                                    draft.artist!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (draft.musicalKey != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                draft.musicalKey!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        _buildFooter(
          onBack: _busy
              ? null
              : () => setState(() => _step = _ImportStep.mapping),
          onNext: _busy || _drafts.isEmpty ? null : _import,
          nextLabel: _busy ? 'A importar…' : 'Importar ${_drafts.length} música(s)',
          busy: _busy,
        ),
      ],
    );
  }

  Widget _buildFooter({
    required VoidCallback? onBack,
    required VoidCallback? onNext,
    required String nextLabel,
    bool busy = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton(
            style: _ghostButtonStyle,
            onPressed: onBack,
            child: const Text('Voltar'),
          ),
          const Spacer(),
          ElevatedButton(
            style: _primaryButtonStyle,
            onPressed: onNext,
            child: busy
                ? const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(nextLabel),
          ),
        ],
      ),
    );
  }
}
