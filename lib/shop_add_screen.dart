import 'package:flutter/material.dart';
import 'api_service.dart';

class ShopAddScreen extends StatefulWidget {
  const ShopAddScreen({super.key});

  @override
  State<ShopAddScreen> createState() => _ShopAddScreenState();
}

class _ShopAddScreenState extends State<ShopAddScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _address = '';
  String _genre = '';
  String _hours = '';
  String _holiday = ''; // ★追加：定休日を保存する変数
  String _homepage = '';
  String _sns = '';
  String _desc = '';
  String _price = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final shopData = {
        "name": _name,
        "address": _address,
        "genres": _genre.split(','),
        "hours": _hours,
        "holiday": _holiday, // ★追加：サーバーに送るデータに含める
        "homepageUrl": _homepage,
        "snsUrl": _sns,
        "description": _desc,
        "priceRange": _price,
        "latitude": 0.0,
        "longitude": 0.0,
      };

      await ApiService.addShop(shopData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店舗の追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: '店名 (必須)'),
                validator: (val) => val!.isEmpty ? '必須' : null,
                onSaved: (val) => _name = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '住所 (必須)'),
                validator: (val) => val!.isEmpty ? '必須' : null,
                onSaved: (val) => _address = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ジャンル (カンマ区切り)'),
                onSaved: (val) => _genre = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '営業時間 (例: 11:00-20:00)'), 
                onSaved: (val) => _hours = val!,
              ),
              // ★追加：定休日の入力フィールド
              TextFormField(
                decoration: const InputDecoration(labelText: '定休日 (例: 火曜日、不定休)'), 
                onSaved: (val) => _holiday = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '価格帯'), 
                onSaved: (val) => _price = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Webサイト'), 
                onSaved: (val) => _homepage = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'SNS'), 
                onSaved: (val) => _sns = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '説明'), 
                maxLines: 3, 
                onSaved: (val) => _desc = val!,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit, 
                child: const Text('登録'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}