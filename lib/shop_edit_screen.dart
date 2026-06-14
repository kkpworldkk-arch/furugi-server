import 'package:flutter/material.dart';
import 'furugiya_model.dart';
import 'api_service.dart';

class ShopEditScreen extends StatefulWidget {
  final FurugiyaShop shop;
  const ShopEditScreen({super.key, required this.shop});

  @override
  State<ShopEditScreen> createState() => _ShopEditScreenState();
}

class _ShopEditScreenState extends State<ShopEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _stationCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _holidayCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _paymentCtrl;
  late final TextEditingController _parkingCtrl;
  late final TextEditingController _homepageCtrl;
  late final TextEditingController _snsCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late Set<String> _selectedGenres;

  static const _allGenres = [
    'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース',
    'ブランド古着', 'ミリタリー', 'ワーク', 'スポーツ', 'Y2K', 'アウトドア',
    'US古着', 'スニーカー', 'その他',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    _nameCtrl        = TextEditingController(text: s.name);
    _addressCtrl     = TextEditingController(text: s.address);
    _stationCtrl     = TextEditingController(text: s.nearestStation);
    _hoursCtrl       = TextEditingController(text: s.hours);
    _holidayCtrl     = TextEditingController(text: s.holiday == 'なし' ? '' : s.holiday);
    _descriptionCtrl = TextEditingController(text: s.description);
    _priceCtrl       = TextEditingController(text: s.priceRange == '不明' ? '' : s.priceRange);
    _paymentCtrl     = TextEditingController(text: s.paymentMethods == '不明' ? '' : s.paymentMethods);
    _parkingCtrl     = TextEditingController(text: s.parking);
    _homepageCtrl    = TextEditingController(text: s.homepageUrl);
    _snsCtrl         = TextEditingController(text: s.snsUrl);
    _latCtrl         = TextEditingController(text: s.latitude.toString());
    _lngCtrl         = TextEditingController(text: s.longitude.toString());
    _selectedGenres  = Set.from(s.genres);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _addressCtrl, _stationCtrl, _hoursCtrl, _holidayCtrl,
      _descriptionCtrl, _priceCtrl, _paymentCtrl, _parkingCtrl,
      _homepageCtrl, _snsCtrl, _latCtrl, _lngCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      final data = <String, dynamic>{
        'name':           _nameCtrl.text.trim(),
        'address':        _addressCtrl.text.trim(),
        'nearestStation': _stationCtrl.text.trim(),
        'genres':         _selectedGenres.toList(),
        'hours':          _hoursCtrl.text.trim(),
        'holiday':        _holidayCtrl.text.trim().isEmpty ? 'なし' : _holidayCtrl.text.trim(),
        'description':    _descriptionCtrl.text.trim(),
        'priceRange':     _priceCtrl.text.trim().isEmpty ? '不明' : _priceCtrl.text.trim(),
        'paymentMethods': _paymentCtrl.text.trim().isEmpty ? '不明' : _paymentCtrl.text.trim(),
        'parking':        _parkingCtrl.text.trim(),
        'homepageUrl':    _homepageCtrl.text.trim(),
        'snsUrl':         _snsCtrl.text.trim(),
        if (lat != null) 'latitude':  lat,
        if (lng != null) 'longitude': lng,
      };
      await ApiService.updateShop(widget.shop.id, data);
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('店舗情報を編集'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    '保存',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 基本情報 ──────────────────────────────
              _section('基本情報'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '店名 *',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '店名を入力してください' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: '住所',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stationCtrl,
                decoration: const InputDecoration(
                  labelText: '最寄り駅',
                  prefixIcon: Icon(Icons.train),
                  hintText: '例: 下北沢駅　複数は「、」で区切る',
                ),
              ),

              // ── ジャンル ──────────────────────────────
              _section('ジャンル'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allGenres.map((genre) {
                  final selected = _selectedGenres.contains(genre);
                  return FilterChip(
                    label: Text(genre),
                    selected: selected,
                    selectedColor: const Color(0xFF5D4037),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (val) => setState(() {
                      if (val) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    }),
                  );
                }).toList(),
              ),

              // ── 営業情報 ──────────────────────────────
              _section('営業情報'),
              TextFormField(
                controller: _hoursCtrl,
                decoration: const InputDecoration(
                  labelText: '営業時間',
                  prefixIcon: Icon(Icons.access_time),
                  hintText: '例: 12:00〜20:00',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _holidayCtrl,
                decoration: const InputDecoration(
                  labelText: '定休日',
                  prefixIcon: Icon(Icons.event_busy),
                  hintText: '例: 月曜日',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: '平均価格帯',
                  prefixIcon: Icon(Icons.currency_yen),
                  hintText: '例: ¥1,000〜¥5,000',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paymentCtrl,
                decoration: const InputDecoration(
                  labelText: '支払い方法',
                  prefixIcon: Icon(Icons.payment),
                  hintText: '例: 現金、クレジットカード',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parkingCtrl,
                decoration: const InputDecoration(
                  labelText: '駐車場',
                  prefixIcon: Icon(Icons.local_parking),
                  hintText: '例: あり・なし・3台',
                ),
              ),

              // ── Web・SNS ──────────────────────────────
              _section('Web・SNS'),
              TextFormField(
                controller: _homepageCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'ホームページURL',
                  prefixIcon: Icon(Icons.language),
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _snsCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Instagram / SNS URL',
                  prefixIcon: Icon(Icons.camera_alt_outlined),
                  hintText: 'https://instagram.com/yourshop',
                ),
              ),

              // ── 説明 ──────────────────────────────────
              _section('お店の説明'),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '説明・コメント',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),

              // ── ピン位置 ──────────────────────────────
              _section('ピン位置（緯度・経度）'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: '緯度'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: '経度'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          '保存する',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
