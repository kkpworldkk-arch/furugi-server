import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // リンクを開く機能
import 'furugiya_model.dart'; 

class ShopDetailScreen extends StatelessWidget {
  final FurugiyaShop shop;

  const ShopDetailScreen({super.key, required this.shop});

  Future<void> _openGoogleMaps(BuildContext context) async {
    // 1. 店名と住所をつなげて「検索ワード」を作ります
    final String query = "${shop.name} ${shop.address}";
    
    // 2. 日本語などをURLで使える記号に変換します
    final String encodedQuery = Uri.encodeComponent(query);
    
    // 3. Googleマップの検索URL
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedQuery";

    // 4. URLを開きます
    await _launchUrl(context, googleMapsUrl);
  }

  // 通常のURLを開く関数
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    if (urlString.trim().isEmpty) {
      _showSnack(context, "URLが登録されていません");
      return;
    }

    String finalUrl = urlString.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final Uri url = Uri.parse(finalUrl);

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) _showSnack(context, "リンクを開けませんでした");
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, "エラーが発生しました: $e");
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像エリア
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade300,
              child: const Icon(Icons.store, size: 80, color: Colors.white),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 店名
                  Text(
                    shop.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // ジャンルと評価
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shop.genres.join(", "),
                          style: TextStyle(color: Colors.brown.shade800, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, color: Colors.orange, size: 20),
                      Text(
                        "${shop.rating} (${shop.reviewCount}件)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 「ここに行く」ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _openGoogleMaps(context),
                      icon: const Icon(Icons.map),
                      label: const Text("ここに行く (Googleマップ)", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),

                  // 店舗情報
                  const Text(
                    "店舗情報",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(Icons.currency_yen, "平均価格帯", shop.priceRange),
                  _buildInfoRow(Icons.access_time, "営業時間", shop.hours),
                  // ★追加：定休日の表示
                  _buildInfoRow(Icons.event_note, "定休日", shop.holiday),
                  
                  InkWell(
                    onTap: () => _openGoogleMaps(context),
                    child: _buildInfoRow(Icons.location_on, "住所", shop.address, isLink: true),
                  ),
                  
                  if (shop.homepageUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.language, "Webサイト", shop.homepageUrl),

                  if (shop.snsUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.link, "SNS / Instagram", shop.snsUrl),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String content, {bool isLink = false}) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: isLink ? Colors.blue : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  content, 
                  style: TextStyle(
                    fontSize: 15, 
                    color: isLink ? Colors.blue : Colors.black,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(BuildContext context, IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}