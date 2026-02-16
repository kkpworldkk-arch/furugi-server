import 'package:flutter/material.dart';
import 'shop_add_screen.dart';
import 'article_post_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        children: [
          // ユーザー情報エリア（現在はゲスト固定）
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ゲストユーザー", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("ログインしていません", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // メニューリスト
          ListTile(
            leading: const Icon(Icons.add_business, color: Colors.blue),
            title: const Text('店舗を追加する'),
            subtitle: const Text('新しい古着屋をマップに登録します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // ここで余計な引数(passwordなど)を渡さず、シンプルに遷移します
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopAddScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.post_add, color: Colors.green),
            title: const Text('記事を投稿する (管理者用)'),
            subtitle: const Text('お知らせやコラムを配信します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // ここもシンプルに遷移します
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArticlePostScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('アプリ設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 設定画面はまだないので何もしないか、スナックバーを表示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('設定機能は開発中です')),
              );
            },
          ),
        ],
      ),
    );
  }
}