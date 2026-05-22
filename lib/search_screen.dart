import 'package:flutter/material.dart';
import 'api_service.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<FurugiyaShop> _allShops = [];
  List<FurugiyaShop> _filteredShops = [];
  bool _isLoading = true;
  final TextEditingController _controller = TextEditingController();
  String _selectedGenre = 'すべて';
  String _sortBy = '評価順';

  static const List<String> _genres = [
    'すべて', 'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース', 'ブランド古着'
  ];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    try {
      final shops = await ApiService.fetchShops();
      if (mounted) {
        setState(() {
          _allShops = shops;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _controller.text.toLowerCase();
    var shops = _allShops.where((shop) {
      final matchText = q.isEmpty ||
          '${shop.name} ${shop.address} ${shop.nearestStation} ${shop.genres.join(' ')} ${shop.description}'
              .toLowerCase()
              .contains(q);
      final matchGenre = _selectedGenre == 'すべて' || shop.genres.contains(_selectedGenre);
      return matchText && matchGenre;
    }).toList();

    if (_sortBy == '評価順') {
      shops.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == '件数順') {
      shops.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    setState(() => _filteredShops = shops);
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

  Widget _buildShopCard(FurugiyaShop shop) {
    final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
    final color = _genreColor(genre);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
      ).then((_) => _applyFilters()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カバーエリア
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 100,
                color: color.withValues(alpha: 0.12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: Icon(Icons.storefront, size: 52, color: color.withValues(alpha: 0.35))),
                    // ジャンルバッジ
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          genre.isEmpty ? '古着' : genre,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // 評価バッジ
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shop.rating >= 4.0 ? Colors.orange.shade700 : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 13),
                            const SizedBox(width: 2),
                            Text(
                              shop.rating > 0 ? shop.rating.toStringAsFixed(1) : 'NEW',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 情報エリア
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        i < shop.rating.floor()
                            ? Icons.star
                            : (i < shop.rating ? Icons.star_half : Icons.star_border),
                        color: Colors.orange, size: 14,
                      )),
                      const SizedBox(width: 4),
                      Text(
                        '${shop.reviewCount}件のレビュー',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      if (shop.priceRange.isNotEmpty && shop.priceRange != '不明')
                        Text(
                          shop.priceRange,
                          style: TextStyle(fontSize: 12, color: Colors.brown[600], fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (shop.address.isNotEmpty)
                    Row(children: [
                      Icon(Icons.place, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(shop.address,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  if (shop.nearestStation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.train, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(shop.nearestStation, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '店名・駅名・ジャンルで検索',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400]),
                      onPressed: () {
                        _controller.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // ジャンルフィルターチップ
                SizedBox(
                  height: 46,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _genres.length,
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      final isSelected = _selectedGenre == genre;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.brown[600],
                          backgroundColor: Colors.grey[100],
                          onSelected: (_) {
                            setState(() => _selectedGenre = genre);
                            _applyFilters();
                          },
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    },
                  ),
                ),
                // 件数 + ソート
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(
                              text: '${_filteredShops.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            TextSpan(
                              text: '件のお店',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        initialValue: _sortBy,
                        onSelected: (val) {
                          setState(() => _sortBy = val);
                          _applyFilters();
                        },
                        itemBuilder: (_) => ['評価順', '件数順']
                            .map((s) => PopupMenuItem(value: s, child: Text(s)))
                            .toList(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_sortBy,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.brown[700], fontWeight: FontWeight.w600)),
                            Icon(Icons.keyboard_arrow_down, color: Colors.brown[700], size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                : _filteredShops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('条件に合うお店が見つかりません',
                                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadShops,
                        color: Colors.brown,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: _filteredShops.length,
                          itemBuilder: (context, index) => _buildShopCard(_filteredShops[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
