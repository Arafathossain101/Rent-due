import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'stories_screen.dart';
import 'storage.dart';

void main() {
  runApp(const RentApp());
}

// ======================================================
// APP
// ======================================================

class RentApp extends StatelessWidget {
  const RentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent Record',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ======================================================
// SPLASH SCREEN
// ======================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/rent is due.jpg',
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.home_work,
                  size: 120,
                  color: Colors.teal.shade100,
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Rent Record',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading your records...',
              style: TextStyle(
                fontSize: 20,
                color: Colors.teal.shade100,
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// HOME SCREEN
// ======================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  List<House> houses = [];
  bool isDeleteMode = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // ======================================================
  // LOAD / SAVE
  // ======================================================

  Future<void> _loadSavedData() async {
    try {
      final savedHouses = await AppStorage.loadHouses();
      if (!mounted) return;

      setState(() {
        houses = savedHouses;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load saved data: $e',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  Future<void> _saveData() async {
    try {
      await AppStorage.saveHouses(houses);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save data: $e',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  // ======================================================
  // IMAGE SOURCE CHOOSER
  // ======================================================

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Choose Photo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Icon(
                      Icons.photo_camera,
                      size: 28,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Take a new photo',
                    style: TextStyle(fontSize: 15),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      size: 28,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Choose from photos',
                    style: TextStyle(fontSize: 15),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // ADD HOUSE
  // ======================================================

  Future<void> _showAddHouseDialog() async {
    final TextEditingController nameController = TextEditingController();
    int selectedStories = 1;
    String? selectedTempImagePath;

    final FixedExtentScrollController storiesScrollController =
        FixedExtentScrollController(initialItem: 0);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add a New House',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HOUSE NAME
                      const Text(
                        'House Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 22),
                        decoration: InputDecoration(
                          hintText: 'Enter house name',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.teal.shade700,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          prefixIcon: Icon(
                            Icons.home,
                            size: 28,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // NUMBER OF STORIES
                      const Text(
                        'Number of Stories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scroll to choose (1 – 100)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Scrollable stories picker
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Highlight band for selected item
                            Container(
                              height: 52,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.teal.shade600,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.25),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            ListWheelScrollView.useDelegate(
                              controller: storiesScrollController,
                              itemExtent: 52,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1.4,
                              perspective: 0.003,
                              onSelectedItemChanged: (index) {
                                setStateDialog(() {
                                  selectedStories = index + 1;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 100,
                                builder: (context, index) {
                                  final number = index + 1;
                                  final bool isSelected =
                                      number == selectedStories;

                                  return Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 120),
                                      style: TextStyle(
                                        fontSize: isSelected ? 28 : 20,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.teal.shade900
                                            : Colors.teal.shade400
                                                .withOpacity(0.55),
                                      ),
                                      child: Text('$number'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Selected stories badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade700,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            selectedStories == 1
                                ? '1 Story selected'
                                : '$selectedStories Stories selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // HOUSE IMAGE
                      const Text(
                        'House Picture (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final ImageSource? source =
                                  await _chooseImageSource();
                              if (source == null) return;

                              final XFile? image = await _picker.pickImage(
                                source: source,
                                imageQuality: 85,
                              );

                              if (image == null) return;

                              setStateDialog(() {
                                selectedTempImagePath = image.path;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not select image: $e',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            selectedTempImagePath != null
                                ? Icons.check_circle
                                : Icons.add_a_photo,
                            size: 28,
                            color: selectedTempImagePath != null
                                ? Colors.green.shade700
                                : Colors.teal.shade700,
                          ),
                          label: Text(
                            selectedTempImagePath != null
                                ? 'Picture selected'
                                : 'Add Picture',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: selectedTempImagePath != null
                                  ? Colors.green.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: selectedTempImagePath != null
                                  ? Colors.green.shade400
                                  : Colors.teal.shade300,
                              width: 1.8,
                            ),
                            backgroundColor: selectedTempImagePath != null
                                ? Colors.green.shade50
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter the house name.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      String? permanentImagePath;

                      if (selectedTempImagePath != null) {
                        permanentImagePath =
                            await AppStorage.saveImagePermanently(
                          selectedTempImagePath!,
                        );
                      }

                      final List<Floor> initialFloors = [];
                      for (int i = 1; i <= selectedStories; i++) {
                        initialFloors.add(
                          Floor(
                            floorNumber: i,
                            rooms: [],
                          ),
                        );
                      }

                      final newHouse = House(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name,
                        numberOfStories: selectedStories,
                        imagePath: permanentImagePath,
                        floors: initialFloors,
                      );

                      if (!mounted) return;

                      setState(() {
                        houses.add(newHouse);
                      });

                      await _saveData();

                      if (!mounted) return;

                      Navigator.pop(dialogContext);
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not save house: $e',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save House',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      nameController.dispose();
      storiesScrollController.dispose();
    });
  }

  // ======================================================
  // CHANGE HOUSE IMAGE
  // ======================================================

  Future<void> _changeHouseImage(House house) async {
    try {
      final ImageSource? source = await _chooseImageSource();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      final String permanentPath =
          await AppStorage.saveImagePermanently(image.path);

      if (!mounted) return;

      setState(() {
        house.imagePath = permanentPath;
      });

      await _saveData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'House image updated successfully.',
            style: TextStyle(fontSize: 16),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not change house image: $e',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  // ======================================================
  // CONFIRM DELETE HOUSE
  // ======================================================

  Future<void> _confirmDeleteDialog(int index) async {
    final house = houses[index];

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete House?',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "${house.name}"?\n\n'
            'All floors, rooms and rent records for this house will be deleted.',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 18),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Yes, Delete',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      houses.removeAt(index);
      if (houses.isEmpty) {
        isDeleteMode = false;
      }
    });

    await _saveData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${house.name} deleted.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // ======================================================
  // HOUSE CARD
  // ======================================================

  Widget _buildHouseCard(House house, int index) {
    return GestureDetector(
      onTap: () {
        if (isDeleteMode) {
          _confirmDeleteDialog(index);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoriesScreen(
              house: house,
              onHouseUpdated: _saveData,
            ),
          ),
        ).then((_) {
          if (!mounted) return;
          setState(() {});
        });
      },
      onLongPress: isDeleteMode
          ? null
          : () {
              _changeHouseImage(house);
            },
      child: Container(
        width: 300,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDeleteMode ? Colors.red.shade600 : Colors.teal.shade200,
            width: isDeleteMode ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // House name
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    house.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),

                // Stories count chip
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        house.numberOfStories == 1
                            ? '1 Story'
                            : '${house.numberOfStories} Stories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ),
                ),

                // Image
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: house.imagePath != null &&
                              house.imagePath!.isNotEmpty
                          ? Image.file(
                              File(house.imagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildNoHouseImage();
                              },
                            )
                          : _buildNoHouseImage(),
                    ),
                  ),
                ),
              ],
            ),

            // Delete mode overlay
            if (isDeleteMode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_forever,
                      size: 90,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Long-press hint
            if (!isDeleteMode)
              Positioned(
                right: 18,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Hold to change photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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

  Widget _buildNoHouseImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home,
              size: 80,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            Text(
              'No house picture',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F6),
      appBar: AppBar(
        title: const Text(
          'My Properties',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              color: Colors.teal.shade50,
              child: Text(
                isDeleteMode
                    ? 'Tap a house to delete it'
                    : 'Tap a house to open · Hold to change photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDeleteMode
                      ? Colors.red.shade700
                      : Colors.teal.shade800,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // House list
            Expanded(
              child: houses.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_work_outlined,
                              size: 90,
                              color: Colors.teal.shade200,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'No houses yet',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap Add below to create your first house.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: houses.length,
                      itemBuilder: (context, index) {
                        return _buildHouseCard(houses[index], index);
                      },
                    ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _showAddHouseDialog,
                        icon: const Icon(Icons.add_home, size: 28),
                        label: const Text(
                          'Add House',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: houses.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  isDeleteMode = !isDeleteMode;
                                });
                              },
                        icon: Icon(
                          isDeleteMode ? Icons.check : Icons.delete_outline,
                          size: 28,
                        ),
                        label: Text(
                          isDeleteMode ? 'Done' : 'Delete',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDeleteMode
                              ? Colors.red.shade600
                              : Colors.red.shade50,
                          foregroundColor: isDeleteMode
                              ? Colors.white
                              : Colors.red.shade800,
                          disabledBackgroundColor: Colors.grey.shade200,
                          elevation: isDeleteMode ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: houses.isEmpty
                                  ? Colors.grey.shade300
                                  : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}