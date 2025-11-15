import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/automation_provider.dart';

class AutomationStatusCard extends ConsumerWidget {
  final dynamic automationState;
  final AnimationController animationController;
  final bool expanded;

  const AutomationStatusCard({
    super.key,
    required this.automationState,
    required this.animationController,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

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
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Automation Status',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (expanded) ...[
                    _buildExpandedStatus(colorScheme),
                  ] else ...[
                    _buildCompactStatus(colorScheme),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactStatus(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusItem(
            'Watering',
            Icons.water_drop,
            Colors.blue,
            'Scheduled',
            'Next: 2h 15m',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusItem(
            'Lighting',
            Icons.lightbulb,
            Colors.orange,
            'Active',
            'On: 16h',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusItem(
            'Climate',
            Icons.thermostat,
            Colors.green,
            'Optimal',
            '23.5°C',
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedStatus(ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDetailedStatusCard(
                'Watering System',
                Icons.water_drop,
                Colors.blue,
                'Scheduled',
                'Next watering in 2h 15m',
                [
                  'Moisture: 45%',
                  'Last: 6h ago',
                  'Duration: 15s',
                  'Tank: 85%',
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailedStatusCard(
                'Lighting System',
                Icons.lightbulb,
                Colors.orange,
                'Active',
                'On for 16 hours',
                [
                  'Intensity: 75%',
                  'Schedule: 18/6',
                  'Spectrum: Full',
                  'Energy: 12.5kWh',
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailedStatusCard(
                'Climate Control',
                Icons.thermostat,
                Colors.green,
                'Optimal',
                'Environment stable',
                [
                  'Temp: 23.5°C',
                  'Humidity: 55%',
                  'CO2: 850ppm',
                  'VPD: 1.2kPa',
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActions(colorScheme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusItem(String title, IconData icon, Color color, String status, String detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 11,
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatusCard(
    String title,
    IconData icon,
    Color color,
    String status,
    String description,
    List<String> metrics,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          ...metrics.map((metric) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric.split(':')[0],
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  metric.split(':')[1],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Icon(
                Icons.flash_on,
                color: colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Quick water action
              },
              icon: const Icon(Icons.water_drop, size: 16),
              label: const Text('Water Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Toggle lights action
              },
              icon: const Icon(Icons.lightbulb, size: 16),
              label: const Text('Toggle Lights'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                foregroundColor: Colors.orange,
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Optimize environment action
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Optimize'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.primary),
                foregroundColor: colorScheme.primary,
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}