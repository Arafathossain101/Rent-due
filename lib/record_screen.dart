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
  // AUTOMATIC MONTHLY BILLS
  // ======================================================

  // Returns the latest amount for a bill type from months before the
  // supplied month. Future scheduled amounts must never affect the
  // current month's due.
  double _lastKnownAmount({
    required String name,
    required bool isRent,
    required DateTime beforeMonth,
  }) {
    if (isRent) return widget.room.baseRentAmount;

    double lastAmount = 0;
    DateTime? latestMonth;

    for (final bill in widget.room.bills) {
      if (bill.isRent) continue;
      if (bill.name.toLowerCase().trim() != name.toLowerCase().trim()) {
        continue;
      }

      final billMonth = _startOfMonth(bill.targetMonth);
      if (!billMonth.isBefore(beforeMonth)) continue;

      if (latestMonth == null || billMonth.isAfter(latestMonth)) {
        latestMonth = billMonth;
        lastAmount = bill.amount;
      }
    }

    return lastAmount;
  }

  String _billIdentityKey(Bill bill) {
    if (bill.isRent) return 'rent';
    return bill.name.toLowerCase().trim();
  }

  Bill? _findBillForMonth({
    required String identityKey,
    required DateTime month,
  }) {
    for (final bill in widget.room.bills) {
      if (_monthKey(bill.targetMonth) != _monthKey(month)) continue;
      if (_billIdentityKey(bill) == identityKey) return bill;
    }
    return null;
  }

  void _ensureDefaultBillsForCurrentMonth({
    bool createLog = true,
  }) {
    final currentMonth = _currentMonth;
    bool stateChanged = false;

    void ensureBill({
      required String name,
      required bool isRent,
      required double amount,
      required String idSuffix,
    }) {
      final existing = _findBillForMonth(
        identityKey: isRent ? 'rent' : name.toLowerCase().trim(),
        month: currentMonth,
      );
      if (existing != null) return;

      widget.room.bills.add(
        Bill(
          id: '${DateTime.now().microsecondsSinceEpoch}$idSuffix',
          name: name,
          amount: amount,
          paidAmount: 0,
          isRent: isRent,
          targetMonth: currentMonth,
        ),
      );
      stateChanged = true;
    }

    // Core recurring bills.
    ensureBill(
      name: 'Rent',
      isRent: true,
      amount: widget.room.baseRentAmount,
      idSuffix: '_rent',
    );

    ensureBill(
      name: 'Gas',
      isRent: false,
      amount: _lastKnownAmount(
        name: 'Gas',
        isRent: false,
        beforeMonth: currentMonth,
      ),
      idSuffix: '_gas',
    );

    ensureBill(
      name: 'Electricity',
      isRent: false,
      amount: _lastKnownAmount(
        name: 'Electricity',
        isRent: false,
        beforeMonth: currentMonth,
      ),
      idSuffix: '_elec',
    );

    // Any custom bill that was previously configured also recurs at the
    // beginning of a new month, unless it already has a current-month bill.
    final previousBills = widget.room.bills
        .where((bill) => _startOfMonth(bill.targetMonth).isBefore(currentMonth))
        .toList();

    final Map<String, Bill> latestPreviousByType = {};
    for (final bill in previousBills) {
      final key = _billIdentityKey(bill);
      final existing = latestPreviousByType[key];
      if (existing == null || bill.targetMonth.isAfter(existing.targetMonth)) {
        latestPreviousByType[key] = bill;
      }
    }

    for (final entry in latestPreviousByType.entries) {
      final key = entry.key;
      if (key == 'rent' || key == 'gas' || key == 'electricity') continue;

      if (_findBillForMonth(identityKey: key, month: currentMonth) != null) {
        continue;
      }

      final previous = entry.value;
      widget.room.bills.add(
        Bill(
          id: '${DateTime.now().microsecondsSinceEpoch}_recurring',
          name: previous.name,
          amount: previous.amount,
          paidAmount: 0,
          isRent: false,
          targetMonth: currentMonth,
        ),
      );
      stateChanged = true;
    }

    if (stateChanged) {
      if (createLog && widget.room.baseRentAmount > 0) {
        widget.room.logs.insert(
          0,
          RentLog(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            date: DateTime.now(),
            description:
                'Monthly bills were added automatically for ${_monthName(currentMonth)} ${currentMonth.year}.',
          ),
        );
      }
      widget.onDataChanged();
      if (mounted) setState(() {});
    }
  }

  // ======================================================
  // RAW REMAINING CALCULATION
  // ======================================================

  double _getRawRemaining(Bill bill) {
    return bill.amount - bill.paidAmount;
  }

  // ======================================================
  // CURRENT BILLS / STATIC BILL CARDS
  // ======================================================

  List<Bill> _sortBills(List<Bill> bills) {
    bills.sort((a, b) {
      if (a.isRent && !b.isRent) return -1;
      if (!a.isRent && b.isRent) return 1;

      const preferred = ['gas', 'electricity'];
      final aIdx = preferred.indexOf(a.name.toLowerCase().trim());
      final bIdx = preferred.indexOf(b.name.toLowerCase().trim());

      if (aIdx != -1 && bIdx != -1) {
        return aIdx.compareTo(bIdx);
      }
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return bills;
  }

  List<Bill> get _currentBills {
    return _sortBills(
      widget.room.bills
          .where((bill) => _monthKey(bill.targetMonth) == _currentMonthKey)
          .toList(),
    );
  }

  // One static card per bill type. When a next-month amount has already
  // been configured, that amount is shown on the card; otherwise the card
  // shows the current month's amount. There is never a separate "next month"
  // card.
  List<Bill> get _addedBills {
    final Map<String, Bill> visibleByType = {};
    final currentKey = _currentMonthKey;
    final nextKey = _monthKey(_nextMonth);

    for (final bill in widget.room.bills) {
      final key = _billIdentityKey(bill);
      final monthKey = _monthKey(bill.targetMonth);
      if (monthKey != currentKey && monthKey != nextKey) continue;

      final existing = visibleByType[key];
      if (existing == null) {
        visibleByType[key] = bill;
      } else {
        final existingKey = _monthKey(existing.targetMonth);
        // Prefer the next-month configured amount over the current-month
        // amount for the static card.
        if (monthKey == nextKey && existingKey != nextKey) {
          visibleByType[key] = bill;
        }
      }
    }

    return _sortBills(visibleByType.values.toList());
  }

  // ======================================================
  // TOTAL DUE
  // ======================================================

  double get _totalDue {
    final currentBillsDue = _currentBills.fold(
      0.0,
      (total, bill) => total + _getRawRemaining(bill),
    );
    return currentBillsDue + widget.room.previousDueAmount;
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
                  onPressed: () => Navigator.pop(dialogContext, true),
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
      _disposeControllersAfterDialog([nameController]);
      return;
    }

    final String newName = nameController.text.trim();

    setState(() {
      widget.room.renterName = newName;
      widget.room.renterIdImagePath = selectedIdPath;
    });

    _addLog('Renter information updated.');
    _disposeControllersAfterDialog([nameController]);
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
      // Previous Due is part of the current Total Due and is paid first.
      if (widget.room.previousDueAmount > 0 && remainingToPay > 0) {
        final previousDuePayment = remainingToPay > widget.room.previousDueAmount
            ? widget.room.previousDueAmount
            : remainingToPay;
        widget.room.previousDueAmount -= previousDuePayment;
        remainingToPay -= previousDuePayment;
      }

      for (final bill in _currentBills) {
        if (remainingToPay <= 0) break;

        final billRemaining = _getRawRemaining(bill);
        if (billRemaining > 0) {
          if (remainingToPay >= billRemaining) {
            bill.paidAmount += billRemaining;
            remainingToPay -= billRemaining;
          } else {
            bill.paidAmount += remainingToPay;
            remainingToPay = 0;
          }
        }
      }

      // Preserve the previous overpayment behavior by assigning any
      // remaining payment to rent first, then the first current bill.
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
        const SnackBar(
          content: Text(
            'All bills have been fully paid.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  // ======================================================
  // ADD BILL
  // ======================================================

  Future<void> _showAddBillDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    // All new bill amounts are configured for the next month by default.
    String selectedMonth = 'next';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Bill',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bill Amount',
                        hintText: 'Enter amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments, size: 28),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Start this bill from:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'current',
                      groupValue: selectedMonth,
                      onChanged: (value) =>
                          setDialogState(() => selectedMonth = value!),
                      title: Text(
                        'Current Month (${_monthName(_currentMonth)})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'next',
                      groupValue: selectedMonth,
                      onChanged: (value) =>
                          setDialogState(() => selectedMonth = value!),
                      title: Text(
                        'Next Month (${_monthName(_nextMonth)})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter the bill name.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid amount.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                      return;
                    }

                    final targetMonth = selectedMonth == 'current'
                        ? _currentMonth
                        : _nextMonth;

                    Navigator.pop(
                      dialogContext,
                      {
                        'name': name,
                        'amount': amount,
                        'targetMonth': targetMonth,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Add Bill',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([nameController, amountController]);

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final amount = result['amount'] as double;
    final targetMonth = result['targetMonth'] as DateTime;
    final identityKey = name.toLowerCase().trim();

    setState(() {
      final existing = _findBillForMonth(
        identityKey: identityKey,
        month: targetMonth,
      );

      if (existing != null) {
        existing.amount = amount;
        existing.name = name;
      } else {
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
      }
    });

    _addLog(
      'Added $name bill ${_money(amount)} for '
      '${_monthName(targetMonth)} ${targetMonth.year}.',
    );
  }

  // ======================================================
  // EDIT BILL
  // ======================================================

  Future<void> _showEditBillDialog(Bill bill) async {
    final nameController = TextEditingController(text: bill.name);
    final amountController =
        TextEditingController(text: bill.amount.toStringAsFixed(0));

    // Editing always defaults to the next month so the current month's due
    // is not accidentally changed.
    String selectedMonth = 'next';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                bill.isRent ? 'Edit Rent' : 'Edit Bill',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
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
                        helperText: bill.isRent
                            ? 'Rent name cannot be changed.'
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amountController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Start this amount from:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'current',
                      groupValue: selectedMonth,
                      onChanged: (value) =>
                          setDialogState(() => selectedMonth = value!),
                      title: Text(
                        'Current Month (${_monthName(_currentMonth)})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'next',
                      groupValue: selectedMonth,
                      onChanged: (value) =>
                          setDialogState(() => selectedMonth = value!),
                      title: Text(
                        'Next Month (${_monthName(_nextMonth)})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!bill.isRent)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(dialogContext, {'action': 'delete'}),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 22,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newAmount =
                        double.tryParse(amountController.text.trim());
                    if (newAmount == null || newAmount < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid amount.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                      return;
                    }

                    final newName = bill.isRent
                        ? 'Rent'
                        : nameController.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Bill name cannot be empty.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      {
                        'action': 'save',
                        'name': newName,
                        'amount': newAmount,
                        'selectedMonth': selectedMonth,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([nameController, amountController]);

    if (result == null || !mounted) return;

    if (result['action'] == 'delete') {
      await _confirmDeleteBill(bill);
      return;
    }

    final oldName = bill.name;
    final oldAmount = bill.amount;
    final newName = result['name'] as String;
    final newAmount = result['amount'] as double;
    final monthChoice = result['selectedMonth'] as String? ?? 'next';
    final targetMonth = monthChoice == 'current' ? _currentMonth : _nextMonth;

    setState(() {
      final oldIdentityKey = _billIdentityKey(bill);
      final targetIdentityKey = bill.isRent
          ? 'rent'
          : newName.toLowerCase().trim();

      // A bill's name identifies its recurring bill type. Keep that identity
      // consistent across its stored monthly records when the name is edited.
      if (!bill.isRent && oldName.toLowerCase().trim() != targetIdentityKey) {
        for (final storedBill in widget.room.bills) {
          if (!storedBill.isRent &&
              _billIdentityKey(storedBill) == oldIdentityKey) {
            storedBill.name = newName;
          }
        }
      }

      Bill? targetBill;
      for (final candidate in widget.room.bills) {
        if (_monthKey(candidate.targetMonth) != _monthKey(targetMonth)) {
          continue;
        }
        if (_billIdentityKey(candidate) == targetIdentityKey) {
          targetBill = candidate;
          break;
        }
      }

      if (targetBill == null) {
        widget.room.bills.add(
          Bill(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: bill.isRent ? 'Rent' : newName,
            amount: newAmount,
            paidAmount: 0,
            isRent: bill.isRent,
            targetMonth: targetMonth,
          ),
        );
      } else {
        targetBill.amount = newAmount;
        if (!targetBill.isRent) {
          targetBill.name = newName;
        }
      }

      // Rent is the recurring base amount. Changing it updates the amount
      // that will be generated automatically in future months, while the
      // target-month record above controls when this new amount starts.
      if (bill.isRent) {
        widget.room.baseRentAmount = newAmount;
      }
    });

    widget.onDataChanged();
    _addLog(
      'Bill updated: $oldName → $newName, '
      '${_money(oldAmount)} → ${_money(newAmount)} from '
      '${_monthName(targetMonth)} ${targetMonth.year}.',
    );
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
    final nameKey = bill.name.toLowerCase().trim();

    final IconData icon = bill.isRent
        ? Icons.home
        : nameKey == 'gas'
            ? Icons.local_fire_department
            : nameKey == 'electricity'
                ? Icons.bolt
                : Icons.receipt_long;

    final Color iconColor = bill.isRent
        ? Colors.teal
        : nameKey == 'gas'
            ? Colors.orange.shade700
            : nameKey == 'electricity'
                ? Colors.amber.shade800
                : Colors.blueGrey;

    return GestureDetector(
      onTap: () => _showEditBillDialog(bill),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 10),
            Text(
              bill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _money(bill.amount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
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
  // PREVIOUS DUE
  // ======================================================

  Future<void> _showAddPreviousDueDialog() async {
    final amountController = TextEditingController();

    final result = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Previous Due',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              labelText: 'Previous Due Amount',
              hintText: 'Enter amount',
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 17),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount =
                    double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid amount.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, amount);
              },
              child: const Text(
                'Add Due',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        );
      },
    );

    _disposeControllersAfterDialog([amountController]);

    if (result == null || !mounted) return;

    setState(() {
      widget.room.previousDueAmount += result;
    });

    _addLog('Previous due added: ${_money(result)}.');
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
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Clear Everything?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'This will permanently remove all bill records, all payments, all previous due amounts, and the entire activity log.\n\nThe renter name, ID document, room information, and room image will remain.\n\nRent, Gas, Electricity, and recurring bill cards will be recreated with zero amounts.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 17),
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
                'Clear Everything',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      widget.room.bills.clear();
      widget.room.logs.clear();
      widget.room.previousDueAmount = 0;
      widget.room.baseRentAmount = 0;
    });

    // Recreate only the fixed monthly cards, all with zero amounts.
    _ensureDefaultBillsForCurrentMonth(createLog: false);

    widget.onDataChanged();
    if (mounted) setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Everything has been cleared.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Added Bills',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Bill types',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 175,
              child: _addedBills.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No bills have been added.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _addedBills.length,
                      itemBuilder: (context, index) =>
                          _buildBillCard(_addedBills[index]),
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
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddPreviousDueDialog,
                icon: const Icon(Icons.history_toggle_off, size: 26),
                label: const Text(
                  'Add Previous Due',
                  style: TextStyle(fontSize: 17),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
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