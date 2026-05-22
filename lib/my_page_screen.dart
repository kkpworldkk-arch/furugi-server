import 'package:flutter/material.dart';
import 'shop_add_screen.dart';
import 'article_post_screen.dart';
import 'favorites_screen.dart';
import 'favorites_manager.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  int _favCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final ids = await FavoritesManager.getIds();
    if (mounted) setState(() => _favCount = ids.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('マイページ', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: Colors.brown,
        child: ListView(
          children: [
            // ユーザープロフィールエリア
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 38, color: Colors.brown.shade400),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ゲストユーザー',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('ログインしていません',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 統計カード
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  _buildStatItem(Icons.favorite, '$_favCount', 'お気に入り', Colors.red),
                  _buildStatDivider(),
                  _buildStatItem(Icons.check_circle, '0', '行った！', Colors.green),
                  _buildStatDivider(),
                  _buildStatItem(Icons.explore, '0', 'ディグった', Colors.brown),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // メニュー
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    title: 'お気に入りの古着屋',
                    subtitle: '$_favCount件のお店をブックマーク中',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    ).then((_) => _loadStats()),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuTile(
                    icon: Icons.add_business,
                    iconColor: Colors.blue,
                    title: '店舗を追加する',
                    subtitle: '新しい古着屋をマップに登録します',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopAddScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuTile(
                    icon: Icons.post_add,
                    iconColor: Colors.green,
                    title: '記事を投稿する (管理者用)',
                    subtitle: 'お知らせやコラムを配信します',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ArticlePostScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.settings,
                    iconColor: Colors.grey,
                    title: 'アプリ設定',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('設定機能は開発中です')),
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuTile(
                    icon: Icons.info_outline,
                    iconColor: Colors.grey,
                    title: 'アプリについて',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('古着屋マップ v1.0')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
