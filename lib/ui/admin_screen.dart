import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/config_manager.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset to Defaults',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset All Settings?'),
                    content: const Text('This will clear all customizations and requires an app restart.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings cleared. Please restart the app.')));
                  }
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Heroes'),
              Tab(text: 'Minions'),
              Tab(text: 'Towers'),
              Tab(text: 'Arena'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminHeroesTab(),
            AdminMinionsTab(),
            AdminTowersTab(),
            AdminArenaTab(),
          ],
        ),
      ),
    );
  }
}

class AdminHeroesTab extends StatefulWidget {
  const AdminHeroesTab({super.key});
  @override
  State<AdminHeroesTab> createState() => _AdminHeroesTabState();
}

class _AdminHeroesTabState extends State<AdminHeroesTab> {
  @override
  Widget build(BuildContext context) {
    final heroes = HeroDefinitions.heroes.keys.toList();
    return ListView.builder(
      itemCount: heroes.length,
      itemBuilder: (context, index) {
        final key = heroes[index];
        final hero = HeroDefinitions.heroes[key]!;
        return ListTile(
          title: Text(hero['name'] as String),
          subtitle: Text('Role: ${hero['role'].toString().split('.').last} | HP: ${hero['hp']}'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editHero(key, hero),
        );
      },
    );
  }

  void _editHero(String key, Map<String, dynamic> hero) {
    // A simplistic edit dialog for demonstration. In a full app, this would be a large form.
    final hpCtrl = TextEditingController(text: hero['hp'].toString());
    final damageCtrl = TextEditingController(text: hero['baseDamage'].toString());
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Edit ${hero['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: hpCtrl, decoration: const InputDecoration(labelText: 'HP')),
            TextField(controller: damageCtrl, decoration: const InputDecoration(labelText: 'Base Damage')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                hero['hp'] = double.tryParse(hpCtrl.text) ?? hero['hp'];
                hero['baseDamage'] = double.tryParse(damageCtrl.text) ?? hero['baseDamage'];
                ConfigManager.saveConfig();
              });
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class AdminMinionsTab extends StatefulWidget {
  const AdminMinionsTab({super.key});
  @override
  State<AdminMinionsTab> createState() => _AdminMinionsTabState();
}

class _AdminMinionsTabState extends State<AdminMinionsTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Melee Minion'),
        _buildNumberField('HP', GameConstants.meleeMinionHp, (v) => GameConstants.meleeMinionHp = v),
        _buildNumberField('Damage', GameConstants.meleeMinionDamage, (v) => GameConstants.meleeMinionDamage = v),
        _buildSectionTitle('Ranged Minion'),
        _buildNumberField('HP', GameConstants.rangedMinionHp, (v) => GameConstants.rangedMinionHp = v),
        _buildNumberField('Damage', GameConstants.rangedMinionDamage, (v) => GameConstants.rangedMinionDamage = v),
        _buildSectionTitle('Siege Minion'),
        _buildNumberField('HP', GameConstants.siegeMinionHp, (v) => GameConstants.siegeMinionHp = v),
        _buildNumberField('Damage', GameConstants.siegeMinionDamage, (v) => GameConstants.siegeMinionDamage = v),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNumberField(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null) {
            onChanged(parsed);
            ConfigManager.saveConfig();
          }
        },
      ),
    );
  }
}

class AdminTowersTab extends StatefulWidget {
  const AdminTowersTab({super.key});
  @override
  State<AdminTowersTab> createState() => _AdminTowersTabState();
}

class _AdminTowersTabState extends State<AdminTowersTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Turret Damage'),
        _buildNumberField('Damage', GameConstants.turretDamage, (v) => GameConstants.turretDamage = v),
        _buildSectionTitle('Outer Turret'),
        _buildNumberField('HP', GameConstants.turretOuterHp, (v) => GameConstants.turretOuterHp = v),
        _buildNumberField('Range', GameConstants.turretOuterRange, (v) => GameConstants.turretOuterRange = v),
        _buildSectionTitle('Inner Turret'),
        _buildNumberField('HP', GameConstants.turretInnerHp, (v) => GameConstants.turretInnerHp = v),
        _buildNumberField('Range', GameConstants.turretInnerRange, (v) => GameConstants.turretInnerRange = v),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNumberField(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null) {
            onChanged(parsed);
            ConfigManager.saveConfig();
          }
        },
      ),
    );
  }
}

class AdminArenaTab extends StatefulWidget {
  const AdminArenaTab({super.key});
  @override
  State<AdminArenaTab> createState() => _AdminArenaTabState();
}

class _AdminArenaTabState extends State<AdminArenaTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('World Size'),
        _buildNumberField('World Width', GameConstants.worldWidth, (v) => GameConstants.worldWidth = v),
        _buildNumberField('World Height', GameConstants.worldHeight, (v) => GameConstants.worldHeight = v),
        _buildSectionTitle('Spawns'),
        _buildNumberField('Minion Spawn Interval', GameConstants.minionSpawnInterval, (v) => GameConstants.minionSpawnInterval = v),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNumberField(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null) {
            onChanged(parsed);
            ConfigManager.saveConfig();
          }
        },
      ),
    );
  }
}
