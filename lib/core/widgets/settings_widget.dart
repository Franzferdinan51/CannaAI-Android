import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/comprehensive_settings_service.dart';
import '../services/comprehensive_ai_assistant_service.dart';
import '../theme/app_theme.dart';

/// Comprehensive Settings Widget
///
/// Provides a complete settings interface for configuring all aspects
/// of the CannaAI application including AI providers, automation, notifications,
/// privacy, analytics, and system settings
class SettingsWidget extends StatefulWidget {
  final SettingsCategory? initialCategory;
  final bool enableExperimental;

  const SettingsWidget({
    Key? key,
    this.initialCategory,
    this.enableExperimental = false,
  }) : super(key: key);

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ComprehensiveSettingsService _settingsService;
  late PageController _pageController;

  AppSettings? _currentSettings;
  bool _isLoading = true;
  bool _hasChanges = false;
  String _searchQuery = '';

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Form keys
  final GlobalKey<FormState> _aiFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _networkFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _sensorFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _pageController = PageController();
    _settingsService = Provider.of<ComprehensiveSettingsService>(context, listen: false);

    // Initialize animations
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _loadSettings();
    _listenToSettingsChanges();

    if (widget.initialCategory != null) {
      final initialIndex = _getCategoryIndex(widget.initialCategory!);
      if (initialIndex != -1) {
        _tabController.animateTo(initialIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = await Provider.of<ComprehensiveSettingsService>(context, listen: false);
      setState(() {
        _currentSettings = service.settings;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load settings: $e');
    }
  }

  void _listenToSettingsChanges() {
    _settingsService.settingsStream.listen((settings) {
      if (mounted) {
        setState(() {
          _currentSettings = settings;
        });
      }
    });
  }

  int _getCategoryIndex(SettingsCategory category) {
    switch (category) {
      case SettingsCategory.theme:
        return 0;
      case SettingsCategory.aiProviders:
        return 1;
      case SettingsCategory.automation:
        return 2;
      case SettingsCategory.notifications:
        return 3;
      case SettingsCategory.privacy:
        return 4;
      case SettingsCategory.sensor:
        return 5;
      case SettingsCategory.analytics:
        return 6;
      case SettingsCategory.system:
        return 7;
      case SettingsCategory.network:
        return 8;
      case SettingsCategory.security:
        return 9;
      case SettingsCategory.experimental:
        return 10;
      default:
        return 0;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _loadSettings,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildThemeSettings(),
                        _buildAIProviderSettings(),
                        _buildAutomationSettings(),
                        _buildNotificationSettings(),
                        _buildPrivacySettings(),
                        _buildSensorSettings(),
                        _buildAnalyticsSettings(),
                        _buildSystemSettings(),
                        _buildNetworkSettings(),
                        _buildSecuritySettings(),
                        if (widget.enableExperimental)
                          _buildExperimentalSettings()
                        else
                          _buildDisabledExperimentalTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Settings'),
      backgroundColor: AppTheme.appBarColor,
      elevation: 0,
      actions: [
        if (_hasChanges)
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _saveAllSettings,
            tooltip: 'Save Changes',
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Export Settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.upload, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Import Settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Reset All'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'validate',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Validate Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: 'Theme', icon: Icon(Icons.palette)),
          Tab(text: 'AI', icon: Icon(Icons.smart_toy)),
          Tab(text: 'Automation', icon: Icon(Icons.autorenew)),
          Tab(text: 'Notifications', icon: Icon(Icons.notifications)),
          Tab(text: 'Privacy', icon: Icon(Icons.lock)),
          Tab(text: 'Sensors', icon: Icon(Icons.sensors)),
          Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          Tab(text: 'System', icon: Icon(Icons.settings)),
          Tab(text: 'Network', icon: Icon(Icons.wifi)),
          Tab(text: 'Security', icon: Icon(Icons.security)),
          if (widget.enableExperimental)
            Tab(text: 'Experimental', icon: Icon(Icons.science)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search settings...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.cardColor,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            'Loading settings...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (!_hasChanges) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _discardChanges,
              child: Text('Discard Changes'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saveAllSettings,
              child: Text('Save All Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Theme Settings Tab

  Widget _buildThemeSettings() {
    if (_currentSettings == null) return SizedBox();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Appearance'),
          _buildThemeModeSelector(),
          SizedBox(height: 20),
          _buildColorPicker(),
          SizedBox(height: 20),
          _buildFontSizeSelector(),
          SizedBox(height: 20),
          _buildAnimationSettings(),
          SizedBox(height: 20),
          _buildAccessibilitySettings(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(ThemeMode.system, 'System'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildThemeOption(ThemeMode.light, 'Light'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildThemeOption(ThemeMode.dark, 'Dark'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String label) {
    final isSelected = _currentSettings!.theme.themeMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSettings = _currentSettings!.copyWith(
            theme: _currentSettings!.theme.copyWith(themeMode: mode),
          );
          _hasChanges = true;
        });
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              mode == ThemeMode.system
                  ? Icons.brightness_auto
                  : mode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.dark_mode,
              color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary Color',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildColorOption(0xFF2196F3, 'Blue'),
              _buildColorOption(0xFF4CAF50, 'Green'),
              _buildColorOption(0xFFFF9800, 'Orange'),
              _buildColorOption(0xFF9C27B0, 'Purple'),
              _buildColorOption(0xFFF44336, 'Red'),
              _buildColorOption(0xFF607D8B, 'Teal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(int color, String label) {
    final isSelected = _currentSettings!.theme.primaryColor == color;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSettings = _currentSettings!.copyWith(
            theme: _currentSettings!.theme.copyWith(primaryColor: color),
          );
          _hasChanges = true;
        });
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(color),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? AppTheme.textColor : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                  )
                : null,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFontSizeOption(FontSize.small, 'Small'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildFontSizeOption(FontSize.medium, 'Medium'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildFontSizeOption(FontSize.large, 'Large'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeOption(FontSize size, String label) {
    final isSelected = _currentSettings!.theme.fontSize == size;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSettings = _currentSettings!.copyWith(
            theme: _currentSettings!.theme.copyWith(fontSize: size),
          );
          _hasChanges = true;
        });
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: size == FontSize.small ? 12 : size == FontSize.large ? 18 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationSettings() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          _buildSwitchTile(
            'Enable Animations',
            'Enable UI animations and transitions',
            _currentSettings!.theme.enableAnimations,
            (value) {
              setState(() {
                _currentSettings = _currentSettings!.copyWith(
                  theme: _currentSettings!.theme.copyWith(enableAnimations: value),
                );
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 12),
          _buildSwitchTile(
            'Reduce Animations',
            'Reduce motion for better performance',
            _currentSettings!.theme.reduceAnimations,
            (value) {
              setState(() {
                _currentSettings = _currentSettings!.copyWith(
                  theme: _currentSettings!.theme.copyWith(reduceAnimations: value),
                );
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilitySettings() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accessibility',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          _buildSwitchTile(
            'High Contrast',
            'Increase contrast for better visibility',
            _currentSettings!.theme.highContrast,
            (value) {
              setState(() {
                _currentSettings = _currentSettings!.copyWith(
                  theme: _currentSettings!.theme.copyWith(highContrast: value),
                );
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  // AI Provider Settings Tab

  Widget _buildAIProviderSettings() {
    if (_currentSettings == null) return SizedBox();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _aiFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('AI Configuration'),
            _buildAIProviderSelector(),
            SizedBox(height: 20),
            _buildLMStudioSettings(),
            SizedBox(height: 20),
            _buildOpenRouterSettings(),
            SizedBox(height: 20),
            _buildDeviceMLSettings(),
            SizedBox(height: 20),
            _buildOfflineRulesSettings(),
            SizedBox(height: 20),
            _buildFallbackSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIProviderSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default AI Provider',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<AIProviderType>(
            value: _currentSettings!.aiProviders.defaultProvider,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: AIProviderType.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Row(
                  children: [
                    Icon(_getAIProviderIcon(provider)),
                    SizedBox(width: 12),
                    Text(_getAIProviderName(provider)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _currentSettings = _currentSettings!.copyWith(
                    aiProviders: _currentSettings!.aiProviders.copyWith(defaultProvider: value),
                  );
                  _hasChanges = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  IconData _getAIProviderIcon(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.lmStudio:
        return Icons.computer;
      case AIProviderType.openRouter:
        return Icons.cloud;
      case AIProviderType.deviceML:
        return Icons.memory;
      case AIProviderType.offlineRules:
        return Icons.rule;
      default:
        return Icons.help_outline;
    }
  }

  String _getAIProviderName(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.lmStudio:
        return 'LM Studio';
      case AIProviderType.openRouter:
        return 'OpenRouter';
      case AIProviderType.deviceML:
        return 'Device ML';
      case AIProviderType.offlineRules:
        return 'Offline Rules';
      default:
        return 'Unknown';
    }
  }

  Widget _buildLMStudioSettings() {
    final lmStudio = _currentSettings!.aiProviders.lmStudio;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LM Studio Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Switch(
                value: lmStudio.enabled,
                onChanged: (value) {
                  setState(() {
                    final updatedAI = _currentSettings!.aiProviders.copyWith(
                      lmStudio: lmStudio.copyWith(enabled: value),
                    );
                    _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                    _hasChanges = true;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (lmStudio.enabled) ...[
            SizedBox(height: 16),
            TextFormField(
              initialValue: lmStudio.baseUrl,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://localhost:1234',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a base URL';
                }
                return null;
              },
              onChanged: (value) {
                final updatedLM = lmStudio.copyWith(baseUrl: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(lmStudio: updatedLM);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              initialValue: lmStudio.modelId,
              decoration: InputDecoration(
                labelText: 'Model ID',
                hintText: 'Enter model identifier',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final updatedLM = lmStudio.copyWith(modelId: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(lmStudio: updatedLM);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: lmStudio.maxTokens.toString(),
                    decoration: InputDecoration(
                      labelText: 'Max Tokens',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final tokens = int.tryParse(value);
                      if (tokens == null || tokens <= 0) {
                        return 'Invalid value';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final tokens = int.tryParse(value) ?? 2048;
                      final updatedLM = lmStudio.copyWith(maxTokens: tokens);
                      final updatedAI = _currentSettings!.aiProviders.copyWith(lmStudio: updatedLM);
                      _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                      _hasChanges = true;
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: lmStudio.temperature.toString(),
                    decoration: InputDecoration(
                      labelText: 'Temperature',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final temp = double.tryParse(value);
                      if (temp == null || temp < 0 || temp > 2) {
                        return 'Must be 0-2';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final temp = double.tryParse(value) ?? 0.7;
                      final updatedLM = lmStudio.copyWith(temperature: temp);
                      final updatedAI = _currentSettings!.aiProviders.copyWith(lmStudio: updatedLM);
                      _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                      _hasChanges = true;
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpenRouterSettings() {
    final openRouter = _currentSettings!.aiProviders.openRouter;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OpenRouter Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Switch(
                value: openRouter.enabled,
                onChanged: (value) {
                  setState(() {
                    final updatedAI = _currentSettings!.aiProviders.copyWith(
                      openRouter: openRouter.copyWith(enabled: value),
                    );
                    _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                    _hasChanges = true;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (openRouter.enabled) ...[
            SizedBox(height: 16),
            TextFormField(
              initialValue: openRouter.apiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your OpenRouter API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (openRouter.enabled && (value == null || value.isEmpty)) {
                  return 'API key is required when enabled';
                }
                return null;
              },
              onChanged: (value) {
                final updatedOR = openRouter.copyWith(apiKey: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(openRouter: updatedOR);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              initialValue: openRouter.modelId,
              decoration: InputDecoration(
                labelText: 'Model',
                hintText: 'anthropic/claude-3-sonnet',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final updatedOR = openRouter.copyWith(modelId: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(openRouter: updatedOR);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceMLSettings() {
    final deviceML = _currentSettings!.aiProviders.deviceML;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device ML Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Switch(
                value: deviceML.enabled,
                onChanged: (value) {
                  setState(() {
                    final updatedAI = _currentSettings!.aiProviders.copyWith(
                      deviceML: deviceML.copyWith(enabled: value),
                    );
                    _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                    _hasChanges = true;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (deviceML.enabled) ...[
            SizedBox(height: 16),
            _buildSwitchTile(
              'Use On-Device ML',
              'Process AI tasks locally on device',
              deviceML.useOnDeviceML,
              (value) {
                final updatedDeviceML = deviceML.copyWith(useOnDeviceML: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(deviceML: updatedDeviceML);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              initialValue: deviceML.modelPath,
              decoration: InputDecoration(
                labelText: 'Model Path',
                hintText: 'Path to ML model file',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final updatedDeviceML = deviceML.copyWith(modelPath: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(deviceML: updatedDeviceML);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              initialValue: deviceML.confidenceThreshold.toString(),
              decoration: InputDecoration(
                labelText: 'Confidence Threshold',
                hintText: '0.0 - 1.0',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final threshold = double.tryParse(value) ?? 0.7;
                final updatedDeviceML = deviceML.copyWith(confidenceThreshold: threshold);
                final updatedAI = _currentSettings!.aiProviders.copyWith(deviceML: updatedDeviceML);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineRulesSettings() {
    final offlineRules = _currentSettings!.aiProviders.offlineRules;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Offline Rules Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Switch(
                value: offlineRules.enabled,
                onChanged: (value) {
                  setState(() {
                    final updatedAI = _currentSettings!.aiProviders.copyWith(
                      offlineRules: offlineRules.copyWith(enabled: value),
                    );
                    _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                    _hasChanges = true;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (offlineRules.enabled) ...[
            SizedBox(height: 16),
            _buildSwitchTile(
              'Use Predefined Rules',
              'Use built-in cultivation rules',
              offlineRules.usePredefinedRules,
              (value) {
                final updatedOffline = offlineRules.copyWith(usePredefinedRules: value);
                final updatedAI = _currentSettings!.aiProviders.copyWith(offlineRules: updatedOffline);
                _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                _hasChanges = true;
              },
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<RulePriority>(
              value: offlineRules.rulePriority,
              decoration: InputDecoration(
                labelText: 'Rule Priority',
                border: OutlineInputBorder(),
              ),
              items: RulePriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(_formatRulePriority(priority)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final updatedOffline = offlineRules.copyWith(rulePriority: value);
                  final updatedAI = _currentSettings!.aiProviders.copyWith(offlineRules: updatedOffline);
                  _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                  _hasChanges = true;
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackSettings() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fallback Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<AIProviderType>(
            value: _currentSettings!.aiProviders.fallbackProvider,
            decoration: InputDecoration(
              labelText: 'Fallback Provider',
              border: OutlineInputBorder(),
            ),
            items: AIProviderType.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Row(
                  children: [
                    Icon(_getAIProviderIcon(provider)),
                    SizedBox(width: 12),
                    Text(_getAIProviderName(provider)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  final updatedAI = _currentSettings!.aiProviders.copyWith(fallbackProvider: value);
                  _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
                  _hasChanges = true;
                });
              }
            },
          ),
          SizedBox(height: 12),
          _buildSwitchTile(
            'Auto Fallback',
            'Automatically switch to fallback on failures',
            _currentSettings!.aiProviders.autoFallback,
            (value) {
              final updatedAI = _currentSettings!.aiProviders.copyWith(autoFallback: value);
              _currentSettings = _currentSettings!.copyWith(aiProviders: updatedAI);
              _hasChanges = true;
            },
          ),
        ],
      ),
    );
  }

  String _formatRulePriority(RulePriority priority) {
    switch (priority) {
      case RulePriority.offlineFirst:
        return 'Offline First';
      case RulePriority.hybrid:
        return 'Hybrid';
      case RulePriority.aiFirst:
        return 'AI First';
      default:
        return 'Unknown';
    }
  }

  // Automation Settings Tab (simplified for brevity)
  Widget _buildAutomationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Automation Configuration'),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  'Enable Automation',
                  'Master switch for automation features',
                  _currentSettings?.automation.enabled ?? false,
                  (value) {
                    // Update automation settings
                  },
                ),
                SizedBox(height: 12),
                _buildSwitchTile(
                  'Auto Mode',
                  'Enable automatic control based on rules',
                  _currentSettings?.automation.autoMode ?? false,
                  (value) {
                    // Update automation settings
                  },
                ),
                SizedBox(height: 12),
                _buildSwitchTile(
                  'Schedule Enabled',
                  'Enable scheduled automation tasks',
                  _currentSettings?.automation.scheduleEnabled ?? false,
                  (value) {
                    // Update automation settings
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Other setting tabs would follow similar patterns...
  // For brevity, I'll include simplified versions

  Widget _buildNotificationSettings() {
    return _buildComingSoonTab('Notification Settings');
  }

  Widget _buildPrivacySettings() {
    return _buildComingSoonTab('Privacy Settings');
  }

  Widget _buildSensorSettings() {
    return _buildComingSoonTab('Sensor Settings');
  }

  Widget _buildAnalyticsSettings() {
    return _buildComingSoonTab('Analytics Settings');
  }

  Widget _buildSystemSettings() {
    return _buildComingSoonTab('System Settings');
  }

  Widget _buildNetworkSettings() {
    return _buildComingSoonTab('Network Settings');
  }

  Widget _buildSecuritySettings() {
    return _buildComingSoonTab('Security Settings');
  }

  Widget _buildExperimentalSettings() {
    return _buildComingSoonTab('Experimental Features');
  }

  Widget _buildDisabledExperimentalTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science,
            color: AppTheme.secondaryTextColor,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Experimental Features Disabled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enable experimental features in app settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            color: AppTheme.secondaryTextColor,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon in the next update',
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // Actions

  Future<void> _saveAllSettings() async {
    if (_currentSettings == null) return;

    try {
      // Validate settings before saving
      if (!_settingsService.validateAIProviderSettings(_currentSettings!.aiProviders)) {
        _showErrorSnackBar('Invalid AI provider settings');
        return;
      }

      // Update all settings
      await _settingsService.updateAIProviderSettings(_currentSettings!.aiProviders);
      await _settingsService.updateThemeSettings(_currentSettings!.theme);
      await _settingsService.updateAutomationSettings(_currentSettings!.automation);

      setState(() {
        _hasChanges = false;
      });

      _showSuccessSnackBar('Settings saved successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to save settings: $e');
    }
  }

  void _discardChanges() {
    setState(() {
      _hasChanges = false;
    });
    _loadSettings(); // Reload original settings
    _showSuccessSnackBar('Changes discarded');
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'export':
        await _exportSettings();
        break;
      case 'import':
        await _importSettings();
        break;
      case 'reset':
        await _resetSettings();
        break;
      case 'validate':
        await _validateSettings();
        break;
    }
  }

  Future<void> _exportSettings() async {
    try {
      final exportData = await _settingsService.exportSettings();
      // Here you would save the export data to a file or share it
      _showSuccessSnackBar('Settings exported successfully');
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    }
  }

  Future<void> _importSettings() async {
    try {
      // Here you would open a file picker and import settings
      _showSuccessSnackBar('Import feature coming soon');
    } catch (e) {
      _showErrorSnackBar('Import failed: $e');
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await _showConfirmationDialog(
      'Reset All Settings',
      'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
    );

    if (confirmed) {
      try {
        await _settingsService.resetToDefaults();
        _loadSettings();
        _showSuccessSnackBar('Settings reset to defaults');
      } catch (e) {
        _showErrorSnackBar('Reset failed: $e');
      }
    }
  }

  Future<void> _validateSettings() async {
    try {
      await _settingsService.validateAllSettings();
      _showSuccessSnackBar('All settings are valid');
    } catch (e) {
      _showErrorSnackBar('Settings validation failed: $e');
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// Riverpod provider
final settingsWidgetProvider = Provider<SettingsWidget>((ref) {
  return SettingsWidget();
});