import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart';

class ShopMapScreen extends StatefulWidget {
  final List<FurugiyaShop> filteredShops;

  const ShopMapScreen({super.key, required this.filteredShops});

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  late GoogleMapController mapController;
  
  // 表示する店舗リスト
  List<FurugiyaShop> _displayedShops = [];
  
  // 検索モード (0: 場所・店名, 1: ジャンル)
  int _searchMode = 0; 

  // 検索条件
  String _keyword = "";
  String? _selectedGenre;
  bool _onlyOpenNow = false;

  @override
  void initState() {
    super.initState();
    _displayedShops = widget.filteredShops;
  }

  // ▼▼▼ フィルタリング実行機能 ▼▼▼
  void _runFilter() {
    setState(() {
      _displayedShops = widget.filteredShops.where((shop) {
        // 1. キーワード判定 (場所モードのとき有効)
        // 住所(市区町村・駅周辺) や 店名 にヒットするか
        final keywordMatch = _keyword.isEmpty ||
            shop.name.contains(_keyword) ||
            shop.address.contains(_keyword);

        // 2. ジャンル判定 (ジャンルモードのとき有効)
        final genreMatch = _selectedGenre == null ||
            shop.genres.contains(_selectedGenre);

        // 3. 営業中フィルター (常に有効)
        final openMatch = !_onlyOpenNow || _isOpenNow(shop.hours);

        return keywordMatch && genreMatch && openMatch;
      }).toList();
    });
  }

  // ▼▼▼ 営業中判定ロジック ▼▼▼
  bool _isOpenNow(String hoursString) {
    if (hoursString.isEmpty || !hoursString.contains('-')) return false;
    try {
      final parts = hoursString.split('-');
      if (parts.length != 2) return false;
      final startMinutes = _toMinutes(parts[0].trim());
      final endMinutes = _toMinutes(parts[1].trim());
      final now = TimeOfDay.now();
      final currentMinutes = now.hour * 60 + now.minute;

      if (startMinutes == -1 || endMinutes == -1) return false;
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } catch (e) {
      return false;
    }
  }

  int _toMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return -1;
    }
  }

  // 全ジャンルリストの生成
  List<String> get _allGenres {
    final genres = <String>{};
    for (var shop in widget.filteredShops) {
      genres.addAll(shop.genres);
    }
    return genres.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    // マーカー作成
    final Set<Marker> markers = _displayedShops.map((shop) {
      return Marker(
        markerId: MarkerId(shop.id.toString()),
        position: LatLng(shop.latitude, shop.longitude),
        infoWindow: InfoWindow(
          title: shop.name,
          snippet: "タップで詳細へ",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopDetailScreen(shop: shop),
              ),
            );
          },
        ),
      );
    }).toSet();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Googleマップ
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(35.6645, 139.7045),
              zoom: 12.0,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            // マップタップでキーボードを閉じる
            onTap: (_) => FocusScope.of(context).unfocus(),
          ),

          // 2. 検索パネル (上に浮いている)
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- A. タブ切り替えボタン (場所・店名 vs ジャンル) ---
                  Row(
                    children: [
                      Expanded(child: _buildTabButton("📍 場所・店名", 0)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTabButton("🏷 ジャンル", 1)),
                    ],
                  ),
                  const Divider(height: 20),

                  // --- B. 入力エリア (モードによって切り替え) ---
                  if (_searchMode == 0)
                    // 0: テキスト入力 (場所・駅・店名)
                    TextField(
                      onChanged: (val) {
                        setState(() {
                          _keyword = val;
                          _selectedGenre = null; // 場所検索時はジャンル解除
                          _runFilter();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: '駅名、市区町村、店名を入力...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    )
                  else
                    // 1: ジャンルチップ選択
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('全て'),
                            selected: _selectedGenre == null,
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedGenre = null;
                                _keyword = ""; // ジャンル検索時はキーワード解除
                                _runFilter();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._allGenres.map((genre) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(genre),
                                selected: _selectedGenre == genre,
                                onSelected: (bool selected) {
                                  setState(() {
                                    _selectedGenre = selected ? genre : null;
                                    _keyword = ""; // ジャンル検索時はキーワード解除
                                    _runFilter();
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // --- C. 営業中ボタン (これだけ下に配置) ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _onlyOpenNow = !_onlyOpenNow;
                          _runFilter();
                        });
                      },
                      icon: Icon(
                        Icons.access_time,
                        color: _onlyOpenNow ? Colors.white : Colors.green,
                      ),
                      label: Text(
                        _onlyOpenNow ? "営業中のお店のみ表示中" : "現在営業中のみ表示",
                        style: TextStyle(
                          color: _onlyOpenNow ? Colors.white : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _onlyOpenNow ? Colors.green : Colors.white,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 件数0件のときのアラート
          if (_displayedShops.isEmpty)
             Positioned(
               bottom: 120,
               left: 20, 
               right: 20,
               child: Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.black87,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: const Text(
                   "条件に一致するお店が見つかりません。\n検索条件を変更してください。", 
                   style: TextStyle(color: Colors.white),
                   textAlign: TextAlign.center,
                 ),
               ),
             ),
        ],
      ),
    );
  }

  // タブボタンを作る部品
  Widget _buildTabButton(String label, int index) {
    final isSelected = _searchMode == index;
    return InkWell(
      onTap: () {
        setState(() {
          _searchMode = index;
          // モードを変えたら、入力内容をリセットして全表示に戻すか、あるいは維持するか
          // 今回は分かりやすくリセットします
          _keyword = "";
          _selectedGenre = null;
          _runFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.brown[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.brown) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.brown : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}