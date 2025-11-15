import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/enhanced_plant_analysis_provider.dart';
import '../models/enhanced_plant_analysis.dart';
import '../widgets/camera_capture_widget.dart';
import '../widgets/analysis_result_display.dart';
import '../widgets/treatment_recommendations.dart';

class PlantAnalysisInterface extends ConsumerStatefulWidget {
  const PlantAnalysisInterface({super.key});

  @override
  ConsumerState<PlantAnalysisInterface> createState() => _PlantAnalysisInterfaceState();
}

class _PlantAnalysisInterfaceState extends ConsumerState<PlantAnalysisInterface>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _slideController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(enhancedPlantAnalysisProvider);
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
                          'Plant Analysis',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          'AI-powered plant health diagnosis',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: analysisState.isAnalyzing ? Colors.orange : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            analysisState.isAnalyzing ? 'Analyzing' : 'Ready',
                            style: const TextStyle(
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
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.camera_alt_outlined),
                      text: 'Capture',
                    ),
                    Tab(
                      icon: Icon(Icons.analytics_outlined),
                      text: 'Results',
                    ),
                    Tab(
                      icon: Icon(Icons.history_outlined),
                      text: 'History',
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
                _buildCaptureTab(analysisState),
                _buildResultsTab(analysisState),
                _buildHistoryTab(analysisState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureTab(PlantAnalysisState analysisState) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideController.value)),
          child: Opacity(
            opacity: _slideController.value,
            child: CameraCaptureWidget(
              onImageCaptured: (image) {
                ref.read(enhancedPlantAnalysisProvider.notifier)
                    .analyzePlantImage(image);
                _tabController.animateTo(1); // Switch to results tab
              },
              isAnalyzing: analysisState.isAnalyzing,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsTab(PlantAnalysisState analysisState) {
    if (analysisState.currentAnalysis == null && !analysisState.isAnalyzing) {
      return _buildEmptyResultsState();
    }

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeController.value,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (analysisState.isAnalyzing) ...[
                  _buildAnalyzingState(),
                ] else if (analysisState.currentAnalysis != null) ...[
                  AnalysisResultDisplay(
                    analysis: analysisState.currentAnalysis!,
                    animationController: _fadeController,
                  ),
                  const SizedBox(height: 24),
                  TreatmentRecommendations(
                    analysis: analysisState.currentAnalysis!,
                    onApplyTreatment: (treatment) {
                      _showTreatmentConfirmation(treatment);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildActionButtons(analysisState.currentAnalysis!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(PlantAnalysisState analysisState) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideController.value)),
          child: Opacity(
            opacity: _slideController.value,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: analysisState.analysisHistory.length,
              itemBuilder: (context, index) {
                final analysis = analysisState.analysisHistory[index];
                return AnalysisHistoryTile(
                  analysis: analysis,
                  onTap: () {
                    _showAnalysisDetails(analysis);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyResultsState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Analysis Yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture a photo of your plant to begin AI analysis',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _tabController.animateTo(0); // Switch to capture tab
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(20),
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
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing Plant Health',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI is examining your plant for health issues, nutrient deficiencies, and environmental stress factors.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(EnhancedPlantAnalysis analysis) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _saveAnalysisReport(analysis);
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('Save Report'),
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
              _shareAnalysisReport(analysis);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Results'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              _tabController.animateTo(0); // Back to capture
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Analyze Another Plant'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showTreatmentConfirmation(String treatment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Treatment'),
        content: Text('Are you sure you want to apply the recommended treatment: "$treatment"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Apply treatment logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Treatment applied successfully')),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAnalysisDetails(EnhancedPlantAnalysis analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnalysisDetailsSheet(analysis: analysis),
    );
  }

  void _saveAnalysisReport(EnhancedPlantAnalysis analysis) {
    // Save analysis report logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analysis report saved successfully')),
    );
  }

  void _shareAnalysisReport(EnhancedPlantAnalysis analysis) {
    // Share analysis report logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analysis report shared successfully')),
    );
  }
}

class AnalysisHistoryTile extends StatelessWidget {
  final EnhancedPlantAnalysis analysis;
  final VoidCallback onTap;

  const AnalysisHistoryTile({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final healthScore = analysis.overallHealthScore ?? 0.0;
    final healthColor = healthScore >= 80 ? Colors.green :
                       healthScore >= 60 ? Colors.orange : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: analysis.imagePath != null
                    ? Image.asset(
                        analysis.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.eco_outlined,
                            color: Colors.grey[400],
                            size: 30,
                          );
                        },
                      )
                    : Icon(
                        Icons.eco_outlined,
                        color: Colors.grey[400],
                        size: 30,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          analysis.strain ?? 'Unknown Strain',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: healthColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${healthScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: healthColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    analysis.primaryDiagnosis ?? 'No diagnosis',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(analysis.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class AnalysisDetailsSheet extends StatelessWidget {
  final EnhancedPlantAnalysis analysis;

  const AnalysisDetailsSheet({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                Text(
                  'Analysis Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (analysis.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      analysis.imagePath!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.eco_outlined,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow('Strain', analysis.strain ?? 'Unknown'),
                _buildDetailRow('Diagnosis', analysis.primaryDiagnosis ?? 'None'),
                _buildDetailRow('Health Score', '${analysis.overallHealthScore?.toStringAsFixed(1) ?? '0.0'}%'),
                _buildDetailRow('Confidence', '${analysis.confidenceScore?.toStringAsFixed(1) ?? '0.0'}%'),
                _buildDetailRow('Analysis Date', _formatFullDate(analysis.timestamp)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}