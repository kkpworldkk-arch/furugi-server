import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'post_dig_screen.dart';

class DigTimelineScreen extends StatefulWidget {
  const DigTimelineScreen({super.key});

  @override
  State<DigTimelineScreen> createState() => _DigTimelineScreenState();
}

class _DigTimelineScreenState extends State<DigTimelineScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;
  final Map<int, bool> _liked = {};
  final Map<int, int> _likeCounts = {};

  final String _apiUrl = "${ApiService.baseUrl}/posts";

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final posts = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        setState(() {
          _posts = posts;
          for (int i = 0; i < posts.length; i++) {
            _liked[i] = false;
            _likeCounts[i] = (posts[i]['likes'] ?? 0) as int;
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("エラー: $e");
      setState(() => _isLoading = false);
    }
  }

  void _toggleLike(int index) {
    setState(() {
      final wasLiked = _liked[index] ?? false;
      _liked[index] = !wasLiked;
      _likeCounts[index] = (_likeCounts[index] ?? 0) + (wasLiked ? -1 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('ディグったアイテム',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        foregroundColor: Colors.brown,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checkroom, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('まだ投稿がありません',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('+ ボタンからディグったアイテムを投稿しましょう',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPosts,
                  color: Colors.brown,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) => _buildPostCard(_posts[index], index),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PostDigScreen()),
        ).then((_) => _fetchPosts()),
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ディグった！', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final isLiked = _liked[index] ?? false;
    final likeCount = _likeCounts[index] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（店舗名 + 日時）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.brown.shade200),
                  ),
                  child: Icon(Icons.store, color: Colors.brown.shade400, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['shopName'] ?? '不明な店舗',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        post['createdAt'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 商品画像
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: post['imageUrl'] != null && post['imageUrl'] != ''
                ? Image.network(
                    post['imageUrl'],
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
                      ),
                    ),
                  )
                : Container(
                    height: 180,
                    color: Colors.grey[100],
                    child: Center(
                      child: Icon(Icons.checkroom, size: 60, color: Colors.grey[400]),
                    ),
                  ),
          ),

          // いいねボタン行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(index),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      color: isLiked ? Colors.red : Colors.grey[500],
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  likeCount > 0 ? '$likeCount' : '',
                  style: TextStyle(
                      fontSize: 13, color: isLiked ? Colors.red : Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('0', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),

          // アイテム名・価格・説明
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        post['itemName'] ?? 'アイテム名なし',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post['price'] != null ? '¥${post['price']}' : '価格不明',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if ((post['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post['description'],
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
