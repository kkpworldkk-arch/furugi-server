import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'furugiya_model.dart';
import 'api_service.dart';
import 'favorites_manager.dart';
import 'visited_manager.dart';
import 'shop_edit_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final FurugiyaShop shop;

  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late FurugiyaShop _shop;
  late double _rating;
  late int _reviewCount;
  bool _isFav = false;
  bool _hasVisited = false;
  List<ShopReview> _reviews = [];
  List<ShopNotice> _notices = [];
  List<ShopMedia> _media = [];
  bool _reviewsLoading = true;
  bool _noticesLoading = true;
  bool _mediaLoading = true;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    _rating = widget.shop.rating;
    _reviewCount = widget.shop.reviewCount;
    _loadFavStatus();
    _loadVisitedStatus();
    _loadReviews();
    _loadNotices();
    _loadMedia();
  }

  Future<void> _loadVisitedStatus() async {
    final visited = await VisitedManager.isVisited(widget.shop.id);
    if (mounted) setState(() => _hasVisited = visited);
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ApiService.getReviews(widget.shop.id);
      if (mounted) setState(() { _reviews = reviews; _reviewsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadNotices() async {
    try {
      final notices = await ApiService.getNotices(widget.shop.id);
      if (mounted) setState(() { _notices = notices; _noticesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _noticesLoading = false);
    }
  }

  Future<void> _loadMedia() async {
    try {
      final media = await ApiService.getMedia(widget.shop.id);
      if (mounted) setState(() { _media = media; _mediaLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _mediaLoading = false);
    }
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

  Future<void> _openEditScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ShopEditScreen(shop: _shop)),
    );
    if (result != null && mounted) {
      setState(() {
        _shop = _shop.copyWith(
          name:           result['name'] as String?,
          address:        result['address'] as String?,
          nearestStation: result['nearestStation'] as String?,
          genres:         (result['genres'] as List<dynamic>?)?.cast<String>(),
          hours:          result['hours'] as String?,
          holiday:        result['holiday'] as String?,
          description:    result['description'] as String?,
          priceRange:     result['priceRange'] as String?,
          paymentMethods: result['paymentMethods'] as String?,
          parking:        result['parking'] as String?,
          homepageUrl:    result['homepageUrl'] as String?,
          snsUrl:         result['snsUrl'] as String?,
          latitude:       result['latitude'] as double?,
          longitude:      result['longitude'] as double?,
        );
      });
      _showSnack(context, '保存しました');
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
      case 'ミリタリー':  return const Color(0xFF33691E);
      case 'ワーク':     return const Color(0xFF37474F);
      case 'スポーツ':   return const Color(0xFF01579B);
      case 'Y2K':       return const Color(0xFFD81B60);
      case 'アウトドア':  return const Color(0xFF2E7D32);
      default:          return const Color(0xFF5D4037);
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    String googleMapsUrl;
    if (_shop.mapUrl.isNotEmpty) {
      googleMapsUrl = _shop.mapUrl;
    } else {
      final String encodedQuery = Uri.encodeComponent("${_shop.name} ${_shop.address}");
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

  void _showReviewDialog() {
    final nicknameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    double selectedRating = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('口コミを投稿'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nicknameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ニックネーム（省略可）', hintText: '匿名'),
                ),
                const SizedBox(height: 16),
                const Text('評価', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = i + 1.0),
                    child: Icon(
                      i < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.orange, size: 32,
                    ),
                  )),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'コメント', hintText: '店舗の感想を書いてください'),
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
                  final result = await ApiService.postReview(
                    widget.shop.id,
                    nicknameCtrl.text.trim(),
                    selectedRating,
                    commentCtrl.text.trim(),
                  );
                  await _loadReviews();
                  if (mounted) {
                    setState(() {
                      _rating = (result['newRating'] as num).toDouble();
                      _reviewCount = result['reviewCount'] as int;
                    });
                    _showSnack(context, '口コミを投稿しました');
                  }
                } catch (e) {
                  if (mounted) _showSnack(context, '投稿に失敗しました: $e');
                }
              },
              child: const Text('投稿'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(ShopMedia m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: m.url.isNotEmpty ? () => _launchUrl(context, m.url) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.source.isNotEmpty ? m.source : 'メディア',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if (m.date.isNotEmpty)
                    Text(m.date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (m.url.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 14, color: Colors.indigo.shade400),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: m.url.isNotEmpty ? Colors.indigo.shade800 : Colors.black87,
                  decoration: m.url.isNotEmpty ? TextDecoration.underline : null,
                ),
              ),
              if (m.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(m.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMediaDialog() {
    final titleCtrl  = TextEditingController();
    final sourceCtrl = TextEditingController();
    final urlCtrl    = TextEditingController();
    final descCtrl   = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.newspaper_outlined, color: Colors.indigo[600], size: 20),
              const SizedBox(width: 8),
              const Text('メディア掲載を追加'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sourceCtrl,
                  decoration: const InputDecoration(
                    labelText: '掲載メディア名 *',
                    hintText: '例: WWD JAPAN、VOGUE JAPAN',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '記事タイトル *',
                    hintText: '例: 注目の古着屋10選',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '記事URL',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '概要（任意）',
                    hintText: '記事の簡単な説明',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty || sourceCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('メディア名と記事タイトルは必須です')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ApiService.addMedia(widget.shop.id, {
                          'title':       titleCtrl.text.trim(),
                          'source':      sourceCtrl.text.trim(),
                          'url':         urlCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadMedia();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('メディア掲載を追加しました')),
                        );
                      } catch (e) {
                        if (ctx.mounted) setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('追加に失敗しました: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('追加', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genre = _shop.genres.isNotEmpty ? _shop.genres.first : '';
    final color = _genreColor(genre);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(_shop.name,
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
            onPressed: _openEditScreen,
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
                  Text(_shop.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // 星評価
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        i < _rating.floor()
                            ? Icons.star
                            : (i < _rating ? Icons.star_half : Icons.star_border),
                        color: Colors.orange, size: 20,
                      )),
                      const SizedBox(width: 6),
                      Text(
                        _rating > 0 ? _rating.toStringAsFixed(1) : '-',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(width: 4),
                      Text('($_reviewCount件のレビュー)',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // アクションボタン行
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await VisitedManager.toggle(widget.shop.id);
                            final visited = await VisitedManager.isVisited(widget.shop.id);
                            if (mounted) {
                              setState(() => _hasVisited = visited);
                              messenger.showSnackBar(SnackBar(
                                content: Text(visited ? 'この店舗に行った記録を追加しました！' : '訪問記録を取り消しました'),
                                duration: const Duration(seconds: 1),
                              ));
                            }
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
                  _buildInfoRow(Icons.currency_yen, '平均価格帯', _shop.priceRange),
                  _buildInfoRow(Icons.access_time, '営業時間', _shop.hours),
                  _buildInfoRow(Icons.event_note, '定休日', _shop.holiday),
                  _buildInfoRow(Icons.local_parking, '駐車場', _formatParking(_shop.parking)),
                  _buildInfoRow(Icons.train, '最寄り駅', _shop.nearestStation),
                  _buildInfoRow(Icons.payments_outlined, '支払い方法', _shop.paymentMethods),
                  InkWell(
                    onTap: () => _openGoogleMaps(context),
                    child: _buildInfoRow(Icons.location_on, '住所', _shop.address, isLink: true),
                  ),
                  if (_shop.homepageUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.language, 'Webサイト', _shop.homepageUrl),
                  if (_shop.snsUrl.isNotEmpty)
                    _buildLinkRow(context, Icons.camera_alt_outlined, 'SNS / Instagram', _shop.snsUrl),
                ],
              ),
            ),

            // お店の説明があれば表示
            if (_shop.description.isNotEmpty) ...[
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
                    Text(_shop.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.6)),
                  ],
                ),
              ),
            ],

            // お知らせセクション
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      const Text('店舗からのお知らせ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_noticesLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_notices.isEmpty)
                    Text('現在お知らせはありません',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]))
                  else
                    ..._notices.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(n.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              Text(n.date,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(n.content,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                        ],
                      ),
                    )),
                ],
              ),
            ),

            // メディア掲載セクション
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.newspaper_outlined, size: 18, color: Colors.indigo[600]),
                          const SizedBox(width: 6),
                          const Text('メディア掲載',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _showAddMediaDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('追加', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_mediaLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_media.isEmpty)
                    Text('掲載情報はまだありません',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]))
                  else
                    ..._media.map((m) => _buildMediaCard(m)),
                ],
              ),
            ),

            // 口コミセクション
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('みんなの口コミ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: _showReviewDialog,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('口コミを書く', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_reviewsLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviews.isEmpty)
                    Text('まだ口コミがありません。最初の口コミを書いてみましょう！',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]))
                  else
                    ..._reviews.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < r.rating ? Icons.star : Icons.star_border,
                                color: Colors.orange, size: 16,
                              )),
                              const SizedBox(width: 8),
                              Text(r.nickname,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Spacer(),
                              Text(r.date,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            ],
                          ),
                          if (r.comment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.comment,
                                style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                          ],
                          const Divider(height: 20),
                        ],
                      ),
                    )),
                ],
              ),
            ),

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
