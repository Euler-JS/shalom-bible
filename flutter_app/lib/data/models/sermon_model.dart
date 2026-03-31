class SermonPoint {
  final String title;
  final String development;
  final List<String> supportingVerses;

  const SermonPoint({
    required this.title,
    required this.development,
    required this.supportingVerses,
  });

  factory SermonPoint.fromJson(Map<String, dynamic> json) {
    return SermonPoint(
      title: json['title']?.toString() ?? '',
      development: json['development']?.toString() ?? '',
      supportingVerses:
          (json['supportingVerses'] as List<dynamic>?)
              ?.map((v) => v.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'development': development,
    'supportingVerses': supportingVerses,
  };
}

class SermonContent {
  final String introduction;
  final List<SermonPoint> points;
  final List<String> illustrations;
  final String conclusion;
  final String closingPrayer;
  final String title;
  final String basePassage;

  const SermonContent({
    required this.introduction,
    required this.points,
    required this.illustrations,
    required this.conclusion,
    required this.closingPrayer,
    this.title = '',
    this.basePassage = '',
  });

  factory SermonContent.fromJson(Map<String, dynamic> json) {
    return SermonContent(
      introduction: json['introduction']?.toString() ?? '',
      points:
          (json['points'] as List<dynamic>?)
              ?.map((p) => SermonPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      illustrations:
          (json['illustrations'] as List<dynamic>?)
              ?.map((i) => i.toString())
              .toList() ??
          [],
      conclusion: json['conclusion']?.toString() ?? '',
      closingPrayer: json['closingPrayer']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      basePassage: json['basePassage']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'introduction': introduction,
    'points': points.map((p) => p.toJson()).toList(),
    'illustrations': illustrations,
    'conclusion': conclusion,
    'closingPrayer': closingPrayer,
    'title': title,
    'basePassage': basePassage,
  };

  String toPlainText(String title, String basePassage) {
    final buf = StringBuffer();
    buf.writeln('=== $title ===');
    buf.writeln('Texto base: $basePassage\n');
    buf.writeln('INTRODUÇÃO\n$introduction\n');
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      buf.writeln('PONTO ${i + 1}: ${p.title}');
      buf.writeln(p.development);
      if (p.supportingVerses.isNotEmpty) {
        buf.writeln('Versículos: ${p.supportingVerses.join(', ')}');
      }
      buf.writeln();
    }
    if (illustrations.isNotEmpty) {
      buf.writeln('ILUSTRAÇÕES');
      for (int i = 0; i < illustrations.length; i++) {
        buf.writeln('${i + 1}. ${illustrations[i]}');
      }
      buf.writeln();
    }
    buf.writeln('CONCLUSÃO\n$conclusion\n');
    buf.writeln('ORAÇÃO DE ENCERRAMENTO\n$closingPrayer');
    return buf.toString();
  }
}

class SermonModel {
  final String? id;
  final String title;
  final String basePassage;
  final String language;
  final String inputPrompt;
  final SermonContent content;
  final DateTime? createdAt;

  const SermonModel({
    this.id,
    required this.title,
    required this.basePassage,
    required this.language,
    required this.inputPrompt,
    required this.content,
    this.createdAt,
  });

  factory SermonModel.fromJson(Map<String, dynamic> json) {
    return SermonModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      basePassage: json['basePassage']?.toString() ?? '',
      language: json['language']?.toString() ?? 'pt',
      inputPrompt: json['inputPrompt']?.toString() ?? '',
      content: SermonContent.fromJson(
        json['content'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'title': title,
    'basePassage': basePassage,
    'language': language,
    'inputPrompt': inputPrompt,
    'content': content.toJson(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
