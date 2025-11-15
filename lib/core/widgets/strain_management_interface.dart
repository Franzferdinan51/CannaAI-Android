import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/strain_data.dart';

class StrainManagementInterface extends ConsumerStatefulWidget {
  const StrainManagementInterface({super.key});

  @override
  ConsumerState<StrainManagementInterface> createState() => _StrainManagementInterfaceState();
}

class _StrainManagementInterfaceState extends ConsumerState<StrainManagementInterface>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  String _searchQuery = '';
  String _selectedCategory = 'All';

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
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
    });
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
                          'Strain Management',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Manage your cannabis strain library',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddStrainDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Strain'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
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
                      icon: Icons.list_outlined,
                      text: 'Library',
                    ),
                    Tab(
                      icon: Icons.favorite_outlined,
                      text: 'Favorites',
                    ),
                    Tab(
                      icon: Icons.compare_outlined,
                      text: 'Compare',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search strains...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list),
                    onSelected: (category) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    itemBuilder: (context) => [
                      'All',
                      'Indica',
                      'Sativa',
                      'Hybrid',
                      'Auto',
                      'CBD',
                    ].map((category) => PopupMenuItem(
                      value: category,
                      child: Text(category),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StrainLibraryTab(
                  searchQuery: _searchQuery,
                  selectedCategory: _selectedCategory,
                  animationController: _fadeController,
                ),
                const FavoriteStrainsTab(),
                const CompareStrainsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStrainDialog() {
    showDialog(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddStrainDialog(),
    );
  }
}

class StrainLibraryTab extends StatelessWidget {
  final String searchQuery;
  final String selectedCategory;
  final AnimationController animationController;

  const StrainLibraryTab({
    super.key,
    required this.searchQuery,
    required this.selectedCategory,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    final strains = _getFilteredStrains();

    if (strains.isEmpty) {
      return _buildEmptyState(context);
    }

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Opacity(
          opacity: animationController.value,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: strains.length,
            itemBuilder: (context, index) {
              final strain = strains[index];
              return StrainCard(
                strain: strain,
                onTap: () {
                  _showStrainDetails(context, strain);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              Icons.grass_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Strains Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Add your first strain to get started',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Add strain logic
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Strain'),
            ),
          ],
        ],
      ),
    );
  }

  List<StrainData> _getFilteredStrains() {
    // Mock strain data - in real app this would come from a provider
    final allStrains = [
      StrainData(
        id: '1',
        name: 'Blue Dream',
        category: 'Hybrid',
        thcLevel: 18.0,
        cbdLevel: 0.5,
        floweringTime: 9,
        difficulty: 'Easy',
        yield: 'High',
        description: 'A balanced hybrid with full-body relaxation and gentle cerebral invigoration.',
        effects: ['Relaxed', 'Happy', 'Creative', 'Euphoric'],
        medical: ['Stress', 'Depression', 'Pain', 'Fatigue'],
        flavors: ['Berry', 'Sweet', 'Blueberry'],
        isFavorite: true,
      ),
      StrainData(
        id: '2',
        name: 'Girl Scout Cookies',
        category: 'Hybrid',
        thcLevel: 28.0,
        cbdLevel: 0.2,
        floweringTime: 10,
        difficulty: 'Moderate',
        yield: 'High',
        description: 'Potent hybrid with euphoric effects and full-body relaxation.',
        effects: ['Euphoric', 'Relaxed', 'Happy', 'Creative'],
        medical: ['Stress', 'Pain', 'Depression', 'Insomnia'],
        flavors: ['Sweet', 'Earthy', 'Spicy'],
        isFavorite: false,
      ),
      StrainData(
        id: '3',
        name: 'Northern Lights',
        category: 'Indica',
        thcLevel: 16.0,
        cbdLevel: 0.5,
        floweringTime: 7,
        difficulty: 'Easy',
        yield: 'High',
        description: 'Classic pure indica with relaxing and sedative effects.',
        effects: ['Relaxed', 'Sleepy', 'Happy', 'Euphoric'],
        medical: ['Insomnia', 'Pain', 'Stress', 'Anxiety'],
        flavors: ['Earthy', 'Sweet', 'Spicy', 'Pine'],
        isFavorite: true,
      ),
      StrainData(
        id: '4',
        name: 'Sour Diesel',
        category: 'Sativa',
        thcLevel: 22.0,
        cbdLevel: 0.2,
        floweringTime: 11,
        difficulty: 'Moderate',
        yield: 'Medium',
        description: 'Energizing sativa with dreamy cerebral effects and fast-acting relief.',
        effects: ['Energetic', 'Happy', 'Creative', 'Uplifted'],
        medical: ['Stress', 'Depression', 'Pain', 'Fatigue'],
        flavors: ['Diesel', 'Earthy', 'Pungent', 'Citrus'],
        isFavorite: false,
      ),
    ];

    return allStrains.where((strain) {
      final matchesSearch = searchQuery.isEmpty ||
          strain.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          strain.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
          strain.effects.any((effect) => effect.toLowerCase().contains(searchQuery.toLowerCase()));

      final matchesCategory = selectedCategory == 'All' || strain.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _showStrainDetails(BuildContext context, StrainData strain) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StrainDetailsSheet(strain: strain),
    );
  }
}

class StrainCard extends StatelessWidget {
  final StrainData strain;
  final VoidCallback onTap;

  const StrainCard({
    super.key,
    required this.strain,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.secondary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.grass,
                    color: colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            strain.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (strain.isFavorite)
                            Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(strain.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              strain.category,
                              style: TextStyle(
                                color: _getCategoryColor(strain.category),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${strain.thcLevel}% THC',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
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
            const SizedBox(height: 12),
            Text(
              strain.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetric('Flowering', '${strain.floweringTime} weeks', Icons.schedule),
                const SizedBox(width: 16),
                _buildMetric('Difficulty', strain.difficulty, Icons.trending_up),
                const SizedBox(width: 16),
                _buildMetric('Yield', strain.yield, Icons.inventory_2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Indica':
        return Colors.purple;
      case 'Sativa':
        return Colors.green;
      case 'Hybrid':
        return Colors.orange;
      case 'Auto':
        return Colors.blue;
      case 'CBD':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class StrainDetailsSheet extends StatelessWidget {
  final StrainData strain;

  const StrainDetailsSheet({
    super.key,
    required this.strain,
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary.withOpacity(0.1),
                              colorScheme.secondary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.grass,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strain.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(strain.category).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    strain.category,
                                    style: TextStyle(
                                      color: _getCategoryColor(strain.category),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    // Toggle favorite
                                  },
                                  icon: Icon(
                                    strain.isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: strain.isFavorite ? Colors.red : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Cannabinoid Profile
                  _buildSectionTitle('Cannabinoid Profile'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCannabinoidCard('THC', '${strain.thcLevel}%', Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCannabinoidCard('CBD', '${strain.cbdLevel}%', Colors.green),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  _buildSectionTitle('Description'),
                  const SizedBox(height: 12),
                  Text(
                    strain.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // Effects
                  _buildSectionTitle('Effects'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: strain.effects.map((effect) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        effect,
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Medical Uses
                  _buildSectionTitle('Medical Uses'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: strain.medical.map((use) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        use,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Flavors
                  _buildSectionTitle('Flavors & Aromas'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: strain.flavors.map((flavor) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        flavor,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Growing Information
                  _buildSectionTitle('Growing Information'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildGrowingInfoRow('Flowering Time', '${strain.floweringTime} weeks'),
                        _buildGrowingInfoRow('Difficulty', strain.difficulty),
                        _buildGrowingInfoRow('Yield', strain.yield),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Add to garden
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Garden'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Compare with others
                          },
                          icon: const Icon(Icons.compare),
                          label: const Text('Compare'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCannabinoidCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowingInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Indica':
        return Colors.purple;
      case 'Sativa':
        return Colors.green;
      case 'Hybrid':
        return Colors.orange;
      case 'Auto':
        return Colors.blue;
      case 'CBD':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class FavoriteStrainsTab extends StatelessWidget {
  const FavoriteStrainsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Favorite strains feature coming soon'),
    );
  }
}

class CompareStrainsTab extends StatelessWidget {
  const CompareStrainsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Strain comparison feature coming soon'),
    );
  }
}

class AddStrainDialog extends StatefulWidget {
  const AddStrainDialog({super.key});

  @override
  State<AddStrainDialog> createState() => _AddStrainDialogState();
}

class _AddStrainDialogState extends State<AddStrainDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thcController = TextEditingController();
  final _cbdController = TextEditingController();
  final _floweringController = TextEditingController();

  String _selectedCategory = 'Hybrid';
  String _selectedDifficulty = 'Easy';
  String _selectedYield = 'Medium';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add New Strain',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Strain Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a strain name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Indica', 'Sativa', 'Hybrid', 'Auto', 'CBD']
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _thcController,
                              decoration: const InputDecoration(
                                labelText: 'THC %',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cbdController,
                              decoration: const InputDecoration(
                                labelText: 'CBD %',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDifficulty,
                              decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Easy', 'Moderate', 'Hard']
                                  .map((difficulty) => DropdownMenuItem(
                                        value: difficulty,
                                        child: Text(difficulty),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDifficulty = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedYield,
                              decoration: const InputDecoration(
                                labelText: 'Yield',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Low', 'Medium', 'High']
                                  .map((yield) => DropdownMenuItem(
                                        value: yield,
                                        child: Text(yield),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYield = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _floweringController,
                        decoration: const InputDecoration(
                          labelText: 'Flowering Time (weeks)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Save strain logic
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Strain added successfully')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Strain'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _thcController.dispose();
    _cbdController.dispose();
    _floweringController.dispose();
    super.dispose();
  }
}

class StrainData {
  final String id;
  final String name;
  final String category;
  final double thcLevel;
  final double cbdLevel;
  final int floweringTime;
  final String difficulty;
  final String yield;
  final String description;
  final List<String> effects;
  final List<String> medical;
  final List<String> flavors;
  final bool isFavorite;

  StrainData({
    required this.id,
    required this.name,
    required this.category,
    required this.thcLevel,
    required this.cbdLevel,
    required this.floweringTime,
    required this.difficulty,
    required this.yield,
    required this.description,
    required this.effects,
    required this.medical,
    required this.flavors,
    this.isFavorite = false,
  });
}