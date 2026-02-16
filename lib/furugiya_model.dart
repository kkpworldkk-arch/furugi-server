class FurugiyaShop {
  final int id;
  final String name;
  final List<String> genres;
  final double rating;
  final int reviewCount;
  final String address;
  final double latitude;
  final double longitude;
  final String plusCode; // ★追加：Plus Codeを保持するプロパティ
  final String homepageUrl;
  final String snsUrl;
  final String hours;
  final String holiday;
  final String description;
  final String priceRange;
  final List<String> imageUrls;

  FurugiyaShop({
    required this.id,
    required this.name,
    required this.genres,
    required this.rating,
    required this.reviewCount,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.plusCode, // ★追加
    required this.homepageUrl,
    required this.snsUrl,
    required this.hours,
    required this.holiday,
    required this.description,
    required this.priceRange,
    required this.imageUrls,
  });

  factory FurugiyaShop.fromJson(Map<String, dynamic> json) {
    return FurugiyaShop(
      id: json['id'] ?? 0,
      name: json['name'] ?? '名称不明',
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      plusCode: json['plusCode'] ?? '', // ★追加：JSONのキー名はキャメルケースを想定
      homepageUrl: json['homepageUrl'] ?? '',
      snsUrl: json['snsUrl'] ?? '',
      hours: json['hours'] ?? '',
      holiday: json['holiday'] ?? 'なし',
      description: json['description'] ?? '',
      priceRange: json['priceRange'] ?? '不明',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class FurugiyaArticle {
  final int id;
  final String title;
  final String content;
  final String genre;
  final String date;

  FurugiyaArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.genre,
    required this.date,
  });

  factory FurugiyaArticle.fromJson(Map<String, dynamic> json) {
    return FurugiyaArticle(
      id: json['id'] ?? 0,
      title: json['title'] ?? '無題',
      content: json['content'] ?? '',
      genre: json['genre'] ?? '未分類',
      date: json['date'] ?? '',
    );
  }
}