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
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      final shops = await ApiService.fetchShops();
      setState(() {
        _allShops = shops;
        _filteredShops = shops;
      });
    } catch (e) {
      // エラー処理
    }
  }

  void _search(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredShops = _allShops.where((shop) {
        final target = '${shop.name} ${shop.address} ${shop.nearestStation} ${shop.genres.join(' ')} ${shop.description}'.toLowerCase();
        return target.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: '店名・住所・駅名・ジャンルで検索',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredShops.length,
        itemBuilder: (context, index) {
          final shop = _filteredShops[index];
          return ListTile(
            leading: const Icon(Icons.store),
            title: Text(shop.name),
            subtitle: Text(shop.address),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
              );
            },
          );
        },
      ),
    );
  }
}