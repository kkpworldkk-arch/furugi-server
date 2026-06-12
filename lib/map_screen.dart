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
    target: LatLng(35.6611, 139.6685),
    zoom: 15,
  );

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  List<FurugiyaShop> _shops = [];
  List<FurugiyaShop> _visibleShops = [];

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // --- 検索とジャンル管理 ---
  final TextEditingController _searchController = TextEditingController();
  String _selectedGenre = 'すべて';
  final List<String> _genres = [
    'すべて', 'ヴィンテージ', 'アメカジ', 'ストリート', 'レディース',
    'ブランド古着', 'ミリタリー', 'ワーク', 'スポーツ', 'Y2K', 'アウトドア',
  ];

  // --- ピン位置調整モード ---
  FurugiyaShop? _adjustingShop;
  LatLng? _adjustedPosition;
  bool _isSaving = false;

  // --- 新規ショップ追加モード ---
  bool _isAddingShop = false;
  LatLng? _newShopPinPosition;
  Map<String, dynamic>? _pendingShopData;
  LatLng _currentMapCenter = const LatLng(35.6611, 139.6685);

  // PC: 700px以上
  bool get _isDesktop => MediaQuery.of(context).size.width >= 700;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadShops({String? query, String? genre}) async {
    try {
      final shops = await ApiService.getShops(
          query: query, genre: genre == 'すべて' ? null : genre);
      setState(() {
        _shops = shops;
        _visibleShops = shops;
        _createMarkers();
      });
      _updateVisibleShops();
    } catch (e) {
      debugPrint("ショップ読み込みエラー: $e");
    }
  }

  Future<void> _updateVisibleShops() async {
    try {
      final bounds = await _mapController.getVisibleRegion();
      if (!mounted) return;
      setState(() {
        _visibleShops = _shops.where((shop) {
          if (shop.latitude == 0 && shop.longitude == 0) return false;
          return bounds.contains(LatLng(shop.latitude, shop.longitude));
        }).toList();
      });
    } catch (_) {}
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
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(shop.latitude, shop.longitude), 16),
    );
  }

  void _openAddShopForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddShopSheet(
        onSubmit: (shopData) async {
          Navigator.pop(ctx);
          LatLng pinPosition = _currentMapCenter;
          final address = (shopData['address'] as String? ?? '').trim();
          if (address.isNotEmpty) {
            try {
              final coords = await ApiService.geocode(address);
              if (coords != null) {
                pinPosition =
                    LatLng(coords['latitude']!, coords['longitude']!);
              }
            } catch (_) {}
          }
          setState(() {
            _pendingShopData = shopData;
            _isAddingShop = true;
            _newShopPinPosition = pinPosition;
            _createMarkers();
          });
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(pinPosition, 17),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('古着屋を追加しました！')));
      setState(() {
        _isAddingShop = false;
        _newShopPinPosition = null;
        _pendingShopData = null;
      });
      await _loadShops(query: _searchController.text, genre: _selectedGenre);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('追加に失敗しました')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ピン位置を保存しました')));
      setState(() {
        _adjustingShop = null;
        _adjustedPosition = null;
      });
      await _loadShops(query: _searchController.text, genre: _selectedGenre);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
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
      case 'ミリタリー':  return const Color(0xFF33691E);
      case 'ワーク':     return const Color(0xFF37474F);
      case 'スポーツ':   return const Color(0xFF01579B);
      case 'Y2K':       return const Color(0xFFD81B60);
      case 'アウトドア':  return const Color(0xFF2E7D32);
      default:          return const Color(0xFF5D4037);
    }
  }

  // ================================================
  //  ショップ情報ポップアップ（コンパクト版）
  // ================================================
  void _showShopInfo(FurugiyaShop shop) {
    final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
    final color = _genreColor(genre);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.storefront, color: color, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                          Row(children: [
                            if (genre.isNotEmpty)
                              Text(genre,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w500)),
                            if (shop.nearestStation.isNotEmpty) ...[
                              if (genre.isNotEmpty)
                                const Text('  ·  ',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              Icon(Icons.train,
                                  size: 11, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(shop.nearestStation,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    if (shop.rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(shop.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                if (shop.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.place, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(shop.address,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ShopDetailScreen(shop: shop),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.brown.shade300),
                        ),
                        child: const Text('詳細を見る',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.directions, size: 15),
                        label: const Text('ここに行く',
                            style: TextStyle(fontSize: 13)),
                        onPressed: () => _openGoogleMaps(shop),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        side: const BorderSide(color: Colors.orange),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _enterAdjustMode(shop);
                      },
                      child: const Icon(Icons.edit_location_alt,
                          color: Colors.orange, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================
  //  デスクトップ：下部横スクロールストリップ
  // ================================================
  Widget _buildDesktopBottomStrip() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.storefront, size: 15,
                      color: Color(0xFF5D4037)),
                  const SizedBox(width: 6),
                  Text(
                    'このエリア ${_visibleShops.length}件',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
            // 横スクロールカード
            SizedBox(
              height: 115,
              child: _visibleShops.isEmpty
                ? const Center(
                    child: Text('このエリアに店舗はありません',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _visibleShops.length,
                    itemBuilder: (context, index) =>
                        _buildDesktopCard(_visibleShops[index]),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCard(FurugiyaShop shop) {
    final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
    final color = _genreColor(genre);
    return GestureDetector(
      onTap: () => _showShopInfo(shop),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10, top: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(shop.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (genre.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(genre,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            Row(
              children: [
                if (shop.nearestStation.isNotEmpty) ...[
                  Icon(Icons.train, size: 11, color: Colors.grey[400]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(shop.nearestStation,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis),
                  ),
                ] else
                  const Spacer(),
                if (shop.rating > 0) ...[
                  const Icon(Icons.star, size: 11, color: Colors.orange),
                  Text(shop.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  //  モバイル：下から引き出せるボトムシート
  // ================================================
  Widget _buildMobileBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.13,
      minChildSize: 0.07,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.07, 0.13, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            children: [
              // ドラッグハンドル
              GestureDetector(
                onTap: () {
                  final current = _sheetController.size;
                  final next = current < 0.3 ? 0.55 : 0.07;
                  _sheetController.animateTo(
                    next,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront,
                              size: 14, color: Color(0xFF5D4037)),
                          const SizedBox(width: 5),
                          Text(
                            'このエリア ${_visibleShops.length}件',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _sheetController.isAttached &&
                                    _sheetController.size > 0.3
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // 店舗リスト
              Expanded(
                child: _visibleShops.isEmpty
                  ? const Center(
                      child: Text('このエリアに店舗はありません',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _visibleShops.length,
                      itemBuilder: (context, index) =>
                          _buildMobileListTile(_visibleShops[index]),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileListTile(FurugiyaShop shop) {
    final genre = shop.genres.isNotEmpty ? shop.genres.first : '';
    final color = _genreColor(genre);
    return InkWell(
      onTap: () => _showShopInfo(shop),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.storefront, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (genre.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(genre,
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600)),
                        ),
                      if (shop.nearestStation.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.train, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(shop.nearestStation,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (shop.rating > 0) ...[
              const SizedBox(width: 8),
              Column(
                children: [
                  const Icon(Icons.star, size: 13, color: Colors.orange),
                  Text(shop.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(FurugiyaShop shop) async {
    final googleMapsUrl = shop.mapUrl.isNotEmpty
        ? shop.mapUrl
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${shop.name} ${shop.address}")}';
    final uri = Uri.parse(googleMapsUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Googleマップを開けませんでした');
      }
    } catch (e) {
      debugPrint('エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool inEditMode = _adjustingShop != null || _isAddingShop;
    final bool isDesktop = _isDesktop;
    // デスクトップ: ストリップ分だけFABを上に逃がす
    final double fabBottomPadding = isDesktop ? 152.0 : 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Googleマップ（全画面）
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _currentMapCenter = position.target,
            onCameraIdle: _updateVisibleShops,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // 2. 検索・ジャンルUI（編集モード中は非表示）
          if (!inEditMode)
            SafeArea(
              child: Column(
                // min にすることで透明な余白からタッチが漏れるのを防ぐ
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 検索バー：白背景Containerがタッチを吸収
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '店名・住所・駅名で検索...',
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.brown),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadShops(genre: _selectedGenre);
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onSubmitted: (value) {
                          _loadShops(
                              query: value, genre: _selectedGenre);
                        },
                      ),
                    ),
                  ),
                  // ジャンルチップ：Containerに色を持たせてチップ間の隙間からタッチが漏れるのを防ぐ
                  Container(
                    height: 44,
                    // 不透明度1%の白でタッチを吸収しつつ見た目は変えない
                    color: const Color(0x03FFFFFF),
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
                            label: Text(genre,
                                style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            selectedColor: Colors.brown,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.9),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedGenre = genre);
                              _loadShops(
                                  query: _searchController.text,
                                  genre: genre);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 3. 店舗パネル（デスクトップ: 下部ストリップ / モバイル: ボトムシート）
          if (!inEditMode) ...[
            if (isDesktop)
              _buildDesktopBottomStrip()
            else
              _buildMobileBottomSheet(),
          ],

          // 4. FAB（ScaffoldでなくStackに配置して位置を制御）
          if (!inEditMode)
            Positioned(
              right: 16,
              bottom: fabBottomPadding,
              child: FloatingActionButton.extended(
                onPressed: _openAddShopForm,
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.add_location_alt, color: Colors.white),
                label: const Text('古着屋を追加',
                    style: TextStyle(color: Colors.white)),
              ),
            ),

          // 5a. 新規ショップ追加モードのUI
          if (_isAddingShop)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_location_alt,
                            color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_pendingShopData?['name'] ?? '新しい古着屋'}\nピンをドラッグして正確な位置に移動してください',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
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
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
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
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
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

          // 5b. ピン位置調整モードのUI
          if (_adjustingShop != null)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_with, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_adjustingShop!.name}\nピンをドラッグして正しい位置に移動してください',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
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
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _cancelAdjust,
                            child: const Text('キャンセル'),
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
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('この位置に保存'),
                            onPressed:
                                _isSaving ? null : _saveAdjustedPosition,
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
