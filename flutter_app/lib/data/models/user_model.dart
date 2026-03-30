class UserModel {
  final String id;
  final String email;
  final String name;
  final String plan;
  final String language;
  final int scenarioSearchUsed;
  final int sermonGeneratorUsed;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.plan,
    required this.language,
    required this.scenarioSearchUsed,
    required this.sermonGeneratorUsed,
  });

  bool get isPremium => plan == 'premium';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final usage = json['usageThisWeek'] as Map<String, dynamic>? ?? {};
    final monthUsage = json['usageThisMonth'] as Map<String, dynamic>? ?? {};
    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      plan: json['plan'] ?? 'free',
      language: json['language'] ?? 'pt',
      scenarioSearchUsed: (usage['scenarioSearch'] as num?)?.toInt() ?? 0,
      sermonGeneratorUsed: (monthUsage['sermonGenerator'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'plan': plan,
        'language': language,
        'usageThisWeek': {'scenarioSearch': scenarioSearchUsed},
        'usageThisMonth': {'sermonGenerator': sermonGeneratorUsed},
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? plan,
    String? language,
    int? scenarioSearchUsed,
    int? sermonGeneratorUsed,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      plan: plan ?? this.plan,
      language: language ?? this.language,
      scenarioSearchUsed: scenarioSearchUsed ?? this.scenarioSearchUsed,
      sermonGeneratorUsed: sermonGeneratorUsed ?? this.sermonGeneratorUsed,
    );
  }
}
