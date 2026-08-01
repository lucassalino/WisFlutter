import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';

import '../domain/csv_import_schema.dart';

class ParsedCsv {
  const ParsedCsv({required this.headers, required this.rows});

  final List<String> headers;
  final List<RawRow> rows;
}

/// Deixa o utilizador escolher um `.csv` e devolve os cabeçalhos + linhas
/// já convertidos em mapas — equivalente a `pickAndParseCsv` do ServiceFlow,
/// trocando `expo-document-picker`/`expo-file-system` por `file_selector`
/// (mais leve que `file_picker`, que só existe para escolher documentos —
/// sem depender de bibliotecas de seleção de fotos/media).
Future<ParsedCsv?> pickAndParseCsv() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
        mimeTypes: ['text/csv'],
        // No iOS, extensions/mimeTypes são ignorados — sem UTIs explícitos
        // o picker nem chega a abrir, lança ArgumentError de imediato.
        uniformTypeIdentifiers: [
          'public.comma-separated-values-text',
          'public.plain-text',
        ],
      ),
    ],
  );
  if (file == null) return null;

  var text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xfeff) {
    text = text.substring(1);
  }
  if (text.trim().isEmpty) return null;

  final table = Csv(dynamicTyping: false).decode(text);
  if (table.isEmpty) return null;

  final headers = table.first
      .map((h) => h.toString().trim())
      .where((h) => h.isNotEmpty)
      .toList();
  if (headers.isEmpty) return null;

  final rows = <RawRow>[];
  for (final rawRow in table.skip(1)) {
    final row = <String, String>{};
    for (var i = 0; i < headers.length && i < rawRow.length; i++) {
      row[headers[i]] = rawRow[i].toString();
    }
    if (row.values.any((v) => v.trim().isNotEmpty)) rows.add(row);
  }

  return ParsedCsv(headers: headers, rows: rows);
}
