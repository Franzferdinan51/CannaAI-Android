import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enhanced_plant_analysis.dart';
import '../providers/automation_provider.dart';

class TreatmentRecommendations extends ConsumerStatefulWidget {
  final EnhancedPlantAnalysis analysis;
  final Function(String) onApplyTreatment;

  const TreatmentRecommendations({
    super.key,
    required this.analysis,
    required this.onApplyTreatment,
  });

  @override
  ConsumerState<TreatmentRecommendations> createState() => _TreatmentRecommendationsState();
}

class _TreatmentRecommendationsState extends ConsumerState<TreatmentRecommendations>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recommendations = _generateRecommendations();

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _slideController.value)),
          child: Opacity(
            opacity: _slideController.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.tertiary.withOpacity(0.1),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.tertiary.withOpacity(0.2),
                  width: 1,
                ),
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
                          color: colorScheme.tertiary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.healing_outlined,
                          color: colorScheme.tertiary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recommended Treatments',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showDetails = !_showDetails;
                          });
                        },
                        child: Text(_showDetails ? 'Show Less' : 'Show Details'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeController.value,
                        child: Column(
                          children: [
                            // Priority treatment
                            if (recommendations['priority'] != null) ...[
                              _buildTreatmentCard(
                                recommendations['priority']!,
                                isPriority: true,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Secondary treatments
                            if (recommendations['secondary'] != null) ...[
                              Text(
                                'Additional Recommendations',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...recommendations['secondary']!.map((treatment) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTreatmentCard(
                                  treatment,
                                  isPriority: false,
                                  colorScheme: colorScheme,
                                ),
                              )),
                            ],

                            // Prevention measures
                            if (recommendations['prevention'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Prevention Measures',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...recommendations['prevention']!.map((treatment) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTreatmentCard(
                                  treatment,
                                  isPriority: false,
                                  isPrevention: true,
                                  colorScheme: colorScheme,
                                ),
                              )),
                            ],
                          ],
                        ),
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

  Widget _buildTreatmentCard(
    Treatment treatment, {
    required bool isPriority,
    required ColorScheme colorScheme,
    bool isPrevention = false,
  }) {
    final cardColor = isPriority
        ? Colors.red.withOpacity(0.1)
        : isPrevention
            ? Colors.blue.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1);

    final borderColor = isPriority
        ? Colors.red.withOpacity(0.3)
        : isPrevention
            ? Colors.blue.withOpacity(0.3)
            : Colors.orange.withOpacity(0.3);

    final iconColor = isPriority ? Colors.red : isPrevention ? Colors.blue : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isPriority ? 2 : 1),
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
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  treatment.icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            treatment.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                        if (isPriority)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PRIORITY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                      Text(
                        treatment.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            treatment.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          if (_showDetails && treatment.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...treatment.details.map((detail) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: iconColor,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            detail,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showTreatmentInstructions(treatment);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Instructions'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: iconColor),
                    foregroundColor: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onApplyTreatment(treatment.title);
                    _applyTreatment(treatment);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, List<Treatment>> _generateRecommendations() {
    final recommendations = <String, List<Treatment>>{
      'priority': [],
      'secondary': [],
      'prevention': [],
    };

    final healthScore = widget.analysis.overallHealthScore ?? 0.0;

    // Priority treatments based on critical issues
    if (healthScore < 40) {
      recommendations['priority']!.addAll([
        Treatment(
          title: 'Immediate Nutrient Intervention',
          category: 'Nutrition',
          description: 'Apply balanced fertilizer solution to address severe nutrient deficiency',
          icon: Icons.grain,
          urgency: 'immediate',
          details: [
            'Use pH-balanced nutrient solution (5.8-6.2)',
            'Apply at 1/4 strength to avoid shock',
            'Monitor plant response over 48 hours',
            'Gradually increase to full strength over 3-4 days'
          ],
        ),
        Treatment(
          title: 'Environmental Adjustment',
          category: 'Environment',
          description: 'Optimize growing conditions immediately',
          icon: Icons.thermostat,
          urgency: 'immediate',
          details: [
            'Check temperature: maintain 20-26°C',
            'Verify humidity levels: 40-60% RH',
            'Ensure proper air circulation',
            'Adjust lighting distance and intensity'
          ],
        ),
      ]);
    }

    // Secondary treatments
    if (widget.analysis.isNutrientDeficiency == true) {
      recommendations['secondary']!.add(Treatment(
        title: 'Nutrient Supplementation',
        category: 'Nutrition',
        description: 'Supplement specific nutrients based on deficiency symptoms',
        icon: Icons.grain,
        urgency: 'within 24 hours',
        details: [
          'Identify specific nutrient deficiencies',
          'Use targeted nutrient supplements',
          'Apply according to manufacturer instructions',
          'Monitor for improvement over 5-7 days'
        ],
      ));
    }

    if (widget.analysis.isEnvironmentalStress == true) {
      recommendations['secondary']!.add(Treatment(
        title: 'Stress Reduction Protocol',
        category: 'Environment',
        description: 'Reduce environmental stress factors',
        icon: Icons.air,
        urgency: 'within 24 hours',
        details: [
          'Check for proper ventilation',
          'Verify CO2 levels (800-1200 ppm)',
          'Ensure stable environmental conditions',
          'Avoid sudden temperature/humidity changes'
        ],
      ));
    }

    // Prevention measures
    recommendations['prevention']!.addAll([
      Treatment(
        title: 'Regular Monitoring Schedule',
        category: 'Prevention',
        description: 'Implement regular plant health monitoring',
        icon: Icons.schedule,
        urgency: 'ongoing',
        details: [
          'Daily visual inspections',
          'Weekly detailed health assessments',
          'Monthly comprehensive analysis',
          'Document all observations and treatments'
        ],
      ),
      Treatment(
        title: 'Optimized Feeding Schedule',
        category: 'Prevention',
        description: 'Establish and maintain optimal feeding routine',
        icon: Icons.water_drop,
        urgency: 'ongoing',
        details: [
          'Create consistent feeding schedule',
          'Monitor pH and EC levels regularly',
          'Adjust nutrient strength based on growth stage',
          'Keep detailed feeding logs'
        ],
      ),
    ]);

    return recommendations;
  }

  void _applyTreatment(Treatment treatment) {
    // Update automation provider with treatment
    if (treatment.category == 'Nutrition') {
      ref.read(automationProvider.notifier).adjustNutrients();
    } else if (treatment.category == 'Environment') {
      ref.read(automationProvider.notifier).optimizeEnvironment();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Treatment "${treatment.title}" applied successfully'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTreatmentInstructions(Treatment treatment) {
    showDialog(
      context: context,
      builder: (context) => TreatmentInstructionsDialog(treatment: treatment),
    );
  }
}

class Treatment {
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final String urgency;
  final List<String> details;

  Treatment({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.urgency,
    this.details = const [],
  });
}

class TreatmentInstructionsDialog extends StatelessWidget {
  final Treatment treatment;

  const TreatmentInstructionsDialog({
    super.key,
    required this.treatment,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgencyColor = treatment.urgency == 'immediate'
        ? Colors.red
        : treatment.urgency == 'within 24 hours'
            ? Colors.orange
            : Colors.blue;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            treatment.icon,
            color: urgencyColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              treatment.title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category and urgency
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    treatment.urgency.toUpperCase(),
                    style: TextStyle(
                      color: urgencyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  treatment.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              treatment.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            // Detailed instructions
            if (treatment.details.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Step-by-step Instructions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...treatment.details.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final instruction = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instruction,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Safety notes
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Always wear protective equipment when handling nutrients and chemicals. Follow manufacturer guidelines and safety precautions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Apply treatment logic here
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: urgencyColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply Treatment'),
        ),
      ],
    );
  }
}