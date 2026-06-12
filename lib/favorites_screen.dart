import 'package:flutter/material.dart';
import 'api_service.dart';
import 'furugiya_model.dart';
import 'favorites_manager.dart';
import 'shop_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FurugiyaShop> _favShops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final ids = await FavoritesManager.getIds();
      final allShops = await ApiService.fetchShops();
      setState(() {
        _favShops = allShops.where((s) => ids.contains(s.id)).toList();
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
        title: const Text('お気に入り', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _favShops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('お気に入りがまだありません',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('店舗詳細画面の ♡ からお気に入り登録できます',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: Colors.brown,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _favShops.length,
                    itemBuilder: (context, index) {
                      final shop = _favShops[index];
                      final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
                      final color = _genreColor(genre);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(Icons.storefront, color: color, size: 22),
                          ),
                          title: Text(shop.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Row(children: [
                                ...List.generate(5, (i) => Icon(
                                  i < shop.rating.floor()
                                      ? Icons.star
                                      : (i < shop.rating ? Icons.star_half : Icons.star_border),
                                  color: Colors.orange, size: 13,
                                )),
                                const SizedBox(width: 4),
                                Text('${shop.reviewCount}件',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ]),
                              const SizedBox(height: 2),
                              Text(shop.address,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
                          ).then((_) => _loadFavorites()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
