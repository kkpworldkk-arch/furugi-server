import 'package:flutter/material.dart';
import 'furugiya_model.dart';
import 'shop_detail_screen.dart'; // ★詳細画面をインポート

class ShopSearchScreen extends StatefulWidget {
  final List<FurugiyaShop> shops;

  const ShopSearchScreen({super.key, required this.shops});

  @override
  State<ShopSearchScreen> createState() => _ShopSearchScreenState();
}

class _ShopSearchScreenState extends State<ShopSearchScreen> {
  // 検索ボックスの文字を管理するコントローラー
  final TextEditingController _searchController = TextEditingController();
  
  // フィルタリング後の店舗リスト
  List<FurugiyaShop> _filteredShops = [];
  bool _onlyOpenNow = false;

  @override
  void initState() {
    super.initState();
    _filteredShops = widget.shops; // 最初は全店舗を表示
  }

  // Googleマップ風の柔軟な検索ロジック
  void _runFilter() {
    final query = _searchController.text.trim(); // 入力された文字（空白削除）

    setState(() {
      _filteredShops = widget.shops.where((shop) {
        // 1. テキスト検索（店名、住所、ジャンル、説明文のどれかにヒットすればOK）
        bool matchText = false;
        if (query.isEmpty) {
          matchText = true; // 何も入力してないときは全員OK
        } else {
          // 検索対象のデータを1つの文字列にまとめる
          final searchTarget = "${shop.name} ${shop.address} ${shop.genres.join(' ')} ${shop.description}";
          
          if (searchTarget.contains(query)) {
            matchText = true;
          }
        }

        // 2. 営業中フィルター
        bool matchOpen = true;
        if (_onlyOpenNow) {
          matchOpen = _isOpen(shop.hours);
        }

        // 両方の条件を満たす場合のみ表示
        return matchText && matchOpen;
      }).toList();
    });
  }

  // 営業時間判定
  bool _isOpen(String hours) {
    try {
      final now = DateTime.now();
      final parts = hours.split(' - ');
      if (parts.length != 2) return false;
      final start = int.parse(parts[0].split(':')[0]);
      final end = int.parse(parts[1].split(':')[0]);
      return now.hour >= start && now.hour < end;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('店舗を探す'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ▼▼▼ 1行目: Googleマップ風検索バー ▼▼▼
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(), // 文字を打つたびに検索実行
              decoration: InputDecoration(
                hintText: "エリア、ジャンル、店名で検索",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _runFilter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), // 丸くする
                  borderSide: BorderSide.none, // 枠線を消す
                ),
              ),
            ),
          ),

          // ▼▼▼ 2行目: 営業中ボタン (左寄せ) ▼▼▼
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text("現在営業中のみ"),
                  selected: _onlyOpenNow,
                  onSelected: (val) {
                    setState(() {
                      _onlyOpenNow = val;
                      _runFilter();
                    });
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.brown.shade100,
                  checkmarkColor: Colors.brown,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ▼▼▼ 3行目以降: リスト表示 ▼▼▼
          Expanded(
            child: _filteredShops.isEmpty
                ? const Center(child: Text("条件に合うお店が見つかりませんでした"))
                : ListView.builder(
                    itemCount: _filteredShops.length,
                    itemBuilder: (context, index) {
                      final shop = _filteredShops[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.store, size: 32, color: Colors.brown),
                          title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shop.address, style: const TextStyle(fontSize: 12)),
                              Text(shop.genres.join(" / "), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          // ▼▼▼ ここを修正しました！詳細画面へ移動します ▼▼▼
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShopDetailScreen(shop: shop),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}