import 'package:flutter/material.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart';
import 'shop_map_screen.dart';

class ShopRankingScreen extends StatefulWidget {
  final List<FurugiyaShop> initialShops;
  const ShopRankingScreen({super.key, required this.initialShops});
  @override
  State<ShopRankingScreen> createState() => _State();
}
class _State extends State<ShopRankingScreen> {
  late List<FurugiyaShop> _shops;
  @override
  void initState() { super.initState(); _shops = widget.initialShops; }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ランキング"), actions: [
        IconButton(icon: const Icon(Icons.map), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopMapScreen(filteredShops: _shops))))
      ]),
      body: ListView.builder(
        itemCount: _shops.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: Text("${i+1}位", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          title: Text(_shops[i].name),
          subtitle: Text("${_shops[i].rating} ⭐ / ${_shops[i].genres.join(', ')}"),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: _shops[i]))),
        )
      ),
    );
  }
}