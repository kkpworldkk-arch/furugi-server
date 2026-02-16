import 'dart:convert';
import 'package:http/http.dart' as http;
import 'furugiya_model.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  // 修正：引数 {String? query, String? genre} を追加
  static Future<List<FurugiyaShop>> getShops({String? query, String? genre}) async {
    return fetchShops(query: query, genre: genre);
  }

  // 修正：条件に合わせてURLを動的に作成
  static Future<List<FurugiyaShop>> fetchShops({String? query, String? genre}) async {
    String url = '$baseUrl/shops?';
    
    // キーワードがあれば追加
    if (query != null && query.isNotEmpty) {
      url += 'q=${Uri.encodeComponent(query)}&';
    }
    // ジャンルがあれば追加
    if (genre != null && genre.isNotEmpty) {
      url += 'genre=${Uri.encodeComponent(genre)}';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // 日本語の文字化けを防ぐために utf8.decode を使用
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => FurugiyaShop.fromJson(item)).toList();
    } else {
      throw Exception('店舗データの読み込みに失敗しました');
    }
  }

  // --- 以降、既存のメソッドはそのまま保持 ---

  // 店舗追加
  static Future<void> addShop(Map<String, dynamic> shopData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shops'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(shopData),
    );
    if (response.statusCode != 201) {
      throw Exception('店舗の追加に失敗しました');
    }
  }

  // 記事リスト取得
  static Future<List<FurugiyaArticle>> fetchArticles() async {
    final response = await http.get(Uri.parse('$baseUrl/articles'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => FurugiyaArticle.fromJson(item)).toList();
    } else {
      throw Exception('記事データの読み込みに失敗しました');
    }
  }

  // 記事投稿
  static Future<void> postArticle(Map<String, dynamic> articleData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/articles'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(articleData),
    );
    if (response.statusCode != 201) {
      throw Exception('記事の投稿に失敗しました');
    }
  }

  // レビュー投稿（ダミー）
  static Future<void> postReview(int shopId, double rating, String comment) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}