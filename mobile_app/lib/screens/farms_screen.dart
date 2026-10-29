import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';



class FarmsScreen extends StatefulWidget {
  final bool openAddDialogOnLoad;

  const FarmsScreen({
    super.key,
    this.openAddDialogOnLoad = false,
  });

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  final FarmStore store = FarmStore.instance;

  @override
  void initState() {
    super.initState();

    if (widget.openAddDialogOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addFarm();
        }
      });
    }
  }

  Future<void> _openDialog({Farm? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FarmDialog(
        store: store,
        existing: existing,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Farm registered successfully!' : 'Farm updated successfully!',
          ),
        ),
      );
    }
  }

  Future<void> _addFarm() => _openDialog();

 
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7FAF7),
    appBar: AppBar(
      title: const Text(
        'My Farms',
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF124B30),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addFarm,
      backgroundColor: const Color(0xFF124B30),
      foregroundColor: Colors.white,
      elevation: 5,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Farm',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        // FULLSCREEN FARM BACKGROUND
        Image.asset(
          'assets/images/farm_illustration.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE5F3E8),
                    Color(0xFF9CCB9E),
                    Color(0xFF4D895A),
                  ],
                ),
              ),
            );
          },
        ),

        // SOFT OVERLAY
        Container(
          color: Colors.black.withValues(alpha: 0.25),
        ),

        // EXISTING FARM DATA
        ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            if (store.loading && store.farms.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }

            if (store.error != null && store.farms.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 45,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          store.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF203328),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: store.load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (store.farms.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: 380,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.agriculture_rounded,
                          size: 65,
                          color: Color(0xFF267447),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome to Your Farm',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF124B30),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Register your farm to monitor climate '
                          'conditions and manage your crop productivity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF64756A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _addFarm,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Register Your Farm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF124B30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                const Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: 18,
                  ),
                  child: Text(
                    'Your Agricultural Spaces',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                for (final farm in store.farms)
                  Card(
                    color: Colors.white.withValues(alpha: 0.95),
                    elevation: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F3E8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          farm.id == store.selected?.id
                              ? Icons.check_circle_rounded
                              : Icons.agriculture_rounded,
                          color: const Color(0xFF267447),
                          size: 28,
                        ),
                      ),
                      title: Text(
                        farm.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF124B30),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          '${farm.location}\n'
                          '${farm.areaHectares != null ? '${num1(farm.areaHectares, 2)} ha' : 'Area not set'}'
                          ' • ${farm.code}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Color(0xFF64756A),
                          ),
                        ),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Edit farm',
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF267447),
                        ),
                        onPressed: () => _openDialog(existing: farm),
                      ),
                      onTap: () {
                        store.select(farm);
                        Navigator.pop(context);
                      },
                    ),
                  ),
              ],
            );
          },
      ),
   ],
    ),
  );
  }
} 


class _FarmDialog extends StatefulWidget {
  final FarmStore store;
  final Farm? existing;

  const _FarmDialog({
    required this.store,
    this.existing,
  });

  @override
  State<_FarmDialog> createState() => _FarmDialogState();
}

class _FarmDialogState extends State<_FarmDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );

  late final TextEditingController _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );

  late final TextEditingController _area = TextEditingController(
    text: widget.existing?.areaHectares?.toString() ?? '',
  );

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _name.text.trim();
      final location = _location.text.trim();
      final area = double.tryParse(_area.text.trim());

      final existing = widget.existing;

      if (existing == null) {
        await widget.store.add(
          name: name,
          location: location,
          areaHectares: area,
        );
      } else {
        await widget.store.update(
          existing.id,
          name: name,
          location: location,
          areaHectares: area,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Unable to save farm. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Register farm' : 'Edit farm',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Farm name',
                    hintText: 'Enter farm name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Farm name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Location (barangay, municipality)',
                    hintText: 'Enter farm location',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _area,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Area (hectares)',
                    helperText: 'Needed for yield forecasts',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Farm area is required';
                    }

                    final number = double.tryParse(text);

                    if (number == null || !number.isFinite || number <= 0) {
                      return 'Enter a valid area above 0';
                    }

                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: statusBad),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(90, 44),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}