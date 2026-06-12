import 'package:flutter/material.dart';

class AddShopSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> shopData) onSubmit;

  const AddShopSheet({super.key, required this.onSubmit});

  @override
  State<AddShopSheet> createState() => _AddShopSheetState();
}

class _AddShopSheetState extends State<AddShopSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stationController = TextEditingController();
  final _hoursController = TextEditingController();
  final _holidayController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _allGenres = [
    'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース',
    'ブランド古着', 'ミリタリー', 'ワーク', 'スポーツ', 'Y2K', 'アウトドア',
    'US古着', 'スニーカー', 'その他',
  ];
  final Set<String> _selectedGenres = {};

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _stationController.dispose();
    _hoursController.dispose();
    _holidayController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'nearestStation': _stationController.text.trim(),
      'genres': _selectedGenres.toList(),
      'hours': _hoursController.text.trim(),
      'holiday': _holidayController.text.trim(),
      'description': _descriptionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_location_alt, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    '新しい古着屋を追加',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '店名 *',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '店名を入力してください' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '住所 *',
                  prefixIcon: Icon(Icons.location_on),
                  helperText: '次のステップで地図上のピン位置を正確に調整できます',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '住所を入力してください' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stationController,
                decoration: const InputDecoration(
                  labelText: '最寄り駅',
                  prefixIcon: Icon(Icons.train),
                  hintText: '例: 下北沢駅　複数は「、」で区切る',
                ),
              ),
              const SizedBox(height: 16),
              const Text('ジャンル', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allGenres.map((genre) {
                  final selected = _selectedGenres.contains(genre);
                  return FilterChip(
                    label: Text(genre),
                    selected: selected,
                    selectedColor: Colors.brown,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedGenres.add(genre);
                        } else {
                          _selectedGenres.remove(genre);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hoursController,
                decoration: const InputDecoration(
                  labelText: '営業時間',
                  prefixIcon: Icon(Icons.access_time),
                  hintText: '例: 12:00 - 20:00',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _holidayController,
                decoration: const InputDecoration(
                  labelText: '定休日',
                  prefixIcon: Icon(Icons.event_busy),
                  hintText: '例: 月曜日',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '説明・コメント',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.location_pin),
                  label: const Text('次へ：地図でピン位置を確認'),
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
