// Comprehensive data models matching CannaAI web application
// Based on analysis of https://github.com/Franzferdinan51/CannaAI.git

import 'package:json_annotation/json_annotation.dart';

part 'data_models.g.dart';

// ==================== CORE DATA MODELS ====================

@JsonSerializable()
class User {
  final String id;
  final String email;
  final String? name;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSettings settings;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class UserSettings {
  final TemperatureUnits temperatureUnits;
  final WeightUnits weightUnits;
  final NotificationPreferences notifications;
  final AutomationSettings automation;
  final AISettings ai;
  final DisplaySettings display;
  final bool darkMode;
  final String defaultRoomId;

  const UserSettings({
    this.temperatureUnits = TemperatureUnits.fahrenheit,
    this.weightUnits = WeightUnits.grams,
    required this.notifications,
    required this.automation,
    required this.ai,
    required this.display,
    this.darkMode = true,
    this.defaultRoomId = '',
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => _$UserSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$UserSettingsToJson(this);
}

// ==================== ENUMS ====================

enum TemperatureUnits { fahrenheit, celsius }
enum WeightUnits { grams, ounces, pounds }
enum PlantType { indica, sativa, hybrid, ruderalis }
enum GrowthStage { germination, seedling, vegetative, flowering, harvest, curing, completed }
enum PlantHealth { excellent, good, fair, poor, critical }
enum AnalysisType { health, pest, nutrient, trichome, harvest }
enum AutomationType { watering, lighting, climate, ventilation, co2 }
enum AIProvider { lmStudio, openRouter, openai, deviceML, offline }

// ==================== SENSOR DATA MODELS ====================

@JsonSerializable()
class SensorData {
  final String id;
  final String roomId;
  final double temperature; // Internal Celsius
  final double humidity; // Percentage
  final double soilMoisture; // Percentage
  final double lightIntensity; // Lux
  final double ph; // pH level
  final double ec; // Electrical conductivity
  final double co2; // PPM
  final double vpd; // Vapor pressure deficit
  final DateTime timestamp;
  final String deviceId;

  const SensorData({
    required this.id,
    required this.roomId,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.lightIntensity,
    required this.ph,
    required this.ec,
    required this.co2,
    required this.vpd,
    required this.timestamp,
    this.deviceId = '',
  });

  factory SensorData.fromJson(Map<String, dynamic> json) => _$SensorDataFromJson(json);
  Map<String, dynamic> toJson() => _$SensorDataToJson(this);

  // Helper methods for display
  double get displayTemperature {
    return temperatureUnits == TemperatureUnits.fahrenheit
        ? (temperature * 9/5) + 32
        : temperature;
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'temperature': displayTemperature,
      'humidity': humidity,
      'soilMoisture': soilMoisture,
      'lightIntensity': lightIntensity,
      'ph': ph,
      'ec': ec,
      'co2': co2,
      'vpd': vpd,
    };
  }
}

// ==================== ROOM MANAGEMENT ====================

@JsonSerializable()
class Room {
  final String id;
  final String name;
  final String? description;
  final RoomType type;
  final RoomSettings settings;
  final List<SensorData> currentSensorData;
  final List<Plant> plants;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Room({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.settings,
    this.currentSensorData = const [],
    this.plants = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);
}

enum RoomType { vegetative, flowering, cloning, drying, curing, general }

@JsonSerializable()
class RoomSettings {
  final double targetTemperature;
  final double targetHumidity;
  final double targetPh;
  final double targetEc;
  final double targetCo2;
  final LightingSettings lighting;
  final VentilationSettings ventilation;
  final IrrigationSettings irrigation;

  const RoomSettings({
    this.targetTemperature = 22.0, // Celsius
    this.targetHumidity = 50.0, // Percentage
    this.targetPh = 6.2,
    this.targetEc = 1.5, // dS/m
    this.targetCo2 = 800.0, // PPM
    required this.lighting,
    required this.ventilation,
    required this.irrigation,
  });

  factory RoomSettings.fromJson(Map<String, dynamic> json) => _$RoomSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$RoomSettingsToJson(this);
}

// ==================== PLANT MANAGEMENT ====================

@JsonSerializable()
class Plant {
  final String id;
  final String roomId;
  final String strainId;
  final String name;
  final String? description;
  final PlantType type;
  final GrowthStage currentStage;
  final PlantHealth healthStatus;
  final DateTime plantedDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final List<PlantMeasurement> measurements;
  final List<PlantHealthRecord> healthHistory;
  final List<String> images;
  final PlantSettings settings;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Plant({
    required this.id,
    required this.roomId,
    required this.strainId,
    required this.name,
    this.description,
    required this.type,
    required this.currentStage,
    required this.healthStatus,
    required this.plantedDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    this.measurements = const [],
    this.healthHistory = const [],
    this.images = const [],
    required this.settings,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) => _$PlantFromJson(json);
  Map<String, dynamic> toJson() => _$PlantToJson(this);

  // Helper methods
  int get ageInDays {
    return DateTime.now().difference(plantedDate).inDays;
  }

  double get growthProgress {
    // Calculate progress based on stage and age
    switch (currentStage) {
      case GrowthStage.germination:
        return (ageInDays / 7).clamp(0.0, 1.0) * 0.05;
      case GrowthStage.seedling:
        return 0.05 + (ageInDays / 14).clamp(0.0, 1.0) * 0.10;
      case GrowthStage.vegetative:
        return 0.15 + (ageInDays / 56).clamp(0.0, 1.0) * 0.45;
      case GrowthStage.flowering:
        return 0.60 + (ageInDays / 63).clamp(0.0, 1.0) * 0.35;
      case GrowthStage.harvest:
        return 0.95;
      case GrowthStage.curing:
        return 0.98;
      case GrowthStage.completed:
        return 1.0;
    }
  }

  int? get daysUntilHarvest {
    if (expectedHarvestDate == null) return null;
    return expectedHarvestDate!.difference(DateTime.now()).inDays;
  }

  bool get needsAttention {
    return healthStatus.index <= PlantHealth.fair.index;
  }
}

@JsonSerializable()
class PlantMeasurement {
  final String id;
  final String plantId;
  final PlantMeasurementType type;
  final double value;
  final String unit;
  final DateTime measuredAt;
  final String? notes;
  final List<String> images;
  final Map<String, dynamic>? environmentalContext;

  const PlantMeasurement({
    required this.id,
    required this.plantId,
    required this.type,
    required this.value,
    required this.unit,
    required this.measuredAt,
    this.notes,
    this.images = const [],
    this.environmentalContext,
  });

  factory PlantMeasurement.fromJson(Map<String, dynamic> json) => _$PlantMeasurementFromJson(json);
  Map<String, dynamic> toJson() => _$PlantMeasurementToJson(this);
}

enum PlantMeasurementType { height, width, leafCount, nodeCount, branchCount, budSize, wetWeight, dryWeight }

// ==================== STRAIN MANAGEMENT ====================

@JsonSerializable()
class Strain {
  final String id;
  final String name;
  final PlantType type;
  final String? lineage;
  final String? description;
  final StrainCharacteristics characteristics;
  final OptimalConditions optimalConditions;
  final List<String> commonDeficiencies;
  final List<String> commonPests;
  final List<String> specialNotes;
  final bool isPurpleStrain;
  final String? image;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Strain({
    required this.id,
    required this.name,
    required this.type,
    this.lineage,
    this.description,
    required this.characteristics,
    required this.optimalConditions,
    this.commonDeficiencies = const [],
    this.commonPests = const [],
    this.specialNotes = const [],
    this.isPurpleStrain = false,
    this.image,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Strain.fromJson(Map<String, dynamic> json) => _$StrainFromJson(json);
  Map<String, dynamic> toJson() => _$StrainToJson(this);
}

@JsonSerializable()
class StrainCharacteristics {
  final double thcPotential; // Percentage
  final double cbdPotential; // Percentage
  final int floweringTime; // Days
  final int heightPotential; // cm
  final double yieldPotential; // g/plant
  final List<String> effects;
  final List<String> flavors;
  final List<String> aromas;
  final Difficulty difficulty;

  const StrainCharacteristics({
    this.thcPotential = 0.0,
    this.cbdPotential = 0.0,
    this.floweringTime = 60,
    this.heightPotential = 120,
    this.yieldPotential = 400.0,
    this.effects = const [],
    this.flavors = const [],
    this.aromas = const [],
    this.difficulty = Difficulty.medium,
  });

  factory StrainCharacteristics.fromJson(Map<String, dynamic> json) => _$StrainCharacteristicsFromJson(json);
  Map<String, dynamic> toJson() => _$StrainCharacteristicsToJson(this);
}

enum Difficulty { easy, medium, hard }

// ==================== ANALYSIS RESULTS ====================

@JsonSerializable()
class AnalysisResult {
  final String id;
  final String plantId;
  final AnalysisType type;
  final double healthScore; // 0.0 to 1.0
  final List<Issue> issues;
  final List<String> recommendations;
  final double confidence; // 0.0 to 1.0
  final Map<String, dynamic> details;
  final List<String> images;
  final String notes;
  final DateTime analyzedAt;
  final DateTime createdAt;
  final String? aiProvider;
  final Map<String, dynamic>? aiResponse;

  const AnalysisResult({
    required this.id,
    required this.plantId,
    required this.type,
    required this.healthScore,
    this.issues = const [],
    this.recommendations = const [],
    required this.confidence,
    this.details = const {},
    this.images = const [],
    this.notes = '',
    required this.analyzedAt,
    required this.createdAt,
    this.aiProvider,
    this.aiResponse,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => _$AnalysisResultFromJson(json);
  Map<String, dynamic> toJson() => _$AnalysisResultToJson(this);

  bool get isHealthy => healthScore >= 0.7;
  bool get needsImmediateAttention => healthScore <= 0.3;
  String get healthStatus {
    if (healthScore >= 0.8) return 'Excellent';
    if (healthScore >= 0.6) return 'Good';
    if (healthScore >= 0.4) return 'Fair';
    if (healthScore >= 0.2) return 'Poor';
    return 'Critical';
  }
}

@JsonSerializable()
class Issue {
  final String id;
  final String type; // nutrient_deficiency, pest, disease, environmental
  final String severity; // low, medium, high, critical
  final String title;
  final String description;
  final List<String> symptoms;
  final List<String> solutions;
  final List<String> images;
  final String? affectedArea; // leaf, stem, root, flower, etc.

  const Issue({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.symptoms = const [],
    this.solutions = const [],
    this.images = const [],
    this.affectedArea,
  });

  factory Issue.fromJson(Map<String, dynamic> json) => _$IssueFromJson(json);
  Map<String, dynamic> toJson() => _$IssueToJson(this);
}

// ==================== AI & CHAT MODELS ====================

@JsonSerializable()
class AIChatMessage {
  final String id;
  final String role; // user, assistant, system
  final String content;
  final DateTime timestamp;
  final List<String> images;
  final Map<String, dynamic>? metadata;
  final String? modelUsed;
  final bool isFromAI;

  const AIChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.images = const [],
    this.metadata,
    this.modelUsed,
    this.isFromAI = false,
  });

  factory AIChatMessage.fromJson(Map<String, dynamic> json) => _$AIChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$AIChatMessageToJson(this);
}

@JsonSerializable()
class AIChatSession {
  final String id;
  final String title;
  final List<AIChatMessage> messages;
  final String? contextPlantId;
  final String? contextRoomId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const AIChatSession({
    required this.id,
    required this.title,
    this.messages = const [],
    this.contextPlantId,
    this.contextRoomId,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory AIChatSession.fromJson(Map<String, dynamic> json) => _$AIChatSessionFromJson(json);
  Map<String, dynamic> toJson() => _$AIChatSessionToJson(this);
}

// ==================== AUTOMATION MODELS ====================

@JsonSerializable()
class AutomationRule {
  final String id;
  final String roomId;
  final String name;
  final AutomationType type;
  final bool isEnabled;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> actions;
  final String schedule; // Cron expression
  final List<String> notificationRecipients;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastExecuted;
  final bool isCurrentlyActive;

  const AutomationRule({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    this.isEnabled = true,
    this.conditions = const {},
    this.actions = const {},
    this.schedule = '',
    this.notificationRecipients = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastExecuted,
    this.isCurrentlyActive = false,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) => _$AutomationRuleFromJson(json);
  Map<String, dynamic> toJson() => _$AutomationRuleToJson(this);
}

@JsonSerializable()
class AutomationHistory {
  final String id;
  final String ruleId;
  final String roomId;
  final AutomationType type;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? inputData;
  final Map<String, dynamic>? outputData;
  final DateTime executedAt;
  final Duration executionTime;

  const AutomationHistory({
    required this.id,
    required this.ruleId,
    required this.roomId,
    required this.type,
    required this.success,
    this.errorMessage,
    this.inputData,
    this.outputData,
    required this.executedAt,
    required this.executionTime,
  });

  factory AutomationHistory.fromJson(Map<String, dynamic> json) => _$AutomationHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$AutomationHistoryToJson(this);
}

// ==================== INVENTORY MODELS ====================

@JsonSerializable()
class InventoryItem {
  final String id;
  final String name;
  final String? description;
  final String category;
  final String supplier;
  final double currentStock;
  final String unit; // grams, liters, units, etc.
  final double minStockLevel;
  final double maxStockLevel;
  final double unitPrice;
  final String? sku;
  final DateTime? expiryDate;
  final List<String> images;
  final Map<String, dynamic>? properties;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.supplier,
    required this.currentStock,
    required this.unit,
    this.minStockLevel = 0.0,
    this.maxStockLevel = 1000.0,
    required this.unitPrice,
    this.sku,
    this.expiryDate,
    this.images = const [],
    this.properties,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryItemToJson(this);

  bool get isLowStock => currentStock <= minStockLevel;
  bool get needsReorder => currentStock <= (minStockLevel * 1.2);
  double get stockStatus => currentStock / maxStockLevel;
}

@JsonSerializable()
class HarvestRecord {
  final String id;
  final String plantId;
  final String roomId;
  final double wetWeight;
  final double dryWeight;
  final double? thcContent;
  final double? cbdContent;
  final int? cureDays;
  final QualityGrade quality;
  final List<String> images;
  final String notes;
  final DateTime harvestedAt;
  final DateTime? driedAt;
  final DateTime? curedAt;
  final Map<String, dynamic>? testingResults;

  const HarvestRecord({
    required this.id,
    required this.plantId,
    required this.roomId,
    required this.wetWeight,
    required this.dryWeight,
    this.thcContent,
    this.cbdContent,
    this.cureDays,
    required this.quality,
    this.images = const [],
    this.notes = '',
    required this.harvestedAt,
    this.driedAt,
    this.curedAt,
    this.testingResults,
  });

  factory HarvestRecord.fromJson(Map<String, dynamic> json) => _$HarvestRecordFromJson(json);
  Map<String, dynamic> toJson() => _$HarvestRecordToJson(this);

  double get dryToWetRatio => wetWeight > 0 ? dryWeight / wetWeight : 0.0;
  double get thcLoss {
    if (thcContent == null) return 0.0;
    return (thcContent! * 0.15); // Approximate 15% loss during curing
  }
}

enum QualityGrade { a, b, c, premium, standard }

// ==================== SETTINGS MODELS ====================

@JsonSerializable()
class NotificationPreferences {
  final bool enabled;
  final bool plantHealthAlerts;
  final bool automationAlerts;
  final bool sensorAlerts;
  final bool maintenanceReminders;
  final bool harvestReminders;
  final bool inventoryAlerts;
  final List<String> emailNotifications;
  final List<String> pushNotifications;
  final bool soundEnabled;
  final String alertLevel; // all, important, critical

  const NotificationPreferences({
    this.enabled = true,
    this.plantHealthAlerts = true,
    this.automationAlerts = true,
    this.sensorAlerts = true,
    this.maintenanceReminders = true,
    this.harvestReminders = true,
    this.inventoryAlerts = true,
    this.emailNotifications = const [],
    this.pushNotifications = const [],
    this.soundEnabled = true,
    this.alertLevel = 'important',
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) => _$NotificationPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPreferencesToJson(json);
}

@JsonSerializable()
class AutomationSettings {
  final bool enabled;
  final WateringSettings watering;
  final LightingSettings lighting;
  final ClimateSettings climate;
  final VentilationSettings ventilation;
  final Co2Settings co2;

  const AutomationSettings({
    this.enabled = true,
    required this.watering,
    required this.lighting,
    required this.climate,
    required this.ventilation,
    required this.co2,
  });

  factory AutomationSettings.fromJson(Map<String, dynamic> json) => _$AutomationSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AutomationSettingsToJson(json);
}

@JsonSerializable()
class AISettings {
  final AIProvider primaryProvider;
  final Map<AIProvider, AIProviderConfig> providers;
  final bool enableLocalAnalysis;
  final bool enableCloudAnalysis;
  final AnalysisPreferences preferences;

  const AISettings({
    this.primaryProvider = AIProvider.deviceML,
    this.providers = const {},
    this.enableLocalAnalysis = true,
    this.enableCloudAnalysis = false,
    required this.preferences,
  });

  factory AISettings.fromJson(Map<String, dynamic> json) => _$AISettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AISettingsToJson(this);
}

@JsonSerializable()
class DisplaySettings {
  final String theme;
  final bool showAdvancedMetrics;
  final bool showPredictiveAnalytics;
  final ChartPreferences chartPreferences;
  final DashboardLayout dashboardLayout;

  const DisplaySettings({
    this.theme = 'dark',
    this.showAdvancedMetrics = true,
    this.showPredictiveAnalytics = true,
    required this.chartPreferences,
    this.dashboardLayout = DashboardLayout.grid,
  });

  factory DisplaySettings.fromJson(Map<String, dynamic> json) => _$DisplaySettingsFromJson(json);
  Map<String, dynamic> toJson() => _$DisplaySettingsToJson(this);
}

// ==================== SUB-SETTINGS MODELS ====================

@JsonSerializable()
class WateringSettings {
  final bool enabled;
  final double moistureThreshold;
  final String schedule; // Cron expression
  final double amountPerWatering; // Liters
  final Duration duration;

  const WateringSettings({
    this.enabled = true,
    this.moistureThreshold = 30.0,
    this.schedule = '0 6,18 * * *',
    this.amountPerWatering = 1.0,
    this.duration = const Duration(minutes: 5),
  });

  factory WateringSettings.fromJson(Map<String, dynamic> json) => _$WateringSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$WateringSettingsToJson(json);
}

@JsonSerializable()
class LightingSettings {
  final bool enabled;
  final String vegSchedule; // Cron for vegetative
  final String flowerSchedule; // Cron for flowering
  final int vegIntensity; // Percentage
  final int flowerIntensity; // Percentage
  final List<LightSpectrum> spectrums;

  const LightingSettings({
    this.enabled = true,
    this.vegSchedule = '0 6-24 * * *',
    this.flowerSchedule = '0 6-18 * * *',
    this.vegIntensity = 75,
    this.flowerIntensity = 100,
    this.spectrums = const [],
  });

  factory LightingSettings.fromJson(Map<String, dynamic> json) => _$LightingSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$LightingSettingsToJson(json);
}

@JsonSerializable()
class ClimateSettings {
  final bool enabled;
  final double minTemp;
  final double maxTemp;
  final double minHumidity;
  final double maxHumidity;
  final double vpdTarget;

  const ClimateSettings({
    this.enabled = true,
    this.minTemp = 18.0,
    this.maxTemp = 26.0,
    this.minHumidity = 40.0,
    this.maxHumidity = 70.0,
    this.vpdTarget = 1.2,
  });

  factory ClimateSettings.fromJson(Map<String, dynamic> json) => _$ClimateSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$ClimateSettingsToJson(json);
}

@JsonSerializable()
class VentilationSettings {
  final bool enabled;
  final bool autoControl;
  final int fanSpeed; // Percentage
  final Duration cycleDuration;
  final Duration restDuration;

  const VentilationSettings({
    this.enabled = true,
    this.autoControl = true,
    this.fanSpeed = 50,
    this.cycleDuration = const Duration(minutes: 15),
    this.restDuration = const Duration(minutes: 30),
  });

  factory VentilationSettings.fromJson(Map<String, dynamic> json) => _$VentilationSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$VentilationSettingsToJson(json);
}

@JsonSerializable()
class Co2Settings {
  final bool enabled;
  final double targetLevel;
  final double maxLevel;
  final Duration injectionDuration;

  const Co2Settings({
    this.enabled = false,
    this.targetLevel = 800.0,
    this.maxLevel = 1200.0,
    this.injectionDuration = const Duration(seconds: 30),
  });

  factory Co2Settings.fromJson(Map<String, dynamic> json) => _$Co2SettingsFromJson(json);
  Map<String, dynamic> toJson() => _$Co2SettingsToJson(json);
}

@JsonSerializable()
class IrrigationSettings {
  final bool enabled;
  final double phTarget;
  final double ecTarget;
  final double runoffTarget;
  final Duration flushInterval;

  const IrrigationSettings({
    this.enabled = true,
    this.phTarget = 6.2,
    this.ecTarget = 1.5,
    this.runoffTarget = 20.0,
    this.flushInterval = const Duration(days: 14),
  });

  factory IrrigationSettings.fromJson(Map<String, dynamic> json) => _$IrrigationSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$IrrigationSettingsToJson(json);
}

@JsonSerializable()
class AIProviderConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final Map<String, dynamic> parameters;
  final bool isEnabled;

  const AIProviderConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.parameters = const {},
    this.isEnabled = true,
  });

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) => _$AIProviderConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AIProviderConfigToJson(this);
}

@JsonSerializable()
class AnalysisPreferences {
  final double confidenceThreshold;
  final bool includeImageAnalysis;
  final bool includeEnvironmentalContext;
  final List<AnalysisType> enabledTypes;
  final Map<String, dynamic> customParameters;

  const AnalysisPreferences({
    this.confidenceThreshold = 0.7,
    this.includeImageAnalysis = true,
    this.includeEnvironmentalContext = true,
    this.enabledTypes = const [
      AnalysisType.health,
      AnalysisType.pest,
      AnalysisType.nutrient,
    ],
    this.customParameters = const {},
  });

  factory AnalysisPreferences.fromJson(Map<String, dynamic> json) => _$AnalysisPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$AnalysisPreferencesToJson(this);
}

@JsonSerializable()
class ChartPreferences {
  final ChartType defaultType;
  final List<String> defaultMetrics;
  final bool showTrends;
  final int dataPointLimit;
  final ChartTheme theme;

  const ChartPreferences({
    this.defaultType = ChartType.line,
    this.defaultMetrics = const ['temperature', 'humidity', 'ph'],
    this.showTrends = true,
    this.dataPointLimit = 100,
    this.theme = ChartTheme.dark,
  });

  factory ChartPreferences.fromJson(Map<String, dynamic> json) => _$ChartPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$ChartPreferencesToJson(json);
}

enum ChartType { line, bar, area, pie, radar }
enum ChartTheme { light, dark, auto }
enum DashboardLayout { grid, list, cards }

// ==================== SUPPORTING MODELS ====================

@JsonSerializable()
class LightSpectrum {
  final String name;
  final int wavelength; // nm
  final double intensity; // Percentage

  const LightSpectrum({
    required this.name,
    required this.wavelength,
    required this.intensity,
  });

  factory LightSpectrum.fromJson(Map<String, dynamic> json) => _$LightSpectrumFromJson(json);
  Map<String, dynamic> toJson() => _$LightSpectrumToJson(this);
}

@JsonSerializable()
class OptimalConditions {
  final TemperatureRange temperature;
  final HumidityRange humidity;
  final PhRange ph;
  final EcRange ec;
  final LightRequirement light;
  final int floweringTime; // Days

  const OptimalConditions({
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.ec,
    required this.light,
    this.floweringTime = 60,
  });

  factory OptimalConditions.fromJson(Map<String, dynamic> json) => _$OptimalConditionsFromJson(json);
  Map<String, dynamic> toJson() => _$OptimalConditionsToJson(this);
}

@JsonSerializable()
class TemperatureRange {
  final double min;
  final double max;
  final double optimal;

  const TemperatureRange({
    required this.min,
    required this.max,
    required this.optimal,
  });

  factory TemperatureRange.fromJson(Map<String, dynamic> json) => _$TemperatureRangeFromJson(json);
  Map<String, dynamic> toJson() => _$TemperatureRangeToJson(this);
}

@JsonSerializable()
class HumidityRange {
  final double min;
  final double max;
  final double optimal;

  const HumidityRange({
    required this.min,
    required this.max,
    required this.optimal,
  });

  factory HumidityRange.fromJson(Map<String, dynamic> json) => _$HumidityRangeFromJson(json);
  Map<String, dynamic> toJson() => _$HumidityRangeToJson(this);
}

@JsonSerializable()
class PhRange {
  final double min;
  final double max;
  final double optimal;

  const PhRange({
    required this.min,
    required this.max,
    required this.optimal,
  });

  factory PhRange.fromJson(Map<String, dynamic> json) => _$PhRangeFromJson(json);
  Map<String, dynamic> toJson() => _$PhRangeToJson(this);
}

@JsonSerializable()
class EcRange {
  final double min;
  final double max;
  final double optimal;

  const EcRange({
    required this.min,
    required this.max,
    required this.optimal,
  });

  factory EcRange.fromJson(Map<String, dynamic> json) => _$EcRangeFromJson(json);
  Map<String, dynamic> toJson() => _$EcRangeToJson(this);
}

@JsonSerializable()
class LightRequirement {
  final int dailyHours;
  final double intensity; // PPFD
  final double distance; // cm from canopy

  const LightRequirement({
    required this.dailyHours,
    required this.intensity,
    required this.distance,
  });

  factory LightRequirement.fromJson(Map<String, dynamic> json) => _$LightRequirementFromJson(json);
  Map<String, dynamic> toJson() => _$LightRequirementToJson(this);
}

@JsonSerializable()
class PlantHealthRecord {
  final String id;
  final String plantId;
  final PlantHealth healthStatus;
  final double healthScore;
  final List<String> issues;
  final List<String> recommendations;
  final Map<String, dynamic> sensorData;
  final List<String> images;
  final String notes;
  final DateTime recordedAt;
  final DateTime createdAt;

  const PlantHealthRecord({
    required this.id,
    required this.plantId,
    required this.healthStatus,
    required this.healthScore,
    this.issues = const [],
    this.recommendations = const [],
    this.sensorData = const {},
    this.images = const [],
    this.notes = '',
    required this.recordedAt,
    required this.createdAt,
  });

  factory PlantHealthRecord.fromJson(Map<String, dynamic> json) => _$PlantHealthRecordFromJson(json);
  Map<String, dynamic> toJson() => _$PlantHealthRecordToJson(this);

  bool get isImproving => healthScore >= 0.7;
  bool get needsImmediateAttention => healthScore <= 0.3;
}

@JsonSerializable()
class PlantSettings {
  final Map<String, dynamic> environmentalPreferences;
  final Map<String, dynamic> customNotes;
  final List<String> tags;
  final bool isMonitored;
  final int wateringFrequency; // Days
  final double waterAmount; // Liters

  const PlantSettings({
    this.environmentalPreferences = const {},
    this.customNotes = const {},
    this.tags = const [],
    this.isMonitored = true,
    this.wateringFrequency = 2,
    this.waterAmount = 1.0,
  });

  factory PlantSettings.fromJson(Map<String, dynamic> json) => _$PlantSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PlantSettingsToJson(this);
}