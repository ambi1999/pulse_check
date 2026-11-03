import 'package:flutter/material.dart';

import 'session_export.dart';
import 'settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SettingsStore();
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final emails = await _store.loadEmails();
    if (!mounted) {
      return;
    }
    setState(() => _controller.text = emails.join(', '));
  }

  Future<void> _save() async {
    final input = _controller.text;
    if (input.trim().isNotEmpty && !isValidEmailList(input)) {
      setState(() => _errorText = 'Check the addresses, e.g. a@example.com, b@example.com');
      return;
    }
    await _store.saveEmails(parseEmails(input));
    if (!mounted) {
      return;
    }
    setState(() => _errorText = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Send results to',
                  hintText: 'a@example.com, b@example.com',
                  helperText: 'Separate addresses with commas',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(height: 24),
              Text(
                "Email isn't a private channel for health data. "
                'Only send results to people you trust.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
