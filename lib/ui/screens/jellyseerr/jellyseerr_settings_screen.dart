import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../../auth/repositories/session_repository.dart';
import '../../widgets/navigation_layout.dart';

/// Jellyseerr integration settings.
class JellyseerrSettingsScreen extends StatefulWidget {
  const JellyseerrSettingsScreen({super.key});

  @override
  State<JellyseerrSettingsScreen> createState() =>
      _JellyseerrSettingsScreenState();
}

class _JellyseerrSettingsScreenState extends State<JellyseerrSettingsScreen> {
  late final PreferenceStore _store;
  late final String _userId;

  // Per-user preference keys
  String get _showInToolbarKey => 'jellyseerr_show_in_toolbar_$_userId';
  String get _connectionUrlKey => 'jellyseerr_connection_url';
  String get _nsfwFilterKey => 'jellyseerr_nsfw_filter';

  bool _showInToolbar = false;
  String _connectionUrl = '';
  bool _nsfwFilter = true;

  @override
  void initState() {
    super.initState();
    _store = GetIt.instance<PreferenceStore>();
    final session = GetIt.instance<SessionRepository>();
    _userId = session.activeUserId ?? '';

    _showInToolbar = _store.getBool(_showInToolbarKey) ?? false;
    _connectionUrl = _store.getString(_connectionUrlKey) ?? '';
    _nsfwFilter = _store.getBool(_nsfwFilterKey) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 80),
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Connection URL'),
                subtitle: Text(_connectionUrl.isEmpty ? 'Not configured' : _connectionUrl),
                onTap: _editConnectionUrl,
              ),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('Authentication'),
                subtitle: Text('None'),
              ),
              SwitchListTile(
                title: const Text('Show in Toolbar'),
                subtitle: const Text('Display Jellyseerr button in the toolbar'),
                secondary: const Icon(Icons.visibility),
                value: _showInToolbar,
                onChanged: (value) async {
                  await _store.setBool(_showInToolbarKey, value);
                  setState(() => _showInToolbar = value);
                },
              ),
              SwitchListTile(
                title: const Text('NSFW Filter'),
                subtitle: const Text('Hide adult content'),
                secondary: const Icon(Icons.shield),
                value: _nsfwFilter,
                onChanged: (value) async {
                  await _store.setBool(_nsfwFilterKey, value);
                  setState(() => _nsfwFilter = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editConnectionUrl() async {
    final controller = TextEditingController(text: _connectionUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jellyseerr URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://jellyseerr.example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await _store.setString(_connectionUrlKey, result);
      setState(() => _connectionUrl = result);
    }
  }
}
