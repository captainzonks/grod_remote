import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/discovery.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pipedCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _quality;
  bool _qualitySaving = false;
  String? _qualityError;
  bool _discovering = false;
  bool _pipedSaving = false;
  String? _pipedError;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _hostCtrl.text = state.host;
    _portCtrl.text = state.port.toString();
    _pinCtrl.text = state.pin;
    // Quality reads from the locally-persisted preference (not
    // `status.quality`, which reports the in-flight track's resolved
    // label and would silently degrade the dropdown to 360p after a
    // low-quality cast).
    _quality = state.defaultQuality;
    // Prefer the daemon's reported URL when known; fall back to whatever
    // the user last typed on this client.
    _pipedCtrl.text = state.status?.pipedUrl ?? state.lastPipedUrl;
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _pinCtrl.dispose();
    _pipedCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AppState>().saveServer(
          _hostCtrl.text.trim(),
          int.parse(_portCtrl.text.trim()),
          _pinCtrl.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server saved')),
    );
    Navigator.pop(context);
  }

  Future<void> _setQuality(String q) async {
    setState(() {
      _qualitySaving = true;
      _qualityError = null;
    });
    try {
      final state = context.read<AppState>();
      // Persist locally and push to daemon in one step. Local persistence
      // is what survives reconnects; the daemon push keeps the next /cast
      // honoring the new preference immediately.
      await state.setDefaultQuality(q);
      if (!mounted) return;
      setState(() => _quality = q);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quality set to $q'), duration: const Duration(seconds: 2)),
      );
      state.refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _qualityError = e.toString());
    } finally {
      if (mounted) setState(() => _qualitySaving = false);
    }
  }

  Future<void> _setPipedUrl(String url) async {
    setState(() {
      _pipedSaving = true;
      _pipedError = null;
    });
    try {
      await context.read<AppState>().setPipedUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Piped URL set to $url'), duration: const Duration(seconds: 2)),
      );
      context.read<AppState>().refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _pipedError = e.toString());
    } finally {
      if (mounted) setState(() => _pipedSaving = false);
    }
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    try {
      final servers = await discoverServers();
      if (!mounted) return;

      if (servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No grod daemons found on the LAN')),
        );
        return;
      }

      // If exactly one, auto-fill. Otherwise present a chooser.
      final chosen = servers.length == 1
          ? servers.first
          : await showDialog<DiscoveredServer>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Found grod daemons'),
                children: servers
                    .map((s) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '${s.host}:${s.port}'
                                '${s.version.isNotEmpty ? '  •  v${s.version}' : ''}'
                                '${s.pinRequired ? '  •  PIN required' : ''}',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            );

      if (chosen == null || !mounted) return;
      setState(() {
        _hostCtrl.text = chosen.host;
        _portCtrl.text = chosen.port.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filled ${chosen.host}:${chosen.port} — tap Save server')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Wrap in SingleChildScrollView so:
      //  - The full form fits short screens (the column is now long enough
      //    to overflow on phones once the Piped + Quality sections were added)
      //  - The soft keyboard reduces the Scaffold's body via
      //    `resizeToAvoidBottomInset`; the ScrollView then has scrollable
      //    space and Flutter auto-scrolls the focused field into view.
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          // Reserve space for the on-screen keyboard so the field that opens
          // it stays visible above the IME instead of being clipped behind.
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _discovering ? null : _discover,
                icon: _discovering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_discovering ? 'Searching...' : 'Find server on LAN'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                autocorrect: false,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '7878',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 65535) ? 'Invalid port' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN (optional)',
                  hintText: 'Leave empty if no PIN set',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save server')),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Piped instance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Daemon will use this Piped API for search and stream resolution. '
                'Pick a preset or type a custom URL.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              // Preset menu — custom (user-saved) URLs render at the top
              // with a delete affordance, then a divider, then the bundled
              // presets.
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pipedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Piped API URL',
                        hintText: 'https://pipedapi.example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<AppState>(
                    builder: (context, state, _) => PopupMenuButton<String>(
                      icon: const Icon(Icons.expand_more),
                      tooltip: 'Pick a Piped instance',
                      onSelected: (v) {
                        setState(() => _pipedCtrl.text = v);
                      },
                      itemBuilder: (menuCtx) => [
                        for (final url in state.customPipedUrls)
                          PopupMenuItem<String>(
                            value: url,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    url,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Inline delete. Pop the menu via the menu
                                // route's context so the surrounding
                                // PopupMenuItem onSelected doesn't fire and
                                // pre-fill the field with a URL the user
                                // just removed.
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remove from list',
                                  onPressed: () {
                                    Navigator.of(menuCtx).pop();
                                    state.removeCustomPipedUrl(url);
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (state.customPipedUrls.isNotEmpty)
                          const PopupMenuDivider(),
                        for (final url in kPipedPresets)
                          PopupMenuItem<String>(
                            value: url,
                            child: Text(url),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _pipedSaving
                    ? null
                    : () {
                        final url = _pipedCtrl.text.trim();
                        if (url.isEmpty) return;
                        _setPipedUrl(url);
                      },
                child: Text(_pipedSaving ? 'Saving…' : 'Save Piped URL'),
              ),
              if (_pipedError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _pipedError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Cast quality',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Affects new casts. Saved on server.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _quality,
                decoration: const InputDecoration(
                  labelText: 'Quality',
                  border: OutlineInputBorder(),
                ),
                items: kQualityOptions
                    .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                    .toList(),
                onChanged: _qualitySaving
                    ? null
                    : (v) {
                        if (v != null) _setQuality(v);
                      },
              ),
              if (_qualitySaving)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (_qualityError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _qualityError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
