import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../providers/t_smart_state.dart';

class AthleteFormScreen extends StatefulWidget {
  const AthleteFormScreen({super.key, this.athleteId});

  final String? athleteId;

  @override
  State<AthleteFormScreen> createState() => _AthleteFormScreenState();
}

class _AthleteFormScreenState extends State<AthleteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _className;
  String _gender = 'Laki-laki';

  @override
  void initState() {
    super.initState();
    final state = context.read<TSmartState>();
    final existing =
        widget.athleteId != null ? state.getAthleteById(widget.athleteId!) : null;
    _name = TextEditingController(text: existing?.name ?? '');
    _age = TextEditingController(text: existing != null ? '${existing.age}' : '');
    _className = TextEditingController(text: existing?.className ?? '');
    _gender = existing?.gender ?? 'Laki-laki';
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _className.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<TSmartState>();
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final className = _className.text.trim();
    if (widget.athleteId != null) {
      final cur = state.getAthleteById(widget.athleteId!);
      if (cur != null) {
        state.updateAthlete(
          cur.copyWith(
            name: _name.text.trim(),
            age: age,
            gender: _gender,
            className: className.isEmpty ? null : className,
            clearClassName: className.isEmpty,
          ),
        );
      }
    } else {
      final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
      state.addAthlete(
        Athlete(
          id: id,
          name: _name.text.trim(),
          age: age,
          gender: _gender,
          className: className.isEmpty ? null : className,
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.athleteId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit atlet' : 'Tambah atlet')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Umur',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (int.tryParse(v.trim()) == null) return 'Angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Jenis kelamin',
                  prefixIcon: Icon(Icons.wc),
                ),
                items: const [
                  DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                  DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? _gender),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _className,
                decoration: const InputDecoration(
                  labelText: 'Kelas (opsional)',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _save,
                child: Text(isEdit ? 'Simpan' : 'Tambah'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
