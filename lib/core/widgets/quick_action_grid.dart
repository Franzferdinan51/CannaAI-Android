import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/automation_provider.dart';

class QuickActionGrid extends ConsumerWidget {
  final AnimationController animationController;

  const QuickActionGrid({
    super.key,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = [
      {
        'title': 'Water Now',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'description': 'Start immediate watering',
      },
      {
        'title': 'Toggle Lights',
        'icon': Icons.lightbulb,
        'color': Colors.orange,
        'description': 'Switch light status',
      },
      {
        'title': 'Analyze Plant',
        'icon': Icons.photo_camera,
        'color': Colors.green,
        'description': 'AI plant analysis',
      },
      {
        'title': 'Optimize',
        'icon': Icons.auto_awesome,
        'color': Colors.purple,
        'description': 'Optimize environment',
      },
      {
        'title': 'Adjust Nutrients',
        'icon': Icons.grain,
        'color': Colors.teal,
        'description': 'Modify feeding',
      },
      {
        'title': 'View Logs',
        'icon': Icons.history,
        'color': Colors.indigo,
        'description': 'System history',
      },
    ];

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationController.value)),
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
                      Icon(
                        Icons.flash_on,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: actions.length,
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      final delay = index * 100;

                      return AnimatedBuilder(
                        animation: animationController,
                        builder: (context, child) {
                          final progress = ((animationController.value * 1000) - delay).clamp(0.0, 600.0) / 600.0;

                          return Transform.scale(
                            scale: 0.8 + (0.2 * progress),
                            child: Opacity(
                              opacity: progress,
                              child: _buildActionTile(
                                action['title'] as String,
                                action['icon'] as IconData,
                                action['color'] as Color,
                                action['description'] as String,
                                colorScheme,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon,
    Color color,
    String description,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () {
        _handleActionTap(title);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionTap(String action) {
    switch (action) {
      case 'Water Now':
        // Start watering
        break;
      case 'Toggle Lights':
        // Toggle lights
        break;
      case 'Analyze Plant':
        // Navigate to plant analysis
        break;
      case 'Optimize':
        // Optimize environment
        break;
      case 'Adjust Nutrients':
        // Adjust nutrients
        break;
      case 'View Logs':
        // View system logs
        break;
    }
  }
}