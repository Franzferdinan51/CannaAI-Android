import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/plant_lifecycle.dart';
import '../services/plant_lifecycle_service.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

/// Comprehensive plant lifecycle management interface
class PlantLifecycleManager extends ConsumerStatefulWidget {
  const PlantLifecycleManager({super.key});

  @override
  ConsumerState<PlantLifecycleManager> createState() => _PlantLifecycleManagerState();
}

class _PlantLifecycleManagerState extends ConsumerState<PlantLifecycleManager>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fabController;
  late AnimationController _listController;
  final PlantLifecycleService _lifecycleService = PlantLifecycleService();
  List<PlantLifecycle> _plants = [];
  bool _isLoading = true;
  String _selectedRoomId = 'all';
  GrowthStage? _selectedStage;
  PlantStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _lifecycleService.initialize().then((_) {
      _loadPlants();
    });

    _fabController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadPlants() async {
    setState(() => _isLoading = true);
    try {
      final plants = await _lifecycleService.getUserPlants('current_user');
      setState(() {
        _plants = plants;
        _isLoading = false;
      });
      _listController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load plants: $e')),
        );
      }
    }
  }

  List<PlantLifecycle> get _filteredPlants {
    var filtered = List<PlantLifecycle>.from(_plants);

    if (_selectedRoomId != 'all') {
      filtered = filtered.where((p) => p.roomId == _selectedRoomId).toList();
    }

    if (_selectedStage != null) {
      filtered = filtered.where((p) => p.currentStage == _selectedStage).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered.where((p) => p.status == _selectedStatus).toList();
    }

    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: _buildFloatingActionButton(colorScheme),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.eco_outlined,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plant Lifecycle Manager',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Track your plants from seed to harvest',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showAnalytics,
                      icon: Icon(Icons.analytics_outlined, color: colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Filters
                _buildFilters(colorScheme),
                const SizedBox(height: 16),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icons.list_alt,
                      text: 'Plants',
                    ),
                    Tab(
                      icon: Icons.timeline,
                      text: 'Timeline',
                    ),
                    Tab(
                      icon: Icons.insights,
                      text: 'Analytics',
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
                _buildPlantsTab(colorScheme),
                _buildTimelineTab(colorScheme),
                _buildAnalyticsTab(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(ColorScheme colorScheme) {
    return ScaleTransition(
      scale: _fabController,
      child: FloatingActionButton.extended(
        onPressed: _showAddPlantDialog,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Plant'),
      ),
    );
  }

  Widget _buildFilters(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRoomId,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Rooms')),
                  DropdownMenuItem(value: 'room1', child: Text('Room 1')),
                  DropdownMenuItem(value: 'room2', child: Text('Room 2')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRoomId = value!);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GrowthStage?>(
              value: _selectedStage,
              hint: const Text('All Stages', style: TextStyle(fontSize: 14)),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Stages')),
                ...GrowthStage.values.map(
                  (stage) => DropdownMenuItem(
                    value: stage,
                    child: Text(_formatStageName(stage)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedStage = value);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: IconButton(
            onPressed: _loadPlants,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPlantsTab(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredPlants = _filteredPlants;

    if (filteredPlants.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filteredPlants.length,
        itemBuilder: (context, index) {
          final plant = filteredPlants[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: PlantLifecycleCard(
                  plant: plant,
                  onTap: () => _showPlantDetails(plant),
                  onStageUpdate: () => _showStageUpdateDialog(plant),
                  onHealthCheck: () => _showHealthCheckDialog(plant),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No plants yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your plants by adding your first one',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddPlantDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Plant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(ColorScheme colorScheme) {
    return const Center(
      child: Text('Timeline view coming soon'),
    );
  }

  Widget _buildAnalyticsTab(ColorScheme colorScheme) {
    return const Center(
      child: Text('Analytics view coming soon'),
    );
  }

  void _showAddPlantDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPlantDialog(
        onPlantAdded: (plant) {
          _loadPlants();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plant added successfully')),
          );
        },
      ),
    );
  }

  void _showPlantDetails(PlantLifecycle plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlantDetailsScreen(plant: plant),
      ),
    );
  }

  void _showStageUpdateDialog(PlantLifecycle plant) {
    showDialog(
      context: context,
      builder: (context) => StageUpdateDialog(
        plant: plant,
        onStageUpdated: () {
          _loadPlants();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Growth stage updated')),
          );
        },
      ),
    );
  }

  void _showHealthCheckDialog(PlantLifecycle plant) {
    showDialog(
      context: context,
      builder: (context) => HealthCheckDialog(
        plant: plant,
        onHealthRecorded: () {
          _loadPlants();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Health check recorded')),
          );
        },
      ),
    );
  }

  void _showAnalytics() {
    // Show analytics dialog or navigate to analytics screen
  }

  String _formatStageName(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.germination:
        return 'Germination';
      case GrowthStage.seedling:
        return 'Seedling';
      case GrowthStage.vegetative:
        return 'Vegetative';
      case GrowthStage.flowering:
        return 'Flowering';
      case GrowthStage.harvest:
        return 'Harvest';
      case GrowthStage.curing:
        return 'Curing';
      case GrowthStage.completed:
        return 'Completed';
    }
  }
}

/// Individual plant lifecycle card widget
class PlantLifecycleCard extends StatelessWidget {
  final PlantLifecycle plant;
  final VoidCallback onTap;
  final VoidCallback onStageUpdate;
  final VoidCallback onHealthCheck;

  const PlantLifecycleCard({
    super.key,
    required this.plant,
    required this.onTap,
    required this.onStageUpdate,
    required this.onHealthCheck,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Plant photo or placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: plant.plantPhoto != null
                          ? DecorationImage(
                              image: NetworkImage(plant.plantPhoto!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: plant.plantPhoto == null
                        ? Icon(
                            Icons.eco_outlined,
                            color: colorScheme.primary,
                            size: 30,
                          )
                        : null,
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
                                plant.plantName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStageColor(plant.currentStage).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatStageName(plant.currentStage),
                                style: TextStyle(
                                  color: _getStageColor(plant.currentStage),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Age: ${plant.ageInDays} days',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (plant.daysUntilHarvest != null)
                              Text(
                                'Harvest in ${plant.daysUntilHarvest} days',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: plant.daysUntilHarvest! < 7 ? Colors.red : Colors.grey[600],
                                  fontWeight: plant.daysUntilHarvest! < 7 ? FontWeight.w600 : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getHealthColor(plant.healthStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: _getHealthColor(plant.healthStatus),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Growth Progress',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(plant.growthProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: plant.growthProgress,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStageUpdate,
                      icon: const Icon(Icons.trending_up, size: 16),
                      label: const Text('Update Stage'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onHealthCheck,
                      icon: const Icon(Icons.health_and_safety, size: 16),
                      label: const Text('Health Check'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStageColor(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.germination:
        return Colors.brown;
      case GrowthStage.seedling:
        return Colors.lightGreen;
      case GrowthStage.vegetative:
        return Colors.green;
      case GrowthStage.flowering:
        return Colors.purple;
      case GrowthStage.harvest:
        return Colors.orange;
      case GrowthStage.curing:
        return Colors.deepOrange;
      case GrowthStage.completed:
        return Colors.blue;
    }
  }

  Color _getHealthColor(PlantHealth health) {
    switch (health) {
      case PlantHealth.excellent:
        return Colors.green;
      case PlantHealth.good:
        return Colors.lightGreen;
      case PlantHealth.fair:
        return Colors.yellow;
      case PlantHealth.poor:
        return Colors.orange;
      case PlantHealth.critical:
        return Colors.red;
    }
  }

  String _formatStageName(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.germination:
        return 'Germination';
      case GrowthStage.seedling:
        return 'Seedling';
      case GrowthStage.vegetative:
        return 'Vegetative';
      case GrowthStage.flowering:
        return 'Flowering';
      case GrowthStage.harvest:
        return 'Harvest';
      case GrowthStage.curing:
        return 'Curing';
      case GrowthStage.completed:
        return 'Completed';
    }
  }
}

/// Add plant dialog
class AddPlantDialog extends StatefulWidget {
  final Function(PlantLifecycle) onPlantAdded;

  const AddPlantDialog({super.key, required this.onPlantAdded});

  @override
  State<AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<AddPlantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedStrain = 'hybrid';
  String _selectedRoom = 'room1';
  DateTime _plantedDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Plant'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plant Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a plant name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStrain,
                decoration: const InputDecoration(
                  labelText: 'Strain',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                  DropdownMenuItem(value: 'indica', child: Text('Indica')),
                  DropdownMenuItem(value: 'sativa', child: Text('Sativa')),
                ],
                onChanged: (value) {
                  setState(() => _selectedStrain = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRoom,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'room1', child: Text('Room 1')),
                  DropdownMenuItem(value: 'room2', child: Text('Room 2')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRoom = value!);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Planted Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_plantedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _plantedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _plantedDate = date);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addPlant,
          child: const Text('Add Plant'),
        ),
      ],
    );
  }

  void _addPlant() async {
    if (_formKey.currentState!.validate()) {
      try {
        final lifecycleService = PlantLifecycleService();
        await lifecycleService.initialize();

        final plant = await lifecycleService.createPlant(
          userId: 'current_user', // Would get actual user ID
          roomId: _selectedRoom,
          strainId: _selectedStrain,
          plantName: _nameController.text,
          plantedDate: _plantedDate,
        );

        widget.onPlantAdded(plant);
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add plant: $e')),
        );
      }
    }
  }
}

/// Stage update dialog
class StageUpdateDialog extends StatefulWidget {
  final PlantLifecycle plant;
  final VoidCallback onStageUpdated;

  const StageUpdateDialog({super.key, required this.plant, required this.onStageUpdated});

  @override
  State<StageUpdateDialog> createState() => _StageUpdateDialogState();
}

class _StageUpdateDialogState extends State<StageUpdateDialog> {
  final _notesController = TextEditingController();
  bool _isUpdating = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Growth Stage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Stage: ${_formatStageName(widget.plant.currentStage)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Select new stage:'),
          const SizedBox(height: 8),
          ...GrowthStage.values.map(
            (stage) => RadioListTile<GrowthStage>(
              title: Text(_formatStageName(stage)),
              value: stage,
              groupValue: _getNextStage(widget.plant.currentStage),
              onChanged: (value) {
                // This would be handled differently in a real implementation
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateStage,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update Stage'),
        ),
      ],
    );
  }

  GrowthStage _getNextStage(GrowthStage currentStage) {
    switch (currentStage) {
      case GrowthStage.germination:
        return GrowthStage.seedling;
      case GrowthStage.seedling:
        return GrowthStage.vegetative;
      case GrowthStage.vegetative:
        return GrowthStage.flowering;
      case GrowthStage.flowering:
        return GrowthStage.harvest;
      case GrowthStage.harvest:
        return GrowthStage.curing;
      case GrowthStage.curing:
        return GrowthStage.completed;
      case GrowthStage.completed:
        return GrowthStage.completed;
    }
  }

  String _formatStageName(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.germination:
        return 'Germination';
      case GrowthStage.seedling:
        return 'Seedling';
      case GrowthStage.vegetative:
        return 'Vegetative';
      case GrowthStage.flowering:
        return 'Flowering';
      case GrowthStage.harvest:
        return 'Harvest';
      case GrowthStage.curing:
        return 'Curing';
      case GrowthStage.completed:
        return 'Completed';
    }
  }

  void _updateStage() async {
    setState(() => _isUpdating = true);
    try {
      final lifecycleService = PlantLifecycleService();
      await lifecycleService.initialize();

      await lifecycleService.updateGrowthStage(
        widget.plant.id,
        _getNextStage(widget.plant.currentStage),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      widget.onStageUpdated();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stage: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}

/// Health check dialog
class HealthCheckDialog extends StatefulWidget {
  final PlantLifecycle plant;
  final VoidCallback onHealthRecorded;

  const HealthCheckDialog({super.key, required this.plant, required this.onHealthRecorded});

  @override
  State<HealthCheckDialog> createState() => _HealthCheckDialogState();
}

class _HealthCheckDialogState extends State<HealthCheckDialog> {
  PlantHealth _selectedHealth = PlantHealth.good;
  double _healthScore = 0.7;
  final _notesController = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Health Check'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Plant Health Status:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: PlantHealth.values.map(
                (health) {
                  final isSelected = _selectedHealth == health;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedHealth = health;
                        _healthScore = _getHealthScoreForStatus(health);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _getHealthColor(health) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _getHealthColor(health) : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _formatHealthName(health),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Health Score: ${(_healthScore * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _healthScore,
              onChanged: (value) {
                setState(() {
                  _healthScore = value;
                  _selectedHealth = _getHealthStatusForScore(value);
                });
              },
              min: 0.0,
              max: 1.0,
              divisions: 10,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isRecording ? null : _recordHealthCheck,
          child: _isRecording
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record Health'),
        ),
      ],
    );
  }

  double _getHealthScoreForStatus(PlantHealth health) {
    switch (health) {
      case PlantHealth.excellent:
        return 0.9;
      case PlantHealth.good:
        return 0.7;
      case PlantHealth.fair:
        return 0.5;
      case PlantHealth.poor:
        return 0.3;
      case PlantHealth.critical:
        return 0.1;
    }
  }

  PlantHealth _getHealthStatusForScore(double score) {
    if (score >= 0.8) return PlantHealth.excellent;
    if (score >= 0.6) return PlantHealth.good;
    if (score >= 0.4) return PlantHealth.fair;
    if (score >= 0.2) return PlantHealth.poor;
    return PlantHealth.critical;
  }

  Color _getHealthColor(PlantHealth health) {
    switch (health) {
      case PlantHealth.excellent:
        return Colors.green;
      case PlantHealth.good:
        return Colors.lightGreen;
      case PlantHealth.fair:
        return Colors.yellow;
      case PlantHealth.poor:
        return Colors.orange;
      case PlantHealth.critical:
        return Colors.red;
    }
  }

  String _formatHealthName(PlantHealth health) {
    switch (health) {
      case PlantHealth.excellent:
        return 'Excellent';
      case PlantHealth.good:
        return 'Good';
      case PlantHealth.fair:
        return 'Fair';
      case PlantHealth.poor:
        return 'Poor';
      case PlantHealth.critical:
        return 'Critical';
    }
  }

  void _recordHealthCheck() async {
    setState(() => _isRecording = true);
    try {
      final lifecycleService = PlantLifecycleService();
      await lifecycleService.initialize();

      await lifecycleService.recordHealthCheck(
        plantId: widget.plant.id,
        healthStatus: _selectedHealth,
        healthScore: _healthScore,
        notes: _notesController.text,
      );

      widget.onHealthRecorded();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record health check: $e')),
      );
    } finally {
      setState(() => _isRecording = false);
    }
  }
}

/// Plant details screen
class PlantDetailsScreen extends StatelessWidget {
  final PlantLifecycle plant;

  const PlantDetailsScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plant.plantName),
        actions: [
          IconButton(
            onPressed: () {
              // Edit plant
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plant details would go here
            Text('Plant details for ${plant.plantName}'),
          ],
        ),
      ),
    );
  }
}