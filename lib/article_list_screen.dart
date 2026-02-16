import 'package:flutter/material.dart';
import 'api_service.dart';
import 'furugiya_model.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  List<FurugiyaArticle> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final data = await ApiService.fetchArticles();
      setState(() {
        _articles = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Scaffold(
      appBar: AppBar(title: const Text('情報・ニュース')),
      body: ListView.builder(
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${article.date} | ${article.genre}"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}