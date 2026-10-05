import 'dart:io';
import 'record_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'storage.dart';

// ======================================================
// STORIES SCREEN
// ======================================================
//
// Elderly-friendly UI:
// - Larger text and icons
// - Bigger touch targets
// - Clear labels and hints
// - Higher contrast
//
// Core functions are unchanged.
// ======================================================

class StoriesScreen extends StatefulWidget {
  final House house;

  // Used by main.dart to save the updated house data
  final VoidCallback onHouseUpdated;

  const StoriesScreen({
    super.key,
    required this.house,
    required this.onHouseUpdated,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final ImagePicker _picker = ImagePicker();

  // ======================================================
  // ORDINAL NUMBER
  // ======================================================

  String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }

    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  // ======================================================
  // ADD ROOM
  // ======================================================

  void _addRoom(int floorIndex) {
    final floor = widget.house.floors[floorIndex];

    setState(() {
      final nextRoomNumber = floor.rooms.length + 1;

      // Examples:
      // Floor 1 -> 101, 102, 103 ... 109, 110, 111
      // Floor 2 -> 201, 202, 203 ... 209, 210, 211
      final roomName =
          '${floor.floorNumber}${nextRoomNumber.toString().padLeft(2, '0')}';

      floor.rooms.add(
        Room(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: roomName,
        ),
      );
    });

    // Save changes to phone storage
    widget.onHouseUpdated();
  }

  // ======================================================
  // REMOVE LAST ROOM WITH CONFIRMATION
  // ======================================================

  Future<void> _removeRoom(int floorIndex) async {
    final floor = widget.house.floors[floorIndex];

    // Nothing to delete
    if (floor.rooms.isEmpty) {
      return;
    }

    // Get the last room before showing the popup
    final room = floor.rooms.last;

    // --------------------------------------------------
    // CONFIRMATION POPUP
    // --------------------------------------------------

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFB71C1C),
                size: 36,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Room?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete Room ${room.name}?\n\n'
            'This will remove the room from this floor.',
            style: const TextStyle(fontSize: 19, color: Color(0xFF1B1B1B)),
          ),
          actions: [
            // CANCEL
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(100, 54)),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF1B1B1B),
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // DELETE
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                minimumSize: const Size(110, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    // --------------------------------------------------
    // DELETE AFTER CONFIRMATION
    // --------------------------------------------------

    if (confirmDelete == true && mounted) {
      setState(() {
        floor.rooms.removeLast();
      });

      // Save changes to phone storage
      widget.onHouseUpdated();

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Room ${room.name} deleted.',
            style: const TextStyle(fontSize: 16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ======================================================
  // PICK ROOM IMAGE
  // ======================================================

  Future<void> _pickRoomImage(
    int floorIndex,
    int roomIndex,
  ) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null || !mounted) {
        return;
      }

      // --------------------------------------------------
      // COPY IMAGE TO PERMANENT APP STORAGE
      // --------------------------------------------------

      final String permanentPath =
          await AppStorage.saveImagePermanently(image.path);

      if (!mounted) {
        return;
      }

      // --------------------------------------------------
      // UPDATE ROOM IMAGE
      // --------------------------------------------------

      setState(() {
        widget.house.floors[floorIndex].rooms[roomIndex].imagePath =
            permanentPath;
      });

      // Save updated data
      widget.onHouseUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Room image updated.',
              style: TextStyle(fontSize: 16),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select image: $e',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  // ======================================================
  // UI CONSTANTS (visual only)
  // ======================================================

  static const Color _brand = Color(0xFF00695C); // deep teal, high contrast
  static const Color _brandSoft = Color(0xFFE0F2F1);
  static const Color _danger = Color(0xFFB71C1C);
  static const Color _ink = Color(0xFF1B1B1B);

  // How faint the room number looks when a photo is set (1.0 = solid).
  // Lower this number for fainter, raise it for clearer.
  static const double _roomNumberOpacityWithImage = 0.5;

  // ======================================================
  // BUILD SCREEN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
          widget.house.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: widget.house.floors.isEmpty
            ? const Center(
                child: Text(
                  'No stories found.',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 24),
                itemCount: widget.house.floors.length,
                itemBuilder: (context, floorIndex) {
                  return _buildFloorRow(floorIndex);
                },
              ),
      ),
    );
  }

  // ======================================================
  // FLOOR ACTION BUTTON (Add / Remove)
  // ======================================================

  Widget _buildFloorActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isAdd,
  }) {
    final Widget text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label),
    );
    const TextStyle textStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    return SizedBox(
      height: 58,
      child: isAdd
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 28),
              label: text,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 2,
                textStyle: textStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 28),
              label: text,
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _danger, width: 2),
                textStyle: textStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }

  // ======================================================
  // FLOOR ROW
  // ======================================================

  Widget _buildFloorRow(int floorIndex) {
    final floor = widget.house.floors[floorIndex];
    final int roomCount = floor.rooms.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brand.withOpacity(0.45), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================================================
          // FLOOR HEADER
          // ==================================================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: _brandSoft,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _brand,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${floor.floorNumber}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getOrdinal(floor.floorNumber)} Floor',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roomCount == 1 ? '1 Room' : '$roomCount Rooms',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // ADD / REMOVE BUTTONS (labelled)
          // ==================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildFloorActionButton(
                    label: 'Remove Room',
                    icon: Icons.remove_circle_outline,
                    onTap: () => _removeRoom(floorIndex),
                    isAdd: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFloorActionButton(
                    label: 'Add Room',
                    icon: Icons.add_circle_outline,
                    onTap: () => _addRoom(floorIndex),
                    isAdd: true,
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // ROOMS
          // ==================================================
          if (floor.rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 28,
              ),
              child: Column(
                children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 44, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  const Text(
                    'No rooms yet.\nTap "Add Room" to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (roomCount > 2)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.swipe, size: 22, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      'Swipe sideways to see all rooms',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: roomCount,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                itemBuilder: (context, roomIndex) {
                  return _buildRoomCard(floorIndex, roomIndex);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ======================================================
  // ROOM CARD
  // ======================================================

  Widget _buildRoomCard(
    int floorIndex,
    int roomIndex,
  ) {
    final room =
        widget.house.floors[floorIndex].rooms[roomIndex];

    final bool hasImage =
        room.imagePath != null && room.imagePath!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        // Navigate to the Record Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecordScreen(
              room: room,
              onDataChanged: widget.onHouseUpdated,
            ),
          ),
        ).then((_) {
          setState(() {}); // Refresh when returning
        });
      },
      // Long press still works as a shortcut for adding/changing the image
      onLongPress: () => _pickRoomImage(floorIndex, roomIndex),
      child: Container(
        width: 158,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _brandSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brand, width: 3),
          image: hasImage
              ? DecorationImage(
                  image: FileImage(
                    File(room.imagePath!),
                  ),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ---------- PLACEHOLDER ICON (only when no photo) ----------
            if (!hasImage)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Icon(
                    Icons.meeting_room,
                    size: 64,
                    color: _brand.withOpacity(0.35),
                  ),
                ),
              ),

            // ---------- ROOM NUMBER (top, faded when photo is set) ----------
            Positioned(
              top: 10,
              left: 8,
              right: 8,
              child: Center(
                child: Opacity(
                  opacity: hasImage ? _roomNumberOpacityWithImage : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _brand, width: 2),
                    ),
                    child: Text(
                      room.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---------- BOTTOM STRIP: OPEN + CAMERA ----------
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 30,
                padding: const EdgeInsets.only(left: 10, right: 6),
                decoration: const BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Open Room',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: hasImage ? 'Change photo' : 'Add photo',
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _pickRoomImage(floorIndex, roomIndex),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              hasImage
                                  ? Icons.cameraswitch
                                  : Icons.add_a_photo,
                              size: 24,
                              color: _brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}