import 'package:flutter/material.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _pushNotifications = true;
  bool _darkMode = false;
  double _volume = 50;
  DateTime? _birthDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: (val) => setState(() => _darkMode = val),
          ),
          const SizedBox(height: 16),
          const Text('Alert Volume', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _volume,
            min: 0,
            max: 100,
            divisions: 10,
            label: _volume.round().toString(),
            onChanged: (val) => setState(() => _volume = val),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Birth Date'),
            subtitle: Text(_birthDate != null ? "${_birthDate!.toLocal()}".split(' ')[0] : 'Not set'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _birthDate = date);
              }
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Sign out logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved Settings successfully')),
              );
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
