// Simplified plant lifecycle models without JSON serialization

enum GrowthStage {
  germination,
  seedling,
  vegetative,
  flowering,
  harvest,
  curing,
  completed,
}

enum PlantHealth {
  excellent,
  good,
  fair,
  poor,
  critical,
}

enum PlantStatus {
  active,
  archived,
  harvested,
  lost,
}

class PlantLifecycle {
  final String id;
  final String userId;
  final String roomId;
  final String strainId;
  final String plantName;
  final String? plantPhoto;
  final DateTime plantedDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final GrowthStage currentStage;
  final PlantHealth healthStatus;
  final PlantStatus status;
  final List<GrowthPhaseRecord> phaseHistory;
  final List<PlantHealthRecord> healthHistory;
  final List<PlantMeasurement> measurements;
  final Map<String, dynamic> environmentalPreferences;
  final Map<String, dynamic> customNotes;
  final List<String> imageGallery;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlantLifecycle({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.strainId,
    required this.plantName,
    this.plantPhoto,
    required this.plantedDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    required this.currentStage,
    required this.healthStatus,
    this.status = PlantStatus.active,
    this.phaseHistory = const [],
    this.healthHistory = const [],
    this.measurements = const [],
    this.environmentalPreferences = const {},
    this.customNotes = const {},
    this.imageGallery = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  PlantLifecycle copyWith({
    String? id,
    String? userId,
    String? roomId,
    String? strainId,
    String? plantName,
    String? plantPhoto,
    DateTime? plantedDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    GrowthStage? currentStage,
    PlantHealth? healthStatus,
    PlantStatus? status,
    List<GrowthPhaseRecord>? phaseHistory,
    List<PlantHealthRecord>? healthHistory,
    List<PlantMeasurement>? measurements,
    Map<String, dynamic>? environmentalPreferences,
    Map<String, dynamic>? customNotes,
    List<String>? imageGallery,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlantLifecycle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      strainId: strainId ?? this.strainId,
      plantName: plantName ?? this.plantName,
      plantPhoto: plantPhoto ?? this.plantPhoto,
      plantedDate: plantedDate ?? this.plantedDate,
      expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
      actualHarvestDate: actualHarvestDate ?? this.actualHarvestDate,
      currentStage: currentStage ?? this.currentStage,
      healthStatus: healthStatus ?? this.healthStatus,
      status: status ?? this.status,
      phaseHistory: phaseHistory ?? this.phaseHistory,
      healthHistory: healthHistory ?? this.healthHistory,
      measurements: measurements ?? this.measurements,
      environmentalPreferences: environmentalPreferences ?? this.environmentalPreferences,
      customNotes: customNotes ?? this.customNotes,
      imageGallery: imageGallery ?? this.imageGallery,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate current age in days
  int get ageInDays {
    final now = DateTime.now();
    return now.difference(plantedDate).inDays;
  }

  /// Calculate progress percentage based on growth stage
  double get growthProgress {
    switch (currentStage) {
      case GrowthStage.germination:
        return (ageInDays / 7).clamp(0.0, 1.0) * 0.05; // 5% of total growth
      case GrowthStage.seedling:
        return 0.05 + (ageInDays / 14).clamp(0.0, 1.0) * 0.10; // 10% of total growth
      case GrowthStage.vegetative:
        return 0.15 + (ageInDays / 56).clamp(0.0, 1.0) * 0.45; // 45% of total growth
      case GrowthStage.flowering:
        return 0.60 + (ageInDays / 63).clamp(0.0, 1.0) * 0.35; // 35% of total growth
      case GrowthStage.harvest:
        return 0.95;
      case GrowthStage.curing:
        return 0.98;
      case GrowthStage.completed:
        return 1.0;
    }
  }

  /// Get days until expected harvest
  int? get daysUntilHarvest {
    if (expectedHarvestDate == null) return null;
    final now = DateTime.now();
    return expectedHarvestDate!.difference(now).inDays;
  }

  /// Check if plant needs attention based on health and stage
  bool get needsAttention {
    return healthStatus.index <= PlantHealth.fair.index;
  }

  @override
  String toString() {
    return 'PlantLifecycle(id: $id, plantName: $plantName, currentStage: $currentStage, healthStatus: $healthStatus, ageInDays: $ageInDays)';
  }
}

class GrowthPhaseRecord {
  final String id;
  final String plantId;
  final GrowthStage stage;
  final DateTime startDate;
  final DateTime? endDate;
  final Map<String, dynamic> environmentalConditions;
  final List<String> notes;
  final List<String> images;
  final Map<String, dynamic> metrics;
  final DateTime createdAt;

  GrowthPhaseRecord({
    required this.id,
    required this.plantId,
    required this.stage,
    required this.startDate,
    this.endDate,
    this.environmentalConditions = const {},
    this.notes = const [],
    this.images = const [],
    this.metrics = const {},
    required this.createdAt,
  });

  bool get isActive => endDate == null;

  int? get durationInDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }
}

class PlantHealthRecord {
  final String id;
  final String plantId;
  final PlantHealth healthStatus;
  final double healthScore; // 0.0 to 1.0
  final List<String> issues;
  final List<String> recommendations;
  final Map<String, dynamic> sensorData;
  final List<String> images;
  final String? analysisId; // Link to plant analysis if available
  final String notes;
  final DateTime recordedAt;
  final DateTime createdAt;

  PlantHealthRecord({
    required this.id,
    required this.plantId,
    required this.healthStatus,
    required this.healthScore,
    this.issues = const [],
    this.recommendations = const [],
    this.sensorData = const {},
    this.images = const [],
    this.analysisId,
    this.notes = '',
    required this.recordedAt,
    required this.createdAt,
  });

  bool get isImproving => healthScore >= 0.7;
  bool get needsImmediateAttention => healthScore <= 0.3;
}

class PlantMeasurement {
  final String id;
  final String plantId;
  final String measurementType; // 'height', 'width', 'leaf_count', 'node_count', etc.
  final double value;
  final String unit; // 'cm', 'inches', 'count', etc.
  final Map<String, dynamic>? environmentalContext;
  final String? notes;
  final List<String> images;
  final DateTime measuredAt;
  final DateTime createdAt;

  PlantMeasurement({
    required this.id,
    required this.plantId,
    required this.measurementType,
    required this.value,
    required this.unit,
    this.environmentalContext,
    this.notes,
    this.images = const [],
    required this.measuredAt,
    required this.createdAt,
  });

  /// Get formatted value with unit
  String get formattedValue {
    switch (measurementType) {
      case 'height':
      case 'width':
        return '${value.toStringAsFixed(1)} $unit';
      case 'leaf_count':
      case 'node_count':
        return '${value.toInt()} $unit';
      default:
        return '$value $unit';
    }
  }
}

class PlantTimelineEvent {
  final String id;
  final String plantId;
  final String eventType; // 'watering', 'feeding', 'training', 'pruning', 'pest_treatment', etc.
  final String title;
  final String description;
  final Map<String, dynamic>? details;
  final List<String> images;
  final DateTime eventDate;
  final DateTime createdAt;

  PlantTimelineEvent({
    required this.id,
    required this.plantId,
    required this.eventType,
    required this.title,
    required this.description,
    this.details,
    this.images = const [],
    required this.eventDate,
    required this.createdAt,
  });
}

/// Plant lifecycle templates for different strains
class GrowthTemplate {
  final String id;
  final String strainId;
  final String name;
  final Map<GrowthStage, int> stageDurations; // Duration in days
  final Map<String, dynamic> idealConditions;
  final Map<GrowthStage, List<String>> stageRecommendations;
  final Map<GrowthStage, List<String>> commonIssues;
  final bool isActive;
  final DateTime createdAt;

  GrowthTemplate({
    required this.id,
    required this.strainId,
    required this.name,
    required this.stageDurations,
    this.idealConditions = const {},
    this.stageRecommendations = const {},
    this.commonIssues = const {},
    this.isActive = true,
    required this.createdAt,
  });

  /// Calculate expected harvest date
  DateTime calculateExpectedHarvestDate(DateTime plantedDate) {
    int totalDays = stageDurations.values.fold(0, (sum, days) => sum + days);
    return plantedDate.add(Duration(days: totalDays));
  }

  /// Get expected date for specific stage
  DateTime? getExpectedStageDate(GrowthStage stage, DateTime plantedDate) {
    int daysToAdd = 0;
    for (final entry in stageDurations.entries) {
      if (entry.key == stage) {
        return plantedDate.add(Duration(days: daysToAdd));
      }
      daysToAdd += entry.value;
    }
    return null;
  }
}