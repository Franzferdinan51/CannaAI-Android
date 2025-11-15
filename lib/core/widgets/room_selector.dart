import 'package:flutter/material.dart';
import '../models/room_config.dart';

class RoomSelector extends StatefulWidget {
  final String selectedRoom;
  final Function(String) onRoomSelected;

  const RoomSelector({
    super.key,
    required this.selectedRoom,
    required this.onRoomSelected,
  });

  @override
  State<RoomSelector> createState() => _RoomSelectorState();
}

class _RoomSelectorState extends State<RoomSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _slideAnimation.value)),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(4),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Room',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${RoomConfig.availableRooms.length} Rooms',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildRoomGrid(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomGrid() {
    final rooms = RoomConfig.availableRooms;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          final isSelected = room.name == widget.selectedRoom;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                widget.onRoomSelected(room.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 100,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          room.icon,
                          color: isSelected ? Colors.white : colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 10,
                            color: isSelected ? Colors.white.withOpacity(0.8) : Colors.green,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${room.plantCount}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected ? Colors.white.withOpacity(0.8) : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RoomManagementSheet extends StatefulWidget {
  final List<RoomConfig> rooms;
  final Function(RoomConfig) onRoomUpdated;
  final Function(String) onRoomDeleted;

  const RoomManagementSheet({
    super.key,
    required this.rooms,
    required this.onRoomUpdated,
    required this.onRoomDeleted,
  });

  @override
  State<RoomManagementSheet> createState() => _RoomManagementSheetState();
}

class _RoomManagementSheetState extends State<RoomManagementSheet> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Room Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _showAddRoomDialog();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRoomList(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.rooms.length,
      itemBuilder: (context, index) {
        final room = widget.rooms[index];
        return RoomManagementTile(
          room: room,
          onEdit: () {
            _showEditRoomDialog(room);
          },
          onDelete: () {
            _showDeleteConfirmation(room);
          },
        );
      },
    );
  }

  void _showAddRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => RoomConfigDialog(
        title: 'Add New Room',
        onSave: (room) {
          widget.onRoomUpdated(room);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditRoomDialog(RoomConfig room) {
    showDialog(
      context: context,
      builder: (context) => RoomConfigDialog(
        title: 'Edit Room',
        room: room,
        onSave: (updatedRoom) {
          widget.onRoomUpdated(updatedRoom);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmation(RoomConfig room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${room.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onRoomDeleted(room.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class RoomManagementTile extends StatelessWidget {
  final RoomConfig room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoomManagementTile({
    super.key,
    required this.room,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              room.icon,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 12,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.plantCount} plants',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.thermostat_outlined,
                      size: 12,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.targetTemperature}°C',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: colorScheme.primary,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoomConfigDialog extends StatefulWidget {
  final String title;
  final RoomConfig? room;
  final Function(RoomConfig) onSave;

  const RoomConfigDialog({
    super.key,
    required this.title,
    this.room,
    required this.onSave,
  });

  @override
  State<RoomConfigDialog> createState() => _RoomConfigDialogState();
}

class _RoomConfigDialogState extends State<RoomConfigDialog> {
  late TextEditingController _nameController;
  late double _targetTemperature;
  late double _targetHumidity;
  late int _plantCount;
  late IconData _selectedIcon;

  final List<IconData> _availableIcons = [
    Icons.meeting_room,
    Icons.greenhouse,
    Icons.yard,
    Icons.balcony,
    Icons.deck,
    Icons.garage,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _targetTemperature = widget.room?.targetTemperature ?? 22.0;
    _targetHumidity = widget.room?.targetHumidity ?? 50.0;
    _plantCount = widget.room?.plantCount ?? 0;
    _selectedIcon = widget.room?.icon ?? Icons.meeting_room;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temperature: ${_targetTemperature.toStringAsFixed(1)}°C'),
                      Slider(
                        value: _targetTemperature,
                        min: 15.0,
                        max: 30.0,
                        divisions: 30,
                        onChanged: (value) {
                          setState(() {
                            _targetTemperature = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Humidity: ${_targetHumidity.toStringAsFixed(0)}%'),
                      Slider(
                        value: _targetHumidity,
                        min: 30.0,
                        max: 80.0,
                        divisions: 50,
                        onChanged: (value) {
                          setState(() {
                            _targetHumidity = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Plant Count',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _plantCount = int.tryParse(value) ?? 0;
              },
              controller: TextEditingController(text: _plantCount.toString()),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableIcons.map((icon) {
                    final isSelected = icon == _selectedIcon;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? colorScheme.primary : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final room = RoomConfig(
                id: widget.room?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                icon: _selectedIcon,
                targetTemperature: _targetTemperature,
                targetHumidity: _targetHumidity,
                plantCount: _plantCount,
              );
              widget.onSave(room);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}