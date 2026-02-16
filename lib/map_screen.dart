import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.658034, 139.701636),
    zoom: 12,
  );

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  List<FurugiyaShop> _shops = [];

  // --- 追加分：検索とジャンル管理 ---
  final TextEditingController _searchController = TextEditingController();
  String _selectedGenre = 'すべて';
  final List<String> _genres = ['すべて', 'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース', 'ブランド古着'];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  // 修正：引数でキーワードとジャンルを受け取れるようにする（ApiService側も対応が必要）
  Future<void> _loadShops({String? query, String? genre}) async {
    try {
      // ApiService.getShopsに検索条件を渡す（※ApiService側の修正も後述します）
      final shops = await ApiService.getShops(query: query, genre: genre == 'すべて' ? null : genre);
      setState(() {
        _shops = shops;
        _createMarkers();
      });
    } catch (e) {
      print("ショップ読み込みエラー: $e");
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var shop in _shops) {
      if (shop.latitude == 0 && shop.longitude == 0) continue;

      final marker = Marker(
        markerId: MarkerId(shop.id.toString()),
        position: LatLng(shop.latitude, shop.longitude),
        onTap: () {
          _showShopInfo(shop);
        },
      );
      _markers.add(marker);
    }
  }

  // --- 既存の _showShopInfo と _openGoogleMaps はそのまま保持 ---
  void _showShopInfo(FurugiyaShop shop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(shop.genres.join(", "), style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(shop.address, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ShopDetailScreen(shop: shop)));
                      },
                      child: const Text("詳細を見る"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text("ここに行く"),
                      onPressed: () => _openGoogleMaps(shop),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps(FurugiyaShop shop) async {
    final String query = "${shop.name} ${shop.address}";
    final String encodedQuery = Uri.encodeComponent(query);
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedQuery";
    final Uri uri = Uri.parse(googleMapsUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        print("Googleマップを開けませんでした");
      }
    } catch (e) {
      print("エラー: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack( // Mapの上にUIを重ねるためにStackを使用
        children: [
          // 1. 下層：Googleマップ
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // 自作UIと被るためボタンのみ無効化（機能は生きています）
            zoomControlsEnabled: false,
          ),

          // 2. 上層：検索・フィルタリングUI
          SafeArea(
            child: Column(
              children: [
                // 検索バー
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '古着屋を検索...',
                        prefixIcon: const Icon(Icons.search, color: Colors.brown),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadShops(genre: _selectedGenre);
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onSubmitted: (value) {
                        _loadShops(query: value, genre: _selectedGenre);
                      },
                    ),
                  ),
                ),

                // ジャンル選択チップ
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _genres.length,
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      final isSelected = _selectedGenre == genre;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(genre),
                          selected: isSelected,
                          selectedColor: Colors.brown,
                          backgroundColor: Colors.white.withOpacity(0.9),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            setState(() => _selectedGenre = genre);
                            _loadShops(query: _searchController.text, genre: genre);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}