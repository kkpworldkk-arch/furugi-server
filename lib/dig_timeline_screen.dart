import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'post_dig_screen.dart';

class DigTimelineScreen extends StatefulWidget {
  const DigTimelineScreen({super.key});

  @override
  State<DigTimelineScreen> createState() => _DigTimelineScreenState();
}

class _DigTimelineScreenState extends State<DigTimelineScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;

  // FlaskサーバーのURL（エミュレータの場合は 10.0.2.2、実機の場合はPCのIPアドレス）
  final String apiUrl = "http://10.0.2.2:5000/api/posts"; 

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  // サーバーから投稿データを取得
  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          _posts = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("エラー: $e");
      setState(() => _isLoading = false);
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ディグったアイテム', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : RefreshIndicator(
              onRefresh: _fetchPosts,
              child: ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) => _buildPostCard(_posts[index]),
              ),
            ),
      // --- ここにプラスボタンを追加 ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 投稿画面（白紙）へ遷移
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PostDigScreen()),
          );
        },
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }


  // 投稿カードのUI
  Widget _buildPostCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 店舗情報ヘッダー
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.store, color: Colors.white)),
            title: Text(post['shopName'] ?? '不明な店舗', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(post['createdAt'] ?? ''),
          ),
          // 商品画像
          post['imageUrl'] != ""
              ? Image.network(
                  post['imageUrl'],
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 50),
                  ),
                )
              : Container(height: 200, color: Colors.grey[300], child: const Icon(Icons.image)),
          
          // アイテム名と価格
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(post['itemName'] ?? 'アイテム名なし', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      post['price'] != null ? "¥${post['price']}" : "価格不明",
                      style: const TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post['description'] ?? '', style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}