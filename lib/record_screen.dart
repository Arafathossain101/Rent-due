import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'storage.dart';

class RecordScreen extends StatefulWidget {
  final Room room;
  final VoidCallback onDataChanged;

  const RecordScreen({
    super.key,
    required this.room,
    required this.onDataChanged,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ======================================================
  // DATE HELPERS
  // ======================================================
  void _disposeControllersAfterDialog(
    List<TextEditingController> controllers,
  ) {
    Future.delayed(const Duration(milliseconds: 300), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[date.month - 1];
  }

  String _money(double amount) {
    return '৳${amount.toStringAsFixed(0)}';
  }

  // ======================================================
  // CURRENT MONTH
  // ======================================================

  DateTime get _currentMonth {
    return _startOfMonth(DateTime.now());
  }

  String get _currentMonthKey {
    return _monthKey(_currentMonth);
  }

  DateTime get _nextMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  // ======================================================
  // INIT
  // ======================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureDefaultBillsForCurrentMonth();
      }
    });
  }

  // ======================================================
  // AUTOMATIC DEFAULT BILLS (Rent + Gas + Electricity)
  // ======================================================

  void _ensureDefaultBillsForCurrentMonth({
    bool createLog = true,
  }) {
    final String monthKey = _currentMonthKey;
    bool stateChanged = false;

    // --- RENT ---
    final bool rentExists = widget.room.bills.any(
      (bill) => bill.isRent && _monthKey(bill.targetMonth) == monthKey,
    );

    // Rent is now always added by default like Gas and Electricity
    if (!rentExists) {
      final double rentAmount = widget.room.baseRentAmount;
      widget.room.bills.add(
        Bill(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'Rent',
          amount: rentAmount,
          paidAmount: 0,
          isRent: true,
          targetMonth: _currentMonth,
        ),
      );
      stateChanged = true;

      if (createLog && rentAmount > 0) {
        widget.room.logs.insert(
          0,
          RentLog(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            date: DateTime.now(),
            description: 'Monthly rent added automatically: ${_money(rentAmount)}',
          ),
        );
      }
    }

    // --- GAS ---
    final bool gasExists = widget.room.bills.any(
      (bill) =>
          !bill.isRent &&
          bill.name.toLowerCase().trim() == 'gas' &&
          _monthKey(bill.targetMonth) == monthKey,
    );

    if (!gasExists) {
      widget.room.bills.add(
        Bill(
          id: '${DateTime.now().microsecondsSinceEpoch}_gas',
          name: 'Gas',
          amount: 0,
          paidAmount: 0,
          isRent: false,
          targetMonth: _currentMonth,
        ),
      );
      stateChanged = true;
    }

    // --- ELECTRICITY ---
    final bool electricityExists = widget.room.bills.any(
      (bill) =>
          !bill.isRent &&
          bill.name.toLowerCase().trim() == 'electricity' &&
          _monthKey(bill.targetMonth) == monthKey,
    );

    if (!electricityExists) {
      widget.room.bills.add(
        Bill(
          id: '${DateTime.now().microsecondsSinceEpoch}_elec',
          name: 'Electricity',
          amount: 0,
          paidAmount: 0,
          isRent: false,
          targetMonth: _currentMonth,
        ),
      );
      stateChanged = true;
    }

    if (stateChanged) {
      setState(() {});
      widget.onDataChanged();
    }
  }

  // ======================================================
  // RAW REMAINING CALCULATION (Allows Negative)
  // ======================================================
  
  double _getRawRemaining(Bill bill) {
    return bill.amount - bill.paidAmount;
  }

  // ======================================================
  // CURRENT MONTH BILLS
  // ======================================================

  List<Bill> get _currentBills {
    final bills = widget.room.bills
        .where((bill) => _monthKey(bill.targetMonth) == _currentMonthKey)
        .toList();

    bills.sort((a, b) {
      if (a.isRent && !b.isRent) return -1;
      if (!a.isRent && b.isRent) return 1;

      const preferred = ['gas', 'electricity'];
      final aIdx = preferred.indexOf(a.name.toLowerCase().trim());
      final bIdx = preferred.indexOf(b.name.toLowerCase().trim());
      if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return bills;
  }

  // ======================================================
  // TOTAL DUE
  // ======================================================

  double get _totalDue {
    return _currentBills.fold(
      0.0,
      (total, bill) => total + _getRawRemaining(bill),
    );
  }

  // ======================================================
  // RENT DUE
  // ======================================================

  double get _currentRentDue {
    for (final bill in _currentBills) {
      if (bill.isRent) {
        return _getRawRemaining(bill);
      }
    }
    return 0.0;
  }

  // ======================================================
  // OTHER BILLS DUE
  // ======================================================

  double get _currentOtherBillsDue {
    return _currentBills
        .where((bill) => !bill.isRent)
        .fold(
          0.0,
          (total, bill) => total + _getRawRemaining(bill),
        );
  }

  // ======================================================
  // ADD LOG
  // ======================================================

  void _addLog(String description) {
    widget.room.logs.insert(
      0,
      RentLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        description: description,
      ),
    );

    widget.onDataChanged();
    if (mounted) setState(() {});
  }

  // ======================================================
  // FILE NAME HELPER & PICKER
  // ======================================================

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  Future<String?> _pickIdDocument() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (file == null || file.path == null) return null;
      return await AppStorage.saveFilePermanently(file.path!);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select ID file: $e')),
      );
      return null;
    }
  }

  // ======================================================
  // RENTER INFORMATION
  // ======================================================

  Future<void> _showRenterDetailsDialog() async {
    final nameController = TextEditingController(text: widget.room.renterName);
    final rentController = TextEditingController(
      text: widget.room.baseRentAmount > 0 ? widget.room.baseRentAmount.toStringAsFixed(0) : '',
    );

    String? selectedIdPath = widget.room.renterIdImagePath;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasId = selectedIdPath != null && selectedIdPath!.isNotEmpty;
            return AlertDialog(
              title: const Text('Renter Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Name (Optional)',
                        hintText: 'Enter renter name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, size: 28),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: rentController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent Amount',
                        hintText: 'Enter monthly rent',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home, size: 28),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasId ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hasId ? Colors.green : Colors.grey.shade400, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(hasId ? Icons.verified : Icons.assignment_ind_outlined, color: hasId ? Colors.green : Colors.grey, size: 26),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('ID Document (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (hasId)
                            Text(_getFileName(selectedIdPath!), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))
                          else
                            const Text('Select an image or PDF.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickIdDocument();
                                if (path == null || !mounted) return;
                                setDialogState(() => selectedIdPath = path);
                              },
                              icon: const Icon(Icons.upload_file, size: 24),
                              label: Text(hasId ? 'Change ID' : 'Select ID', style: const TextStyle(fontSize: 16)),
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
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel', style: TextStyle(fontSize: 17)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final rent = double.tryParse(rentController.text.trim());
                    if (rent == null || rent < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid monthly rent.', style: TextStyle(fontSize: 16))));
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  child: const Text('Save', style: TextStyle(fontSize: 17)),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      _disposeControllersAfterDialog([nameController, rentController]);
      return;
    }

    final String newName = nameController.text.trim();
    final double newRent = double.tryParse(rentController.text.trim()) ?? 0;
    final double oldRent = widget.room.baseRentAmount;

    setState(() {
      widget.room.renterName = newName;
      widget.room.baseRentAmount = newRent;
      widget.room.renterIdImagePath = selectedIdPath;
    });

    Bill? currentRentBill;
    for (final bill in widget.room.bills) {
      if (bill.isRent && _monthKey(bill.targetMonth) == _currentMonthKey) {
        currentRentBill = bill;
        break;
      }
    }

    if (currentRentBill != null) {
      final paidAmount = currentRentBill.paidAmount;
      setState(() {
        currentRentBill!.amount = newRent;
        // Allows keeping the current paid amount untouched so they can maintain overpayments
      });
    }

    _ensureDefaultBillsForCurrentMonth(createLog: false);

    String description = 'Renter information updated.';
    if (oldRent != newRent) {
      description += ' Monthly rent changed from ${_money(oldRent)} to ${_money(newRent)}.';
    }

    _addLog(description);
    _disposeControllersAfterDialog([nameController, rentController]);
  }

  // ======================================================
  // UPDATE ALL BILLS (Distributes Payment)
  // ======================================================

  Bill? _getCurrentRentBill() {
    for (final bill in _currentBills) {
      if (bill.isRent) return bill;
    }
    return null;
  }

  Future<void> _showUpdateBillsDialog() async {
    final double totalRemaining = _totalDue;

    final amountController = TextEditingController();
    String selectedOption = 'specific';

    final result = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update the Bills', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Bills Remaining', style: TextStyle(color: Colors.black54, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            _money(totalRemaining),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'specific',
                      groupValue: selectedOption,
                      onChanged: (value) => setDialogState(() => selectedOption = value!),
                      title: const Text('Specific Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                      subtitle: const Text('Pay a custom amount', style: TextStyle(fontSize: 14)),
                    ),
                    if (selectedOption == 'specific')
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 18),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount to Pay',
                          hintText: 'Enter amount',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    const SizedBox(height: 6),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'full',
                      groupValue: selectedOption,
                      onChanged: (value) => setDialogState(() => selectedOption = value!),
                      title: const Text('Full Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                      subtitle: Text('Pay ${_money(totalRemaining)}', style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 17)),
                ),
                ElevatedButton(
                  onPressed: () {
                    double amount;
                    if (selectedOption == 'full') {
                      amount = totalRemaining;
                    } else {
                      amount = double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.', style: TextStyle(fontSize: 16))));
                        return;
                      }
                    }
                    Navigator.pop(dialogContext, amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Update Bills', style: TextStyle(fontSize: 17)),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([amountController]);

    if (result == null || !mounted) return;

    _applyPaymentToAllBills(result);
  }

  void _applyPaymentToAllBills(double amount) {
    double remainingToPay = amount;

    setState(() {
      for (final bill in _currentBills) {
        double billRemaining = _getRawRemaining(bill);
        if (billRemaining > 0) {
          if (remainingToPay >= billRemaining) {
            bill.paidAmount += billRemaining;
            remainingToPay -= billRemaining;
          } else {
            bill.paidAmount += remainingToPay;
            remainingToPay = 0;
            break;
          }
        }
      }

      // If overpaid, assign the negative balance primarily to the Rent bill
      if (remainingToPay > 0) {
        final rentBill = _getCurrentRentBill();
        if (rentBill != null) {
          rentBill.paidAmount += remainingToPay;
        } else if (_currentBills.isNotEmpty) {
          _currentBills.first.paidAmount += remainingToPay;
        }
      }
    });

    _addLog('Bills updated with payment: ${_money(amount)}.');
    
    if (_totalDue <= 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All bills have been fully paid.', style: TextStyle(fontSize: 16))),
      );
    }
  }

  // ======================================================
  // ADD BILL
  // ======================================================

  Future<void> _showAddBillDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedMonth = 'current';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Bill', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Bill Name',
                        hintText: 'Water, Internet...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long, size: 28),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Bill Amount',
                        hintText: 'Enter amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments, size: 28),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add this bill to:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    RadioListTile<String>(
                      value: 'current',
                      groupValue: selectedMonth,
                      onChanged: (value) => setDialogState(() => selectedMonth = value!),
                      title: Text('Current Month (${_monthName(_currentMonth)})', style: const TextStyle(fontSize: 16)),
                    ),
                    RadioListTile<String>(
                      value: 'next',
                      groupValue: selectedMonth,
                      onChanged: (value) => setDialogState(() => selectedMonth = value!),
                      title: Text('Next Month (${_monthName(_nextMonth)})', style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 17)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the bill name.', style: TextStyle(fontSize: 16))));
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.', style: TextStyle(fontSize: 16))));
                      return;
                    }
                    final DateTime targetMonth = selectedMonth == 'current' ? _currentMonth : _nextMonth;
                    Navigator.pop(dialogContext, {'name': name, 'amount': amount, 'targetMonth': targetMonth});
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  child: const Text('Add Bill', style: TextStyle(fontSize: 17)),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([nameController, amountController]);

    if (result == null || !mounted) return;

    final String name = result['name'] as String;
    final double amount = result['amount'] as double;
    final DateTime targetMonth = result['targetMonth'] as DateTime;

    setState(() {
      widget.room.bills.add(
        Bill(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          amount: amount,
          paidAmount: 0,
          isRent: false,
          targetMonth: targetMonth,
        ),
      );
    });

    _addLog('Added $name bill ${_money(amount)} for ${_monthName(targetMonth)} ${targetMonth.year}.');
  }

  // ======================================================
  // EDIT BILL
  // ======================================================

  Future<void> _showEditBillDialog(Bill bill) async {
    final nameController = TextEditingController(text: bill.name);
    final amountController = TextEditingController(text: bill.amount.toStringAsFixed(0));

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(bill.isRent ? 'Edit Rent' : 'Edit Bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !bill.isRent,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Bill Name',
                    border: const OutlineInputBorder(),
                    helperText: bill.isRent ? 'Rent name cannot be changed.' : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: amountController,
                  style: const TextStyle(fontSize: 18),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: Text('Original: ${_money(bill.amount)}', style: const TextStyle(color: Colors.grey, fontSize: 15))),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text('Paid: ${_money(bill.paidAmount)}', style: const TextStyle(color: Colors.grey, fontSize: 15))),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Remaining: ${_money(_getRawRemaining(bill))}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _getRawRemaining(bill) <= 0 ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!bill.isRent)
              TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext, {'action': 'delete'}),
                icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel', style: TextStyle(fontSize: 17)),
            ),
            ElevatedButton(
              onPressed: () {
                final newAmount = double.tryParse(amountController.text.trim());
                if (newAmount == null || newAmount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.', style: TextStyle(fontSize: 16))));
                  return;
                }
                String newName = bill.name;
                if (!bill.isRent) {
                  newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill name cannot be empty.', style: TextStyle(fontSize: 16))));
                    return;
                  }
                }
                Navigator.pop(dialogContext, {'action': 'save', 'name': newName, 'amount': newAmount});
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              child: const Text('Save', style: TextStyle(fontSize: 17)),
            ),
          ],
        );
      },
    );

    _disposeControllersAfterDialog([nameController, amountController]);

    if (result == null || !mounted) return;

    if (result['action'] == 'delete') {
      await _confirmDeleteBill(bill);
      return;
    }

    if (result['action'] == 'save') {
      final oldName = bill.name;
      final oldAmount = bill.amount;
      final newName = result['name'] as String;
      final newAmount = result['amount'] as double;

      setState(() {
        if (!bill.isRent) bill.name = newName;
        bill.amount = newAmount;
        if (bill.isRent) widget.room.baseRentAmount = newAmount;
      });

      if (bill.isRent) {
        _addLog('Rent changed from ${_money(oldAmount)} to ${_money(newAmount)}.');
      } else {
        _addLog('Bill updated: $oldName → ${bill.name}, ${_money(oldAmount)} → ${_money(newAmount)}.');
      }
    }
  }

  Future<void> _confirmDeleteBill(Bill bill) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Delete Bill?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
            ],
          ),
          content: Text('Are you sure you want to delete "${bill.name}"?\n\nAmount: ${_money(bill.amount)}\nMonth: ${_monthName(bill.targetMonth)} ${bill.targetMonth.year}\n\nThis action cannot be undone.', style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(fontSize: 17)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              child: const Text('Delete', style: TextStyle(fontSize: 17)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      widget.room.bills.removeWhere((item) => item.id == bill.id);
    });

    _addLog('Deleted bill: ${bill.name} ${_money(bill.amount)}.');
  }

  // ======================================================
  // BILL CARD
  // ======================================================

  Widget _buildBillCard(Bill bill) {
    final double rawRemaining = _getRawRemaining(bill);
    final bool paid = rawRemaining <= 0;

    return GestureDetector(
      onTap: () => _showEditBillDialog(bill),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: paid ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: paid ? Colors.green : Colors.grey.shade300, width: 1.8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bill.isRent
                  ? Icons.home
                  : (bill.name.toLowerCase() == 'gas'
                      ? Icons.local_fire_department
                      : (bill.name.toLowerCase() == 'electricity' ? Icons.bolt : Icons.receipt_long)),
              size: 34,
              color: bill.isRent
                  ? Colors.teal
                  : (bill.name.toLowerCase() == 'gas'
                      ? Colors.orange.shade700
                      : (bill.name.toLowerCase() == 'electricity' ? Colors.amber.shade800 : Colors.blueGrey)),
            ),
            const SizedBox(height: 10),
            Text(
              bill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _money(rawRemaining),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: paid ? Colors.green : Colors.teal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              paid ? 'Payable' : 'Tap to edit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: paid ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // LOG ITEM & BOTTOM SHEET
  // ======================================================

  Widget _buildLogItem(RentLog log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(radius: 22, child: Icon(Icons.history, size: 22)),
        title: Text(log.description, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        subtitle: Text(_formatDate(log.date), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _showLogBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(3)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activity Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('${widget.room.logs.length} entries', style: const TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: widget.room.logs.isEmpty
                      ? const Center(child: Text('No activity yet.', style: TextStyle(color: Colors.grey, fontSize: 18)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: widget.room.logs.length,
                          itemBuilder: (context, index) => _buildLogItem(widget.room.logs[index]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ======================================================
  // CLEAR HISTORY & BUILD OTHERS
  // ======================================================

  Future<void> _showClearHistoryDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Expanded(child: Text('Clear Whole History?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
            ],
          ),
          content: const Text(
            'This will permanently remove:\n\n• All bills\n• All rent payment records\n• All activity logs\n\nRenter name, ID and monthly rent settings will remain.\n\nRent, Gas and Electricity for the current month will be created again automatically.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel', style: TextStyle(fontSize: 17))),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              child: const Text('Clear Everything', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      widget.room.bills.clear();
      widget.room.logs.clear();
    });

    _ensureDefaultBillsForCurrentMonth(createLog: false);
    widget.room.logs.insert(0, RentLog(id: DateTime.now().microsecondsSinceEpoch.toString(), date: DateTime.now(), description: 'All previous bill, payment, and activity history was cleared.'));
    
    widget.onDataChanged();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All history has been cleared.', style: TextStyle(fontSize: 16))));
  }

  Widget _buildIdStatus() {
    final path = widget.room.renterIdImagePath;
    if (path == null || path.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_ind_outlined, color: Colors.grey, size: 20),
            SizedBox(width: 6),
            Text('Not added', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }
    final bool isPdf = path.toLowerCase().endsWith('.pdf');
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _getFileName(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // BUILD SCREEN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${widget.room.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(onPressed: _showRenterDetailsDialog, tooltip: 'Renter Information', icon: const Icon(Icons.person, size: 28)),
          IconButton(onPressed: _showClearHistoryDialog, tooltip: 'Clear History', icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _showRenterDetailsDialog,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.teal.shade200, width: 1.5)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Name', style: TextStyle(color: Colors.black54, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(widget.room.renterName.trim().isEmpty ? 'Not added' : widget.room.renterName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('Tap to edit', style: TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ID', style: TextStyle(color: Colors.black54, fontSize: 14)),
                          const SizedBox(height: 5),
                          _buildIdStatus(),
                          const SizedBox(height: 2),
                          const Text('Tap to edit', style: TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Date', style: TextStyle(color: Colors.black54, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(_formatDate(DateTime.now()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _totalDue > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _totalDue > 0 ? Colors.orange.shade200 : Colors.green.shade200, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Due', style: TextStyle(color: Colors.black54, fontSize: 14)),
                        const SizedBox(height: 6),
                        FittedBox(
                          child: Text(
                            _money(_totalDue),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: _totalDue > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rent Due: ${_money(_currentRentDue)}', style: const TextStyle(color: Colors.black54, fontSize: 15)),
                Text('Bills Due: ${_money(_currentOtherBillsDue)}', style: const TextStyle(color: Colors.black54, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bills This Month', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('Tap a bill to edit', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 155,
              child: _currentBills.isEmpty
                  ? Container(decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('No bills for this month.', style: TextStyle(color: Colors.grey, fontSize: 16))))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _currentBills.length,
                      itemBuilder: (context, index) => _buildBillCard(_currentBills[index]),
                    ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showUpdateBillsDialog,
                      icon: const Icon(Icons.payments, size: 26),
                      label: const Text('Update Bills', style: TextStyle(fontSize: 17)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showAddBillDialog,
                      icon: const Icon(Icons.add, size: 26),
                      label: const Text('Add Bills', style: TextStyle(fontSize: 17)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // Activity Log styled cleanly as a sticky bottom navigation bar
      bottomNavigationBar: SafeArea(
        child: InkWell(
          onTap: _showLogBottomSheet,
          child: Container(
            height: kBottomNavigationBarHeight + 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 28, color: Colors.teal),
                const SizedBox(width: 10),
                Text(
                  'View Activity Log (${widget.room.logs.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}