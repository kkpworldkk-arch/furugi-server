import 'dart:convert';
import 'package:http/http.dart' as http;
import 'furugiya_model.dart';

class ApiService {
  static const String baseUrl = 'https://web-production-632bbc.up.railway.app/api';

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

  // 店舗削除
  static Future<void> deleteShop(int shopId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/shops/$shopId'),
    );
    if (response.statusCode != 200) {
      throw Exception('削除に失敗しました');
    }
  }

  // 店舗情報更新
  static Future<void> updateShop(int shopId, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/shops/$shopId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('更新に失敗しました');
    }
  }

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

  // 住所→座標変換
  static Future<Map<String, double>?> geocode(String address) async {
    final response = await http.get(
      Uri.parse('$baseUrl/geocode?address=${Uri.encodeComponent(address)}'),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'latitude': (body['latitude'] as num).toDouble(),
        'longitude': (body['longitude'] as num).toDouble(),
      };
    }
    return null;
  }

  // レビュー一覧取得
  static Future<List<ShopReview>> getReviews(int shopId) async {
    final response = await http.get(Uri.parse('$baseUrl/shops/$shopId/reviews'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => ShopReview.fromJson(item)).toList();
    } else {
      throw Exception('口コミの読み込みに失敗しました');
    }
  }

  // レビュー投稿
  static Future<Map<String, dynamic>> postReview(
      int shopId, String nickname, double rating, String comment) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shops/$shopId/reviews'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"nickname": nickname, "rating": rating, "comment": comment}),
    );
    if (response.statusCode != 201) {
      throw Exception('口コミの投稿に失敗しました');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // お知らせ取得
  static Future<List<ShopNotice>> getNotices(int shopId) async {
    final response = await http.get(Uri.parse('$baseUrl/shops/$shopId/notices'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => ShopNotice.fromJson(item)).toList();
    } else {
      throw Exception('お知らせの読み込みに失敗しました');
    }
  }

  // メディア掲載一覧取得
  static Future<List<ShopMedia>> getMedia(int shopId) async {
    final response = await http.get(Uri.parse('$baseUrl/shops/$shopId/media'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => ShopMedia.fromJson(item)).toList();
    } else {
      throw Exception('メディア情報の読み込みに失敗しました');
    }
  }

  // メディア掲載追加
  static Future<void> addMedia(int shopId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shops/$shopId/media'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('メディア情報の追加に失敗しました');
    }
  }
}