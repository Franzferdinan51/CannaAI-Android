import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/enhanced_sensor_provider.dart';
import '../providers/enhanced_plant_analysis_provider.dart';
import '../providers/automation_provider.dart';
import '../models/sensor_data.dart';
import '../models/room_config.dart';
import '../widgets/enhanced_sensor_card.dart';
import '../widgets/room_selector.dart';
import '../widgets/plant_health_preview.dart';
import '../widgets/automation_status_card.dart';
import '../widgets/ai_assistant_card.dart';
import '../widgets/quick_action_grid.dart';

class EnhancedMainDashboard extends ConsumerStatefulWidget {
  const EnhancedMainDashboard({super.key});

  @override
  ConsumerState<EnhancedMainDashboard> createState() => _EnhancedMainDashboardState();
}

class _EnhancedMainDashboardState extends ConsumerState<EnhancedMainDashboard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _chartController;
  late TabController _tabController;

  String _selectedRoom = 'Main Room';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _tabController = TabController(length: 4, vsync: this);

    // Start animations with delays
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _chartController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _chartController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensorData = ref.watch(enhancedSensorProvider);
    final plantAnalysisData = ref.watch(enhancedPlantAnalysisProvider);
    final automationState = ref.watch(automationProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Enhanced App Header with Room Selection
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.secondary.withOpacity(0.05),
                        colorScheme.tertiary.withOpacity(0.02),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreetingSection(colorScheme),
                          const SizedBox(height: 16),
                          _buildGlobalStatusRow(automationState, colorScheme),
                          const SizedBox(height: 16),
                          _buildRoomSelector(colorScheme),
                          const SizedBox(height: 16),
                          _buildQuickStatsRow(sensorData, plantAnalysisData, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: colorScheme.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined),
                    text: 'Overview',
                  ),
                  Tab(
                    icon: Icon(Icons.sensors_outlined),
                    text: 'Sensors',
                  ),
                  Tab(
                    icon: Icon(Icons.eco_outlined),
                    text: 'Plants',
                  ),
                  Tab(
                    icon: Icon(Icons.auto_awesome_outlined),
                    text: 'Automation',
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildOverviewTab(sensorData, plantAnalysisData, automationState),
            _buildSensorsTab(sensorData),
            _buildPlantsTab(plantAnalysisData),
            _buildAutomationTab(automationState),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final animationProgress = _slideController.value;

        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationProgress)),
          child: Opacity(
            opacity: animationProgress,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_getTimeOfDay()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CannaAI Pro Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$_selected Room Control Center',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 4 * _pulseController.value,
                                    spreadRadius: 2 * _pulseController.value,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'System Online',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlobalStatusRow(automationState, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final animationProgress = (_slideController.value - 0.2).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationProgress)),
          child: Opacity(
            opacity: animationProgress,
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGlobalStatusItem(
                    Icons.thermostat_outlined,
                    'Environment',
                    'Optimal',
                    Colors.green,
                  ),
                  _buildGlobalStatusItem(
                    Icons.eco_outlined,
                    'Plant Health',
                    '${12 + (_selectedRoom == 'Main Room' ? 0 : 6)} Active',
                    colorScheme.primary,
                  ),
                  _buildGlobalStatusItem(
                    Icons.auto_awesome_outlined,
                    'Automations',
                    '${automationState.activeAutomations} Running',
                    Colors.orange,
                  ),
                  _buildGlobalStatusItem(
                    Icons.warning_outlined,
                    'Alerts',
                    '2 Active',
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlobalStatusItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomSelector(ColorScheme colorScheme) {
    return RoomSelector(
      selectedRoom: _selectedRoom,
      onRoomSelected: (room) {
        setState(() {
          _selectedRoom = room;
        });
      },
    );
  }

  Widget _buildQuickStatsRow(sensorData, plantAnalysisData, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final animationProgress = (_slideController.value - 0.4).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 40 * (1 - animationProgress)),
          child: Opacity(
            opacity: animationProgress,
            child: Row(
              children: [
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: '${sensorData.getLatestValue(SensorType.temperature)?.toStringAsFixed(1) ?? '0.0'}°C',
                    color: Colors.orange,
                    trend: '+2.1°',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: '${sensorData.getLatestValue(SensorType.humidity)?.toStringAsFixed(0) ?? '0'}%',
                    color: Colors.blue,
                    trend: '-5%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.eco,
                    label: 'Health Score',
                    value: '${plantAnalysisData.overallHealthScore?.toStringAsFixed(0) ?? '85'}%',
                    color: Colors.green,
                    trend: '+3%',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(sensorData, plantAnalysisData, automationState) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),

        // Sensor Grid Preview
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final mainSensors = [
                  {'type': SensorType.temperature, 'name': 'Temperature', 'icon': Icons.thermostat, 'unit': '°C'},
                  {'type': SensorType.humidity, 'name': 'Humidity', 'icon': Icons.water_drop, 'unit': '%'},
                  {'type': SensorType.ph, 'name': 'pH Level', 'icon': Icons.science, 'unit': ''},
                  {'type': SensorType.lightIntensity, 'name': 'Light Intensity', 'icon': Icons.lightbulb, 'unit': 'lux'},
                ];

                if (index >= mainSensors.length) return null;

                final sensor = mainSensors[index];
                final sensorType = sensor['type'] as SensorType;

                return EnhancedSensorCard(
                  name: sensor['name'] as String,
                  value: sensorData.getLatestValue(sensorType)?.toStringAsFixed(1) ?? '0.0',
                  unit: sensor['unit'] as String,
                  icon: sensor['icon'] as IconData,
                  type: sensorType,
                  status: sensorData.getSensorStatus(sensorType),
                  showTrend: true,
                  animationDelay: index * 100,
                  slideController: _slideController,
                );
              },
              childCount: 4,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 24)),

        // Plant Health Preview
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PlantHealthPreview(
              analysisData: plantAnalysisData,
              animationController: _chartController,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 24)),

        // Automation Status
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutomationStatusCard(
              automationState: automationState,
              animationController: _slideController,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 24)),

        // AI Assistant Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AIAssistantCard(
              animationController: _slideController,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSensorsTab(sensorData) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),

        // All Sensors Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final allSensors = [
                  {'type': SensorType.temperature, 'name': 'Temperature', 'icon': Icons.thermostat, 'unit': '°C'},
                  {'type': SensorType.humidity, 'name': 'Humidity', 'icon': Icons.water_drop, 'unit': '%'},
                  {'type': SensorType.ph, 'name': 'pH Level', 'icon': Icons.science, 'unit': ''},
                  {'type': SensorType.lightIntensity, 'name': 'Light Intensity', 'icon': Icons.lightbulb, 'unit': 'lux'},
                  {'type': SensorType.co2, 'name': 'CO₂ Level', 'icon': Icons.air, 'unit': 'ppm'},
                  {'type': SensorType.ec, 'name': 'EC Level', 'icon': Icons.electric_bolt, 'unit': 'mS/cm'},
                  {'type': SensorType.vpd, 'name': 'VPD', 'icon': Icons.water, 'unit': 'kPa'},
                ];

                if (index >= allSensors.length) return null;

                final sensor = allSensors[index];
                final sensorType = sensor['type'] as SensorType;

                return EnhancedSensorCard(
                  name: sensor['name'] as String,
                  value: sensorData.getLatestValue(sensorType)?.toStringAsFixed(1) ?? '0.0',
                  unit: sensor['unit'] as String,
                  icon: sensor['icon'] as IconData,
                  type: sensorType,
                  status: sensorData.getSensorStatus(sensorType),
                  showTrend: true,
                  animationDelay: index * 100,
                  slideController: _slideController,
                );
              },
              childCount: 7,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPlantsTab(plantAnalysisData) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),

        // Plant Health Overview
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PlantHealthPreview(
              analysisData: plantAnalysisData,
              animationController: _chartController,
              expanded: true,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildAutomationTab(automationState) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),

        // Quick Actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: QuickActionGrid(
              animationController: _slideController,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 24)),

        // Automation Status
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutomationStatusCard(
              automationState: automationState,
              animationController: _slideController,
              expanded: true,
            ),
          ),
        ),

        SliverToBoxAdapter(child: const SizedBox(height: 100)),
      ],
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String trend;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trend.startsWith('+') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: trend.startsWith('+') ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}