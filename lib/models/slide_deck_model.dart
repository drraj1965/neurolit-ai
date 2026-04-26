import 'dart:convert';

class SlideItem {
  final String title;
  final List<String> points;
  final String section;

  const SlideItem({
    required this.title,
    required this.points,
    this.section = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'points': points,
        'section': section,
      };

  factory SlideItem.fromJson(Map<String, dynamic> json) {
    return SlideItem(
      title: json['title']?.toString() ?? '',
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      section: json['section']?.toString() ?? '',
    );
  }
}

class SlideDeckModel {
  final String topic;
  final List<SlideItem> slides;

  const SlideDeckModel({
    required this.topic,
    required this.slides,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'slides': slides.map((e) => e.toJson()).toList(),
      };

  factory SlideDeckModel.fromJson(Map<String, dynamic> json) {
    return SlideDeckModel(
      topic: json['topic']?.toString() ?? '',
      slides: (json['slides'] as List<dynamic>? ?? [])
          .map((e) => SlideItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}