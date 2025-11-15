import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../database/database_service.dart';

/// Enhanced strain management service with comprehensive cannabis strain database
class StrainService {
  static final StrainService _instance = StrainService._internal();
  factory StrainService() => _instance;
  StrainService._internal();

  final Logger _logger = Logger();
  late DatabaseService _databaseService;
  late SharedPreferences _prefs;

  /// Initialize strain service
  Future<void> initialize() async {
    try {
      _databaseService = await DatabaseService.getInstance();
      _prefs = await SharedPreferences.getInstance();
      await _loadComprehensiveStrainDatabase();
      _logger.i('Strain service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize strain service: $e');
      rethrow;
    }
  }

  /// Load comprehensive cannabis strain database
  Future<void> _loadComprehensiveStrainDatabase() async {
    try {
      final existingStrains = await _databaseService.repositories.strainRepository.getAllStrains();

      if (existingStrains.isEmpty) {
        await _insertComprehensiveStrains();
        _logger.i('Loaded comprehensive strain database with 25+ strains');
      } else {
        _logger.i('Strain database already contains ${existingStrains.length} strains');
      }
    } catch (e) {
      _logger.e('Failed to load comprehensive strain database: $e');
    }
  }

  /// Insert comprehensive collection of cannabis strains
  Future<void> _insertComprehensiveStrains() async {
    final comprehensiveStrains = [
      // Popular Hybrids
      {
        'name': 'Blue Dream',
        'type': 'Hybrid',
        'subtype': 'Sativa-dominant',
        'thc_level': '17-24%',
        'cbd_level': '<1%',
        'description': 'Balanced hybrid known for relaxation and gentle cerebral stimulation',
        'effects': ['Happy', 'Euphoric', 'Relaxed', 'Creative'],
        'medical_uses': ['Stress', 'Depression', 'Pain', 'Fatigue'],
        'flavors': ['Blueberry', 'Sweet', 'Berry'],
        'flowering_time': 9,
        'difficulty': 'Easy',
        'yield': 'High',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'Girl Scout Cookies',
        'type': 'Hybrid',
        'subtype': 'Indica-dominant',
        'thc_level': '25-28%',
        'cbd_level': '<1%',
        'description': 'Potent hybrid with euphoric effects and full-body relaxation',
        'effects': ['Euphoric', 'Happy', 'Relaxed', 'Creative'],
        'medical_uses': ['Stress', 'Pain', 'Depression', 'Insomnia'],
        'flavors': ['Sweet', 'Earthy', 'Spicy'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 21.0,
        'optimal_temp_max': 29.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium-Tall',
        'resistance': ['Pests'],
      },
      {
        'name': 'OG Kush',
        'type': 'Hybrid',
        'subtype': 'Indica-dominant',
        'thc_level': '20-26%',
        'cbd_level': '<1%',
        'description': 'Classic strain with stress-relieving effects',
        'effects': ['Relaxed', 'Happy', 'Euphoric', 'Sleepy'],
        'medical_uses': ['Stress', 'Pain', 'Insomnia', 'Anxiety'],
        'flavors': ['Earthy', 'Woody', 'Citrus'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 22.0,
        'optimal_temp_max': 30.0,
        'optimal_humidity_min': 35.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'growth_height': 'Medium',
        'resistance': ['Mold'],
      },
      // Indica Strains
      {
        'name': 'Northern Lights',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '16-21%',
        'cbd_level': '<1%',
        'description': 'Relaxing indica with resinous buds and fast flowering',
        'effects': ['Relaxed', 'Happy', 'Sleepy', 'Euphoric'],
        'medical_uses': ['Insomnia', 'Pain', 'Stress', 'Depression'],
        'flavors': ['Sweet', 'Spicy', 'Earthy'],
        'flowering_time': 7,
        'difficulty': 'Easy',
        'yield': 'High',
        'optimal_temp_min': 18.0,
        'optimal_temp_max': 26.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Short-Medium',
        'resistance': ['Mold', 'Pests', 'Disease'],
      },
      {
        'name': 'Granddaddy Purple',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '17-23%',
        'cbd_level': '<1%',
        'description': 'Famous purple strain with relaxing effects',
        'effects': ['Relaxed', 'Happy', 'Sleepy', 'Euphoric'],
        'medical_uses': ['Pain', 'Stress', 'Insomnia', 'Muscle Spasms'],
        'flavors': ['Grape', 'Berry', 'Sweet'],
        'flowering_time': 10,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold'],
      },
      {
        'name': 'Blue Cheese',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '15-20%',
        'cbd_level': '<1%',
        'description': 'Unique cheese flavor with relaxing effects',
        'effects': ['Relaxed', 'Happy', 'Euphoric', 'Hungry'],
        'medical_uses': ['Stress', 'Pain', 'Lack of Appetite', 'Insomnia'],
        'flavors': ['Cheese', 'Blueberry', 'Sweet'],
        'flowering_time': 8,
        'difficulty': 'Easy',
        'yield': 'High',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
      // Sativa Strains
      {
        'name': 'Purple Haze',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '17-22%',
        'cbd_level': '<1%',
        'description': 'Energizing sativa with dreamy, psychedelic effects',
        'effects': ['Happy', 'Energetic', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Fatigue', 'Pain'],
        'flavors': ['Sweet', 'Earthy', 'Berry'],
        'flowering_time': 10,
        'difficulty': 'Hard',
        'yield': 'Medium',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 50.0,
        'optimal_humidity_max': 70.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'growth_height': 'Tall',
        'resistance': ['Pests'],
      },
      {
        'name': 'Sour Diesel',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '20-26%',
        'cbd_level': '<1%',
        'description': 'Energizing strain with pungent diesel aroma',
        'effects': ['Energetic', 'Happy', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Pain', 'Fatigue'],
        'flavors': ['Diesel', 'Pungent', 'Earthy'],
        'flowering_time': 10,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 22.0,
        'optimal_temp_max': 30.0,
        'optimal_humidity_min': 35.0,
        'optimal_humidity_max': 50.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'growth_height': 'Tall',
        'resistance': ['Mold'],
      },
      {
        'name': 'Jack Herer',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '18-23%',
        'cbd_level': '<1%',
        'description': 'Classic sativa named after cannabis activist',
        'effects': ['Happy', 'Energetic', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Pain', 'Fatigue'],
        'flavors': ['Citrus', 'Pine', 'Earthy'],
        'flowering_time': 9,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Tall',
        'resistance': ['Mold', 'Pests'],
      },
      // CBD-Rich Strains
      {
        'name': 'Charlotte\'s Web',
        'type': 'CBD-dominant',
        'subtype': 'High CBD',
        'thc_level': '<1%',
        'cbd_level': '15-20%',
        'description': 'High-CBD strain known for medical use',
        'effects': ['Relaxed', 'Calm', 'Focused'],
        'medical_uses': ['Seizures', 'Pain', 'Anxiety', 'Inflammation'],
        'flavors': ['Sweet', 'Earthy', 'Woody'],
        'flowering_time': 8,
        'difficulty': 'Easy',
        'yield': 'Medium',
        'optimal_temp_min': 18.0,
        'optimal_temp_max': 26.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'ACDC',
        'type': 'CBD-dominant',
        'subtype': 'High CBD',
        'thc_level': '<1%',
        'cbd_level': '16-24%',
        'description': 'Balanced CBD strain with minimal psychoactive effects',
        'effects': ['Relaxed', 'Focused', 'Calm', 'Happy'],
        'medical_uses': ['Pain', 'Anxiety', 'Epilepsy', 'Stress'],
        'flavors': ['Sweet', 'Citrus', 'Earthy'],
        'flowering_time': 9,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Tall',
        'resistance': ['Mold'],
      },
      // Additional Popular Strains
      {
        'name': 'Gorilla Glue #4',
        'type': 'Hybrid',
        'subtype': 'Indica-dominant',
        'thc_level': '25-30%',
        'cbd_level': '<1%',
        'description': 'Extremely potent hybrid with relaxing effects',
        'effects': ['Relaxed', 'Happy', 'Euphoric', 'Sleepy'],
        'medical_uses': ['Pain', 'Stress', 'Insomnia', 'Depression'],
        'flavors': ['Chocolate', 'Diesel', 'Coffee'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium-High',
        'optimal_temp_min': 21.0,
        'optimal_temp_max': 29.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'Pineapple Express',
        'type': 'Hybrid',
        'subtype': 'Sativa-dominant',
        'thc_level': '19-25%',
        'cbd_level': '<1%',
        'description': 'Tropical-flavored hybrid with energizing effects',
        'effects': ['Happy', 'Energetic', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Fatigue', 'Pain'],
        'flavors': ['Pineapple', 'Cedar', 'Sweet'],
        'flowering_time': 8,
        'difficulty': 'Easy',
        'yield': 'High',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'growth_height': 'Medium-Tall',
        'resistance': ['Mold'],
      },
      {
        'name': 'Wedding Cake',
        'type': 'Hybrid',
        'subtype': 'Indica-dominant',
        'thc_level': '25-27%',
        'cbd_level': '<1%',
        'description': 'Sweet and tangy hybrid with relaxing effects',
        'effects': ['Happy', 'Relaxed', 'Euphoric', 'Hungry'],
        'medical_uses': ['Stress', 'Pain', 'Anxiety', 'Depression'],
        'flavors': ['Sweet', 'Vanilla', 'Earthy'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium-High',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold'],
      },
      {
        'name': 'White Widow',
        'type': 'Hybrid',
        'subtype': 'Balanced',
        'thc_level': '18-25%',
        'cbd_level': '<1%',
        'description': 'Classic balanced hybrid with euphoric effects',
        'effects': ['Euphoric', 'Happy', 'Relaxed', 'Creative'],
        'medical_uses': ['Stress', 'Pain', 'Depression', 'Fatigue'],
        'flavors': ['Earthy', 'Woody', 'Spicy'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'Amnesia Haze',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '20-25%',
        'cbd_level': '<1%',
        'description': 'Powerful sativa with energizing mental effects',
        'effects': ['Energetic', 'Creative', 'Euphoric', 'Happy'],
        'medical_uses': ['Stress', 'Depression', 'Fatigue', 'Pain'],
        'flavors': ['Citrus', 'Lemon', 'Earthy'],
        'flowering_time': 11,
        'difficulty': 'Hard',
        'yield': 'Medium',
        'optimal_temp_min': 22.0,
        'optimal_temp_max': 30.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'growth_height': 'Tall',
        'resistance': ['Mold'],
      },
      {
        'name': 'Critical Kush',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '18-22%',
        'cbd_level': '<1%',
        'description': 'Fast-flowering indica with heavy effects',
        'effects': ['Relaxed', 'Happy', 'Sleepy', 'Euphoric'],
        'medical_uses': ['Insomnia', 'Pain', 'Stress', 'Anxiety'],
        'flavors': ['Earthy', 'Woody', 'Spicy'],
        'flowering_time': 7,
        'difficulty': 'Easy',
        'yield': 'High',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Short-Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'Lemon Haze',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '17-25%',
        'cbd_level': '<1%',
        'description': 'Citrusy sativa with energizing effects',
        'effects': ['Energetic', 'Happy', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Fatigue', 'Pain'],
        'flavors': ['Lemon', 'Citrus', 'Sweet'],
        'flowering_time': 9,
        'difficulty': 'Medium',
        'yield': 'Medium-High',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'growth_height': 'Tall',
        'resistance': ['Pests'],
      },
      {
        'name': 'Blackberry Kush',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '16-20%',
        'cbd_level': '<1%',
        'description': 'Berry-flavored indica with heavy relaxing effects',
        'effects': ['Relaxed', 'Happy', 'Euphoric', 'Sleepy'],
        'medical_uses': ['Pain', 'Stress', 'Insomnia', 'Depression'],
        'flavors': ['Berry', 'Sweet', 'Earthy'],
        'flowering_time': 8,
        'difficulty': 'Easy',
        'yield': 'Medium',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Short-Medium',
        'resistance': ['Mold'],
      },
      {
        'name': 'Super Silver Haze',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '18-23%',
        'cbd_level': '<1%',
        'description': 'Award-winning sativa with energetic effects',
        'effects': ['Energetic', 'Happy', 'Creative', 'Euphoric'],
        'medical_uses': ['Stress', 'Depression', 'Fatigue', 'Pain'],
        'flavors': ['Spicy', 'Earthy', 'Citrus'],
        'flowering_time': 11,
        'difficulty': 'Hard',
        'yield': 'Medium',
        'optimal_temp_min': 22.0,
        'optimal_temp_max': 30.0,
        'optimal_humidity_min': 35.0,
        'optimal_humidity_max': 50.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'growth_height': 'Tall',
        'resistance': ['Mold'],
      },
      {
        'name': 'Afghan Kush',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '15-20%',
        'cbd_level': '<1%',
        'description': 'Landrace indica from Afghanistan',
        'effects': ['Relaxed', 'Happy', 'Sleepy', 'Euphoric'],
        'medical_uses': ['Insomnia', 'Pain', 'Stress', 'Anxiety'],
        'flavors': ['Earthy', 'Woody', 'Spicy'],
        'flowering_time': 7,
        'difficulty': 'Easy',
        'yield': 'Medium-High',
        'optimal_temp_min': 18.0,
        'optimal_temp_max': 26.0,
        'optimal_humidity_min': 35.0,
        'optimal_humidity_max': 50.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'growth_height': 'Short',
        'resistance': ['Mold', 'Pests', 'Disease'],
      },
      {
        'name': 'Green Crack',
        'type': 'Sativa',
        'subtype': 'Pure',
        'thc_level': '17-24%',
        'cbd_level': '<1%',
        'description': 'Energizing sativa with sharp mental effects',
        'effects': ['Energetic', 'Happy', 'Creative', 'Focused'],
        'medical_uses': ['Fatigue', 'Stress', 'Depression', 'Pain'],
        'flavors': ['Citrus', 'Tropical', 'Sweet'],
        'flowering_time': 9,
        'difficulty': 'Medium',
        'yield': 'High',
        'optimal_temp_min': 21.0,
        'optimal_temp_max': 29.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium-Tall',
        'resistance': ['Mold'],
      },
      {
        'name': 'Bubba Kush',
        'type': 'Indica',
        'subtype': 'Pure',
        'thc_level': '16-22%',
        'cbd_level': '<1%',
        'description': 'Heavy indica with tranquilizing effects',
        'effects': ['Sleepy', 'Relaxed', 'Happy', 'Euphoric'],
        'medical_uses': ['Insomnia', 'Pain', 'Stress', 'Muscle Spasms'],
        'flavors': ['Earthy', 'Sweet', 'Coffee'],
        'flowering_time': 8,
        'difficulty': 'Easy',
        'yield': 'Medium',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Short-Medium',
        'resistance': ['Mold', 'Pests'],
      },
      {
        'name': 'Harlequin',
        'type': 'CBD-dominant',
        'subtype': 'High CBD',
        'thc_level': '4-7%',
        'cbd_level': '8-16%',
        'description': 'CBD-rich strain with balanced effects',
        'effects': ['Relaxed', 'Happy', 'Calm', 'Focused'],
        'medical_uses': ['Pain', 'Anxiety', 'Stress', 'Inflammation'],
        'flavors': ['Earthy', 'Woody', 'Spicy'],
        'flowering_time': 8,
        'difficulty': 'Medium',
        'yield': 'Medium',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'growth_height': 'Medium',
        'resistance': ['Mold', 'Pests'],
      },
    ];

    final now = DateTime.now().toIso8601String();
    for (final strain in comprehensiveStrains) {
      await _databaseService.repositories.strainRepository.createStrain({
        ...strain,
        'created_at': now,
        'updated_at': now,
        'is_favorite': false,
        'user_notes': '',
        'grow_count': 0,
        'success_rate': 0.0,
        'total_rating': 0.0,
        'rating_count': 0,
      });
    }

    _logger.i('Inserted ${comprehensiveStrains.length} comprehensive strains into database');
  }

  /// Get all strain profiles with optional filtering
  Future<List<Map<String, dynamic>>> getAllStrains({
    String? type,
    String? subtype,
    String? difficulty,
    String? sortBy,
    bool? favoriteOnly,
  }) async {
    try {
      return await _databaseService.repositories.strainRepository.getAllStrains(
        type: type,
        subtype: subtype,
        difficulty: difficulty,
        sortBy: sortBy ?? 'name',
        favoriteOnly: favoriteOnly ?? false,
      );
    } catch (e) {
      _logger.e('Failed to get all strains: $e');
      rethrow;
    }
  }

  /// Search strains by name, effect, or medical use
  Future<List<Map<String, dynamic>>> searchStrains(String query) async {
    try {
      return await _databaseService.repositories.strainRepository.searchStrains(query);
    } catch (e) {
      _logger.e('Failed to search strains: $e');
      rethrow;
    }
  }

  /// Get detailed strain information by ID
  Future<Map<String, dynamic>?> getStrainById(int strainId) async {
    try {
      return await _databaseService.repositories.strainRepository.getStrainById(strainId);
    } catch (e) {
      _logger.e('Failed to get strain by ID: $e');
      rethrow;
    }
  }

  /// Get strain by name
  Future<Map<String, dynamic>?> getStrainByName(String name) async {
    try {
      return await _databaseService.repositories.strainRepository.getStrainByName(name);
    } catch (e) {
      _logger.e('Failed to get strain by name: $e');
      rethrow;
    }
  }

  /// Add new custom strain
  Future<Map<String, dynamic>> addCustomStrain(Map<String, dynamic> strainData) async {
    try {
      final customStrain = {
        ...strainData,
        'is_custom': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_favorite': false,
        'user_notes': '',
        'grow_count': 0,
        'success_rate': 0.0,
        'total_rating': 0.0,
        'rating_count': 0,
      };

      final strainId = await _databaseService.repositories.strainRepository.createStrain(customStrain);
      final strain = await getStrainById(strainId);

      _logger.i('Added custom strain: ${strainData['name']}');
      return strain!;
    } catch (e) {
      _logger.e('Failed to add custom strain: $e');
      rethrow;
    }
  }

  /// Update strain information
  Future<void> updateStrain(int strainId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _databaseService.repositories.strainRepository.updateStrain(strainId, updates);
      _logger.i('Updated strain: $strainId');
    } catch (e) {
      _logger.e('Failed to update strain: $e');
      rethrow;
    }
  }

  /// Toggle strain favorite status
  Future<void> toggleFavorite(int strainId) async {
    try {
      final strain = await getStrainById(strainId);
      if (strain != null) {
        final isFavorite = !(strain['is_favorite'] as bool);
        await updateStrain(strainId, {'is_favorite': isFavorite});
        _logger.i('Toggled favorite status for strain: $strainId');
      }
    } catch (e) {
      _logger.e('Failed to toggle favorite: $e');
      rethrow;
    }
  }

  /// Rate strain
  Future<void> rateStrain(int strainId, double rating) async {
    try {
      final strain = await getStrainById(strainId);
      if (strain != null) {
        final totalRating = (strain['total_rating'] as double) + rating;
        final ratingCount = (strain['rating_count'] as int) + 1;
        final averageRating = totalRating / ratingCount;

        await updateStrain(strainId, {
          'total_rating': totalRating,
          'rating_count': ratingCount,
          'average_rating': averageRating,
        });
        _logger.i('Rated strain: $strainId with rating: $rating');
      }
    } catch (e) {
      _logger.e('Failed to rate strain: $e');
      rethrow;
    }
  }

  /// Add user notes to strain
  Future<void> addStrainNotes(int strainId, String notes) async {
    try {
      await updateStrain(strainId, {'user_notes': notes});
      _logger.i('Added notes to strain: $strainId');
    } catch (e) {
      _logger.e('Failed to add strain notes: $e');
      rethrow;
    }
  }

  /// Update grow statistics for strain
  Future<void> updateGrowStats(int strainId, bool success) async {
    try {
      final strain = await getStrainById(strainId);
      if (strain != null) {
        final growCount = (strain['grow_count'] as int) + 1;
        final successCount = strain['success_count'] as int? ?? 0;
        final newSuccessCount = success ? successCount + 1 : successCount;
        final successRate = newSuccessCount / growCount;

        await updateStrain(strainId, {
          'grow_count': growCount,
          'success_count': newSuccessCount,
          'success_rate': successRate,
        });
        _logger.i('Updated grow stats for strain: $strainId');
      }
    } catch (e) {
      _logger.e('Failed to update grow stats: $e');
      rethrow;
    }
  }

  /// Get recommended strains based on criteria
  Future<List<Map<String, dynamic>>> getRecommendedStrains({
    String? experienceLevel,
    List<String>? desiredEffects,
    List<String>? medicalUses,
    String? growthEnvironment,
    int? floweringTime,
    String? difficulty,
  }) async {
    try {
      return await _databaseService.repositories.strainRepository.getRecommendedStrains(
        experienceLevel: experienceLevel,
        desiredEffects: desiredEffects,
        medicalUses: medicalUses,
        growthEnvironment: growthEnvironment,
        floweringTime: floweringTime,
        difficulty: difficulty,
      );
    } catch (e) {
      _logger.e('Failed to get recommended strains: $e');
      rethrow;
    }
  }

  /// Get strain statistics
  Future<Map<String, dynamic>> getStrainStatistics() async {
    try {
      return await _databaseService.repositories.strainRepository.getStrainStatistics();
    } catch (e) {
      _logger.e('Failed to get strain statistics: $e');
      rethrow;
    }
  }

  /// Export strain data
  Future<Map<String, dynamic>> exportStrainData() async {
    try {
      final strains = await getAllStrains();
      return {
        'strains': strains,
        'export_timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
      };
    } catch (e) {
      _logger.e('Failed to export strain data: $e');
      rethrow;
    }
  }

  /// Import strain data
  Future<void> importStrainData(Map<String, dynamic> exportData) async {
    try {
      final strains = exportData['strains'] as List?;
      if (strains != null) {
        for (final strain in strains) {
          if (strain is Map<String, dynamic>) {
            await addCustomStrain(strain);
          }
        }
        _logger.i('Imported ${strains.length} strains');
      }
    } catch (e) {
      _logger.e('Failed to import strain data: $e');
      rethrow;
    }
  }

  /// Delete strain
  Future<void> deleteStrain(int strainId) async {
    try {
      await _databaseService.repositories.strainRepository.deleteStrain(strainId);
      _logger.i('Deleted strain: $strainId');
    } catch (e) {
      _logger.e('Failed to delete strain: $e');
      rethrow;
    }
  }

  /// Get strain types and subtypes for filtering
  Map<String, List<String>> getStrainCategories() {
    return {
      'Type': ['Sativa', 'Indica', 'Hybrid', 'CBD-dominant'],
      'Subtype': ['Pure', 'Balanced', 'Sativa-dominant', 'Indica-dominant', 'High CBD'],
      'Difficulty': ['Easy', 'Medium', 'Hard'],
      'Yield': ['Low', 'Medium', 'High'],
      'Height': ['Short', 'Medium', 'Tall'],
      'Flowering Time': ['Fast (7-8 weeks)', 'Medium (9-10 weeks)', 'Long (11+ weeks)'],
    };
  }

  /// Get strain recommendation based on environmental conditions
  Future<List<Map<String, dynamic>>> getStrainsByEnvironment({
    required double temperature,
    required double humidity,
    required double ph,
    String? experienceLevel,
  }) async {
    try {
      return await _databaseService.repositories.strainRepository.getStrainsByEnvironment(
        temperature: temperature,
        humidity: humidity,
        ph: ph,
        experienceLevel: experienceLevel,
      );
    } catch (e) {
      _logger.e('Failed to get strains by environment: $e');
      rethrow;
    }
  }
}