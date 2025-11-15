import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// User Model with validation and business logic
@JsonSerializable()
class UserModel {
  final int id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isAdmin;
  final Map<String, dynamic>? preferences;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    required this.isActive,
    required this.isAdmin,
    this.preferences,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  // Validation methods
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';
    return null;
  }

  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 20) return 'Username cannot exceed 20 characters';
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) return 'Username can only contain letters, numbers, and underscores';
    return null;
  }

  static String? validateDisplayName(String? displayName) {
    if (displayName == null || displayName.isEmpty) return 'Display name is required';
    if (displayName.length < 2) return 'Display name must be at least 2 characters';
    if (displayName.length > 50) return 'Display name cannot exceed 50 characters';
    return null;
  }

  // Business logic methods
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.substring(0, 1).toUpperCase();
  }

  bool get isRecentlyActive {
    if (lastLoginAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastLoginAt!);
    return diff.inDays <= 7;
  }

  // Preference helpers
  T? getPreference<T>(String key) {
    return preferences?[key] as T?;
  }

  UserModel copyWithPreference(String key, dynamic value) {
    final newPreferences = Map<String, dynamic>.from(preferences ?? {});
    newPreferences[key] = value;
    return UserModel(
      id: id,
      email: email,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastLoginAt: lastLoginAt,
      isActive: isActive,
      isAdmin: isAdmin,
      preferences: newPreferences,
    );
  }
}

// Room Model with validation and helper methods
@JsonSerializable()
class RoomModel {
  final int id;
  final String name;
  final String? description;
  final String? location;
  final String? imageUrl;
  final String roomType;
  final double size;
  final double targetTemperature;
  final double targetHumidity;
  final double targetPh;
  final double targetEc;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoomModel({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.imageUrl,
    required this.roomType,
    required this.size,
    required this.targetTemperature,
    required this.targetHumidity,
    required this.targetPh,
    required this.targetEc,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) => _$RoomModelFromJson(json);
  Map<String, dynamic> toJson() => _$RoomModelToJson(this);

  // Validation methods
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Room name is required';
    if (name.length < 2) return 'Room name must be at least 2 characters';
    if (name.length > 50) return 'Room name cannot exceed 50 characters';
    return null;
  }

  static String? validateSize(String? size) {
    if (size == null || size.isEmpty) return 'Room size is required';
    final sizeValue = double.tryParse(size);
    if (sizeValue == null) return 'Please enter a valid number';
    if (sizeValue <= 0) return 'Room size must be greater than 0';
    if (sizeValue > 1000) return 'Room size seems too large (max 1000 sq meters)';
    return null;
  }

  static String? validateTargetTemperature(String? temp) {
    if (temp == null || temp.isEmpty) return 'Target temperature is required';
    final tempValue = double.tryParse(temp);
    if (tempValue == null) return 'Please enter a valid temperature';
    if (tempValue < 10) return 'Temperature cannot be below 10°C';
    if (tempValue > 40) return 'Temperature cannot exceed 40°C';
    return null;
  }

  static String? validateTargetHumidity(String? humidity) {
    if (humidity == null || humidity.isEmpty) return 'Target humidity is required';
    final humidityValue = double.tryParse(humidity);
    if (humidityValue == null) return 'Please enter a valid humidity percentage';
    if (humidityValue < 20) return 'Humidity cannot be below 20%';
    if (humidityValue > 90) return 'Humidity cannot exceed 90%';
    return null;
  }

  static String? validateTargetPh(String? ph) {
    if (ph == null || ph.isEmpty) return 'Target pH is required';
    final phValue = double.tryParse(ph);
    if (phValue == null) return 'Please enter a valid pH value';
    if (phValue < 3.0) return 'pH cannot be below 3.0';
    if (phValue > 9.0) return 'pH cannot exceed 9.0';
    return null;
  }

  // Helper methods
  String get displayName => name.trim();
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isVegetative => roomType.toLowerCase() == 'vegetative';
  bool get isFlowering => roomType.toLowerCase() == 'flowering';
  bool get isDrying => roomType.toLowerCase() == 'drying';
  bool get isGeneral => roomType.toLowerCase() == 'general';

  String get sizeDisplay => '${size.toStringAsFixed(1)} m²';
  String get temperatureDisplay => '${targetTemperature.toStringAsFixed(1)}°C';
  String get humidityDisplay => '${targetHumidity.toStringAsFixed(0)}%';
  String get phDisplay => targetPh.toStringAsFixed(1);
  String get ecDisplay => '${targetEc.toStringAsFixed(1)} mS/cm';

  RoomModel copyWith({
    String? name,
    String? description,
    String? location,
    String? imageUrl,
    String? roomType,
    double? size,
    double? targetTemperature,
    double? targetHumidity,
    double? targetPh,
    double? targetEc,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return RoomModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      roomType: roomType ?? this.roomType,
      size: size ?? this.size,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      targetHumidity: targetHumidity ?? this.targetHumidity,
      targetPh: targetPh ?? this.targetPh,
      targetEc: targetEc ?? this.targetEc,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

// Strain Model with validation and business logic
@JsonSerializable()
class StrainModel {
  final int id;
  final String name;
  final String? breeder;
  final String? genetics;
  final String type;
  final String? thcLevel;
  final String? cbdLevel;
  final String? floweringTime;
  final String? yield;
  final String difficulty;
  final String? description;
  final String? imageUrl;
  final String? flavorProfile;
  final String? effects;
  final String? medicalUses;
  final String? growthCharacteristics;
  final double? optimalTemperature;
  final double? optimalHumidity;
  final double? optimalPh;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StrainModel({
    required this.id,
    required this.name,
    this.breeder,
    this.genetics,
    required this.type,
    this.thcLevel,
    this.cbdLevel,
    this.floweringTime,
    this.yield,
    required this.difficulty,
    this.description,
    this.imageUrl,
    this.flavorProfile,
    this.effects,
    this.medicalUses,
    this.growthCharacteristics,
    this.optimalTemperature,
    this.optimalHumidity,
    this.optimalPh,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StrainModel.fromJson(Map<String, dynamic> json) => _$StrainModelFromJson(json);
  Map<String, dynamic> toJson() => _$StrainModelToJson(this);

  // Validation methods
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Strain name is required';
    if (name.length < 2) return 'Strain name must be at least 2 characters';
    if (name.length > 100) return 'Strain name cannot exceed 100 characters';
    return null;
  }

  static String? validateType(String? type) {
    if (type == null || type.isEmpty) return 'Strain type is required';
    final validTypes = ['indica', 'sativa', 'hybrid', 'ruderalis'];
    if (!validTypes.contains(type.toLowerCase())) {
      return 'Type must be one of: ${validTypes.join(', ')}';
    }
    return null;
  }

  static String? validateDifficulty(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) return 'Difficulty is required';
    final validDifficulties = ['easy', 'medium', 'hard', 'expert'];
    if (!validDifficulties.contains(difficulty.toLowerCase())) {
      return 'Difficulty must be one of: ${validDifficulties.join(', ')}';
    }
    return null;
  }

  // Helper methods
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isIndica => type.toLowerCase() == 'indica';
  bool get isSativa => type.toLowerCase() == 'sativa';
  bool get isHybrid => type.toLowerCase() == 'hybrid';
  bool get isRuderalis => type.toLowerCase() == 'ruderalis';

  bool get isEasy => difficulty.toLowerCase() == 'easy';
  bool get isMedium => difficulty.toLowerCase() == 'medium';
  bool get isHard => difficulty.toLowerCase() == 'hard';
  bool get isExpert => difficulty.toLowerCase() == 'expert';

  bool get hasOptimalConditions =>
      optimalTemperature != null && optimalHumidity != null && optimalPh != null;

  String get typeDisplay => type[0].toUpperCase() + type.substring(1);
  String get difficultyDisplay => difficulty[0].toUpperCase() + difficulty.substring(1);

  String get thcDisplay {
    if (thcLevel == null || thcLevel!.isEmpty) return 'Unknown';
    return 'THC: $thcLevel';
  }

  String get cbdDisplay {
    if (cbdLevel == null || cbdLevel!.isEmpty) return 'Unknown';
    return 'CBD: $cbdLevel';
  }

  String get floweringDisplay {
    if (floweringTime == null || floweringTime!.isEmpty) return 'Unknown';
    return 'Flowering: $floweringTime';
  }

  String get yieldDisplay {
    if (yield == null || yield!.isEmpty) return 'Unknown';
    return 'Yield: $yield';
  }

  List<String> get flavorList {
    if (flavorProfile == null || flavorProfile!.isEmpty) return [];
    return flavorProfile!.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
  }

  List<String> get effectsList {
    if (effects == null || effects!.isEmpty) return [];
    return effects!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get medicalUsesList {
    if (medicalUses == null || medicalUses!.isEmpty) return [];
    return medicalUses!.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
  }
}

// Plant Model with comprehensive business logic
@JsonSerializable()
class PlantModel {
  final int id;
  final String name;
  final int strainId;
  final int roomId;
  final String growthStage;
  final String healthStatus;
  final DateTime plantedDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final double? height;
  final double? weight;
  final String? gender;
  final String? phenotype;
  final String? notes;
  final String? imageUrl;
  final double? temperature;
  final double? humidity;
  final double? ph;
  final double? ec;
  final double? lightIntensity;
  final int wateringCount;
  final DateTime? lastWateringAt;
  final int feedingCount;
  final DateTime? lastFeedingAt;
  final bool isActive;
  final bool isMotherPlant;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlantModel({
    required this.id,
    required this.name,
    required this.strainId,
    required this.roomId,
    required this.growthStage,
    required this.healthStatus,
    required this.plantedDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    this.height,
    this.weight,
    this.gender,
    this.phenotype,
    this.notes,
    this.imageUrl,
    this.temperature,
    this.humidity,
    this.ph,
    this.ec,
    this.lightIntensity,
    required this.wateringCount,
    this.lastWateringAt,
    required this.feedingCount,
    this.lastFeedingAt,
    required this.isActive,
    required this.isMotherPlant,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) => _$PlantModelFromJson(json);
  Map<String, dynamic> toJson() => _$PlantModelToJson(this);

  // Validation methods
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Plant name is required';
    if (name.length < 1) return 'Plant name must be at least 1 character';
    if (name.length > 50) return 'Plant name cannot exceed 50 characters';
    return null;
  }

  static String? validateGrowthStage(String? stage) {
    if (stage == null || stage.isEmpty) return 'Growth stage is required';
    final validStages = ['seedling', 'vegetative', 'flowering', 'harvesting'];
    if (!validStages.contains(stage.toLowerCase())) {
      return 'Growth stage must be one of: ${validStages.join(', ')}';
    }
    return null;
  }

  static String? validateHealthStatus(String? status) {
    if (status == null || status.isEmpty) return 'Health status is required';
    final validStatuses = ['healthy', 'warning', 'critical'];
    if (!validStatuses.contains(status.toLowerCase())) {
      return 'Health status must be one of: ${validStatuses.join(', ')}';
    }
    return null;
  }

  static String? validateHeight(String? height) {
    if (height == null || height.isEmpty) return null; // Height is optional
    final heightValue = double.tryParse(height);
    if (heightValue == null) return 'Please enter a valid height';
    if (heightValue <= 0) return 'Height must be greater than 0';
    if (heightValue > 500) return 'Height seems unrealistic (max 500 cm)';
    return null;
  }

  static String? validatePh(String? ph) {
    if (ph == null || ph.isEmpty) return null; // pH is optional
    final phValue = double.tryParse(ph);
    if (phValue == null) return 'Please enter a valid pH value';
    if (phValue < 3.0) return 'pH cannot be below 3.0';
    if (phValue > 9.0) return 'pH cannot exceed 9.0';
    return null;
  }

  // Business logic methods
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isSeedling => growthStage.toLowerCase() == 'seedling';
  bool get isVegetative => growthStage.toLowerCase() == 'vegetative';
  bool get isFlowering => growthStage.toLowerCase() == 'flowering';
  bool get isHarvesting => growthStage.toLowerCase() == 'harvesting';

  bool get isHealthy => healthStatus.toLowerCase() == 'healthy';
  bool get hasWarning => healthStatus.toLowerCase() == 'warning';
  bool get isCritical => healthStatus.toLowerCase() == 'critical';

  bool get isFemale => gender?.toLowerCase() == 'female';
  bool get isMale => gender?.toLowerCase() == 'male';
  bool get isHermaphrodite => gender?.toLowerCase() == 'hermaphrodite';

  bool get hasExpectedHarvest => expectedHarvestDate != null;
  bool get isHarvested => actualHarvestDate != null;
  bool get isOverdueForHarvest {
    if (!hasExpectedHarvest || isHarvested) return false;
    return DateTime.now().isAfter(expectedHarvestDate!);
  }

  Duration get age {
    final now = isHarvested ? actualHarvestDate! : DateTime.now();
    return now.difference(plantedDate);
  }

  int get ageInDays => age.inDays;
  int get ageInWeeks => (ageInDays / 7).floor();

  String get ageDisplay {
    if (ageInDays < 7) return '$ageInDays days';
    if (ageInDays < 30) return '$ageInWeeks weeks';
    return '${(ageInDays / 30).floor()} months';
  }

  bool get wasRecentlyWatered {
    if (lastWateringAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastWateringAt!);
    return diff.inDays <= 3;
  }

  bool get wasRecentlyFed {
    if (lastFeedingAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastFeedingAt!);
    return diff.inDays <= 7;
  }

  String get heightDisplay {
    if (height == null) return 'Not measured';
    return '${height!.toStringAsFixed(1)} cm';
  }

  String get weightDisplay {
    if (weight == null) return 'Not measured';
    return '${weight!.toStringAsFixed(1)} g';
  }

  String get phDisplay {
    if (ph == null) return 'Not measured';
    return ph!.toStringAsFixed(1);
  }

  String get ecDisplay {
    if (ec == null) return 'Not measured';
    return '${ec!.toStringAsFixed(1)} mS/cm';
  }

  String get wateringFrequency {
    if (wateringCount == 0) return 'Never watered';
    if (lastWateringAt == null) return 'Unknown';
    final daysSincePlanted = ageInDays;
    if (daysSincePlanted == 0) return 'Unknown';
    final frequency = (daysSincePlanted / wateringCount).round();
    return 'Every $frequency days';
  }

  String get feedingFrequency {
    if (feedingCount == 0) return 'Never fed';
    if (lastFeedingAt == null) return 'Unknown';
    final daysSincePlanted = ageInDays;
    if (daysSincePlanted == 0) return 'Unknown';
    final frequency = (daysSincePlanted / feedingCount).round();
    return 'Every $frequency days';
  }

  // Progress indicators
  double get growthProgress {
    switch (growthStage.toLowerCase()) {
      case 'seedling':
        return 0.25;
      case 'vegetative':
        return 0.5;
      case 'flowering':
        return 0.75;
      case 'harvesting':
        return 1.0;
      default:
        return 0.0;
    }
  }

  String get nextStageRecommendation {
    switch (growthStage.toLowerCase()) {
      case 'seedling':
        return 'Move to vegetative stage after 2-3 weeks';
      case 'vegetative':
        return 'Switch to flowering when plant reaches desired height';
      case 'flowering':
        return 'Harvest when trichomes are milky to amber';
      case 'harvesting':
        return 'Plant ready for harvest';
      default:
        return 'Monitor growth';
    }
  }
}

// Sensor Device Model
@JsonSerializable()
class SensorDeviceModel {
  final int id;
  final String deviceId;
  final String name;
  final String type;
  final String? manufacturer;
  final String? model;
  final String? firmwareVersion;
  final String? bluetoothAddress;
  final String? wifiAddress;
  final double calibrationOffset;
  final double calibrationScale;
  final String unit;
  final double? minReading;
  final double? maxReading;
  final int? batteryLevel;
  final bool isOnline;
  final bool isActive;
  final DateTime? lastSeenAt;
  final DateTime? lastCalibrationAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? roomId;

  const SensorDeviceModel({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.type,
    this.manufacturer,
    this.model,
    this.firmwareVersion,
    this.bluetoothAddress,
    this.wifiAddress,
    required this.calibrationOffset,
    required this.calibrationScale,
    required this.unit,
    this.minReading,
    this.maxReading,
    this.batteryLevel,
    required this.isOnline,
    required this.isActive,
    this.lastSeenAt,
    this.lastCalibrationAt,
    required this.createdAt,
    required this.updatedAt,
    this.roomId,
  });

  factory SensorDeviceModel.fromJson(Map<String, dynamic> json) => _$SensorDeviceModelFromJson(json);
  Map<String, dynamic> toJson() => _$SensorDeviceModelToJson(this);

  // Validation methods
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Device name is required';
    if (name.length < 2) return 'Device name must be at least 2 characters';
    if (name.length > 50) return 'Device name cannot exceed 50 characters';
    return null;
  }

  static String? validateDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return 'Device ID is required';
    if (deviceId.length < 3) return 'Device ID must be at least 3 characters';
    if (deviceId.length > 50) return 'Device ID cannot exceed 50 characters';
    return null;
  }

  // Helper methods
  bool get isTemperatureSensor => type.toLowerCase() == 'temperature';
  bool get isHumiditySensor => type.toLowerCase() == 'humidity';
  bool get isPhSensor => type.toLowerCase() == 'ph';
  bool get isEcSensor => type.toLowerCase() == 'ec';
  bool get isLightSensor => type.toLowerCase() == 'light';
  bool get isCo2Sensor => type.toLowerCase() == 'co2';

  bool get hasBluetooth => bluetoothAddress != null && bluetoothAddress!.isNotEmpty;
  bool get hasWifi => wifiAddress != null && wifiAddress!.isNotEmpty;
  bool get isBatteryPowered => batteryLevel != null;

  bool get needsCalibration {
    if (lastCalibrationAt == null) return true;
    final now = DateTime.now();
    final diff = now.difference(lastCalibrationAt!);
    return diff.inDays > 30; // Needs calibration every 30 days
  }

  bool get isLowBattery {
    if (batteryLevel == null) return false;
    return batteryLevel! < 20;
  }

  bool get wasRecentlySeen {
    if (lastSeenAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastSeenAt!);
    return diff.inMinutes <= 5;
  }

  String get connectionStatus {
    if (!isActive) return 'Inactive';
    if (!isOnline) return 'Offline';
    if (!wasRecentlySeen) return 'Unresponsive';
    return 'Online';
  }

  String get batteryStatus {
    if (!isBatteryPowered) return 'AC Powered';
    if (batteryLevel == null) return 'Unknown';
    if (batteryLevel! < 10) return 'Critical';
    if (batteryLevel! < 20) return 'Low';
    return 'Good';
  }

  String get typeDisplay {
    switch (type.toLowerCase()) {
      case 'temperature':
        return 'Temperature Sensor';
      case 'humidity':
        return 'Humidity Sensor';
      case 'ph':
        return 'pH Sensor';
      case 'ec':
        return 'EC Sensor';
      case 'light':
        return 'Light Sensor';
      case 'co2':
        return 'CO2 Sensor';
      default:
        return '${type[0].toUpperCase()}${type.substring(1)} Sensor';
    }
  }

  double applyCalibration(double rawValue) {
    return (rawValue + calibrationOffset) * calibrationScale;
  }

  bool isReadingInRange(double value) {
    if (minReading != null && value < minReading!) return false;
    if (maxReading != null && value > maxReading!) return false;
    return true;
  }
}

// Sensor Reading Model
@JsonSerializable()
class SensorReadingModel {
  final int id;
  final int deviceId;
  final double value;
  final String unit;
  final String quality;
  final String? notes;
  final DateTime timestamp;

  const SensorReadingModel({
    required this.id,
    required this.deviceId,
    required this.value,
    required this.unit,
    required this.quality,
    this.notes,
    required this.timestamp,
  });

  factory SensorReadingModel.fromJson(Map<String, dynamic> json) => _$SensorReadingModelFromJson(json);
  Map<String, dynamic> toJson() => _$SensorReadingModelToJson(this);

  // Helper methods
  bool get isGoodQuality => quality.toLowerCase() == 'good';
  bool get isPoorQuality => quality.toLowerCase() == 'poor';
  bool get isError => quality.toLowerCase() == 'error';

  String get valueDisplay {
    switch (unit.toLowerCase()) {
      case 'celsius':
        return '${value.toStringAsFixed(1)}°C';
      case 'fahrenheit':
        return '${value.toStringAsFixed(1)}°F';
      case 'percent':
        return '${value.toStringAsFixed(0)}%';
      case 'ph':
        return value.toStringAsFixed(1);
      case 'ec':
        return '${value.toStringAsFixed(1)} mS/cm';
      case 'ppm':
        return '${value.toStringAsFixed(0)} ppm';
      case 'lux':
        return '${value.toStringAsFixed(0)} lux';
      case 'watts':
        return '${value.toStringAsFixed(0)}W';
      default:
        return '${value.toStringAsFixed(1)} $unit';
    }
  }

  String get qualityDisplay {
    switch (quality.toLowerCase()) {
      case 'good':
        return 'Good';
      case 'poor':
        return 'Poor';
      case 'error':
        return 'Error';
      default:
        return quality;
    }
  }

  bool get isRecent {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inMinutes <= 60; // Recent if within last hour
  }
}

// Plant Analysis Model
@JsonSerializable()
class PlantAnalysisModel {
  final int id;
  final int plantId;
  final String analysisType;
  final List<String>? symptoms;
  final double healthScore;
  final double confidence;
  final String? diagnosis;
  final List<String>? recommendations;
  final String? imageUrl;
  final Map<String, dynamic>? imageAnalysisData;
  final double? temperature;
  final double? humidity;
  final double? ph;
  final double? ec;
  final double? lightIntensity;
  final double? co2Level;
  final Map<String, dynamic>? environmentalConditions;
  final String? notes;
  final DateTime analysisDate;
  final DateTime createdAt;

  const PlantAnalysisModel({
    required this.id,
    required this.plantId,
    required this.analysisType,
    this.symptoms,
    required this.healthScore,
    required this.confidence,
    this.diagnosis,
    this.recommendations,
    this.imageUrl,
    this.imageAnalysisData,
    this.temperature,
    this.humidity,
    this.ph,
    this.ec,
    this.lightIntensity,
    this.co2Level,
    this.environmentalConditions,
    this.notes,
    required this.analysisDate,
    required this.createdAt,
  });

  factory PlantAnalysisModel.fromJson(Map<String, dynamic> json) => _$PlantAnalysisModelFromJson(json);
  Map<String, dynamic> toJson() => _$PlantAnalysisModelToJson(this);

  // Helper methods
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasSymptoms => symptoms != null && symptoms!.isNotEmpty;
  bool get hasRecommendations => recommendations != null && recommendations!.isNotEmpty;
  bool get hasEnvironmentalData =>
      temperature != null || humidity != null || ph != null || ec != null;

  bool get isHealthy => healthScore >= 70;
  bool get hasWarning => healthScore >= 40 && healthScore < 70;
  bool get isCritical => healthScore < 40;

  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.6;

  bool get isHealthAnalysis => analysisType.toLowerCase() == 'health';
  bool get isGrowthAnalysis => analysisType.toLowerCase() == 'growth';
  bool get isPestAnalysis => analysisType.toLowerCase() == 'pest';
  bool get isNutrientAnalysis => analysisType.toLowerCase() == 'nutrient';

  String get healthScoreDisplay {
    return '${healthScore.toStringAsFixed(0)}/100';
  }

  String get confidenceDisplay {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  String get healthStatusDisplay {
    if (isHealthy) return 'Healthy';
    if (hasWarning) return 'Warning';
    return 'Critical';
  }

  String get confidenceLevelDisplay {
    if (isHighConfidence) return 'High';
    if (isMediumConfidence) return 'Medium';
    return 'Low';
  }

  String get analysisTypeDisplay {
    switch (analysisType.toLowerCase()) {
      case 'health':
        return 'Health Analysis';
      case 'growth':
        return 'Growth Analysis';
      case 'pest':
        return 'Pest Analysis';
      case 'nutrient':
        return 'Nutrient Analysis';
      default:
        return '${analysisType[0].toUpperCase()}${analysisType.substring(1)} Analysis';
    }
  }

  String get urgencyLevel {
    if (isCritical && isHighConfidence) return 'Urgent';
    if (isCritical) return 'High';
    if (hasWarning) return 'Medium';
    return 'Low';
  }
}

// Automation Rule Model
@JsonSerializable()
class AutomationRuleModel {
  final int id;
  final String name;
  final String? description;
  final String triggerType;
  final Map<String, dynamic> triggerCondition;
  final String actionType;
  final Map<String, dynamic> actionParameters;
  final bool isActive;
  final DateTime? lastExecutedAt;
  final DateTime? nextExecutionAt;
  final int executionCount;
  final String? schedule;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? roomId;
  final int? deviceId;

  const AutomationRuleModel({
    required this.id,
    required this.name,
    this.description,
    required this.triggerType,
    required this.triggerCondition,
    required this.actionType,
    required this.actionParameters,
    required this.isActive,
    this.lastExecutedAt,
    this.nextExecutionAt,
    required this.executionCount,
    this.schedule,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.roomId,
    this.deviceId,
  });

  factory AutomationRuleModel.fromJson(Map<String, dynamic> json) => _$AutomationRuleModelFromJson(json);
  Map<String, dynamic> toJson() => _$AutomationRuleModelToJson(this);

  // Helper methods
  bool get isTimeBased => triggerType.toLowerCase() == 'time';
  bool get isSensorBased => triggerType.toLowerCase() == 'sensor_threshold';
  bool get isManual => triggerType.toLowerCase() == 'manual';

  bool get isWateringAction => actionType.toLowerCase() == 'watering';
  bool get isLightingAction => actionType.toLowerCase() == 'lighting';
  bool get isClimateAction => actionType.toLowerCase() == 'climate';
  bool get isNotificationAction => actionType.toLowerCase() == 'notification';

  bool get hasEverExecuted => executionCount > 0;
  bool get isScheduled => schedule != null && schedule!.isNotEmpty;
  bool get isReadyToExecute {
    if (!isActive) return false;
    if (nextExecutionAt == null) return false;
    return DateTime.now().isAfter(nextExecutionAt!);
  }

  bool get isHighPriority => priority >= 8;
  bool get isMediumPriority => priority >= 5 && priority < 8;
  bool get isLowPriority => priority < 5;

  String get triggerTypeDisplay {
    switch (triggerType.toLowerCase()) {
      case 'time':
        return 'Time-based';
      case 'sensor_threshold':
        return 'Sensor Threshold';
      case 'manual':
        return 'Manual';
      default:
        return '${triggerType[0].toUpperCase()}${triggerType.substring(1)}';
    }
  }

  String get actionTypeDisplay {
    switch (actionType.toLowerCase()) {
      case 'watering':
        return 'Watering System';
      case 'lighting':
        return 'Lighting System';
      case 'climate':
        return 'Climate Control';
      case 'notification':
        return 'Send Notification';
      default:
        return '${actionType[0].toUpperCase()}${actionType.substring(1)}';
    }
  }

  String get priorityDisplay {
    if (isHighPriority) return 'High';
    if (isMediumPriority) return 'Medium';
    return 'Low';
  }

  String get statusDisplay {
    if (!isActive) return 'Inactive';
    if (isReadyToExecute) return 'Ready';
    if (nextExecutionAt == null) return 'No Schedule';
    return 'Scheduled';
  }

  String get frequencyDisplay {
    if (!isScheduled) return 'Manual';
    return schedule ?? 'Unknown';
  }

  String get lastExecutionDisplay {
    if (!hasEverExecuted) return 'Never';
    if (lastExecutedAt == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(lastExecutedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String get nextExecutionDisplay {
    if (!isScheduled) return 'Manual';
    if (nextExecutionAt == null) return 'Not scheduled';
    final now = DateTime.now();
    if (isReadyToExecute) return 'Ready now';
    final diff = nextExecutionAt!.difference(now);
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours} hours';
    return 'In ${diff.inDays} days';
  }
}

// Extension methods for JSON serialization of complex types
extension JsonExtensions on Map<String, dynamic> {
  String toJsonString() => json.encode(this);
}

extension StringJsonExtensions on String {
  Map<String, dynamic> toJsonObject() {
    try {
      return json.decode(this) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}