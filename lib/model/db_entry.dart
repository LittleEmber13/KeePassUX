import 'dart:typed_data';

class DbEntry {
  final String uuid;
  final String label;
  final String userName;
  final String password;
  final String url;
  final String notes;
  final int icon;
  final Uint8List? customIconData;

  final List<String> additionalUrls;

  DbEntry({
    required this.uuid,
    required this.label,
    required this.userName,
    required this.password,
    required this.url,
    required this.notes,
    required this.icon,
    this.customIconData,
    this.additionalUrls = const [],
  });
}