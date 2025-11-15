import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsDashboard extends ConsumerStatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  ConsumerState<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends ConsumerState<AnalyticsDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _chartController;
  late AnimationController _slideController;
  String _selectedTimeRange = '7D';
  String _selectedMetric = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _chartController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chartController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.secondary.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics Dashboard',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Monitor your grow room performance',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _exportData,
                      icon: const Icon(Icons.download),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Time Range Selector
                _buildTimeRangeSelector(colorScheme),

                const SizedBox(height: 16),

                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icons.dashboard_outlined,
                      text: 'Overview',
                    ),
                    Tab(
                      icon: Icons.thermostat_outlined,
                      text: 'Environment',
                    ),
                    Tab(
                      icon: Icons.eco_outlined,
                      text: 'Growth',
                    ),
                    Tab(
                      icon: Icons.trending_up_outlined,
                      text: 'Performance',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(
                  selectedTimeRange: _selectedTimeRange,
                  chartController: _chartController,
                ),
                EnvironmentTab(
                  selectedTimeRange: _selectedTimeRange,
                  chartController: _chartController,
                ),
                GrowthTab(
                  selectedTimeRange: _selectedTimeRange,
                  chartController: _chartController,
                ),
                PerformanceTab(
                  selectedTimeRange: _selectedTimeRange,
                  chartController: _chartController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(ColorScheme colorScheme) {
    final timeRanges = ['24H', '7D', '30D', '90D', '1Y'];

    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timeRanges.length,
        itemBuilder: (context, index) {
          final range = timeRanges[index];
          final isSelected = range == _selectedTimeRange;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(range),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTimeRange = range;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: colorScheme.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? colorScheme.primary : Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }

  void _exportData() {
    // Export analytics data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics data exported successfully')),
    );
  }
}

class OverviewTab extends StatelessWidget {
  final String selectedTimeRange;
  final AnimationController chartController;

  const OverviewTab({
    super.key,
    required this.selectedTimeRange,
    required this.chartController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Grid
          _buildKeyMetricsGrid(colorScheme),

          const SizedBox(height: 24),

          // Environment Health Chart
          _buildEnvironmentHealthChart(colorScheme),

          const SizedBox(height: 24),

          // Growth Progress
          _buildGrowthProgressCard(colorScheme),

          const SizedBox(height: 24),

          // Recent Alerts
          _buildRecentAlertsCard(colorScheme),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Metrics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final metrics = [
              {
                'title': 'Avg Temperature',
                'value': '23.5°C',
                'change': '+0.5°',
                'trend': 'up',
                'color': Colors.orange,
                'icon': Icons.thermostat,
              },
              {
                'title': 'Avg Humidity',
                'value': '55%',
                'change': '-2%',
                'trend': 'down',
                'color': Colors.blue,
                'icon': Icons.water_drop,
              },
              {
                'title': 'Plant Health',
                'value': '87%',
                'change': '+3%',
                'trend': 'up',
                'color': Colors.green,
                'icon': Icons.eco,
              },
              {
                'title': 'Energy Usage',
                'value': '145 kWh',
                'change': '-12%',
                'trend': 'down',
                'color': Colors.purple,
                'icon': Icons.electric_bolt,
              },
            ];

            final metric = metrics[index];
            return _buildMetricCard(metric, colorScheme);
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric, ColorScheme colorScheme) {
    final color = metric['color'] as Color;
    final trend = metric['trend'] as String;
    final change = metric['change'] as String;
    final isPositive = trend == 'up' && !change.startsWith('-') ||
                       trend == 'down' && change.startsWith('-');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  metric['icon'] as IconData,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            metric['title'] as String,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric['value'] as String,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentHealthChart(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environment Health Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 7 days performance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Temperature line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 75),
                      FlSpot(1, 78),
                      FlSpot(2, 82),
                      FlSpot(3, 79),
                      FlSpot(4, 85),
                      FlSpot(5, 83),
                      FlSpot(6, 87),
                    ],
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.3),
                          Colors.orange.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Humidity line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 60),
                      FlSpot(1, 58),
                      FlSpot(2, 55),
                      FlSpot(3, 57),
                      FlSpot(4, 54),
                      FlSpot(5, 56),
                      FlSpot(6, 55),
                    ],
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: 40,
                maxY: 100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Temperature Health', Colors.orange),
              const SizedBox(width: 24),
              _buildLegendItem('Humidity Level', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthProgressCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Progress',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildGrowthStage(
            'Germination',
            100,
            Colors.green,
            true,
          ),
          const SizedBox(height: 12),
          _buildGrowthStage(
            'Seedling',
            100,
            Colors.lightGreen,
            true,
          ),
          const SizedBox(height: 12),
          _buildGrowthStage(
            'Vegetative',
            65,
            Colors.blue,
            false,
          ),
          const SizedBox(height: 12),
          _buildGrowthStage(
            'Flowering',
            0,
            Colors.purple,
            false,
          ),
          const SizedBox(height: 12),
          _buildGrowthStage(
            'Harvest',
            0,
            Colors.orange,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthStage(String stage, double progress, Color color, bool isCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              stage,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCompleted ? color : Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              '${progress.toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress / 100.0,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAlertsCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                'Recent Alerts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            'Low moisture detected',
            '2 hours ago',
            Icons.water_drop,
            Colors.orange,
            'Warning',
          ),
          _buildAlertItem(
            'Temperature spike detected',
            '5 hours ago',
            Icons.thermostat,
            Colors.red,
            'Critical',
          ),
          _buildAlertItem(
            'Nutrient solution ready',
            '1 day ago',
            Icons.grain,
            Colors.blue,
            'Info',
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String message, String time, IconData icon, Color color, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EnvironmentTab extends StatelessWidget {
  final String selectedTimeRange;
  final AnimationController chartController;

  const EnvironmentTab({
    super.key,
    required this.selectedTimeRange,
    required this.chartController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildEnvironmentChart('Temperature', '°C', Colors.orange, 20, 30),
          const SizedBox(height: 24),
          _buildEnvironmentChart('Humidity', '%', Colors.blue, 40, 70),
          const SizedBox(height: 24),
          _buildEnvironmentChart('CO2 Levels', 'ppm', Colors.teal, 400, 1200),
          const SizedBox(height: 24),
          _buildEnvironmentChart('Light Intensity', 'lux', Colors.yellow, 20000, 60000),
        ],
      ),
    );
  }

  Widget _buildEnvironmentChart(String title, String unit, Color color, double min, double max) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}$unit',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateMockData(min, max),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.3),
                          color.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minY: min,
                maxY: max,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateMockData(double min, double max) {
    return List.generate(24, (index) {
      final value = min + (max - min) * (0.5 + 0.3 * (index / 24));
      return FlSpot(index.toDouble(), value);
    });
  }
}

class GrowthTab extends StatefulWidget {
  final String selectedTimeRange;
  final AnimationController chartController;

  const GrowthTab({
    super.key,
    required this.selectedTimeRange,
    required this.chartController,
  });

  @override
  State<GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends State<GrowthTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  Map<String, dynamic>? _growthAnalytics;

  @override
  void initState() {
    super.initState();
    _loadGrowthAnalytics();
  }

  Future<void> _loadGrowthAnalytics() async {
    try {
      await _analyticsService.initialize();
      final analytics = await _analyticsService.getDashboardAnalytics();
      setState(() {
        _growthAnalytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_growthAnalytics == null) {
      return Center(
        child: Text(
          'Unable to load growth analytics',
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plant Health Trends
          _buildPlantHealthTrends(colorScheme),

          const SizedBox(height: 24),

          // Growth Stage Distribution
          _buildGrowthStageDistribution(colorScheme),

          const SizedBox(height: 24),

          // Growth Rate Analysis
          _buildGrowthRateAnalysis(colorScheme),

          const SizedBox(height: 24),

          // Strain Performance Comparison
          _buildStrainPerformanceComparison(colorScheme),

          const SizedBox(height: 24),

          // Yield Predictions
          _buildYieldPredictions(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPlantHealthTrends(ColorScheme colorScheme) {
    final healthAnalytics = _growthAnalytics!['plant_health'] as Map<String, dynamic>? ?? {};
    final healthTrends = healthAnalytics['health_trends'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plant Health Trends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall plant health progression over time',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Day 1', 'Day 7', 'Day 14', 'Day 21', 'Day 28'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 65),
                      FlSpot(1, 72),
                      FlSpot(2, 78),
                      FlSpot(3, 85),
                      FlSpot(4, 87),
                    ],
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.3),
                          Colors.green.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minY: 40,
                maxY: 100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthMetric('Current Average', '87%', Colors.green),
              _buildHealthMetric('Improvement', '+22%', Colors.lightGreen),
              _buildHealthMetric('Issues Resolved', '12', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGrowthStageDistribution(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Stage Distribution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: 35,
                    title: 'Vegetative\n35%',
                    color: Colors.green,
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 40,
                    title: 'Flowering\n40%',
                    color: Colors.purple,
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 15,
                    title: 'Seedling\n15%',
                    color: Colors.lightGreen,
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 10,
                    title: 'Germination\n10%',
                    color: Colors.brown,
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
                centerSpaceRadius: 40,
                centerSpaceColor: Colors.grey.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthRateAnalysis(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Rate Analysis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}cm',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final weeks = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6'];
                        if (value.toInt() >= 0 && value.toInt() < weeks.length) {
                          return Text(
                            weeks[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: 15, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: 22, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(toY: 28, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 3, barRods: [
                    BarChartRodData(toY: 35, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 4, barRods: [
                    BarChartRodData(toY: 42, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 5, barRods: [
                    BarChartRodData(toY: 48, color: Colors.green),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Average Growth Rate: 5.5 cm/week',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrainPerformanceComparison(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strain Performance Comparison',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Growth Rate', 'Yield', 'Resilience', 'Quality', 'Efficiency'];
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          final angle = value * 72;
                          return Transform.rotate(
                            angle: angle * 3.14159 / 180,
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                radarTouchData: RadarTouchData(touchTooltipData: RadarTouchTooltipData()),
                radarBackgroundData: RadarBackgroundData(
                  fillColor: Colors.grey.withOpacity(0.1),
                ),
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.green.withOpacity(0.3),
                    borderColor: Colors.green,
                    entryRadius: 3,
                    dataEntries: [
                      const RadarEntry(value: 0.8),
                      const RadarEntry(value: 0.7),
                      const RadarEntry(value: 0.9),
                      const RadarEntry(value: 0.8),
                      const RadarEntry(value: 0.7),
                    ],
                  ),
                  RadarDataSet(
                    fillColor: Colors.purple.withOpacity(0.3),
                    borderColor: Colors.purple,
                    entryRadius: 3,
                    dataEntries: [
                      const RadarEntry(value: 0.7),
                      const RadarEntry(value: 0.8),
                      const RadarEntry(value: 0.6),
                      const RadarEntry(value: 0.9),
                      const RadarEntry(value: 0.8),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStrainLegend('Blue Dream', Colors.green),
              const SizedBox(width: 24),
              _buildStrainLegend('OG Kush', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrainLegend(String strain, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          strain,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildYieldPredictions(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yield Predictions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final predictions = [
                {
                  'strain': 'Blue Dream',
                  'yield': '450g',
                  'confidence': 'High',
                  'color': Colors.green,
                },
                {
                  'strain': 'OG Kush',
                  'yield': '380g',
                  'confidence': 'Medium',
                  'color': Colors.purple,
                },
                {
                  'strain': 'Northern Lights',
                  'yield': '520g',
                  'confidence': 'High',
                  'color': Colors.blue,
                },
                {
                  'strain': 'Girl Scout Cookies',
                  'yield': '410g',
                  'confidence': 'Low',
                  'color': Colors.orange,
                },
              ];

              final prediction = predictions[index];
              return _buildYieldCard(prediction, colorScheme);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYieldCard(Map<String, dynamic> prediction, ColorScheme colorScheme) {
    final color = prediction['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prediction['strain'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            prediction['yield'] as String,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yield Prediction',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${prediction['confidence']} Confidence',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PerformanceTab extends StatefulWidget {
  final String selectedTimeRange;
  final AnimationController chartController;

  const PerformanceTab({
    super.key,
    required this.selectedTimeRange,
    required this.chartController,
  });

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  Map<String, dynamic>? _performanceAnalytics;

  @override
  void initState() {
    super.initState();
    _loadPerformanceAnalytics();
  }

  Future<void> _loadPerformanceAnalytics() async {
    try {
      await _analyticsService.initialize();
      final analytics = await _analyticsService.getDashboardAnalytics();
      setState(() {
        _performanceAnalytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_performanceAnalytics == null) {
      return Center(
        child: Text(
          'Unable to load performance analytics',
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Automation Performance
          _buildAutomationPerformance(colorScheme),

          const SizedBox(height: 24),

          // Resource Efficiency Metrics
          _buildResourceEfficiency(colorScheme),

          const SizedBox(height: 24),

          // ROI Analysis
          _buildROIAnalysis(colorScheme),

          const SizedBox(height: 24),

          // Device Reliability
          _buildDeviceReliability(colorScheme),

          const SizedBox(height: 24),

          // Cost Analysis
          _buildCostAnalysis(colorScheme),
        ],
      ),
    );
  }

  Widget _buildAutomationPerformance(ColorScheme colorScheme) {
    final automationAnalytics = _performanceAnalytics!['automation_performance'] as Map<String, dynamic>? ?? {};
    final performanceMetrics = automationAnalytics['performance_metrics'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automation Performance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall system automation effectiveness',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final devices = ['Lights', 'Water', 'Fans', 'Heat', 'CO2', 'Pumps'];
                        if (value.toInt() >= 0 && value.toInt() < devices.length) {
                          return Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            alignment: Alignment.topRight,
                            child: Text(
                              devices[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: 95, color: Colors.green),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: 88, color: Colors.blue),
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(toY: 92, color: Colors.purple),
                  ]),
                  BarChartGroupData(x: 3, barRods: [
                    BarChartRodData(toY: 87, color: Colors.orange),
                  ]),
                  BarChartGroupData(x: 4, barRods: [
                    BarChartRodData(toY: 90, color: Colors.teal),
                  ]),
                  BarChartGroupData(x: 5, barRods: [
                    BarChartRodData(toY: 85, color: Colors.red),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPerformanceMetric('Overall Success', '90.2%', Colors.green),
              _buildPerformanceMetric('Schedule Adherence', '85.7%', Colors.blue),
              _buildPerformanceMetric('Response Time', '1.2s', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResourceEfficiency(ColorScheme colorScheme) {
    final efficiencyAnalytics = _performanceAnalytics!['efficiency_metrics'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resource Efficiency',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final metrics = [
                {
                  'label': 'Water Usage',
                  'value': '78%',
                  'color': Colors.blue,
                  'trend': 'down',
                  'trendValue': '-12%',
                },
                {
                  'label': 'Energy',
                  'value': '82%',
                  'color': Colors.green,
                  'trend': 'up',
                  'trendValue': '+5%',
                },
                {
                  'label': 'Nutrients',
                  'value': '85%',
                  'color': Colors.purple,
                  'trend': 'up',
                  'trendValue': '+8%',
                },
                {
                  'label': 'Time',
                  'value': '75%',
                  'color': Colors.orange,
                  'trend': 'down',
                  'trendValue': '-3%',
                },
              ];

              final metric = metrics[index];
              return _buildEfficiencyCard(metric, colorScheme);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard(Map<String, dynamic> metric, ColorScheme colorScheme) {
    final color = metric['color'] as Color;
    final trend = metric['trend'] as String;
    final trendValue = metric['trendValue'] as String;
    final isPositive = trend == 'up' && !trendValue.startsWith('-') ||
                       trend == 'down' && trendValue.startsWith('-');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric['label'] as String,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                metric['value'] as String,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trendValue,
                      style: TextStyle(
                        fontSize: 10,
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Efficiency',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildROIAnalysis(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return on Investment Analysis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Investment line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 500),
                      FlSpot(1, 800),
                      FlSpot(2, 1200),
                      FlSpot(3, 1500),
                      FlSpot(4, 1800),
                      FlSpot(5, 2000),
                    ],
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  // Revenue line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0),
                      FlSpot(1, 200),
                      FlSpot(2, 800),
                      FlSpot(3, 1800),
                      FlSpot(4, 3200),
                      FlSpot(5, 4500),
                    ],
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: 0,
                maxY: 5000,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildROILegend('Investment', Colors.red),
              const SizedBox(width: 24),
              _buildROILegend('Revenue', Colors.green),
              const SizedBox(width: 24),
              Text(
                'ROI: 125%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildROILegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceReliability(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Reliability',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...[
            {
              'device': 'LED Grow Lights',
              'uptime': '99.2%',
              'issues': 0,
              'color': Colors.green,
            },
            {
              'device': 'Water Pump System',
              'uptime': '96.8%',
              'issues': 2,
              'color': Colors.blue,
            },
            {
              'device': 'Climate Controller',
              'uptime': '98.1%',
              'issues': 1,
              'color': Colors.purple,
            },
            {
              'device': 'CO2 Generator',
              'uptime': '94.5%',
              'issues': 3,
              'color': Colors.orange,
            },
          ].map((device) => _buildDeviceReliabilityRow(device, colorScheme)).toList(),
        ],
      ),
    );
  }

  Widget _buildDeviceReliabilityRow(Map<String, dynamic> device, ColorScheme colorScheme) {
    final color = device['color'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.devices,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device['device'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Issues: ${device['issues']} this month',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                device['uptime'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: double.parse(device['uptime'].replaceAll('%', '')) / 100,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildCostAnalysis(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Cost Analysis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final costs = [
                {
                  'category': 'Electricity',
                  'amount': '\$125',
                  'change': '+8%',
                  'trend': 'up',
                  'color': Colors.yellow,
                },
                {
                  'category': 'Water',
                  'amount': '\$45',
                  'change': '-5%',
                  'trend': 'down',
                  'color': Colors.blue,
                },
                {
                  'category': 'Nutrients',
                  'amount': '\$78',
                  'change': '+2%',
                  'trend': 'up',
                  'color': Colors.green,
                },
                {
                  'category': 'Maintenance',
                  'amount': '\$32',
                  'change': '0%',
                  'trend': 'stable',
                  'color': Colors.purple,
                },
              ];

              final cost = costs[index];
              return _buildCostCard(cost, colorScheme);
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Monthly Cost',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '\$280',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCard(Map<String, dynamic> cost, ColorScheme colorScheme) {
    final color = cost['color'] as Color;
    final change = cost['change'] as String;
    final isIncrease = change.startsWith('+');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.attach_money,
                  color: color,
                  size: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isIncrease ? Colors.red : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isIncrease ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        color: isIncrease ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cost['category'] as String,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cost['amount'] as String,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}