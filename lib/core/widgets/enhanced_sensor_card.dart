import 'package:flutter/material.dart';
import '../providers/sensor_provider.dart';

class EnhancedSensorCard extends StatefulWidget {
  final String name;
  final String value;
  final String unit;
  final IconData icon;
  final SensorType type;
  final SensorStatus status;
  final bool showTrend;
  final int animationDelay;
  final AnimationController slideController;

  const EnhancedSensorCard({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
    required this.type,
    required this.status,
    this.showTrend = false,
    this.animationDelay = 0,
    required this.slideController,
  });

  @override
  State<EnhancedSensorCard> createState() => _EnhancedSensorCardState();
}

class _EnhancedSensorCardState extends State<EnhancedSensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.status == SensorStatus.critical) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(widget.status);
    final statusIcon = _getStatusIcon(widget.status);

    return AnimatedBuilder(
      animation: widget.slideController,
      builder: (context, child) {
        final animationProgress = (widget.slideController.value - (widget.animationDelay / 800))
            .clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 50 * (1 - animationProgress)),
          child: Opacity(
            opacity: animationProgress,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.status == SensorStatus.critical ? _pulseAnimation.value : 1.0,
                  child: GestureDetector(
                    onTap: () {
                      _showSensorDetails(context);
                    },
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
                          if (widget.status == SensorStatus.critical)
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: widget.status == SensorStatus.critical ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderRow(colorScheme, statusColor, statusIcon),
                          const SizedBox(height: 12),
                          _buildValueSection(colorScheme),
                          const SizedBox(height: 8),
                          _buildProgressBar(statusColor),
                          const SizedBox(height: 8),
                          _buildStatusSection(statusColor),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(ColorScheme colorScheme, Color statusColor, IconData statusIcon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icon,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        Row(
          children: [
            if (widget.showTrend) ...[
              _buildTrendIndicator(),
              const SizedBox(width: 8),
            ],
            Icon(
              statusIcon,
              color: statusColor,
              size: 16,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    // Mock trend data - in real app this would come from provider
    final isIncreasing = DateTime.now().millisecond % 2 == 0;
    final trendValue = (DateTime.now().millisecond % 10 + 1).toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isIncreasing ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: isIncreasing ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 2),
          Text(
            '$trendValue%',
            style: TextStyle(
              color: isIncreasing ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueSection(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            widget.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.unit.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(
            widget.unit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(Color statusColor) {
    final progress = _calculateProgress();

    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getStatusText(widget.status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
        Text(
          _getOptimalRange(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  double _calculateProgress() {
    // Calculate progress based on sensor type and current value
    final value = double.tryParse(widget.value) ?? 0.0;

    switch (widget.type) {
      case SensorType.temperature:
        return (value.clamp(15.0, 30.0) - 15.0) / 15.0;
      case SensorType.humidity:
        return (value.clamp(30.0, 80.0) - 30.0) / 50.0;
      case SensorType.ph:
        return (value.clamp(5.5, 7.5) - 5.5) / 2.0;
      case SensorType.lightIntensity:
        return (value.clamp(20000.0, 60000.0) - 20000.0) / 40000.0;
      case SensorType.co2:
        return (value.clamp(400.0, 1200.0) - 400.0) / 800.0;
      case SensorType.ec:
        return (value.clamp(1.0, 3.0) - 1.0) / 2.0;
      case SensorType.vpd:
        return (value.clamp(0.8, 1.5) - 0.8) / 0.7;
    }
  }

  String _getOptimalRange() {
    switch (widget.type) {
      case SensorType.temperature:
        return 'Optimal: 20-26°C';
      case SensorType.humidity:
        return 'Optimal: 40-60%';
      case SensorType.ph:
        return 'Optimal: 5.8-6.8';
      case SensorType.lightIntensity:
        return 'Optimal: 30000-50000 lux';
      case SensorType.co2:
        return 'Optimal: 800-1200 ppm';
      case SensorType.ec:
        return 'Optimal: 1.2-2.0 mS/cm';
      case SensorType.vpd:
        return 'Optimal: 0.8-1.2 kPa';
    }
  }

  void _showSensorDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SensorDetailsSheet(
        name: widget.name,
        value: widget.value,
        unit: widget.unit,
        icon: widget.icon,
        type: widget.type,
        status: widget.status,
      ),
    );
  }

  Color _getStatusColor(SensorStatus status) {
    switch (status) {
      case SensorStatus.optimal:
        return Colors.green;
      case SensorStatus.warning:
        return Colors.orange;
      case SensorStatus.critical:
        return Colors.red;
      case SensorStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(SensorStatus status) {
    switch (status) {
      case SensorStatus.optimal:
        return Icons.check_circle;
      case SensorStatus.warning:
        return Icons.warning;
      case SensorStatus.critical:
        return Icons.error;
      case SensorStatus.unknown:
        return Icons.help;
    }
  }

  String _getStatusText(SensorStatus status) {
    switch (status) {
      case SensorStatus.optimal:
        return 'Optimal';
      case SensorStatus.warning:
        return 'Warning';
      case SensorStatus.critical:
        return 'Critical';
      case SensorStatus.unknown:
        return 'Unknown';
    }
  }
}

class SensorDetailsSheet extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final IconData icon;
  final SensorType type;
  final SensorStatus status;

  const SensorDetailsSheet({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
    required this.type,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Current: $value$unit',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailsSection(context),
                const SizedBox(height: 24),
                _buildActionButtons(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Optimal Range', _getOptimalRange()),
        _buildDetailRow('Current Status', _getStatusText(status)),
        _buildDetailRow('Last Updated', '${DateTime.now().difference(Duration(minutes: 5)).inMinutes} minutes ago'),
        _buildDetailRow('Calibration', 'Next: ${DateTime.now().add(Duration(days: 7)).day}/${DateTime.now().add(Duration(days: 7)).month}'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to calibration
            },
            icon: const Icon(Icons.tune),
            label: const Text('Calibrate Sensor'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to history
            },
            icon: const Icon(Icons.history),
            label: const Text('View History'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _getOptimalRange() {
    switch (type) {
      case SensorType.temperature:
        return '20-26°C';
      case SensorType.humidity:
        return '40-60%';
      case SensorType.ph:
        return '5.8-6.8 pH';
      case SensorType.lightIntensity:
        return '30000-50000 lux';
      case SensorType.co2:
        return '800-1200 ppm';
      case SensorType.ec:
        return '1.2-2.0 mS/cm';
      case SensorType.vpd:
        return '0.8-1.2 kPa';
    }
  }

  Color _getStatusColor(SensorStatus status) {
    switch (status) {
      case SensorStatus.optimal:
        return Colors.green;
      case SensorStatus.warning:
        return Colors.orange;
      case SensorStatus.critical:
        return Colors.red;
      case SensorStatus.unknown:
        return Colors.grey;
    }
  }

  String _getStatusText(SensorStatus status) {
    switch (status) {
      case SensorStatus.optimal:
        return 'Optimal';
      case SensorStatus.warning:
        return 'Warning';
      case SensorStatus.critical:
        return 'Critical';
      case SensorStatus.unknown:
        return 'Unknown';
    }
  }
}