import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'furugiya_model.dart';
import 'api_service.dart';

class ShopDetailScreen extends StatefulWidget {
  final FurugiyaShop shop;

  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late String _paymentMethods;
  late String _hours;
  late String _holiday;
  late String _priceRange;

  @override
  void initState() {
    super.initState();
    _paymentMethods = widget.shop.paymentMethods;
    _hours = widget.shop.hours;
    _holiday = widget.shop.holiday;
    _priceRange = widget.shop.priceRange;
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    String googleMapsUrl;

    if (widget.shop.mapUrl.isNotEmpty) {
      googleMapsUrl = widget.shop.mapUrl;
    } else {
      final String encodedQuery = Uri.encodeComponent("${widget.shop.name} ${widget.shop.address}");
      googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedQuery";
    }

    await _launchUrl(context, googleMapsUrl);
  }

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

  void _showEditDialog() {
    final paymentCtrl = TextEditingController(text: _paymentMethods == '不明' ? '' : _paymentMethods);
    final hoursCtrl = TextEditingController(text: _hours);
    final holidayCtrl = TextEditingController(text: _holiday == 'なし' ? '' : _holiday);
    final priceCtrl = TextEditingController(text: _priceRange == '不明' ? '' : _priceRange);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('店舗情報を編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: paymentCtrl,
                decoration: const InputDecoration(
                  labelText: '支払い方法',
                  hintText: '例: 現金、クレジットカード',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(
                  labelText: '営業時間',
                  hintText: '例: 11:00〜20:00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holidayCtrl,
                decoration: const InputDecoration(
                  labelText: '定休日',
                  hintText: '例: 月曜日',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: '平均価格帯',
                  hintText: '例: ¥1,000〜¥5,000',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.updateShop(widget.shop.id, {
                  'paymentMethods': paymentCtrl.text.trim(),
                  'hours': hoursCtrl.text.trim(),
                  'holiday': holidayCtrl.text.trim().isEmpty ? 'なし' : holidayCtrl.text.trim(),
                  'priceRange': priceCtrl.text.trim().isEmpty ? '不明' : priceCtrl.text.trim(),
                });
                setState(() {
                  _paymentMethods = paymentCtrl.text.trim().isEmpty ? '不明' : paymentCtrl.text.trim();
                  _hours = hoursCtrl.text.trim();
                  _holiday = holidayCtrl.text.trim().isEmpty ? 'なし' : holidayCtrl.text.trim();
                  _priceRange = priceCtrl.text.trim().isEmpty ? '不明' : priceCtrl.text.trim();
                });
                if (mounted) _showSnack(context, '保存しました');
              } catch (e) {
                if (mounted) _showSnack(context, '保存に失敗しました: $e');
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shop.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '情報を編集',
            onPressed: _showEditDialog,
          ),
        ],
      ),
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
                    widget.shop.name,
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
                          widget.shop.genres.join(", "),
                          style: TextStyle(color: Colors.brown.shade800, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, color: Colors.orange, size: 20),
                      Text(
                        "${widget.shop.rating} (${widget.shop.reviewCount}件)",
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

                  _buildInfoRow(Icons.currency_yen, "平均価格帯", _priceRange),
                  _buildInfoRow(Icons.access_time, "営業時間", _hours),
                  _buildInfoRow(Icons.event_note, "定休日", _holiday),
                  _buildInfoRow(Icons.train, "最寄り駅", widget.shop.nearestStation),
                  _buildInfoRow(Icons.payments_outlined, "支払い方法", _paymentMethods),

                  InkWell(
                    onTap: () => _openGoogleMaps(context),
                    child: _buildInfoRow(Icons.location_on, "住所", widget.shop.address, isLink: true),
                  ),

                  if (widget.shop.homepageUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.language, "Webサイト", widget.shop.homepageUrl),

                  if (widget.shop.snsUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.link, "SNS / Instagram", widget.shop.snsUrl),

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
