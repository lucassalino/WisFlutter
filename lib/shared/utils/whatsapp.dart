/// Utilitários para gerar links wa.me (WhatsApp Click-to-Chat) — sem API,
/// a app gera a mensagem pronta e a pessoa toca para enviar. Espelha
/// src/lib/whatsapp.ts.
library;

import 'package:intl/intl.dart';

String sanitizePhone(String? phone) {
  if (phone == null) return '';
  return phone.replaceAll(RegExp(r'\D'), '');
}

String buildWhatsAppLink(String? phone, String message) {
  final number = sanitizePhone(phone);
  final text = Uri.encodeComponent(message);
  return number.isNotEmpty
      ? 'https://wa.me/$number?text=$text'
      : 'https://wa.me/?text=$text';
}

String formatDateLong(DateTime date) =>
    DateFormat("d 'de' MMMM 'de' y", 'pt').format(date);

/// Mensagem de aviso de escala para enviar por WhatsApp.
String scheduleMessage({
  required String name,
  required String orgName,
  required String ministry,
  required String eventName,
  required DateTime date,
  String? time,
  String? arrivalTime,
  String appUrl = 'https://wis-services.com',
}) {
  final nameParts = name.split(' ');
  final firstName = nameParts.isNotEmpty ? nameParts.first : name;
  final when = '${formatDateLong(date)}${time != null ? ' às $time' : ''}';
  final ministryLabel = ministry.isNotEmpty ? ministry : eventName;
  final arrival = arrivalTime != null
      ? '\n⏰ Chegada da equipa: *$arrivalTime*\n'
      : '';
  return 'Olá, *$firstName*! 🙌\n\n'
      'A *$orgName* escalou-te no *$ministryLabel* para o culto do dia *$when*.\n'
      '$arrival'
      '\nPara veres os detalhes da escala, cifras ou ficheiros, abre a app:\n$appUrl\n\n'
      'Confirma a tua presença na app:\n'
      '✅ Sim, confirmo\n'
      '❌ Não poderei ir';
}
