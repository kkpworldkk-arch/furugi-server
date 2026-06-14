class FurugiyaShop {
  final int id;
  final String name;
  final List<String> genres;
  final double rating;
  final int reviewCount;
  final String address;
  final String nearestStation;
  final double latitude;
  final double longitude;
  final String plusCode; // ★追加：Plus Codeを保持するプロパティ
  final String homepageUrl;
  final String snsUrl;
  final String hours;
  final String holiday;
  final String description;
  final String priceRange;
  final String placeId;
  final String mapUrl;
  final String paymentMethods;
  final List<String> imageUrls;
  final String parking;

  FurugiyaShop({
    required this.id,
    required this.name,
    required this.genres,
    required this.rating,
    required this.reviewCount,
    required this.address,
    required this.nearestStation,
    required this.latitude,
    required this.longitude,
    required this.plusCode,
    required this.homepageUrl,
    required this.snsUrl,
    required this.hours,
    required this.holiday,
    required this.description,
    required this.priceRange,
    required this.placeId,
    required this.mapUrl,
    required this.paymentMethods,
    required this.imageUrls,
    required this.parking,
  });

  factory FurugiyaShop.fromJson(Map<String, dynamic> json) {
    return FurugiyaShop(
      id: json['id'] ?? 0,
      name: json['name'] ?? '名称不明',
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      address: json['address'] ?? '',
      nearestStation: json['nearestStation'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      plusCode: json['plusCode'] ?? '',
      homepageUrl: json['homepageUrl'] ?? '',
      snsUrl: json['snsUrl'] ?? '',
      hours: json['hours'] ?? '',
      holiday: json['holiday'] ?? 'なし',
      description: json['description'] ?? '',
      priceRange: json['priceRange'] ?? '不明',
      placeId: json['placeId'] ?? '',
      mapUrl: json['mapUrl'] ?? '',
      paymentMethods: json['paymentMethods'] ?? '不明',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      parking: json['parking'] ?? '',
    );
  }

  FurugiyaShop copyWith({
    int? id,
    String? name,
    List<String>? genres,
    double? rating,
    int? reviewCount,
    String? address,
    String? nearestStation,
    double? latitude,
    double? longitude,
    String? plusCode,
    String? homepageUrl,
    String? snsUrl,
    String? hours,
    String? holiday,
    String? description,
    String? priceRange,
    String? placeId,
    String? mapUrl,
    String? paymentMethods,
    List<String>? imageUrls,
    String? parking,
  }) {
    return FurugiyaShop(
      id: id ?? this.id,
      name: name ?? this.name,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      address: address ?? this.address,
      nearestStation: nearestStation ?? this.nearestStation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      plusCode: plusCode ?? this.plusCode,
      homepageUrl: homepageUrl ?? this.homepageUrl,
      snsUrl: snsUrl ?? this.snsUrl,
      hours: hours ?? this.hours,
      holiday: holiday ?? this.holiday,
      description: description ?? this.description,
      priceRange: priceRange ?? this.priceRange,
      placeId: placeId ?? this.placeId,
      mapUrl: mapUrl ?? this.mapUrl,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      imageUrls: imageUrls ?? this.imageUrls,
      parking: parking ?? this.parking,
    );
  }
}

class ShopReview {
  final int id;
  final String nickname;
  final double rating;
  final String comment;
  final String date;

  ShopReview({
    required this.id,
    required this.nickname,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory ShopReview.fromJson(Map<String, dynamic> json) {
    return ShopReview(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? '匿名',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class ShopNotice {
  final int id;
  final String title;
  final String content;
  final String date;

  ShopNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  factory ShopNotice.fromJson(Map<String, dynamic> json) {
    return ShopNotice(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class ShopMedia {
  final int id;
  final String title;
  final String source;
  final String url;
  final String date;
  final String description;

  ShopMedia({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.date,
    required this.description,
  });

  factory ShopMedia.fromJson(Map<String, dynamic> json) {
    return ShopMedia(
      id:          json['id'] ?? 0,
      title:       json['title'] ?? '',
      source:      json['source'] ?? '',
      url:         json['url'] ?? '',
      date:        json['date'] ?? '',
      description: json['description'] ?? '',
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