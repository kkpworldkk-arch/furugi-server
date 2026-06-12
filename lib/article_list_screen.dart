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
    setState(() => _isLoading = true);
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

  Color _genreColor(String genre) {
    switch (genre) {
      case 'ヴィンテージ': return const Color(0xFF8B6914);
      case 'アメカジ':   return const Color(0xFF1565C0);
      case 'ストリート':  return const Color(0xFF6A1B9A);
      case 'レディース':  return const Color(0xFFAD1457);
      case 'ブランド古着': return const Color(0xFF00695C);
      case 'ミリタリー':  return const Color(0xFF33691E);
      case 'ワーク':     return const Color(0xFF37474F);
      case 'スポーツ':   return const Color(0xFF01579B);
      case 'Y2K':       return const Color(0xFFD81B60);
      case 'アウトドア':  return const Color(0xFF2E7D32);
      case 'お知らせ':   return const Color(0xFF1565C0);
      case 'コラム':    return const Color(0xFF00695C);
      default:          return const Color(0xFF5D4037);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('情報・コラム', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('記事がまだありません',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadArticles,
                  color: Colors.brown,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      final color = _genreColor(article.genre);
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 10, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // カバーエリア
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: Container(
                                  height: 80,
                                  color: color.withValues(alpha: 0.10),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 16),
                                      Icon(Icons.article, size: 36, color: color.withValues(alpha: 0.5)),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: color, borderRadius: BorderRadius.circular(20)),
                                        child: Text(article.genre,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // 記事情報
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(article.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 15, height: 1.4)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(article.date,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        const Spacer(),
                                        Text('続きを読む',
                                            style: TextStyle(
                                                fontSize: 12, color: Colors.brown[600],
                                                fontWeight: FontWeight.w600)),
                                        Icon(Icons.arrow_forward_ios,
                                            size: 11, color: Colors.brown[600]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
