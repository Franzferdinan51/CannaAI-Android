import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';

import '../database/comprehensive_database.dart';
import '../models/comprehensive/data_models.dart';
import 'comprehensive_api_service.dart';
import 'package:riverpod/riverpod.dart';

/// Comprehensive Analytics Service
///
/// Provides advanced analytics, charts, and data visualization
/// for cultivation operations with detailed insights and reporting
class ComprehensiveAnalyticsService {
  final AppDatabase _database;
  final ComprehensiveApiService _apiService;

  // Data streams
  final _analyticsController = StreamController<AnalyticsData>.broadcast();
  final _chartsController = StreamController<List<ChartData>>.broadcast();
  final _reportsController = StreamController<List<AnalyticsReport>>.broadcast();
  final _insightsController = StreamController<List<CultivationInsight>>.broadcast();

  // Caching
  AnalyticsData? _cachedAnalytics;
  List<ChartData>? _cachedCharts;
  List<AnalyticsReport>? _cachedReports;
  DateTime? _lastCacheUpdate;

  // Constants
  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const int _maxDataPoints = 1000;
  static const int _sampleIntervalHours = 1;

  ComprehensiveAnalyticsService({
    required AppDatabase database,
    required ComprehensiveApiService apiService,
  }) : _database = database, _apiService = apiService {
    _initializeAnalytics();
  }

  // Getters
  Stream<AnalyticsData> get analyticsStream => _analyticsController.stream;
  Stream<List<ChartData>> get chartsStream => _chartsController.stream;
  Stream<List<AnalyticsReport>> get reportsStream => _reportsController.stream;
  Stream<List<CultivationInsight>> get insightsStream => _insightsController.stream;

  Future<void> _initializeAnalytics() async {
    try {
      // Load cached analytics if available
      await _loadCachedAnalytics();

      // Start periodic analytics updates
      Timer.periodic(Duration(minutes: 15), (_) => _refreshAnalytics());

      debugPrint('Analytics service initialized');
    } catch (e) {
      debugPrint('Error initializing analytics: $e');
    }
  }

  /// Load cached analytics data
  Future<void> _loadCachedAnalytics() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/analytics_cache.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final cachedData = jsonDecode(jsonString);
        _lastCacheUpdate = DateTime.parse(cachedData['lastUpdate']);

        if (DateTime.now().difference(_lastCacheUpdate!) < _cacheTimeout) {
          _cachedAnalytics = AnalyticsData.fromJson(cachedData['analytics']);
          _cachedCharts = (cachedData['charts'] as List)
              .map((e) => ChartData.fromJson(e))
              .toList();
          _cachedReports = (cachedData['reports'] as List)
              .map((e) => AnalyticsReport.fromJson(e))
              .toList();

          _analyticsController.add(_cachedAnalytics!);
          _chartsController.add(_cachedCharts!);
          _reportsController.add(_cachedReports!);

          debugPrint('Loaded cached analytics data');
        }
      }
    } catch (e) {
      debugPrint('Error loading cached analytics: $e');
    }
  }

  /// Save analytics data to cache
  Future<void> _saveAnalyticsCache() async {
    try {
      if (_cachedAnalytics == null || _cachedCharts == null || _cachedReports == null) {
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/analytics_cache.json');

      final cacheData = {
        'lastUpdate': DateTime.now().toIso8601String(),
        'analytics': _cachedAnalytics!.toJson(),
        'charts': _cachedCharts!.map((e) => e.toJson()).toList(),
        'reports': _cachedReports!.map((e) => e.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(cacheData));
      debugPrint('Saved analytics cache');
    } catch (e) {
      debugPrint('Error saving analytics cache: $e');
    }
  }

  /// Refresh all analytics data
  Future<void> _refreshAnalytics() async {
    try {
      final analytics = await generateAnalyticsData();
      final charts = await generateChartData();
      final reports = await generateAnalyticsReports();

      _cachedAnalytics = analytics;
      _cachedCharts = charts;
      _cachedReports = reports;
      _lastCacheUpdate = DateTime.now();

      _analyticsController.add(analytics);
      _chartsController.add(charts);
      _reportsController.add(reports);

      await _saveAnalyticsCache();

      // Generate insights
      final insights = await generateCultivationInsights(analytics);
      _insightsController.add(insights);

    } catch (e) {
      debugPrint('Error refreshing analytics: $e');
    }
  }

  /// Generate comprehensive analytics data
  Future<AnalyticsData> generateAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
    String? roomId,
  }) async {
    try {
      final now = DateTime.now();
      final effectiveStartDate = startDate ?? now.subtract(Duration(days: 30));
      final effectiveEndDate = endDate ?? now;

      // Fetch data for analytics
      final sensorDataQuery = drift.SelectStatement(_database.select(_database.sensorDataTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(effectiveStartDate, effectiveEndDate)));

      if (roomId != null) {
        sensorDataQuery.where((tbl) => tbl.roomId.equals(roomId));
      }

      final sensorData = await sensorDataQuery.get();
      final analysisResults = await (_database.select(_database.analysisResultsTable)
          ..where((tbl) => tbl.analysisDate.isBetweenValues(effectiveStartDate, effectiveEndDate)))
          .get();

      final harvestRecords = await (_database.select(_database.harvestRecordsTable)
          ..where((tbl) => tbl.harvestDate.isBetweenValues(effectiveStartDate, effectiveEndDate)))
          .get();

      final plants = await (_database.select(_database.plantsTable)).get();

      // Generate metrics
      final overviewMetrics = await _generateOverviewMetrics(
        effectiveStartDate,
        effectiveEndDate,
        roomId
      );

      final growthMetrics = _calculateGrowthMetrics(plants, analysisResults);
      final yieldMetrics = _calculateYieldMetrics(harvestRecords);
      final environmentalMetrics = _calculateEnvironmentalMetrics(sensorData);
      final automationMetrics = await _calculateAutomationMetrics(effectiveStartDate, effectiveEndDate);
      final financialMetrics = await _calculateFinancialMetrics(harvestRecords, effectiveStartDate, effectiveEndDate);

      return AnalyticsData(
        overview: overviewMetrics,
        growth: growthMetrics,
        yield: yieldMetrics,
        environmental: environmentalMetrics,
        automation: automationMetrics,
        financial: financialMetrics,
        generatedAt: now,
        dateRange: AnalyticsDateRange(
          startDate: effectiveStartDate,
          endDate: effectiveEndDate,
        ),
      );
    } catch (e) {
      debugPrint('Error generating analytics data: $e');
      return _createEmptyAnalyticsData();
    }
  }

  /// Generate overview metrics
  Future<OverviewMetrics> _generateOverviewMetrics(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      // Get current plants count
      final plantsQuery = drift.SelectStatement(_database.select(_database.plantsTable));
      if (roomId != null) {
        plantsQuery.where((tbl) => tbl.roomId.equals(roomId));
      }
      final currentPlants = await plantsQuery.get();

      // Get active rooms count
      final rooms = roomId != null
          ? await (_database.select(_database.roomsTable)
              ..where((tbl) => tbl.id.equals(roomId))).get()
          : await (_database.select(_database.roomsTable)).get();

      final activeRooms = rooms.where((r) => r.isActive).length;

      // Get analysis count
      final analysisQuery = drift.SelectStatement(_database.select(_database.analysisResultsTable)
          ..where((tbl) => tbl.analysisDate.isBetweenValues(startDate, endDate)));
      if (roomId != null) {
        analysisQuery.where((tbl) => tbl.roomId.equals(roomId)));
      }
      final analyses = await analysisQuery.get();

      // Get automation status
      final automationQuery = drift.SelectStatement(_database.select(_database.automationRulesTable));
      if (roomId != null) {
        automationQuery.where((tbl) => tbl.roomId.equals(roomId)));
      }
      final automationRules = await automationQuery.get();
      final activeRules = automationRules.where((r) => r.isEnabled).length;

      return OverviewMetrics(
        totalPlants: currentPlants.length,
        activeRooms: activeRooms,
        totalAnalyses: analyses.length,
        healthScore: _calculateHealthScore(analyses),
        automationEfficiency: _calculateAutomationEfficiency(analyses),
        productivityIndex: _calculateProductivityIndex(currentPlants, analyses),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error generating overview metrics: $e');
      return OverviewMetrics(
        totalPlants: 0,
        activeRooms: 0,
        totalAnalyses: 0,
        healthScore: 0.0,
        automationEfficiency: 0.0,
        productivityIndex: 0.0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Calculate growth metrics
  GrowthMetrics _calculateGrowthMetrics(
    List<PlantData> plants,
    List<AnalysisResultData> analyses,
  ) {
    try {
      final growthStages = plants.groupListsBy((p) => p.growthStage);
      final averageGrowthRate = _calculateAverageGrowthRate(analyses);
      final healthyPlants = analyses.where((a) => a.healthScore > 0.7).length;
      final totalPlants = plants.isNotEmpty ? plants.length : 1;

      return GrowthMetrics(
        averageGrowthRate: averageGrowthRate,
        healthyPlantPercentage: (healthyPlants / totalPlants) * 100,
        growthStageDistribution: growthStages.map((stage, plants) =>
            MapEntry(stage, plants.length.toDouble())).toMap(),
        averagePlantHeight: _calculateAveragePlantHeight(analyses),
        averageLeafCount: _calculateAverageLeafCount(analyses),
        growthVelocity: _calculateGrowthVelocity(analyses),
        estimatedHarvestDate: _estimateHarvestDate(plants),
      );
    } catch (e) {
      debugPrint('Error calculating growth metrics: $e');
      return GrowthMetrics(
        averageGrowthRate: 0.0,
        healthyPlantPercentage: 0.0,
        growthStageDistribution: {},
        averagePlantHeight: 0.0,
        averageLeafCount: 0.0,
        growthVelocity: 0.0,
        estimatedHarvestDate: null,
      );
    }
  }

  /// Calculate yield metrics
  YieldMetrics _calculateYieldMetrics(List<HarvestRecordData> harvests) {
    try {
      if (harvests.isEmpty) {
        return YieldMetrics(
          totalYield: 0.0,
          averageYieldPerPlant: 0.0,
          yieldByStrain: {},
          yieldTrend: YieldTrend.stable,
          qualityDistribution: {},
          harvestEfficiency: 0.0,
          topPerformingStrains: [],
          projectedYield: 0.0,
        );
      }

      final totalYield = harvests.fold<double>(
          0.0, (sum, h) => sum + (h.totalWeight ?? 0.0));

      final averageYieldPerPlant = harvests.fold<double>(
          0.0, (sum, h) => sum + (h.weightPerPlant ?? 0.0)) / harvests.length;

      final yieldByStrain = harvests.groupListsBy((h) => h.strain).map(
        (strain, records) => MapEntry(
          strain,
          records.fold<double>(0.0, (sum, r) => sum + (r.totalWeight ?? 0.0)),
        ),
      );

      final yieldTrend = _calculateYieldTrend(harvests);
      final qualityDistribution = _calculateQualityDistribution(harvests);

      return YieldMetrics(
        totalYield: totalYield,
        averageYieldPerPlant: averageYieldPerPlant,
        yieldByStrain: yieldByStrain,
        yieldTrend: yieldTrend,
        qualityDistribution: qualityDistribution,
        harvestEfficiency: _calculateHarvestEfficiency(harvests),
        topPerformingStrains: _getTopPerformingStrains(yieldByStrain),
        projectedYield: _projectYield(harvests),
      );
    } catch (e) {
      debugPrint('Error calculating yield metrics: $e');
      return YieldMetrics(
        totalYield: 0.0,
        averageYieldPerPlant: 0.0,
        yieldByStrain: {},
        yieldTrend: YieldTrend.stable,
        qualityDistribution: {},
        harvestEfficiency: 0.0,
        topPerformingStrains: [],
        projectedYield: 0.0,
      );
    }
  }

  /// Calculate environmental metrics
  EnvironmentalMetrics _calculateEnvironmentalMetrics(List<SensorDataPoint> sensorData) {
    try {
      if (sensorData.isEmpty) {
        return EnvironmentalMetrics(
          averageTemperature: 0.0,
          averageHumidity: 0.0,
          averagePh: 0.0,
          averageEc: 0.0,
          averageCo2: 0.0,
          temperatureStability: 0.0,
          humidityStability: 0.0,
          optimalEnvironmentScore: 0.0,
          environmentAlerts: [],
        );
      }

      final temps = sensorData.map((s) => s.temperature).toList();
      final humidities = sensorData.map((s) => s.humidity).toList();
      final phs = sensorData.map((s) => s.ph).where((p) => p != null).cast<double>().toList();
      final ecs = sensorData.map((s) => s.ec).where((e) => e != null).cast<double>().toList();
      final co2s = sensorData.map((s) => s.co2).where((c) => c != null).cast<double>().toList();

      final averageTemp = temps.reduce((a, b) => a + b) / temps.length;
      final averageHumidity = humidities.reduce((a, b) => a + b) / humidities.length;
      final averagePh = phs.isNotEmpty ? phs.reduce((a, b) => a + b) / phs.length : 0.0;
      final averageEc = ecs.isNotEmpty ? ecs.reduce((a, b) => a + b) / ecs.length : 0.0;
      final averageCo2 = co2s.isNotEmpty ? co2s.reduce((a, b) => a + b) / co2s.length : 0.0;

      final tempStability = _calculateStability(temps);
      final humidityStability = _calculateStability(humidities);

      final alerts = _generateEnvironmentAlerts(averageTemp, averageHumidity, averagePh, averageEc);

      return EnvironmentalMetrics(
        averageTemperature: averageTemp,
        averageHumidity: averageHumidity,
        averagePh: averagePh,
        averageEc: averageEc,
        averageCo2: averageCo2,
        temperatureStability: tempStability,
        humidityStability: humidityStability,
        optimalEnvironmentScore: _calculateOptimalEnvironmentScore(
          averageTemp, averageHumidity, averagePh, averageEc
        ),
        environmentAlerts: alerts,
      );
    } catch (e) {
      debugPrint('Error calculating environmental metrics: $e');
      return EnvironmentalMetrics(
        averageTemperature: 0.0,
        averageHumidity: 0.0,
        averagePh: 0.0,
        averageEc: 0.0,
        averageCo2: 0.0,
        temperatureStability: 0.0,
        humidityStability: 0.0,
        optimalEnvironmentScore: 0.0,
        environmentAlerts: [],
      );
    }
  }

  /// Calculate automation metrics
  Future<AutomationMetrics> _calculateAutomationMetrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final rules = await (_database.select(_database.automationRulesTable)
          ..where((tbl) => tbl.createdAt.isBetweenValues(startDate, endDate))).get();

      final activeRules = rules.where((r) => r.isEnabled).length;
      final automationLogs = await (_database.select(_database.automationLogsTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))).get();

      final successfulAutomations = automationLogs.where((log) =>
          log.action.contains('completed') || log.action.contains('success')).length;

      final failures = automationLogs.length - successfulAutomations;

      return AutomationMetrics(
        activeRules: activeRules,
        totalExecutions: automationLogs.length,
        successRate: automationLogs.isNotEmpty
            ? (successfulAutomations / automationLogs.length) * 100
            : 0.0,
        averageExecutionTime: _calculateAverageExecutionTime(automationLogs),
        savedLaborHours: _calculateSavedLaborHours(automationLogs),
        resourceOptimization: _calculateResourceOptimization(automationLogs),
        mostActiveRule: _getMostActiveRule(automationLogs),
        leastActiveRule: _getLeastActiveRule(automationLogs),
        automationEfficiency: _calculateAutomationEfficiency(automationLogs),
      );
    } catch (e) {
      debugPrint('Error calculating automation metrics: $e');
      return AutomationMetrics(
        activeRules: 0,
        totalExecutions: 0,
        successRate: 0.0,
        averageExecutionTime: 0.0,
        savedLaborHours: 0.0,
        resourceOptimization: 0.0,
        mostActiveRule: '',
        leastActiveRule: '',
        automationEfficiency: 0.0,
      );
    }
  }

  /// Calculate financial metrics
  Future<FinancialMetrics> _calculateFinancialMetrics(
    List<HarvestRecordData> harvests,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // For demonstration, using mock financial data
      // In real implementation, this would connect to financial data sources

      final totalRevenue = harvests.fold<double>(
          0.0, (sum, h) => sum + (h.estimatedYieldGrams ?? 0.0) * 10.0); // $10/gram

      final operationalCosts = _calculateOperationalCosts(startDate, endDate);
      final laborCosts = _calculateLaborCosts(startDate, endDate);
      final utilityCosts = _calculateUtilityCosts(startDate, endDate);
      final supplyCosts = _calculateSupplyCosts(startDate, endDate);

      final totalCosts = operationalCosts + laborCosts + utilityCosts + supplyCosts;
      final netProfit = totalRevenue - totalCosts;

      final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

      return FinancialMetrics(
        totalRevenue: totalRevenue,
        totalCosts: totalCosts,
        netProfit: netProfit,
        profitMargin: profitMargin,
        operationalCosts: operationalCosts,
        laborCosts: laborCosts,
        utilityCosts: utilityCosts,
        supplyCosts: supplyCosts,
        averageRevenuePerHarvest: harvests.isNotEmpty ? totalRevenue / harvests.length : 0.0,
        costPerGram: harvests.isNotEmpty ? totalCosts / harvests.fold(0.0, (sum, h) => sum + (h.estimatedYieldGrams ?? 0.0)) : 0.0,
        returnOnInvestment: _calculateROI(totalRevenue, totalCosts),
        projectedMonthlyProfit: _projectMonthlyProfit(netProfit),
      );
    } catch (e) {
      debugPrint('Error calculating financial metrics: $e');
      return FinancialMetrics(
        totalRevenue: 0.0,
        totalCosts: 0.0,
        netProfit: 0.0,
        profitMargin: 0.0,
        operationalCosts: 0.0,
        laborCosts: 0.0,
        utilityCosts: 0.0,
        supplyCosts: 0.0,
        averageRevenuePerHarvest: 0.0,
        costPerGram: 0.0,
        returnOnInvestment: 0.0,
        projectedMonthlyProfit: 0.0,
      );
    }
  }

  /// Generate chart data for visualization
  Future<List<ChartData>> generateChartData({
    ChartType? type,
    String? roomId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final charts = <ChartData>[];
      final effectiveStartDate = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final effectiveEndDate = endDate ?? DateTime.now();

      // Temperature trend chart
      charts.add(await _generateTemperatureChart(effectiveStartDate, effectiveEndDate, roomId));

      // Humidity trend chart
      charts.add(await _generateHumidityChart(effectiveStartDate, effectiveEndDate, roomId));

      // Plant growth chart
      charts.add(await _generateGrowthChart(effectiveStartDate, effectiveEndDate, roomId));

      // Yield by strain chart
      charts.add(await _generateYieldChart(effectiveStartDate, effectiveEndDate, roomId));

      // Health score chart
      charts.add(await _generateHealthScoreChart(effectiveStartDate, effectiveEndDate, roomId));

      // Automation efficiency chart
      charts.add(await _generateAutomationChart(effectiveStartDate, effectiveEndDate, roomId));

      // Environmental conditions chart
      charts.add(await _generateEnvironmentalChart(effectiveStartDate, effectiveEndDate, roomId));

      return charts.where((chart) => chart.dataPoints.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error generating chart data: $e');
      return [];
    }
  }

  /// Generate temperature trend chart
  Future<ChartData> _generateTemperatureChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.sensorDataTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.timestamp)]));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final sensorData = await query.get();

      // Sample data to avoid too many points
      final sampledData = _sampleData(sensorData, _maxDataPoints ~/ 4);

      final dataPoints = sampledData.map((data) => ChartDataPoint(
        x: data.timestamp.millisecondsSinceEpoch.toDouble(),
        y: data.temperature,
        label: DateFormat('MMM dd').format(data.timestamp),
        metadata: {'roomId': data.roomId, 'sensorId': data.sensorId},
      )).toList();

      return ChartData(
        id: 'temperature_trend',
        title: 'Temperature Trend',
        type: ChartType.line,
        dataPoints: dataPoints,
        xAxisLabel: 'Date',
        yAxisLabel: 'Temperature (°F)',
        color: Colors.red.value,
        strokeWidth: 2.0,
        showDots: true,
        filledArea: false,
      );
    } catch (e) {
      debugPrint('Error generating temperature chart: $e');
      return ChartData(
        id: 'temperature_trend',
        title: 'Temperature Trend',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Temperature (°F)',
        color: Colors.red.value,
      );
    }
  }

  /// Generate humidity trend chart
  Future<ChartData> _generateHumidityChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.sensorDataTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.timestamp)]));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final sensorData = await query.get();
      final sampledData = _sampleData(sensorData, _maxDataPoints ~/ 4);

      final dataPoints = sampledData.map((data) => ChartDataPoint(
        x: data.timestamp.millisecondsSinceEpoch.toDouble(),
        y: data.humidity,
        label: DateFormat('MMM dd').format(data.timestamp),
        metadata: {'roomId': data.roomId, 'sensorId': data.sensorId},
      )).toList();

      return ChartData(
        id: 'humidity_trend',
        title: 'Humidity Trend',
        type: ChartType.line,
        dataPoints: dataPoints,
        xAxisLabel: 'Date',
        yAxisLabel: 'Humidity (%)',
        color: Colors.blue.value,
        strokeWidth: 2.0,
        showDots: true,
        filledArea: false,
      );
    } catch (e) {
      debugPrint('Error generating humidity chart: $e');
      return ChartData(
        id: 'humidity_trend',
        title: 'Humidity Trend',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Humidity (%)',
        color: Colors.blue.value,
      );
    }
  }

  /// Generate plant growth chart
  Future<ChartData> _generateGrowthChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.analysisResultsTable)
          ..where((tbl) => tbl.analysisDate.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.analysisDate)]));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final analyses = await query.get();

      final dataPoints = analyses.map((analysis) => ChartDataPoint(
        x: analysis.analysisDate.millisecondsSinceEpoch.toDouble(),
        y: (analysis.heightCm ?? 0.0),
        label: DateFormat('MMM dd').format(analysis.analysisDate),
        metadata: {
          'analysisId': analysis.id,
          'plantId': analysis.plantId,
          'healthScore': analysis.healthScore,
        },
      )).toList();

      return ChartData(
        id: 'plant_growth',
        title: 'Plant Growth',
        type: ChartType.line,
        dataPoints: dataPoints,
        xAxisLabel: 'Date',
        yAxisLabel: 'Height (cm)',
        color: Colors.green.value,
        strokeWidth: 3.0,
        showDots: true,
        filledArea: true,
        areaColor: Colors.green.withOpacity(0.3),
      );
    } catch (e) {
      debugPrint('Error generating growth chart: $e');
      return ChartData(
        id: 'plant_growth',
        title: 'Plant Growth',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Height (cm)',
        color: Colors.green.value,
      );
    }
  }

  /// Generate yield by strain chart
  Future<ChartData> _generateYieldChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.harvestRecordsTable)
          ..where((tbl) => tbl.harvestDate.isBetweenValues(startDate, endDate)));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final harvests = await query.get();

      final yieldsByStrain = harvests.groupListsBy((h) => h.strain);
      final dataPoints = yieldsByStrain.entries.map((entry) {
        final totalYield = entry.value.fold<double>(
            0.0, (sum, h) => sum + (h.totalWeight ?? 0.0));

        return ChartDataPoint(
          x: dataPoints.length.toDouble(),
          y: totalYield,
          label: entry.key,
          metadata: {
            'strain': entry.key,
            'harvestCount': entry.value.length,
            'averageYield': totalYield / entry.value.length,
          },
        );
      }).toList();

      return ChartData(
        id: 'yield_by_strain',
        title: 'Yield by Strain',
        type: ChartType.bar,
        dataPoints: dataPoints,
        xAxisLabel: 'Strain',
        yAxisLabel: 'Yield (g)',
        color: Colors.purple.value,
        showGrid: true,
        showLabels: true,
      );
    } catch (e) {
      debugPrint('Error generating yield chart: $e');
      return ChartData(
        id: 'yield_by_strain',
        title: 'Yield by Strain',
        type: ChartType.bar,
        dataPoints: [],
        xAxisLabel: 'Strain',
        yAxisLabel: 'Yield (g)',
        color: Colors.purple.value,
      );
    }
  }

  /// Generate health score chart
  Future<ChartData> _generateHealthScoreChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.analysisResultsTable)
          ..where((tbl) => tbl.analysisDate.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.analysisDate)]));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final analyses = await query.get();

      final dataPoints = analyses.map((analysis) => ChartDataPoint(
        x: analysis.analysisDate.millisecondsSinceEpoch.toDouble(),
        y: analysis.healthScore * 100,
        label: DateFormat('MMM dd').format(analysis.analysisDate),
        metadata: {
          'analysisId': analysis.id,
          'plantId': analysis.plantId,
          'recommendations': analysis.recommendations,
        },
      )).toList();

      return ChartData(
        id: 'health_score',
        title: 'Health Score Trend',
        type: ChartType.line,
        dataPoints: dataPoints,
        xAxisLabel: 'Date',
        yAxisLabel: 'Health Score (%)',
        color: Colors.teal.value,
        strokeWidth: 2.5,
        showDots: true,
        filledArea: false,
        showGrid: true,
      );
    } catch (e) {
      debugPrint('Error generating health score chart: $e');
      return ChartData(
        id: 'health_score',
        title: 'Health Score Trend',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Health Score (%)',
        color: Colors.teal.value,
      );
    }
  }

  /// Generate automation efficiency chart
  Future<ChartData> _generateAutomationChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.automationLogsTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.timestamp)]));

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final logs = await query.get();

      // Group by date and calculate success rate
      final logsByDate = groupBy(logs, (log) => DateTime(
        log.timestamp.year,
        log.timestamp.month,
        log.timestamp.day,
      ));

      final dataPoints = logsByDate.entries.map((entry) {
        final dayLogs = entry.value;
        final successes = dayLogs.where((log) =>
            log.action.contains('success') || log.action.contains('completed')).length;
        final successRate = dayLogs.isNotEmpty ? (successes / dayLogs.length) * 100 : 0.0;

        return ChartDataPoint(
          x: entry.key.millisecondsSinceEpoch.toDouble(),
          y: successRate,
          label: DateFormat('MMM dd').format(entry.key),
          metadata: {
            'totalExecutions': dayLogs.length,
            'successfulExecutions': successes,
            'failedExecutions': dayLogs.length - successes,
          },
        );
      }).toList();

      return ChartData(
        id: 'automation_efficiency',
        title: 'Automation Efficiency',
        type: ChartType.line,
        dataPoints: dataPoints,
        xAxisLabel: 'Date',
        yAxisLabel: 'Success Rate (%)',
        color: Colors.orange.value,
        strokeWidth: 2.0,
        showDots: true,
        filledArea: true,
        areaColor: Colors.orange.withOpacity(0.2),
      );
    } catch (e) {
      debugPrint('Error generating automation chart: $e');
      return ChartData(
        id: 'automation_efficiency',
        title: 'Automation Efficiency',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Success Rate (%)',
        color: Colors.orange.value,
      );
    }
  }

  /// Generate environmental conditions chart
  Future<ChartData> _generateEnvironmentalChart(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    try {
      final query = drift.SelectStatement(_database.select(_database.sensorDataTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.timestamp)])
          ..limit(100)); // Limit for performance

      if (roomId != null) {
        query.where((tbl) => tbl.roomId.equals(roomId));
      }

      final sensorData = await query.get();

      // Create multi-series chart with temperature, humidity, and optimal ranges
      final tempData = sensorData.map((data) => ChartDataPoint(
        x: data.timestamp.millisecondsSinceEpoch.toDouble(),
        y: data.temperature,
        label: 'Temperature',
        metadata: {'type': 'temperature', 'roomId': data.roomId},
      )).toList();

      final humidityData = sensorData.map((data) => ChartDataPoint(
        x: data.timestamp.millisecondsSinceEpoch.toDouble(),
        y: data.humidity,
        label: 'Humidity',
        metadata: {'type': 'humidity', 'roomId': data.roomId},
      )).toList();

      // Combine into single chart with multiple series
      final combinedData = [...tempData, ...humidityData];

      return ChartData(
        id: 'environmental_conditions',
        title: 'Environmental Conditions',
        type: ChartType.multiLine,
        dataPoints: combinedData,
        xAxisLabel: 'Date',
        yAxisLabel: 'Value',
        colors: [Colors.red.value, Colors.blue.value],
        strokeWidth: 2.0,
        showDots: false,
        showGrid: true,
        legend: ['Temperature (°F)', 'Humidity (%)'],
      );
    } catch (e) {
      debugPrint('Error generating environmental chart: $e');
      return ChartData(
        id: 'environmental_conditions',
        title: 'Environmental Conditions',
        type: ChartType.multiLine,
        dataPoints: [],
        xAxisLabel: 'Date',
        yAxisLabel: 'Value',
        colors: [Colors.red.value, Colors.blue.value],
        legend: ['Temperature (°F)', 'Humidity (%)'],
      );
    }
  }

  /// Generate analytics reports
  Future<List<AnalyticsReport>> generateAnalyticsReports({
    DateTime? startDate,
    DateTime? endDate,
    String? roomId,
  }) async {
    try {
      final reports = <AnalyticsReport>[];
      final effectiveStartDate = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final effectiveEndDate = endDate ?? DateTime.now();

      // Daily report
      reports.add(await _generateDailyReport(effectiveStartDate, effectiveEndDate, roomId));

      // Weekly report
      reports.add(await _generateWeeklyReport(effectiveStartDate, effectiveEndDate, roomId));

      // Monthly report
      reports.add(await _generateMonthlyReport(effectiveStartDate, effectiveEndDate, roomId));

      // Plant performance report
      reports.add(await _generatePlantPerformanceReport(effectiveStartDate, effectiveEndDate, roomId));

      // Environmental report
      reports.add(await _generateEnvironmentalReport(effectiveStartDate, effectiveEndDate, roomId));

      // Automation report
      reports.add(await _generateAutomationReport(effectiveStartDate, effectiveEndDate, roomId));

      return reports;
    } catch (e) {
      debugPrint('Error generating analytics reports: $e');
      return [];
    }
  }

  /// Generate cultivation insights
  Future<List<CultivationInsight>> generateCultivationInsights(
    AnalyticsData analytics,
  ) async {
    try {
      final insights = <CultivationInsight>[];

      // Growth insights
      if (analytics.growth.averageGrowthRate < 2.0) {
        insights.add(CultivationInsight(
          id: 'slow_growth',
          title: 'Slow Growth Detected',
          description: 'Plant growth rate is below optimal. Consider adjusting nutrients or lighting.',
          type: InsightType.warning,
          priority: InsightPriority.medium,
          recommendation: 'Review nutrient schedule and light intensity',
          actionable: true,
        ));
      }

      // Health insights
      if (analytics.overview.healthScore < 0.7) {
        insights.add(CultivationInsight(
          id: 'low_health',
          title: 'Low Plant Health Score',
          description: 'Overall plant health is below 70%. Immediate attention recommended.',
          type: InsightType.critical,
          priority: InsightPriority.high,
          recommendation: 'Conduct thorough plant inspection and analysis',
          actionable: true,
        ));
      }

      // Environmental insights
      if (analytics.environmental.temperatureStability < 0.8) {
        insights.add(CultivationInsight(
          id: 'temperature_instability',
          title: 'Temperature Fluctuations',
          description: 'Temperature stability is below 80%. Consider improving climate control.',
          type: InsightType.info,
          priority: InsightPriority.medium,
          recommendation: 'Check HVAC system and insulation',
          actionable: true,
        ));
      }

      // Yield insights
      if (analytics.yield.yieldTrend == YieldTrend.declining) {
        insights.add(CultivationInsight(
          id: 'declining_yield',
          title: 'Declining Yield Trend',
          description: 'Yield has been declining over recent harvests.',
          type: InsightType.warning,
          priority: InsightPriority.high,
          recommendation: 'Review growing conditions and strain performance',
          actionable: true,
        ));
      }

      // Automation insights
      if (analytics.automation.successRate < 90.0) {
        insights.add(CultivationInsight(
          id: 'automation_issues',
          title: 'Automation Success Rate Low',
          description: 'Automation success rate is below 90%. Check rule configurations.',
          type: InsightType.warning,
          priority: InsightPriority.medium,
          recommendation: 'Review automation rules and sensor calibration',
          actionable: true,
        ));
      }

      // Financial insights
      if (analytics.financial.profitMargin < 30.0) {
        insights.add(CultivationInsight(
          id: 'low_profit_margin',
          title: 'Low Profit Margin',
          description: 'Profit margin is below 30%. Consider optimizing operations.',
          type: InsightType.info,
          priority: InsightPriority.high,
          recommendation: 'Review costs and optimize resource usage',
          actionable: true,
        ));
      }

      return insights;
    } catch (e) {
      debugPrint('Error generating cultivation insights: $e');
      return [];
    }
  }

  // Helper methods

  double _calculateHealthScore(List<AnalysisResultData> analyses) {
    if (analyses.isEmpty) return 0.0;
    return analyses.map((a) => a.healthScore).reduce((a, b) => a + b) / analyses.length;
  }

  double _calculateAutomationEfficiency(List<dynamic> data) {
    // Simplified calculation
    return 85.0; // Placeholder
  }

  double _calculateProductivityIndex(List<PlantData> plants, List<AnalysisResultData> analyses) {
    if (plants.isEmpty || analyses.isEmpty) return 0.0;
    return (analyses.length / plants.length) * _calculateHealthScore(analyses);
  }

  double _calculateAverageGrowthRate(List<AnalysisResultData> analyses) {
    // Simplified growth rate calculation
    return 2.5; // cm per week
  }

  double _calculateAveragePlantHeight(List<AnalysisResultData> analyses) {
    final heights = analyses.map((a) => a.heightCm ?? 0.0).where((h) => h > 0);
    return heights.isNotEmpty ? heights.reduce((a, b) => a + b) / heights.length : 0.0;
  }

  double _calculateAverageLeafCount(List<AnalysisResultData> analyses) {
    // Simplified calculation
    return 12.0; // average leaf count
  }

  double _calculateGrowthVelocity(List<AnalysisResultData> analyses) {
    return 1.8; // cm per week
  }

  DateTime? _estimateHarvestDate(List<PlantData> plants) {
    if (plants.isEmpty) return null;

    // Find earliest expected harvest
    final harvestDates = plants.map((p) => p.expectedHarvestDate).where((d) => d != null);
    if (harvestDates.isEmpty) return null;

    return harvestDates.reduce((a, b) => a!.isBefore(b!) ? a! : b!);
  }

  YieldTrend _calculateYieldTrend(List<HarvestRecordData> harvests) {
    if (harvests.length < 2) return YieldTrend.stable;

    final sortedHarvests = harvests..sort((a, b) => a.harvestDate.compareTo(b.harvestDate));
    final recentHarvests = sortedHarvests.takeLast(3);
    final earlierHarvests = sortedHarvests.skip(sortedHarvests.length - 6).take(3);

    final recentAverage = recentHarvests.fold<double>(
        0.0, (sum, h) => sum + (h.totalWeight ?? 0.0)) / recentHarvests.length;
    final earlierAverage = earlierHarvests.isNotEmpty
        ? earlierHarvests.fold<double>(0.0, (sum, h) => sum + (h.totalWeight ?? 0.0)) / earlierHarvests.length
        : recentAverage;

    if (recentAverage > earlierAverage * 1.1) return YieldTrend.increasing;
    if (recentAverage < earlierAverage * 0.9) return YieldTrend.declining;
    return YieldTrend.stable;
  }

  Map<String, double> _calculateQualityDistribution(List<HarvestRecordData> harvests) {
    // Simplified quality distribution
    return {
      'Premium': 30.0,
      'Standard': 50.0,
      'Basic': 20.0,
    };
  }

  double _calculateHarvestEfficiency(List<HarvestRecordData> harvests) {
    return 92.0; // percentage
  }

  List<String> _getTopPerformingStrains(Map<String, double> yieldByStrain) {
    return yieldByStrain.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(3)
        .map((e) => e.key)
        .toList();
  }

  double _projectYield(List<HarvestRecordData> harvests) {
    if (harvests.isEmpty) return 0.0;

    final averageYield = harvests.fold<double>(
        0.0, (sum, h) => sum + (h.totalWeight ?? 0.0)) / harvests.length;

    return averageYield * 1.05; // 5% growth assumption
  }

  double _calculateStability(List<double> values) {
    if (values.length < 2) return 1.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final standardDeviation = math.sqrt(variance);

    // Convert to stability score (lower deviation = higher stability)
    return math.max(0.0, 1.0 - (standardDeviation / mean));
  }

  List<EnvironmentAlert> _generateEnvironmentAlerts(
    double temperature,
    double humidity,
    double ph,
    double ec,
  ) {
    final alerts = <EnvironmentAlert>[];

    if (temperature > 85) {
      alerts.add(EnvironmentAlert(
        type: 'high_temperature',
        message: 'Temperature too high: ${temperature.toStringAsFixed(1)}°F',
        severity: 'warning',
      ));
    }

    if (humidity < 40) {
      alerts.add(EnvironmentAlert(
        type: 'low_humidity',
        message: 'Humidity too low: ${humidity.toStringAsFixed(1)}%',
        severity: 'info',
      ));
    }

    if (ph < 6.0 || ph > 7.0) {
      alerts.add(EnvironmentAlert(
        type: 'ph_imbalance',
        message: 'pH out of optimal range: ${ph.toStringAsFixed(1)}',
        severity: 'warning',
      ));
    }

    return alerts;
  }

  double _calculateOptimalEnvironmentScore(double temperature, double humidity, double ph, double ec) {
    double score = 0.0;
    int factors = 0;

    // Temperature optimal range: 70-85°F
    if (temperature >= 70 && temperature <= 85) {
      score += 1.0;
    } else if (temperature >= 65 && temperature <= 90) {
      score += 0.7;
    } else {
      score += 0.3;
    }
    factors++;

    // Humidity optimal range: 40-60%
    if (humidity >= 40 && humidity <= 60) {
      score += 1.0;
    } else if (humidity >= 30 && humidity <= 70) {
      score += 0.7;
    } else {
      score += 0.3;
    }
    factors++;

    // pH optimal range: 6.0-7.0
    if (ph >= 6.0 && ph <= 7.0) {
      score += 1.0;
    } else if (ph >= 5.5 && ph <= 7.5) {
      score += 0.7;
    } else {
      score += 0.3;
    }
    factors++;

    // EC optimal range: 1.2-2.0
    if (ec >= 1.2 && ec <= 2.0) {
      score += 1.0;
    } else if (ec >= 1.0 && ec <= 2.5) {
      score += 0.7;
    } else {
      score += 0.3;
    }
    factors++;

    return (score / factors) * 100;
  }

  double _calculateAverageExecutionTime(List<AutomationLogData> logs) {
    if (logs.isEmpty) return 0.0;
    return 5.2; // minutes - placeholder
  }

  double _calculateSavedLaborHours(List<AutomationLogData> logs) {
    return logs.length * 0.5; // 30 minutes per automation
  }

  double _calculateResourceOptimization(List<AutomationLogData> logs) {
    return 25.0; // percentage - placeholder
  }

  String _getMostActiveRule(List<AutomationLogData> logs) {
    // Group logs by rule and find most active
    final ruleCounts = <String, int>{};
    for (final log in logs) {
      ruleCounts[log.ruleName] = (ruleCounts[log.ruleName] ?? 0) + 1;
    }

    if (ruleCounts.isEmpty) return 'N/A';

    return ruleCounts.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .first.key;
  }

  String _getLeastActiveRule(List<AutomationLogData> logs) {
    // Similar to most active but find least
    final ruleCounts = <String, int>{};
    for (final log in logs) {
      ruleCounts[log.ruleName] = (ruleCounts[log.ruleName] ?? 0) + 1;
    }

    if (ruleCounts.isEmpty) return 'N/A';

    return ruleCounts.entries
        .sorted((a, b) => a.value.compareTo(b.value))
        .first.key;
  }

  double _calculateOperationalCosts(DateTime startDate, DateTime endDate) {
    // Simplified operational costs calculation
    final days = endDate.difference(startDate).inDays;
    return days * 50.0; // $50 per day
  }

  double _calculateLaborCosts(DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    return days * 100.0; // $100 per day
  }

  double _calculateUtilityCosts(DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    return days * 25.0; // $25 per day
  }

  double _calculateSupplyCosts(DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    return days * 15.0; // $15 per day
  }

  double _calculateROI(double revenue, double costs) {
    if (costs == 0) return 0.0;
    return ((revenue - costs) / costs) * 100;
  }

  double _projectMonthlyProfit(double currentProfit) {
    return currentProfit * 4.3; // Weekly to monthly conversion
  }

  List<T> _sampleData<T>(List<T> data, int maxPoints) {
    if (data.length <= maxPoints) return data;

    final step = (data.length / maxPoints).ceil();
    final sampled = <T>[];

    for (int i = 0; i < data.length; i += step) {
      sampled.add(data[i]);
    }

    return sampled;
  }

  Future<AnalyticsReport> _generateDailyReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'daily_report',
      title: 'Daily Cultivation Report',
      type: ReportType.daily,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Daily summary of cultivation operations and performance',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  Future<AnalyticsReport> _generateWeeklyReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'weekly_report',
      title: 'Weekly Cultivation Report',
      type: ReportType.weekly,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Weekly performance analysis and trends',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  Future<AnalyticsReport> _generateMonthlyReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'monthly_report',
      title: 'Monthly Cultivation Report',
      type: ReportType.monthly,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Comprehensive monthly analysis and performance metrics',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  Future<AnalyticsReport> _generatePlantPerformanceReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'plant_performance',
      title: 'Plant Performance Report',
      type: ReportType.plantPerformance,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Detailed analysis of plant health and growth metrics',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  Future<AnalyticsReport> _generateEnvironmentalReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'environmental',
      title: 'Environmental Conditions Report',
      type: ReportType.environmental,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Analysis of environmental conditions and optimization opportunities',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  Future<AnalyticsReport> _generateAutomationReport(
    DateTime startDate,
    DateTime endDate,
    String? roomId,
  ) async {
    return AnalyticsReport(
      id: 'automation',
      title: 'Automation Performance Report',
      type: ReportType.automation,
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(startDate: startDate, endDate: endDate),
      summary: 'Analysis of automation system efficiency and performance',
      metrics: {},
      charts: [],
      insights: [],
    );
  }

  AnalyticsData _createEmptyAnalyticsData() {
    return AnalyticsData(
      overview: OverviewMetrics(
        totalPlants: 0,
        activeRooms: 0,
        totalAnalyses: 0,
        healthScore: 0.0,
        automationEfficiency: 0.0,
        productivityIndex: 0.0,
        lastUpdated: DateTime.now(),
      ),
      growth: GrowthMetrics(
        averageGrowthRate: 0.0,
        healthyPlantPercentage: 0.0,
        growthStageDistribution: {},
        averagePlantHeight: 0.0,
        averageLeafCount: 0.0,
        growthVelocity: 0.0,
        estimatedHarvestDate: null,
      ),
      yield: YieldMetrics(
        totalYield: 0.0,
        averageYieldPerPlant: 0.0,
        yieldByStrain: {},
        yieldTrend: YieldTrend.stable,
        qualityDistribution: {},
        harvestEfficiency: 0.0,
        topPerformingStrains: [],
        projectedYield: 0.0,
      ),
      environmental: EnvironmentalMetrics(
        averageTemperature: 0.0,
        averageHumidity: 0.0,
        averagePh: 0.0,
        averageEc: 0.0,
        averageCo2: 0.0,
        temperatureStability: 0.0,
        humidityStability: 0.0,
        optimalEnvironmentScore: 0.0,
        environmentAlerts: [],
      ),
      automation: AutomationMetrics(
        activeRules: 0,
        totalExecutions: 0,
        successRate: 0.0,
        averageExecutionTime: 0.0,
        savedLaborHours: 0.0,
        resourceOptimization: 0.0,
        mostActiveRule: '',
        leastActiveRule: '',
        automationEfficiency: 0.0,
      ),
      financial: FinancialMetrics(
        totalRevenue: 0.0,
        totalCosts: 0.0,
        netProfit: 0.0,
        profitMargin: 0.0,
        operationalCosts: 0.0,
        laborCosts: 0.0,
        utilityCosts: 0.0,
        supplyCosts: 0.0,
        averageRevenuePerHarvest: 0.0,
        costPerGram: 0.0,
        returnOnInvestment: 0.0,
        projectedMonthlyProfit: 0.0,
      ),
      generatedAt: DateTime.now(),
      dateRange: AnalyticsDateRange(
        startDate: DateTime.now().subtract(Duration(days: 30)),
        endDate: DateTime.now(),
      ),
    );
  }

  /// Export analytics data
  Future<Map<String, dynamic>> exportAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
    String? roomId,
    ExportFormat format = ExportFormat.json,
  }) async {
    try {
      final analytics = await generateAnalyticsData(
        startDate: startDate,
        endDate: endDate,
        roomId: roomId,
      );

      final charts = await generateChartData(
        startDate: startDate,
        endDate: endDate,
        roomId: roomId,
      );

      final reports = await generateAnalyticsReports(
        startDate: startDate,
        endDate: endDate,
        roomId: roomId,
      );

      final exportData = {
        'exportInfo': {
          'exportedAt': DateTime.now().toIso8601String(),
          'dateRange': {
            'startDate': startDate?.toIso8601String(),
            'endDate': endDate?.toIso8601String(),
          },
          'roomId': roomId,
          'format': format.toString(),
        },
        'analytics': analytics.toJson(),
        'charts': charts.map((c) => c.toJson()).toList(),
        'reports': reports.map((r) => r.toJson()).toList(),
      };

      return exportData;
    } catch (e) {
      debugPrint('Error exporting analytics data: $e');
      return {};
    }
  }

  /// Get real-time analytics summary
  Future<Map<String, dynamic>> getRealTimeSummary() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get today's metrics
      final todayAnalytics = await generateAnalyticsData(
        startDate: today,
        endDate: now,
      );

      return {
        'timestamp': now.toIso8601String(),
        'overview': todayAnalytics.overview.toJson(),
        'alerts': todayAnalytics.environmental.environmentAlerts.map((a) => a.toJson()).toList(),
        'recentInsights': await generateCultivationInsights(todayAnalytics),
        'activeAutomations': todayAnalytics.automation.activeRules,
        'systemHealth': {
          'healthScore': todayAnalytics.overview.healthScore,
          'automationEfficiency': todayAnalytics.automation.successRate,
          'environmentStability': todayAnalytics.environmental.optimalEnvironmentScore,
        },
      };
    } catch (e) {
      debugPrint('Error getting real-time summary: $e');
      return {'error': e.toString()};
    }
  }

  /// Cleanup resources
  void dispose() {
    _analyticsController.close();
    _chartsController.close();
    _reportsController.close();
    _insightsController.close();
  }
}

// Data models for analytics

enum ChartType {
  line,
  bar,
  pie,
  area,
  scatter,
  multiLine,
}

enum YieldTrend {
  increasing,
  stable,
  declining,
}

enum ReportType {
  daily,
  weekly,
  monthly,
  plantPerformance,
  environmental,
  automation,
}

enum ExportFormat {
  json,
  csv,
  pdf,
}

enum InsightType {
  info,
  warning,
  critical,
  success,
}

enum InsightPriority {
  low,
  medium,
  high,
}

class AnalyticsData {
  final OverviewMetrics overview;
  final GrowthMetrics growth;
  final YieldMetrics yield;
  final EnvironmentalMetrics environmental;
  final AutomationMetrics automation;
  final FinancialMetrics financial;
  final DateTime generatedAt;
  final AnalyticsDateRange dateRange;

  AnalyticsData({
    required this.overview,
    required this.growth,
    required this.yield,
    required this.environmental,
    required this.automation,
    required this.financial,
    required this.generatedAt,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
    'overview': overview.toJson(),
    'growth': growth.toJson(),
    'yield': yield.toJson(),
    'environmental': environmental.toJson(),
    'automation': automation.toJson(),
    'financial': financial.toJson(),
    'generatedAt': generatedAt.toIso8601String(),
    'dateRange': dateRange.toJson(),
  };

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      overview: OverviewMetrics.fromJson(json['overview']),
      growth: GrowthMetrics.fromJson(json['growth']),
      yield: YieldMetrics.fromJson(json['yield']),
      environmental: EnvironmentalMetrics.fromJson(json['environmental']),
      automation: AutomationMetrics.fromJson(json['automation']),
      financial: FinancialMetrics.fromJson(json['financial']),
      generatedAt: DateTime.parse(json['generatedAt']),
      dateRange: AnalyticsDateRange.fromJson(json['dateRange']),
    );
  }
}

class OverviewMetrics {
  final int totalPlants;
  final int activeRooms;
  final int totalAnalyses;
  final double healthScore;
  final double automationEfficiency;
  final double productivityIndex;
  final DateTime lastUpdated;

  OverviewMetrics({
    required this.totalPlants,
    required this.activeRooms,
    required this.totalAnalyses,
    required this.healthScore,
    required this.automationEfficiency,
    required this.productivityIndex,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'totalPlants': totalPlants,
    'activeRooms': activeRooms,
    'totalAnalyses': totalAnalyses,
    'healthScore': healthScore,
    'automationEfficiency': automationEfficiency,
    'productivityIndex': productivityIndex,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory OverviewMetrics.fromJson(Map<String, dynamic> json) {
    return OverviewMetrics(
      totalPlants: json['totalPlants'],
      activeRooms: json['activeRooms'],
      totalAnalyses: json['totalAnalyses'],
      healthScore: json['healthScore'].toDouble(),
      automationEfficiency: json['automationEfficiency'].toDouble(),
      productivityIndex: json['productivityIndex'].toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

class GrowthMetrics {
  final double averageGrowthRate;
  final double healthyPlantPercentage;
  final Map<String, double> growthStageDistribution;
  final double averagePlantHeight;
  final double averageLeafCount;
  final double growthVelocity;
  final DateTime? estimatedHarvestDate;

  GrowthMetrics({
    required this.averageGrowthRate,
    required this.healthyPlantPercentage,
    required this.growthStageDistribution,
    required this.averagePlantHeight,
    required this.averageLeafCount,
    required this.growthVelocity,
    required this.estimatedHarvestDate,
  });

  Map<String, dynamic> toJson() => {
    'averageGrowthRate': averageGrowthRate,
    'healthyPlantPercentage': healthyPlantPercentage,
    'growthStageDistribution': growthStageDistribution,
    'averagePlantHeight': averagePlantHeight,
    'averageLeafCount': averageLeafCount,
    'growthVelocity': growthVelocity,
    'estimatedHarvestDate': estimatedHarvestDate?.toIso8601String(),
  };

  factory GrowthMetrics.fromJson(Map<String, dynamic> json) {
    return GrowthMetrics(
      averageGrowthRate: json['averageGrowthRate'].toDouble(),
      healthyPlantPercentage: json['healthyPlantPercentage'].toDouble(),
      growthStageDistribution: Map<String, double>.from(json['growthStageDistribution']),
      averagePlantHeight: json['averagePlantHeight'].toDouble(),
      averageLeafCount: json['averageLeafCount'].toDouble(),
      growthVelocity: json['growthVelocity'].toDouble(),
      estimatedHarvestDate: json['estimatedHarvestDate'] != null
          ? DateTime.parse(json['estimatedHarvestDate'])
          : null,
    );
  }
}

class YieldMetrics {
  final double totalYield;
  final double averageYieldPerPlant;
  final Map<String, double> yieldByStrain;
  final YieldTrend yieldTrend;
  final Map<String, double> qualityDistribution;
  final double harvestEfficiency;
  final List<String> topPerformingStrains;
  final double projectedYield;

  YieldMetrics({
    required this.totalYield,
    required this.averageYieldPerPlant,
    required this.yieldByStrain,
    required this.yieldTrend,
    required this.qualityDistribution,
    required this.harvestEfficiency,
    required this.topPerformingStrains,
    required this.projectedYield,
  });

  Map<String, dynamic> toJson() => {
    'totalYield': totalYield,
    'averageYieldPerPlant': averageYieldPerPlant,
    'yieldByStrain': yieldByStrain,
    'yieldTrend': yieldTrend.toString(),
    'qualityDistribution': qualityDistribution,
    'harvestEfficiency': harvestEfficiency,
    'topPerformingStrains': topPerformingStrains,
    'projectedYield': projectedYield,
  };

  factory YieldMetrics.fromJson(Map<String, dynamic> json) {
    return YieldMetrics(
      totalYield: json['totalYield'].toDouble(),
      averageYieldPerPlant: json['averageYieldPerPlant'].toDouble(),
      yieldByStrain: Map<String, double>.from(json['yieldByStrain']),
      yieldTrend: YieldTrend.values.firstWhere((e) => e.toString() == json['yieldTrend']),
      qualityDistribution: Map<String, double>.from(json['qualityDistribution']),
      harvestEfficiency: json['harvestEfficiency'].toDouble(),
      topPerformingStrains: List<String>.from(json['topPerformingStrains']),
      projectedYield: json['projectedYield'].toDouble(),
    );
  }
}

class EnvironmentalMetrics {
  final double averageTemperature;
  final double averageHumidity;
  final double averagePh;
  final double averageEc;
  final double averageCo2;
  final double temperatureStability;
  final double humidityStability;
  final double optimalEnvironmentScore;
  final List<EnvironmentAlert> environmentAlerts;

  EnvironmentalMetrics({
    required this.averageTemperature,
    required this.averageHumidity,
    required this.averagePh,
    required this.averageEc,
    required this.averageCo2,
    required this.temperatureStability,
    required this.humidityStability,
    required this.optimalEnvironmentScore,
    required this.environmentAlerts,
  });

  Map<String, dynamic> toJson() => {
    'averageTemperature': averageTemperature,
    'averageHumidity': averageHumidity,
    'averagePh': averagePh,
    'averageEc': averageEc,
    'averageCo2': averageCo2,
    'temperatureStability': temperatureStability,
    'humidityStability': humidityStability,
    'optimalEnvironmentScore': optimalEnvironmentScore,
    'environmentAlerts': environmentAlerts.map((a) => a.toJson()).toList(),
  };

  factory EnvironmentalMetrics.fromJson(Map<String, dynamic> json) {
    return EnvironmentalMetrics(
      averageTemperature: json['averageTemperature'].toDouble(),
      averageHumidity: json['averageHumidity'].toDouble(),
      averagePh: json['averagePh'].toDouble(),
      averageEc: json['averageEc'].toDouble(),
      averageCo2: json['averageCo2'].toDouble(),
      temperatureStability: json['temperatureStability'].toDouble(),
      humidityStability: json['humidityStability'].toDouble(),
      optimalEnvironmentScore: json['optimalEnvironmentScore'].toDouble(),
      environmentAlerts: (json['environmentAlerts'] as List)
          .map((a) => EnvironmentAlert.fromJson(a))
          .toList(),
    );
  }
}

class AutomationMetrics {
  final int activeRules;
  final int totalExecutions;
  final double successRate;
  final double averageExecutionTime;
  final double savedLaborHours;
  final double resourceOptimization;
  final String mostActiveRule;
  final String leastActiveRule;
  final double automationEfficiency;

  AutomationMetrics({
    required this.activeRules,
    required this.totalExecutions,
    required this.successRate,
    required this.averageExecutionTime,
    required this.savedLaborHours,
    required this.resourceOptimization,
    required this.mostActiveRule,
    required this.leastActiveRule,
    required this.automationEfficiency,
  });

  Map<String, dynamic> toJson() => {
    'activeRules': activeRules,
    'totalExecutions': totalExecutions,
    'successRate': successRate,
    'averageExecutionTime': averageExecutionTime,
    'savedLaborHours': savedLaborHours,
    'resourceOptimization': resourceOptimization,
    'mostActiveRule': mostActiveRule,
    'leastActiveRule': leastActiveRule,
    'automationEfficiency': automationEfficiency,
  };

  factory AutomationMetrics.fromJson(Map<String, dynamic> json) {
    return AutomationMetrics(
      activeRules: json['activeRules'],
      totalExecutions: json['totalExecutions'],
      successRate: json['successRate'].toDouble(),
      averageExecutionTime: json['averageExecutionTime'].toDouble(),
      savedLaborHours: json['savedLaborHours'].toDouble(),
      resourceOptimization: json['resourceOptimization'].toDouble(),
      mostActiveRule: json['mostActiveRule'],
      leastActiveRule: json['leastActiveRule'],
      automationEfficiency: json['automationEfficiency'].toDouble(),
    );
  }
}

class FinancialMetrics {
  final double totalRevenue;
  final double totalCosts;
  final double netProfit;
  final double profitMargin;
  final double operationalCosts;
  final double laborCosts;
  final double utilityCosts;
  final double supplyCosts;
  final double averageRevenuePerHarvest;
  final double costPerGram;
  final double returnOnInvestment;
  final double projectedMonthlyProfit;

  FinancialMetrics({
    required this.totalRevenue,
    required this.totalCosts,
    required this.netProfit,
    required this.profitMargin,
    required this.operationalCosts,
    required this.laborCosts,
    required this.utilityCosts,
    required this.supplyCosts,
    required this.averageRevenuePerHarvest,
    required this.costPerGram,
    required this.returnOnInvestment,
    required this.projectedMonthlyProfit,
  });

  Map<String, dynamic> toJson() => {
    'totalRevenue': totalRevenue,
    'totalCosts': totalCosts,
    'netProfit': netProfit,
    'profitMargin': profitMargin,
    'operationalCosts': operationalCosts,
    'laborCosts': laborCosts,
    'utilityCosts': utilityCosts,
    'supplyCosts': supplyCosts,
    'averageRevenuePerHarvest': averageRevenuePerHarvest,
    'costPerGram': costPerGram,
    'returnOnInvestment': returnOnInvestment,
    'projectedMonthlyProfit': projectedMonthlyProfit,
  };

  factory FinancialMetrics.fromJson(Map<String, dynamic> json) {
    return FinancialMetrics(
      totalRevenue: json['totalRevenue'].toDouble(),
      totalCosts: json['totalCosts'].toDouble(),
      netProfit: json['netProfit'].toDouble(),
      profitMargin: json['profitMargin'].toDouble(),
      operationalCosts: json['operationalCosts'].toDouble(),
      laborCosts: json['laborCosts'].toDouble(),
      utilityCosts: json['utilityCosts'].toDouble(),
      supplyCosts: json['supplyCosts'].toDouble(),
      averageRevenuePerHarvest: json['averageRevenuePerHarvest'].toDouble(),
      costPerGram: json['costPerGram'].toDouble(),
      returnOnInvestment: json['returnOnInvestment'].toDouble(),
      projectedMonthlyProfit: json['projectedMonthlyProfit'].toDouble(),
    );
  }
}

class AnalyticsDateRange {
  final DateTime startDate;
  final DateTime endDate;

  AnalyticsDateRange({
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
  };

  factory AnalyticsDateRange.fromJson(Map<String, dynamic> json) {
    return AnalyticsDateRange(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
    );
  }
}

class ChartData {
  final String id;
  final String title;
  final ChartType type;
  final List<ChartDataPoint> dataPoints;
  final String xAxisLabel;
  final String yAxisLabel;
  final int color;
  final List<int>? colors;
  final double strokeWidth;
  final bool showDots;
  final bool filledArea;
  final int? areaColor;
  final bool showGrid;
  final bool showLabels;
  final List<String>? legend;

  ChartData({
    required this.id,
    required this.title,
    required this.type,
    required this.dataPoints,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.color,
    this.colors,
    this.strokeWidth = 2.0,
    this.showDots = false,
    this.filledArea = false,
    this.areaColor,
    this.showGrid = false,
    this.showLabels = false,
    this.legend,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.toString(),
    'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
    'xAxisLabel': xAxisLabel,
    'yAxisLabel': yAxisLabel,
    'color': color,
    'colors': colors,
    'strokeWidth': strokeWidth,
    'showDots': showDots,
    'filledArea': filledArea,
    'areaColor': areaColor,
    'showGrid': showGrid,
    'showLabels': showLabels,
    'legend': legend,
  };

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      id: json['id'],
      title: json['title'],
      type: ChartType.values.firstWhere((e) => e.toString() == json['type']),
      dataPoints: (json['dataPoints'] as List)
          .map((p) => ChartDataPoint.fromJson(p))
          .toList(),
      xAxisLabel: json['xAxisLabel'],
      yAxisLabel: json['yAxisLabel'],
      color: json['color'],
      colors: json['colors'] != null ? List<int>.from(json['colors']) : null,
      strokeWidth: json['strokeWidth']?.toDouble() ?? 2.0,
      showDots: json['showDots'] ?? false,
      filledArea: json['filledArea'] ?? false,
      areaColor: json['areaColor'],
      showGrid: json['showGrid'] ?? false,
      showLabels: json['showLabels'] ?? false,
      legend: json['legend'] != null ? List<String>.from(json['legend']) : null,
    );
  }
}

class ChartDataPoint {
  final double x;
  final double y;
  final String label;
  final Map<String, dynamic> metadata;

  ChartDataPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'label': label,
    'metadata': metadata,
  };

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
      label: json['label'],
      metadata: Map<String, dynamic>.from(json['metadata']),
    );
  }
}

class AnalyticsReport {
  final String id;
  final String title;
  final ReportType type;
  final DateTime generatedAt;
  final AnalyticsDateRange dateRange;
  final String summary;
  final Map<String, dynamic> metrics;
  final List<ChartData> charts;
  final List<CultivationInsight> insights;

  AnalyticsReport({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedAt,
    required this.dateRange,
    required this.summary,
    required this.metrics,
    required this.charts,
    required this.insights,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.toString(),
    'generatedAt': generatedAt.toIso8601String(),
    'dateRange': dateRange.toJson(),
    'summary': summary,
    'metrics': metrics,
    'charts': charts.map((c) => c.toJson()).toList(),
    'insights': insights.map((i) => i.toJson()).toList(),
  };

  factory AnalyticsReport.fromJson(Map<String, dynamic> json) {
    return AnalyticsReport(
      id: json['id'],
      title: json['title'],
      type: ReportType.values.firstWhere((e) => e.toString() == json['type']),
      generatedAt: DateTime.parse(json['generatedAt']),
      dateRange: AnalyticsDateRange.fromJson(json['dateRange']),
      summary: json['summary'],
      metrics: Map<String, dynamic>.from(json['metrics']),
      charts: (json['charts'] as List)
          .map((c) => ChartData.fromJson(c))
          .toList(),
      insights: (json['insights'] as List)
          .map((i) => CultivationInsight.fromJson(i))
          .toList(),
    );
  }
}

class CultivationInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final InsightPriority priority;
  final String recommendation;
  final bool actionable;

  CultivationInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.recommendation,
    required this.actionable,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.toString(),
    'priority': priority.toString(),
    'recommendation': recommendation,
    'actionable': actionable,
  };

  factory CultivationInsight.fromJson(Map<String, dynamic> json) {
    return CultivationInsight(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: InsightType.values.firstWhere((e) => e.toString() == json['type']),
      priority: InsightPriority.values.firstWhere((e) => e.toString() == json['priority']),
      recommendation: json['recommendation'],
      actionable: json['actionable'],
    );
  }
}

class EnvironmentAlert {
  final String type;
  final String message;
  final String severity;

  EnvironmentAlert({
    required this.type,
    required this.message,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'message': message,
    'severity': severity,
  };

  factory EnvironmentAlert.fromJson(Map<String, dynamic> json) {
    return EnvironmentAlert(
      type: json['type'],
      message: json['message'],
      severity: json['severity'],
    );
  }
}

// Riverpod providers
final analyticsServiceProvider = Provider<ComprehensiveAnalyticsService>((ref) {
  throw UnimplementedError('AnalyticsService provider not implemented yet');
});

final analyticsStreamProvider = StreamProvider<AnalyticsData>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  return service.analyticsStream;
});

final chartsStreamProvider = StreamProvider<List<ChartData>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  return service.chartsStream;
});

final reportsStreamProvider = StreamProvider<List<AnalyticsReport>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  return service.reportsStream;
});

final insightsStreamProvider = StreamProvider<List<CultivationInsight>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  return service.insightsStream;
});