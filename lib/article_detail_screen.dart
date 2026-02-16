import 'package:flutter/material.dart';
import 'furugiya_model.dart';

class ArticleDetailScreen extends StatelessWidget {
  final FurugiyaArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(article.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("${article.date}  ${article.genre}", style: const TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            Text(article.content, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}