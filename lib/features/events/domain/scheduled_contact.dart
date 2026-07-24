/// Uma pessoa escalada num evento, com contacto — usada para gerar
/// mensagens de WhatsApp ao publicar a escala.
class ScheduledContact {
  const ScheduledContact({
    required this.userId,
    required this.name,
    this.phone,
    required this.confirmed,
    required this.ministries,
  });

  final String userId;
  final String name;
  final String? phone;
  final bool? confirmed;
  final List<String> ministries;
}
