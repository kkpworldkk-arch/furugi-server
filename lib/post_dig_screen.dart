import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostDigScreen extends StatefulWidget {
  const PostDigScreen({super.key});

  @override
  State<PostDigScreen> createState() => _PostDigScreenState();
}

class _PostDigScreenState extends State<PostDigScreen> {
  File? _image;
  final _picker = ImagePicker();
  final _itemNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<dynamic> _shops = [];
  String? _selectedShopId;
  bool _isUploading = false;

  // FlaskサーバーのURL
  final String baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchShops(); // 投稿時に選択する店舗リストを取得
  }

  // 店舗リストの取得
  Future<void> _fetchShops() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/api/shops"));
      if (response.statusCode == 200) {
        setState(() {
          _shops = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      debugPrint("店舗取得エラー: $e");
    }
  }

  // 写真を撮る/選ぶ
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  // サーバーへ投稿
  Future<void> _submitPost() async {
    if (_image == null || _selectedShopId == null || _itemNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("写真、店名、商品名は必須です")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/api/posts"));
      request.fields['itemName'] = _itemNameController.text;
      request.fields['price'] = _priceController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['shopId'] = _selectedShopId!;
      
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

      var response = await request.send();

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context); // 成功したら画面を閉じる
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ナイスディグ！投稿しました")));
      } else {
        throw Exception("投稿失敗");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ディグを投稿', style: TextStyle(color: Colors.brown)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (_isUploading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else
            TextButton(onPressed: _submitPost, child: const Text('投稿', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 画像選択エリア
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                child: _image != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_image!, fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text("タップして写真を追加")]),
              ),
            ),
            const SizedBox(height: 20),
            // 店舗選択ドロップダウン
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "購入した店舗", border: OutlineInputBorder()),
              initialValue: _selectedShopId,
              items: _shops.map((shop) {
                return DropdownMenuItem<String>(value: shop['id'].toString(), child: Text(shop['name']));
              }).toList(),
              onChanged: (val) => setState(() => _selectedShopId = val),
            ),
            const SizedBox(height: 16),
            TextField(controller: _itemNameController, decoration: const InputDecoration(labelText: "商品名 (例: '90s チャンピオン リバースウィーブ)", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "価格 (例: 12000)", prefixText: "¥ ", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: "感想・メモ", border: OutlineInputBorder())),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('カメラで撮影'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('ライブラリから選択'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }
}