import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'furugiya_model.dart';
import 'api_service.dart';
import 'favorites_manager.dart';

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
  late String _parking;
  bool _isFav = false;
  bool _hasVisited = false;

  @override
  void initState() {
    super.initState();
    _paymentMethods = widget.shop.paymentMethods;
    _hours = widget.shop.hours;
    _holiday = widget.shop.holiday;
    _priceRange = widget.shop.priceRange;
    _parking = widget.shop.parking;
    _loadFavStatus();
  }

  Future<void> _loadFavStatus() async {
    final fav = await FavoritesManager.isFav(widget.shop.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    await FavoritesManager.toggle(widget.shop.id);
    final fav = await FavoritesManager.isFav(widget.shop.id);
    if (mounted) {
      setState(() => _isFav = fav);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFav ? 'お気に入りに追加しました' : 'お気に入りから外しました'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  String _formatParking(String p) {
    if (p.isEmpty) return '';
    if (p == 'なし') return 'なし';
    if (p == 'あり') return 'あり';
    final n = int.tryParse(p);
    return n != null ? '$n台' : p;
  }

  Color _genreColor(String genre) {
    switch (genre) {
      case 'ヴィンテージ': return const Color(0xFF8B6914);
      case 'アメカジ':   return const Color(0xFF1565C0);
      case 'ストリート':  return const Color(0xFF6A1B9A);
      case 'レディース':  return const Color(0xFFAD1457);
      case 'ブランド古着': return const Color(0xFF00695C);
      default:          return const Color(0xFF5D4037);
    }
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
                  labelText: '支払い方法', hintText: '例: 現金、クレジットカード'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(
                  labelText: '営業時間', hintText: '例: 11:00〜20:00'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holidayCtrl,
                decoration: const InputDecoration(
                  labelText: '定休日', hintText: '例: 月曜日'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: '平均価格帯', hintText: '例: ¥1,000〜¥5,000'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
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
    final genre = widget.shop.genres.isNotEmpty ? widget.shop.genres.first : '';
    final color = _genreColor(genre);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(widget.shop.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : Colors.grey[600],
            ),
            tooltip: _isFav ? 'お気に入り解除' : 'お気に入り追加',
            onPressed: _toggleFav,
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.grey[600]),
            tooltip: '情報を編集',
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カバーエリア（ジャンル色）
            Container(
              height: 180,
              width: double.infinity,
              color: color.withValues(alpha: 0.15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: Icon(Icons.storefront, size: 90, color: color.withValues(alpha: 0.35))),
                  Positioned(
                    bottom: 12, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        genre.isEmpty ? '古着' : genre,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // メイン情報エリア
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 店名
                  Text(widget.shop.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // 星評価
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        i < widget.shop.rating.floor()
                            ? Icons.star
                            : (i < widget.shop.rating ? Icons.star_half : Icons.star_border),
                        color: Colors.orange, size: 20,
                      )),
                      const SizedBox(width: 6),
                      Text(
                        widget.shop.rating > 0
                            ? widget.shop.rating.toStringAsFixed(1)
                            : '-',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(width: 4),
                      Text('(${widget.shop.reviewCount}件のレビュー)',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // アクションボタン行
                  Row(
                    children: [
                      // 行った！ボタン
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _hasVisited = !_hasVisited);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_hasVisited ? 'この店舗に行った記録を追加しました！' : '訪問記録を取り消しました'),
                              duration: const Duration(seconds: 1),
                            ));
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _hasVisited ? Colors.green.shade50 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _hasVisited ? Colors.green : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _hasVisited ? Icons.check_circle : Icons.check_circle_outline,
                                  color: _hasVisited ? Colors.green : Colors.grey,
                                  size: 22,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hasVisited ? '行った！✓' : '行った！',
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold,
                                    color: _hasVisited ? Colors.green : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ここに行くボタン
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _openGoogleMaps(context),
                          icon: const Icon(Icons.map, size: 20),
                          label: const Text('ここに行く',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 店舗情報セクション
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('店舗情報',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.currency_yen, '平均価格帯', _priceRange),
                  _buildInfoRow(Icons.access_time, '営業時間', _hours),
                  _buildInfoRow(Icons.event_note, '定休日', _holiday),
                  _buildInfoRow(Icons.local_parking, '駐車場', _formatParking(_parking)),
                  _buildInfoRow(Icons.train, '最寄り駅', widget.shop.nearestStation),
                  _buildInfoRow(Icons.payments_outlined, '支払い方法', _paymentMethods),
                  InkWell(
                    onTap: () => _openGoogleMaps(context),
                    child: _buildInfoRow(Icons.location_on, '住所', widget.shop.address, isLink: true),
                  ),
                  if (widget.shop.homepageUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.language, 'Webサイト', widget.shop.homepageUrl),
                  if (widget.shop.snsUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.link, 'SNS / Instagram', widget.shop.snsUrl),
                ],
              ),
            ),

            // お店の説明があれば表示
            if (widget.shop.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('お店について',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.shop.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.6)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String content, {bool isLink = false}) {
    if (content.isEmpty || content == '不明' || content == 'なし') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isLink ? Colors.blue : Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLink ? Colors.blue : Colors.black87,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(url,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
