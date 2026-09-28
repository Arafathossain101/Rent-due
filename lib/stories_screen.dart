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
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 30,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Room?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete Room ${room.name}?\n\n'
            'This will remove the room from this floor.',
            style: const TextStyle(fontSize: 17),
          ),
          actions: [
            // CANCEL
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 17,
                ),
              ),
            ),

            // DELETE
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 17),
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
  // BUILD SCREEN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.house.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: widget.house.floors.isEmpty
            ? const Center(
                child: Text(
                  'No stories found.',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.grey,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: widget.house.floors.length,
                itemBuilder: (context, floorIndex) {
                  return _buildFloorRow(floorIndex);
                },
              ),
      ),
    );
  }

  // ======================================================
  // FLOOR ROW
  // ======================================================

  Widget _buildFloorRow(int floorIndex) {
    final floor = widget.house.floors[floorIndex];

    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ==================================================
          // LEFT FLOOR PANEL
          // ==================================================

          Container(
            width: 118,
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ------------------------------------------------
                // FLOOR NUMBER
                // ------------------------------------------------

                Text(
                  '${_getOrdinal(floor.floorNumber)}\nFloor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 14),

                // ------------------------------------------------
                // REMOVE + ADD BUTTONS (larger for elders)
                // ------------------------------------------------

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // REMOVE BUTTON
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _removeRoom(floorIndex),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 26,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ADD BUTTON
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _addRoom(floorIndex),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 26,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // ROOM COUNT
                // ------------------------------------------------

                Text(
                  '${floor.rooms.length} Rooms',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // RIGHT ROOM PANEL
          // ==================================================

          Expanded(
            child: floor.rooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Tap  +  to add rooms',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: floor.rooms.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    itemBuilder: (
                      context,
                      roomIndex,
                    ) {
                      return _buildRoomCard(
                        floorIndex,
                        roomIndex,
                      );
                    },
                  ),
          ),
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
      onLongPress: () => _pickRoomImage(floorIndex, roomIndex),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.brown.shade200,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.brown.shade800,
            width: 3,
          ),
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
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ---------- ROOM NUMBER (center) ----------
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  room.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // ---------- HOLD TO ADD IMAGE HINT ----------
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasImage ? Icons.image : Icons.touch_app,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        hasImage ? 'Hold to change' : 'Hold to add image',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
