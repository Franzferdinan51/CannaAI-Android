class StrainData {
  final String id;
  final String name;
  final String category;
  final double thcLevel;
  final double cbdLevel;
  final int floweringTime;
  final String difficulty;
  final String yield;
  final String description;
  final List<String> effects;
  final List<String> medical;
  final List<String> flavors;
  final bool isFavorite;

  StrainData({
    required this.id,
    required this.name,
    required this.category,
    required this.thcLevel,
    required this.cbdLevel,
    required this.floweringTime,
    required this.difficulty,
    required this.yield,
    required this.description,
    required this.effects,
    required this.medical,
    required this.flavors,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'thcLevel': thcLevel,
      'cbdLevel': cbdLevel,
      'floweringTime': floweringTime,
      'difficulty': difficulty,
      'yield': yield,
      'description': description,
      'effects': effects,
      'medical': medical,
      'flavors': flavors,
      'isFavorite': isFavorite,
    };
  }

  factory StrainData.fromJson(Map<String, dynamic> json) {
    return StrainData(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      thcLevel: json['thcLevel'].toDouble(),
      cbdLevel: json['cbdLevel'].toDouble(),
      floweringTime: json['floweringTime'],
      difficulty: json['difficulty'],
      yield: json['yield'],
      description: json['description'],
      effects: List<String>.from(json['effects']),
      medical: List<String>.from(json['medical']),
      flavors: List<String>.from(json['flavors']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}