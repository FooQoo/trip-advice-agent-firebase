class SuggestedPlan {
  final String name;
  final String theme;
  final String area;
  final String description;
  final List<String> caution;
  final List<Schedule> schedule;

  SuggestedPlan({
    required this.name,
    required this.theme,
    required this.area,
    required this.description,
    required this.caution,
    required this.schedule,
  });

  factory SuggestedPlan.fromJson(Map<String, dynamic> json) {
    return SuggestedPlan(
      name: json['name'] as String,
      theme: json['theme'] as String,
      area: json['area'] as String,
      description: json['description'] as String,
      caution: (json['caution'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      schedule: (json['schedule'] as List<dynamic>)
          .map((e) =>
              Schedule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'theme': theme,
      'area': area,
      'description': description,
      'caution': caution,
      'schedule': schedule.map((s) => s.toJson()).toList(),
    };
  }
}

/// スケジュール（プラン内の日ごとの予定）を表すクラス
class Schedule {
  final String date;
  final String name;
  final String description;
  final List<DayFlow> dayFlow;
  final int dayBudget;
  final String area;
  final List<Spot> spot;

  Schedule({
    required this.date,
    required this.name,
    required this.description,
    required this.dayFlow,
    required this.dayBudget,
    required this.area,
    required this.spot,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      date: json['date'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      dayFlow: (json['dayFlow'] as List<dynamic>)
          .map((e) => DayFlow.fromJson(e as Map<String, dynamic>))
          .toList(),
      dayBudget: (json['dayBudget'] as num).toInt(),
      area: json['area'] as String,
      spot: (json['spot'] as List<dynamic>)
          .map((e) => Spot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'name': name,
      'description': description,
      'area': area,
      'spot': spot.map((s) => s.toJson()).toList(),
    };
  }
}

class DayFlow {
  final String startTime;
  final String label;
  final String? spotImageUrl;

  DayFlow({
    required this.startTime,
    required this.label,
    required this.spotImageUrl,
  });

  factory DayFlow.fromJson(Map<String, dynamic> json) {
    print(json);
    return DayFlow(
      startTime: json['startTime'] as String,
      label: json['label'] as String,
      spotImageUrl: json['spotImageUrl'] as String?,
    );
  }
}

/// スケジュール内のスポット（観光地など）を表すクラス
class Spot {
  final String name;
  final String activity;
  final String reason;
  final double? rating;
  final int? ratingCount;
  final List<Review> review;
  final List<String?> businessHours;
  final int duration;
  final int? minPrice;
  final int? maxPrice;
  final String? websiteUrl;
  final String? photoUri;

  Spot({
    required this.name,
    required this.activity,
    required this.reason,
    this.rating,
    this.ratingCount,
    required this.review,
    required this.businessHours,
    required this.duration,
    this.minPrice,
    this.maxPrice,
    this.websiteUrl,
    this.photoUri,
  });

  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      name: json['name'] as String,
      activity: json['activity'] as String,
      reason: json['reason'] as String,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      ratingCount: json['ratingCount'] != null
          ? (json['ratingCount'] as num).toInt()
          : null,
      // review: Review.fromJson(json['review'] as Map<String, dynamic>),
      review: (json['review'] as List<dynamic>)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      businessHours: (json['businessHours'] as List<dynamic>)
          .map((e) => e as String?)
          .toList(),
      duration: (json['duration'] as num).toInt(),
      minPrice: json['minPrice'] != null
          ? (json['minPrice'] as num).toInt()
          : null,
      maxPrice: json['maxPrice'] != null
          ? (json['maxPrice'] as num).toInt()
          : null,
      websiteUrl: json['websiteUrl'] as String?,
      photoUri: json['photoUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'activity': activity,
      'reason': reason,
      'rating': rating,
      'ratingCount': ratingCount,
      'review': review.map((r) => r.toJson()).toList(),
      'businessHours': businessHours,
      'duration': duration,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'websiteUrl': websiteUrl,
      'photoUri': photoUri,
    };
  }
}

/// スポット内のレビューを表すクラス
class Review {
  final double rating;
  final String? text;

  Review({
    required this.rating,
    this.text,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      rating: (json['rating'] as num).toDouble(),
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'text': text,
    };
  }
}
