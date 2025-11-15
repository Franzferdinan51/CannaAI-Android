import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/enhanced_plant_analysis_provider.dart';
import '../models/enhanced_plant_analysis.dart';

class PlantHealthPreview extends ConsumerWidget {
  final dynamic analysisData;
  final AnimationController animationController;
  final bool expanded;

  const PlantHealthPreview({
    super.key,
    required this.analysisData,
    required this.animationController,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final healthScore = analysisData.overallHealthScore ?? 85.0;

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationController.value)),
          child: Opacity(
            opacity: animationController.value,
            child: Container(
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.eco_outlined,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Plant Health Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (expanded) ...[
                    _buildExpandedHealthView(colorScheme, healthScore),
                  ] else ...[
                    _buildCompactHealthView(colorScheme, healthScore),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactHealthView(ColorScheme colorScheme, double healthScore) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildHealthScoreRing(healthScore, colorScheme),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthMetric('Leaf Health', 92, Colors.green),
              const SizedBox(height: 8),
              _buildHealthMetric('Nutrients', 78, Colors.orange),
              const SizedBox(height: 8),
              _buildHealthMetric('Water Status', 85, Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedHealthView(ColorScheme colorScheme, double healthScore) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHealthScoreRing(healthScore, colorScheme),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildHealthChart(colorScheme),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailedMetrics(colorScheme),
      ],
    );
  }

  Widget _buildHealthScoreRing(double score, ColorScheme colorScheme) {
    final healthColor = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;

    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  value: score / 100.0,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: healthColor,
                    ),
                  ),
                  Text(
                    'HEALTH',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : 'Needs Attention',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: healthColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthChart(ColorScheme colorScheme) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 70),
                const FlSpot(1, 75),
                const FlSpot(2, 82),
                const FlSpot(3, 78),
                const FlSpot(4, 85),
                const FlSpot(5, 88),
                const FlSpot(6, 85),
              ],
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.3),
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.primary.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: 60,
          maxY: 100,
        ),
      ),
    );
  }

  Widget _buildHealthMetric(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics(ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Leaf Health',
                92,
                Icons.eco,
                Colors.green,
                'No visible issues',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Nutrients',
                78,
                Icons.grain,
                Colors.orange,
                'Slight deficiency',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Water Status',
                85,
                Icons.water_drop,
                Colors.blue,
                'Optimal hydration',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Light Exposure',
                88,
                Icons.lightbulb,
                Colors.yellow,
                'Good coverage',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, double value, IconData icon, Color color, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}