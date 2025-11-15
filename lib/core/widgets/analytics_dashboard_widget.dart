import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../services/comprehensive_analytics_service.dart';
import '../services/comprehensive_api_service.dart';
import '../../theme/app_theme.dart';

/// Comprehensive Analytics Dashboard Widget
///
/// Displays detailed analytics, charts, and insights for cultivation operations
class AnalyticsDashboardWidget extends StatefulWidget {
  final String? roomId;
  final DateTimeRange? dateRange;
  final bool showRealTimeData;
  final bool enableDataExport;

  const AnalyticsDashboardWidget({
    Key? key,
    this.roomId,
    this.dateRange,
    this.showRealTimeData = true,
    this.enableDataExport = true,
  }) : super(key: key);

  @override
  _AnalyticsDashboardWidgetState createState() => _AnalyticsDashboardWidgetState();
}

class _AnalyticsDashboardWidgetState extends State<AnalyticsDashboardWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ComprehensiveAnalyticsService _analyticsService;

  // State variables
  AnalyticsData? _currentAnalytics;
  List<ChartData> _charts = [];
  List<AnalyticsReport> _reports = [];
  List<CultivationInsight> _insights = [];
  bool _isLoading = true;
  String _selectedTimeRange = '30d';
  ChartType _selectedChartType = ChartType.line;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _analyticsService = Provider.of<ComprehensiveAnalyticsService>(context, listen: false);

    // Initialize animations
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _loadAnalyticsData();
    _startAnimations();

    if (widget.showRealTimeData) {
      _startRealTimeUpdates();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  void _startRealTimeUpdates() {
    // Update every 30 seconds for real-time data
    Stream.periodic(Duration(seconds: 30)).listen((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final startDate = widget.dateRange?.start ?? _getStartDateForRange(_selectedTimeRange);
      final endDate = widget.dateRange?.end ?? DateTime.now();

      // Load data in parallel
      final results = await Future.wait([
        _analyticsService.generateAnalyticsData(
          startDate: startDate,
          endDate: endDate,
          roomId: widget.roomId,
        ),
        _analyticsService.generateChartData(
          startDate: startDate,
          endDate: endDate,
          roomId: widget.roomId,
        ),
        _analyticsService.generateAnalyticsReports(
          startDate: startDate,
          endDate: endDate,
          roomId: widget.roomId,
        ),
      ]);

      setState(() {
        _currentAnalytics = results[0] as AnalyticsData;
        _charts = results[1] as List<ChartData>;
        _reports = results[2] as List<AnalyticsReport>;
        _isLoading = false;
      });

      // Load insights separately
      final insights = await _analyticsService.generateCultivationInsights(_currentAnalytics!);
      setState(() {
        _insights = insights;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load analytics data: $e');
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      final startDate = _getStartDateForRange(_selectedTimeRange);
      final endDate = DateTime.now();

      final analytics = await _analyticsService.generateAnalyticsData(
        startDate: startDate,
        endDate: endDate,
        roomId: widget.roomId,
      );

      if (mounted) {
        setState(() {
          _currentAnalytics = analytics;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing analytics data: $e');
    }
  }

  DateTime _getStartDateForRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case '7d':
        return now.subtract(Duration(days: 7));
      case '30d':
        return now.subtract(Duration(days: 30));
      case '90d':
        return now.subtract(Duration(days: 90));
      case '1y':
        return now.subtract(Duration(days: 365));
      default:
        return now.subtract(Duration(days: 30));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _loadAnalyticsData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildTimeRangeSelector(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildGrowthTab(),
                          _buildYieldTab(),
                          _buildEnvironmentalTab(),
                          _buildAutomationTab(),
                          _buildFinancialTab(),
                          _buildReportsTab(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  'Real-time cultivation insights and performance metrics',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (widget.enableDataExport)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.textColor),
              onSelected: _handleExportAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export_json',
                  child: Row(
                    children: [
                      Icon(Icons.code, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text('Export JSON'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text('Export CSV'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text('Refresh Data'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Time Range:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['7d', '30d', '90d', '1y'].map((range) {
                  final isSelected = _selectedTimeRange == range;
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_formatTimeRange(range)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTimeRange = range;
                          });
                          _loadAnalyticsData();
                        }
                      },
                      backgroundColor: AppTheme.cardColor,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryColor,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            'Loading analytics data...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_currentAnalytics == null) return _buildEmptyState();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(),
          SizedBox(height: 20),
          _buildQuickStats(),
          SizedBox(height: 20),
          _buildRecentInsights(),
          SizedBox(height: 20),
          _buildKeyMetricsChart(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Total Plants',
          _currentAnalytics!.overview.totalPlants.toString(),
          Icons.eco_outlined,
          Colors.green,
          subtitle: 'Active plants',
        ),
        _buildMetricCard(
          'Health Score',
          '${(_currentAnalytics!.overview.healthScore * 100).toStringAsFixed(1)}%',
          Icons.favorite_outline,
          _getHealthScoreColor(_currentAnalytics!.overview.healthScore),
          subtitle: 'Overall health',
        ),
        _buildMetricCard(
          'Automation Efficiency',
          '${_currentAnalytics!.overview.automationEfficiency.toStringAsFixed(1)}%',
          Icons.smart_toy_outlined,
          Colors.blue,
          subtitle: 'System efficiency',
        ),
        _buildMetricCard(
          'Productivity Index',
          _currentAnalytics!.overview.productivityIndex.toStringAsFixed(2),
          Icons.trending_up_outlined,
          Colors.purple,
          subtitle: 'Growth metric',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    {String? subtitle},
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Spacer(),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildQuickStats() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Active Rooms',
                  _currentAnalytics!.overview.activeRooms.toString(),
                  Icons.meeting_room_outlined,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Analyses',
                  _currentAnalytics!.overview.totalAnalyses.toString(),
                  Icons.analytics_outlined,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Avg Growth Rate',
                  '${_currentAnalytics!.growth.averageGrowthRate.toStringAsFixed(1)} cm/wk',
                  Icons.show_chart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentInsights() {
    if (_insights.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          ..._insights.take(3).map((insight) => _buildInsightCard(insight)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(CultivationInsight insight) {
    Color cardColor;
    IconData iconData;

    switch (insight.type) {
      case InsightType.critical:
        cardColor = Colors.red.withOpacity(0.1);
        iconData = Icons.warning;
        break;
      case InsightType.warning:
        cardColor = Colors.orange.withOpacity(0.1);
        iconData = Icons.error_outline;
        break;
      case InsightType.info:
        cardColor = Colors.blue.withOpacity(0.1);
        iconData = Icons.info_outline;
        break;
      case InsightType.success:
        cardColor = Colors.green.withOpacity(0.1);
        iconData = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: insight.type == InsightType.critical
              ? Colors.red.withOpacity(0.3)
              : insight.type == InsightType.warning
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            iconData,
            color: insight.type == InsightType.critical
                ? Colors.red
                : insight.type == InsightType.warning
                    ? Colors.orange
                    : Colors.blue,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (insight.actionable)
            Icon(
              Icons.touch_app,
              color: AppTheme.primaryColor,
              size: 16,
            ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsChart() {
    final chart = _charts.firstWhere(
      (c) => c.id == 'health_score',
      orElse: () => _charts.first,
    );

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chart.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(chart),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGrowthMetricsGrid(),
          SizedBox(height: 20),
          _buildGrowthChart(),
          SizedBox(height: 20),
          _buildGrowthStageDistribution(),
        ],
      ),
    );
  }

  Widget _buildGrowthMetricsGrid() {
    final growth = _currentAnalytics!.growth;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Avg Growth Rate',
          '${growth.averageGrowthRate.toStringAsFixed(1)} cm/wk',
          Icons.trending_up,
          Colors.green,
          subtitle: 'Weekly growth',
        ),
        _buildMetricCard(
          'Healthy Plants',
          '${growth.healthyPlantPercentage.toStringAsFixed(1)}%',
          Icons.favorite,
          Colors.pink,
          subtitle: 'Health percentage',
        ),
        _buildMetricCard(
          'Avg Height',
          '${growth.averagePlantHeight.toStringAsFixed(1)} cm',
          Icons.height,
          Colors.blue,
          subtitle: 'Plant height',
        ),
        _buildMetricCard(
          'Growth Velocity',
          '${growth.growthVelocity.toStringAsFixed(1)} cm/wk',
          Icons.speed,
          Colors.orange,
          subtitle: 'Growth speed',
        ),
      ],
    );
  }

  Widget _buildGrowthChart() {
    final chart = _charts.firstWhere(
      (c) => c.id == 'plant_growth',
      orElse: () => _charts.isNotEmpty ? _charts.first : ChartData(
        id: 'empty',
        title: 'No Data',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: '',
        yAxisLabel: '',
        color: Colors.grey.value,
      ),
    );

    return Container(
      height: 350,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plant Growth Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              PopupMenuButton<ChartType>(
                icon: Icon(Icons.tune, color: AppTheme.primaryColor),
                onSelected: (type) {
                  setState(() {
                    _selectedChartType = type;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ChartType.line,
                    child: Text('Line Chart'),
                  ),
                  PopupMenuItem(
                    value: ChartType.area,
                    child: Text('Area Chart'),
                  ),
                  PopupMenuItem(
                    value: ChartType.bar,
                    child: Text('Bar Chart'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(chart),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthStageDistribution() {
    final distribution = _currentAnalytics!.growth.growthStageDistribution;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Stage Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          ...distribution.entries.map((entry) {
            final percentage = (entry.value / distribution.values.fold(0, (a, b) => a + b)) * 100;
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        '${entry.value.toInt()} plants (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getGrowthStageColor(entry.key),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getGrowthStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'seedling':
        return Colors.green;
      case 'vegetative':
        return Colors.blue;
      case 'flowering':
        return Colors.purple;
      case 'harvesting':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildYieldTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYieldMetricsGrid(),
          SizedBox(height: 20),
          _buildYieldChart(),
          SizedBox(height: 20),
          _buildYieldTrendAnalysis(),
          SizedBox(height: 20),
          _buildTopPerformingStrains(),
        ],
      ),
    );
  }

  Widget _buildYieldMetricsGrid() {
    final yield = _currentAnalytics!.yield;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Total Yield',
          '${yield.totalYield.toStringAsFixed(0)} g',
          Icons.grain,
          Colors.green,
          subtitle: 'All harvests',
        ),
        _buildMetricCard(
          'Avg Yield/Plant',
          '${yield.averageYieldPerPlant.toStringAsFixed(0)} g',
          Icons.leaderboard,
          Colors.blue,
          subtitle: 'Per plant average',
        ),
        _buildMetricCard(
          'Harvest Efficiency',
          '${yield.harvestEfficiency.toStringAsFixed(1)}%',
          Icons.speed,
          Colors.orange,
          subtitle: 'Process efficiency',
        ),
        _buildMetricCard(
          'Projected Yield',
          '${yield.projectedYield.toStringAsFixed(0)} g',
          Icons.trending_up,
          Colors.purple,
          subtitle: 'Next harvest estimate',
        ),
      ],
    );
  }

  Widget _buildYieldChart() {
    final chart = _charts.firstWhere(
      (c) => c.id == 'yield_by_strain',
      orElse: () => _charts.isNotEmpty ? _charts.first : ChartData(
        id: 'empty',
        title: 'No Data',
        type: ChartType.bar,
        dataPoints: [],
        xAxisLabel: '',
        yAxisLabel: '',
        color: Colors.grey.value,
      ),
    );

    return Container(
      height: 350,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yield by Strain',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(chart),
          ),
        ],
      ),
    );
  }

  Widget _buildYieldTrendAnalysis() {
    final yield = _currentAnalytics!.yield;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yield Trend Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getYieldTrendColor(yield.yieldTrend).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getYieldTrendIcon(yield.yieldTrend),
                  color: _getYieldTrendColor(yield.yieldTrend),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Trend',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    Text(
                      _formatYieldTrend(yield.yieldTrend),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getYieldTrendColor(yield.yieldTrend),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformingStrains() {
    final topStrains = _currentAnalytics!.yield.topPerformingStrains;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performing Strains',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          ...topStrains.asMap().entries.map((entry) {
            final index = entry.key;
            final strain = entry.value;

            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strain,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnvironmentalMetricsGrid(),
          SizedBox(height: 20),
          _buildEnvironmentalCharts(),
          SizedBox(height: 20),
          _buildEnvironmentalAlerts(),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalMetricsGrid() {
    final env = _currentAnalytics!.environmental;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Avg Temperature',
          '${env.averageTemperature.toStringAsFixed(1)}°F',
          Icons.thermostat,
          Colors.red,
          subtitle: 'Room temperature',
        ),
        _buildMetricCard(
          'Avg Humidity',
          '${env.averageHumidity.toStringAsFixed(1)}%',
          Icons.water_drop,
          Colors.blue,
          subtitle: 'Relative humidity',
        ),
        _buildMetricCard(
          'Avg pH',
          env.averagePh.toStringAsFixed(1),
          Icons.science,
          Colors.green,
          subtitle: 'Nutrient pH',
        ),
        _buildMetricCard(
          'Environment Score',
          '${env.optimalEnvironmentScore.toStringAsFixed(1)}%',
          Icons.eco,
          Colors.teal,
          subtitle: 'Optimal conditions',
        ),
      ],
    );
  }

  Widget _buildEnvironmentalCharts() {
    final tempChart = _charts.firstWhere(
      (c) => c.id == 'temperature_trend',
      orElse: () => _charts.isNotEmpty ? _charts.first : ChartData(
        id: 'empty',
        title: 'No Data',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: '',
        yAxisLabel: '',
        color: Colors.grey.value,
      ),
    );

    return Container(
      height: 350,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental Conditions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(tempChart),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalAlerts() {
    final alerts = _currentAnalytics!.environmental.environmentAlerts;

    if (alerts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(width: 12),
            Text(
              'All environmental conditions are optimal',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          ...alerts.map((alert) => _buildAlertCard(alert)).toList(),
        ],
      ),
    );
  }

  Widget _buildAlertCard(EnvironmentAlert alert) {
    Color alertColor;

    switch (alert.severity) {
      case 'critical':
        alertColor = Colors.red;
        break;
      case 'warning':
        alertColor = Colors.orange;
        break;
      case 'info':
        alertColor = Colors.blue;
        break;
      default:
        alertColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alertColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.severity == 'critical'
                ? Icons.warning
                : alert.severity == 'warning'
                    ? Icons.error_outline
                    : Icons.info_outline,
            color: alertColor,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAutomationMetricsGrid(),
          SizedBox(height: 20),
          _buildAutomationChart(),
          SizedBox(height: 20),
          _buildAutomationRulesList(),
        ],
      ),
    );
  }

  Widget _buildAutomationMetricsGrid() {
    final automation = _currentAnalytics!.automation;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Active Rules',
          automation.activeRules.toString(),
          Icons.rule,
          Colors.blue,
          subtitle: 'Enabled automations',
        ),
        _buildMetricCard(
          'Success Rate',
          '${automation.successRate.toStringAsFixed(1)}%',
          Icons.check_circle,
          Colors.green,
          subtitle: 'Execution success',
        ),
        _buildMetricCard(
          'Total Executions',
          automation.totalExecutions.toString(),
          Icons.play_arrow,
          Colors.purple,
          subtitle: 'Run count',
        ),
        _buildMetricCard(
          'Saved Labor',
          '${automation.savedLaborHours.toStringAsFixed(1)} hrs',
          Icons.access_time,
          Colors.orange,
          subtitle: 'Time saved',
        ),
      ],
    );
  }

  Widget _buildAutomationChart() {
    final chart = _charts.firstWhere(
      (c) => c.id == 'automation_efficiency',
      orElse: () => _charts.isNotEmpty ? _charts.first : ChartData(
        id: 'empty',
        title: 'No Data',
        type: ChartType.line,
        dataPoints: [],
        xAxisLabel: '',
        yAxisLabel: '',
        color: Colors.grey.value,
      ),
    );

    return Container(
      height: 350,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automation Efficiency Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(chart),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationRulesList() {
    final automation = _currentAnalytics!.automation;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rule Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          _buildRuleActivityRow('Most Active', automation.mostActiveRule, Icons.trending_up),
          SizedBox(height: 12),
          _buildRuleActivityRow('Least Active', automation.leastActiveRule, Icons.trending_down),
        ],
      ),
    );
  }

  Widget _buildRuleActivityRow(String label, String ruleName, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              Text(
                ruleName.isNotEmpty ? ruleName : 'N/A',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinancialMetricsGrid(),
          SizedBox(height: 20),
          _buildFinancialSummary(),
          SizedBox(height: 20),
          _buildCostBreakdown(),
        ],
      ),
    );
  }

  Widget _buildFinancialMetricsGrid() {
    final financial = _currentAnalytics!.financial;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          'Total Revenue',
          '\$${financial.totalRevenue.toStringAsFixed(0)}',
          Icons.attach_money,
          Colors.green,
          subtitle: 'Gross revenue',
        ),
        _buildMetricCard(
          'Net Profit',
          '\$${financial.netProfit.toStringAsFixed(0)}',
          Icons.trending_up,
          financial.netProfit >= 0 ? Colors.blue : Colors.red,
          subtitle: 'After costs',
        ),
        _buildMetricCard(
          'Profit Margin',
          '${financial.profitMargin.toStringAsFixed(1)}%',
          Icons.pie_chart,
          financial.profitMargin >= 30 ? Colors.green : Colors.orange,
          subtitle: 'Profitability',
        ),
        _buildMetricCard(
          'ROI',
          '${financial.returnOnInvestment.toStringAsFixed(1)}%',
          Icons.show_chart,
          financial.returnOnInvestment >= 0 ? Colors.purple : Colors.red,
          subtitle: 'Return on investment',
        ),
      ],
    );
  }

  Widget _buildFinancialSummary() {
    final financial = _currentAnalytics!.financial;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          _buildFinancialRow('Average Revenue per Harvest',
              '\$${financial.averageRevenuePerHarvest.toStringAsFixed(0)}'),
          SizedBox(height: 12),
          _buildFinancialRow('Cost per Gram',
              '\$${financial.costPerGram.toStringAsFixed(2)}'),
          SizedBox(height: 12),
          _buildFinancialRow('Projected Monthly Profit',
              '\$${financial.projectedMonthlyProfit.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(
        label,
        style: TextStyle(
          color: AppTheme.secondaryTextColor,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
    ],
  );
  }

  Widget _buildCostBreakdown() {
    final financial = _currentAnalytics!.financial;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          _buildCostItem('Operational', financial.operationalCosts, financial.totalCosts),
          _buildCostItem('Labor', financial.laborCosts, financial.totalCosts),
          _buildCostItem('Utilities', financial.utilityCosts, financial.totalCosts),
          _buildCostItem('Supplies', financial.supplyCosts, financial.totalCosts),
        ],
      ),
    );
  }

  Widget _buildCostItem(String category, double cost, double totalCosts) {
    final percentage = totalCosts > 0 ? (cost / totalCosts) * 100 : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor,
                ),
              ),
              Text(
                '\$${cost.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppTheme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getCostCategoryColor(category),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCostCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'operational':
        return Colors.blue;
      case 'labor':
        return Colors.green;
      case 'utilities':
        return Colors.orange;
      case 'supplies':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportsHeader(),
          SizedBox(height: 20),
          ..._reports.map((report) => _buildReportCard(report)).toList(),
        ],
      ),
    );
  }

  Widget _buildReportsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Analytics Reports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _generateNewReport,
          icon: Icon(Icons.add, size: 18),
          label: Text('Generate Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(AnalyticsReport report) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatReportType(report.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.secondaryTextColor),
                onSelected: (action) => _handleReportAction(report, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Export'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            report.summary,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: AppTheme.secondaryTextColor,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                'Generated ${_formatDate(report.generatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              Spacer(),
              if (report.insights.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${report.insights.length} insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart(ChartData chart) {
    if (chart.dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              color: AppTheme.secondaryTextColor,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Build chart based on type
    switch (chart.type) {
      case ChartType.line:
        return _buildLineChart(chart);
      case ChartType.bar:
        return _buildBarChart(chart);
      case ChartType.area:
        return _buildAreaChart(chart);
      case ChartType.multiLine:
        return _buildMultiLineChart(chart);
      default:
        return _buildLineChart(chart);
    }
  }

  Widget _buildLineChart(ChartData chart) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: chart.dataPoints.map((point) => FlSpot(point.x, point.y)).toList(),
            isCurved: true,
            color: Color(chart.color),
            barWidth: chart.strokeWidth,
            isStrokeCapRound: true,
            dotData: chart.showDots
                ? FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Color(chart.color),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  )
                : FlDotData(show: false),
            belowBarData: chart.filledArea
                ? BarAreaData(
                    show: true,
                    color: Color(chart.areaColor ?? chart.color).withOpacity(0.3),
                  )
                : BarAreaData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _calculateLabelInterval(chart.dataPoints),
              getTitlesWidget: (value, meta) {
                final point = chart.dataPoints.firstWhere(
                  (p) => (p.x - value).abs() < 1000,
                  orElse: () => chart.dataPoints.first,
                );
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    point.label,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: chart.showGrid
            ? FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.dividerColor,
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: AppTheme.dividerColor,
                    strokeWidth: 1,
                  );
                },
              )
            : FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: AppTheme.dividerColor),
            bottom: BorderSide(color: AppTheme.dividerColor),
            top: BorderSide(color: Colors.transparent),
            right: BorderSide(color: Colors.transparent),
          ),
        ),
        minX: chart.dataPoints.first.x,
        maxX: chart.dataPoints.last.x,
        minY: _calculateMinY(chart.dataPoints),
        maxY: _calculateMaxY(chart.dataPoints),
      ),
    );
  }

  Widget _buildBarChart(ChartData chart) {
    return BarChart(
      BarChartData(
        barGroups: chart.dataPoints.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;

          return BarChartGroupData(
            x: index.toInt(),
            barRods: [
              BarChartRodData(
                toY: point.y,
                color: Color(chart.color),
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < chart.dataPoints.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      chart.dataPoints[index].label,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: AppTheme.dividerColor),
            bottom: BorderSide(color: AppTheme.dividerColor),
            top: BorderSide(color: Colors.transparent),
            right: BorderSide(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaChart(ChartData chart) {
    // Similar to line chart but with filled area
    return _buildLineChart(chart); // Reuse line chart logic
  }

  Widget _buildMultiLineChart(ChartData chart) {
    // For multi-line charts, handle multiple series
    return _buildLineChart(chart); // Simplified for now
  }

  double _calculateLabelInterval(List<ChartDataPoint> points) {
    if (points.isEmpty) return 1.0;
    final range = points.last.x - points.first.x;
    return range / 5; // Show max 5 labels
  }

  double _calculateMinY(List<ChartDataPoint> points) {
    if (points.isEmpty) return 0.0;
    final minY = points.map((p) => p.y).reduce(math.min);
    return math.max(0, minY - (minY * 0.1));
  }

  double _calculateMaxY(List<ChartDataPoint> points) {
    if (points.isEmpty) return 100.0;
    final maxY = points.map((p) => p.y).reduce(math.max);
    return maxY + (maxY * 0.1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            color: AppTheme.secondaryTextColor,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No Analytics Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start analyzing your cultivation data to see insights here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalyticsData,
            icon: Icon(Icons.refresh),
            label: Text('Refresh Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handleExportAction(String action) async {
    switch (action) {
      case 'export_json':
        await _exportData(ExportFormat.json);
        break;
      case 'export_csv':
        await _exportData(ExportFormat.csv);
        break;
      case 'refresh':
        await _loadAnalyticsData();
        break;
    }
  }

  Future<void> _exportData(ExportFormat format) async {
    try {
      final startDate = _getStartDateForRange(_selectedTimeRange);
      final endDate = DateTime.now();

      final exportData = await _analyticsService.exportAnalyticsData(
        startDate: startDate,
        endDate: endDate,
        roomId: widget.roomId,
        format: format,
      );

      // Here you would save the data to a file or share it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateNewReport() async {
    // Implementation for generating new reports
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report generation feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _handleReportAction(AnalyticsReport report, String action) {
    switch (action) {
      case 'view':
        // Navigate to report detail view
        break;
      case 'export':
        // Export report
        break;
      case 'share':
        // Share report
        break;
    }
  }

  String _formatTimeRange(String range) {
    switch (range) {
      case '7d':
        return '7 Days';
      case '30d':
        return '30 Days';
      case '90d':
        return '90 Days';
      case '1y':
        return '1 Year';
      default:
        return range;
    }
  }

  String _formatYieldTrend(YieldTrend trend) {
    switch (trend) {
      case YieldTrend.increasing:
        return 'Increasing';
      case YieldTrend.stable:
        return 'Stable';
      case YieldTrend.declining:
        return 'Declining';
      default:
        return 'Unknown';
    }
  }

  Color _getYieldTrendColor(YieldTrend trend) {
    switch (trend) {
      case YieldTrend.increasing:
        return Colors.green;
      case YieldTrend.stable:
        return Colors.blue;
      case YieldTrend.declining:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getYieldTrendIcon(YieldTrend trend) {
    switch (trend) {
      case YieldTrend.increasing:
        return Icons.trending_up;
      case YieldTrend.stable:
        return Icons.trending_flat;
      case YieldTrend.declining:
        return Icons.trending_down;
      default:
        return Icons.help_outline;
    }
  }

  String _formatReportType(ReportType type) {
    switch (type) {
      case ReportType.daily:
        return 'Daily Report';
      case ReportType.weekly:
        return 'Weekly Report';
      case ReportType.monthly:
        return 'Monthly Report';
      case ReportType.plantPerformance:
        return 'Plant Performance Report';
      case ReportType.environmental:
        return 'Environmental Report';
      case ReportType.automation:
        return 'Automation Report';
      default:
        return 'Unknown Report';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}

// Helper extension for list operations
extension ListExtension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
  List<T> takeLast(int n) => sublist(length - n);
}