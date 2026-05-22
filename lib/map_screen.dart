import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart';
import 'add_shop_sheet.dart';

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

  // --- 検索とジャンル管理 ---
  final TextEditingController _searchController = TextEditingController();
  String _selectedGenre = 'すべて';
  final List<String> _genres = ['すべて', 'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース', 'ブランド古着'];

  // --- ピン位置調整モード（既存ショップ）---
  FurugiyaShop? _adjustingShop;
  LatLng? _adjustedPosition;
  bool _isSaving = false;

  // --- 新規ショップ追加モード ---
  bool _isAddingShop = false;
  LatLng? _newShopPinPosition;
  Map<String, dynamic>? _pendingShopData;
  LatLng _currentMapCenter = const LatLng(35.658034, 139.701636);

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops({String? query, String? genre}) async {
    try {
      final shops = await ApiService.getShops(query: query, genre: genre == 'すべて' ? null : genre);
      setState(() {
        _shops = shops;
        _createMarkers();
      });
    } catch (e) {
      debugPrint("ショップ読み込みエラー: $e");
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var shop in _shops) {
      if (shop.latitude == 0 && shop.longitude == 0) continue;

      final isAdjusting = _adjustingShop?.id == shop.id;
      final position = isAdjusting && _adjustedPosition != null
          ? _adjustedPosition!
          : LatLng(shop.latitude, shop.longitude);

      _markers.add(Marker(
        markerId: MarkerId(shop.id.toString()),
        position: position,
        draggable: isAdjusting,
        icon: isAdjusting
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
            : BitmapDescriptor.defaultMarker,
        onDragEnd: isAdjusting
            ? (newPos) => setState(() => _adjustedPosition = newPos)
            : null,
        onTap: isAdjusting ? null : () => _showShopInfo(shop),
      ));
    }

    // 新規追加モード中のピン（緑）
    if (_isAddingShop && _newShopPinPosition != null) {
      _markers.add(Marker(
        markerId: const MarkerId('__new_shop__'),
        position: _newShopPinPosition!,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onDragEnd: (newPos) => setState(() => _newShopPinPosition = newPos),
      ));
    }
  }

  void _enterAdjustMode(FurugiyaShop shop) {
    setState(() {
      _adjustingShop = shop;
      _adjustedPosition = LatLng(shop.latitude, shop.longitude);
      _createMarkers();
    });
    // 対象ピンに地図を移動
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(shop.latitude, shop.longitude), 16),
    );
  }

  // --- 新規ショップ追加 ---

  void _openAddShopForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddShopSheet(
        onSubmit: (shopData) {
          Navigator.pop(ctx);
          setState(() {
            _pendingShopData = shopData;
            _isAddingShop = true;
            _newShopPinPosition = _currentMapCenter;
            _createMarkers();
          });
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(_currentMapCenter, 16),
          );
        },
      ),
    );
  }

  void _cancelAddShop() {
    setState(() {
      _isAddingShop = false;
      _newShopPinPosition = null;
      _pendingShopData = null;
      _createMarkers();
    });
  }

  Future<void> _saveNewShop() async {
    if (_pendingShopData == null || _newShopPinPosition == null) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.addShop({
        ..._pendingShopData!,
        'latitude': _newShopPinPosition!.latitude,
        'longitude': _newShopPinPosition!.longitude,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('古着屋を追加しました！')),
      );
      setState(() {
        _isAddingShop = false;
        _newShopPinPosition = null;
        _pendingShopData = null;
      });
      await _loadShops(query: _searchController.text, genre: _selectedGenre);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('追加に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelAdjust() {
    setState(() {
      _adjustingShop = null;
      _adjustedPosition = null;
      _createMarkers();
    });
  }

  Future<void> _saveAdjustedPosition() async {
    if (_adjustingShop == null || _adjustedPosition == null) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.updateShop(_adjustingShop!.id, {
        'latitude': _adjustedPosition!.latitude,
        'longitude': _adjustedPosition!.longitude,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ピン位置を保存しました')),
      );
      setState(() {
        _adjustingShop = null;
        _adjustedPosition = null;
      });
      await _loadShops(query: _searchController.text, genre: _selectedGenre);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  void _showShopInfo(FurugiyaShop shop) {
    final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
    final color = _genreColor(genre);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ドラッグハンドル
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // カラーヘッダー
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.storefront, color: color, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          if (genre.isNotEmpty)
                            Text(genre, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    // 評価バッジ
                    if (shop.rating > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 13),
                            const SizedBox(width: 2),
                            Text(shop.rating.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // 住所・駅・価格帯
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(
                  children: [
                    if (shop.address.isNotEmpty)
                      Row(children: [
                        Icon(Icons.place, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(child: Text(shop.address,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
                      ]),
                    if (shop.nearestStation.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.train, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(shop.nearestStation, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        if (shop.priceRange.isNotEmpty && shop.priceRange != '不明') ...[
                          const Spacer(),
                          Text(shop.priceRange,
                              style: TextStyle(fontSize: 13, color: Colors.brown[600], fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              const Divider(height: 16),
              // ボタン行
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => ShopDetailScreen(shop: shop)));
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text("詳細を見る"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text("ここに行く"),
                        onPressed: () => _openGoogleMaps(shop),
                      ),
                    ),
                  ],
                ),
              ),
              // ピン位置調整ボタン
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_location_alt, color: Colors.orange, size: 18),
                    label: const Text("ピン位置を修正", style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                    onPressed: () {
                      Navigator.pop(context);
                      _enterAdjustMode(shop);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps(FurugiyaShop shop) async {
    String googleMapsUrl;

    if (shop.mapUrl.isNotEmpty) {
      googleMapsUrl = shop.mapUrl;
    } else {
      final String encodedQuery = Uri.encodeComponent("${shop.name} ${shop.address}");
      googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedQuery";
    }

    final Uri uri = Uri.parse(googleMapsUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint("Googleマップを開けませんでした");
      }
    } catch (e) {
      debugPrint("エラー: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool inEditMode = _adjustingShop != null || _isAddingShop;
    return Scaffold(
      floatingActionButton: inEditMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddShopForm,
              backgroundColor: Colors.green.shade700,
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text('古着屋を追加', style: TextStyle(color: Colors.white)),
            ),
      body: Stack(
        children: [
          // 1. 下層：Googleマップ
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _currentMapCenter = position.target,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // 2. 上層：検索・フィルタリングUI（編集モード中は非表示）
          if (!inEditMode)
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
                          hintText: '店名・住所・駅名で検索...',
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
                            backgroundColor: Colors.white.withValues(alpha: 0.9),
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

          // 3a. 新規ショップ追加モードのUI
          if (_isAddingShop)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_location_alt, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_pendingShopData?['name'] ?? '新しい古着屋'}\nピンをドラッグして正確な位置に移動してください',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _cancelAddShop,
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('この位置で登録'),
                            onPressed: _isSaving ? null : _saveNewShop,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 3b. ピン位置調整モードのUI（既存ショップ）
          if (_adjustingShop != null)
            SafeArea(
              child: Column(
                children: [
                  // 上部：説明バナー
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_with, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_adjustingShop!.name}\nピンをドラッグして正しい位置に移動してください',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 下部：保存・キャンセルボタン
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _cancelAdjust,
                            child: const Text("キャンセル"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: const Text("この位置に保存"),
                            onPressed: _isSaving ? null : _saveAdjustedPosition,
                          ),
                        ),
                      ],
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
