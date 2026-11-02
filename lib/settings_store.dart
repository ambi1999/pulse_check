import 'package:shared_preferences/shared_preferences.dart';

/// Saves settings on the phone (no database or cloud needed).
class SettingsStore {
  static const _emailsKey = 'recipient_emails';

  Future<List<String>> loadEmails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_emailsKey) ?? const [];
  }

  Future<void> saveEmails(List<String> emails) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_emailsKey, emails);
  }
}
