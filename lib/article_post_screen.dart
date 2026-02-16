import 'package:flutter/material.dart';
import 'api_service.dart';

class ArticlePostScreen extends StatefulWidget {
  const ArticlePostScreen({super.key});

  @override
  State<ArticlePostScreen> createState() => _ArticlePostScreenState();
}

class _ArticlePostScreenState extends State<ArticlePostScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _content = '';
  String _genre = 'お知らせ';
  String _password = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final articleData = {
        "title": _title,
        "content": _content,
        "genre": _genre,
        "password": _password,
      };
      await ApiService.postArticle(articleData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿しました')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記事投稿')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'タイトル'),
                validator: (v) => v!.isEmpty ? '必須' : null,
                onSaved: (v) => _title = v!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '本文'),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? '必須' : null,
                onSaved: (v) => _content = v!,
              ),
              DropdownButtonFormField<String>(
                value: _genre,
                items: ['お知らせ', 'コラム'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _genre = v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
                onSaved: (v) => _password = v!,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text('投稿')),
            ],
          ),
        ),
      ),
    );
  }
}