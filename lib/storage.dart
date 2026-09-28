import 'dart:convert';
import 'dart:io';
import 'storage.dart';
import 'main.dart';
import 'stories_screen.dart';
import 'package:rent_due/storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ======================================================
// RENT LOG
// ======================================================

class RentLog {
  String id;
  DateTime date;
  String description;

  RentLog({
    required this.id,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory RentLog.fromJson(Map<String, dynamic> json) {
    return RentLog(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      description: json['description']?.toString() ?? '',
    );
  }
}

// ======================================================
// BILL
// ======================================================

class Bill {
  String id;
  String name;
  double amount;
  double paidAmount;
  bool isRent;
  DateTime targetMonth;

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    this.paidAmount = 0.0,
    this.isRent = false,
    required this.targetMonth,
  });

  // ====================================================
  // REMAINING AMOUNT
  // ====================================================
  // Allows negative values if paidAmount > amount (overpayment).
  double get remainingAmount {
    return amount - paidAmount;
  }

  // ====================================================
  // PAID STATUS
  // ====================================================
  bool get isPaid {
    return remainingAmount <= 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'paidAmount': paidAmount,
      'isRent': isRent,
      'targetMonth': targetMonth.toIso8601String(),
      'isPaid': isPaid,
    };
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    final double amount = (json['amount'] as num?)?.toDouble() ?? 0.0;

    final double paidAmount = (json['paidAmount'] as num?)?.toDouble() ??
        ((json['isPaid'] == true) ? amount : 0.0);

    final String name = json['name']?.toString() ?? 'Bill';

    final bool isRent =
        json['isRent'] == true || name.toLowerCase().trim() == 'rent';

    final DateTime targetMonth =
        DateTime.tryParse(json['targetMonth']?.toString() ?? '') ??
            DateTime.now();

    return Bill(
      id: json['id']?.toString() ?? '',
      name: name,
      amount: amount,
      paidAmount: paidAmount,
      isRent: isRent,
      targetMonth: targetMonth,
    );
  }
}

// ======================================================
// ROOM
// ======================================================

class Room {
  String id;
  String name;
  String? imagePath;
  String renterName;
  String? renterIdImagePath;
  double baseRentAmount;
  List<Bill> bills;
  List<RentLog> logs;

  Room({
    required this.id,
    required this.name,
    this.imagePath,
    this.renterName = '',
    this.renterIdImagePath,
    this.baseRentAmount = 0.0,
    List<Bill>? bills,
    List<RentLog>? logs,
  })  : bills = bills ?? [],
        logs = logs ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'renterName': renterName,
      'renterIdImagePath': renterIdImagePath,
      'baseRentAmount': baseRentAmount,
      'bills': bills.map((bill) => bill.toJson()).toList(),
      'logs': logs.map((log) => log.toJson()).toList(),
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    List<Bill> loadedBills = [];
    final dynamic billsData = json['bills'];
    if (billsData is List) {
      loadedBills = billsData
          .whereType<Map>()
          .map((bill) => Bill.fromJson(Map<String, dynamic>.from(bill)))
          .toList();
    }

    List<RentLog> loadedLogs = [];
    final dynamic logsData = json['logs'];
    if (logsData is List) {
      loadedLogs = logsData
          .whereType<Map>()
          .map((log) => RentLog.fromJson(Map<String, dynamic>.from(log)))
          .toList();
    }

    return Room(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      renterName: json['renterName']?.toString() ?? '',
      renterIdImagePath: json['renterIdImagePath']?.toString(),
      baseRentAmount: (json['baseRentAmount'] as num?)?.toDouble() ?? 0.0,
      bills: loadedBills,
      logs: loadedLogs,
    );
  }
}

// ======================================================
// FLOOR
// ======================================================

class Floor {
  int floorNumber;
  List<Room> rooms;

  Floor({
    required this.floorNumber,
    required this.rooms,
  });

  Map<String, dynamic> toJson() {
    return {
      'floorNumber': floorNumber,
      'rooms': rooms.map((room) => room.toJson()).toList(),
    };
  }

  factory Floor.fromJson(Map<String, dynamic> json) {
    List<Room> loadedRooms = [];
    final dynamic roomsData = json['rooms'];
    if (roomsData is List) {
      loadedRooms = roomsData
          .whereType<Map>()
          .map((room) => Room.fromJson(Map<String, dynamic>.from(room)))
          .toList();
    }

    return Floor(
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 1,
      rooms: loadedRooms,
    );
  }
}

// ======================================================
// HOUSE
// ======================================================

class House {
  String id;
  String name;
  String? imagePath;
  int numberOfStories;
  List<Floor> floors;

  House({
    required this.id,
    required this.name,
    this.imagePath,
    required this.numberOfStories,
    required this.floors,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'numberOfStories': numberOfStories,
      'floors': floors.map((floor) => floor.toJson()).toList(),
    };
  }

  factory House.fromJson(Map<String, dynamic> json) {
    List<Floor> loadedFloors = [];
    final dynamic floorsData = json['floors'];
    if (floorsData is List) {
      loadedFloors = floorsData
          .whereType<Map>()
          .map((floor) => Floor.fromJson(Map<String, dynamic>.from(floor)))
          .toList();
    }

    return House(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      numberOfStories: (json['numberOfStories'] as num?)?.toInt() ??
          loadedFloors.length,
      floors: loadedFloors,
    );
  }
}

// ======================================================
// STORAGE MANAGER
// ======================================================

class AppStorage {
  static Future<String> saveImagePermanently(String tempPath) async {
    return saveFilePermanently(tempPath);
  }

  static Future<String> saveFilePermanently(String tempPath) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String originalFileName = p.basename(tempPath);
    final String uniqueFileName =
        '${DateTime.now().microsecondsSinceEpoch}_$originalFileName';
    final String destination = p.join(directory.path, uniqueFileName);

    final File sourceFile = File(tempPath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist.');
    }

    final File savedFile = await sourceFile.copy(destination);
    return savedFile.path;
  }

  static Future<void> saveHouses(List<House> houses) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data =
        houses.map((house) => house.toJson()).toList();
    final String encodedData = jsonEncode(data);
    await prefs.setString('my_rent_data', encodedData);
  }

  static Future<List<House>> loadHouses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('my_rent_data');

    if (encodedData == null || encodedData.trim().isEmpty) {
      return [];
    }

    try {
      final dynamic decoded = jsonDecode(encodedData);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => House.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearAllHouses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('my_rent_data');
  }
}