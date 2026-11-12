import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/transaction_viewmodel.dart';

/// Halaman atau form modal untuk mencatat dan mengubah transaksi lokal.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.existingTransaction});

  final TransactionModel? existingTransaction;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late TransactionType _selectedType;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    _selectedType = existing?.type ?? TransactionType.expense;
    final validCategories = TransactionCategories.forType(_selectedType);
    _selectedCategory =
        existing != null && validCategories.contains(existing.category)
        ? existing.category
        : validCategories.first;
    _selectedDate = existing?.createdAt ?? DateTime.now();

    _amountController = TextEditingController(
      text: existing != null ? existing.amount.round().toString() : '',
    );
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType nextType) {
    if (_selectedType == nextType) return;
    final nextCategories = TransactionCategories.forType(nextType);
    setState(() {
      _selectedType = nextType;
      if (!nextCategories.contains(_selectedCategory)) {
        _selectedCategory = nextCategories.first;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      helpText: 'Pilih Tanggal Transaksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _saveTransaction() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedAmount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (parsedAmount == null || parsedAmount <= 0) {
      return;
    }

    setState(() => _isSaving = true);
    final vm = context.read<TransactionViewModel>();

    final bool ok;
    if (_isEditing) {
      ok = await vm.updateTransaction(
        widget.existingTransaction!.copyWith(
          title: _titleController.text.trim(),
          amount: parsedAmount,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
          createdAt: _selectedDate,
        ),
      );
    } else {
      ok = await vm.addTransaction(
        title: _titleController.text.trim(),
        amount: parsedAmount,
        type: _selectedType,
        category: _selectedCategory,
        note: _noteController.text.trim(),
        createdAt: _selectedDate,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.transactionsError ?? 'Gagal menyimpan transaksi lokal.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existingTransaction;
    if (existing == null) return;

    final colors = context.finoraColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.divider),
        ),
        title: const Text('Hapus transaksi ini?'),
        content: Text(
          'Catatan "${existing.title}" akan dihapus dari penyimpanan lokal perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.expense,
              foregroundColor: colors.surface,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    final ok = await context.read<TransactionViewModel>().deleteTransaction(
      existing.id,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final categories = TransactionCategories.forType(_selectedType);
    final vm = context.watch<TransactionViewModel>();
    final parsedPreview = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final usdPreview =
        (parsedPreview != null && parsedPreview > 0 && vm.exchangeRate != null)
        ? vm.convertIdrToUsd(parsedPreview)
        : null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Transaksi' : 'Catat Transaksi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.divider),
        ),
        actions: [
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Hapus transaksi',
                onPressed: _isSaving ? null : _confirmDelete,
                icon: Icon(Icons.delete_outline, color: colors.expense),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Jenis Transaksi',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _TypeOptionButton(
                              label: 'Pengeluaran',
                              icon: Icons.arrow_upward,
                              selected:
                                  _selectedType == TransactionType.expense,
                              activeColor: colors.expense,
                              activeSurface: colors.expenseSurface,
                              onTap: () =>
                                  _onTypeChanged(TransactionType.expense),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypeOptionButton(
                              label: 'Pemasukan',
                              icon: Icons.arrow_downward,
                              selected: _selectedType == TransactionType.income,
                              activeColor: colors.income,
                              activeSurface: colors.incomeSurface,
                              onTap: () =>
                                  _onTypeChanged(TransactionType.income),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _amountController,
                        autofocus: !_isEditing,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                        decoration: InputDecoration(
                          labelText: 'Nominal (Rupiah)',
                          prefixText: 'Rp ',
                          hintText: '50000',
                          helperText: usdPreview != null
                              ? 'Setara ${FinoraFormatters.formatUsd(usdPreview)} USD (kurs tersimpan)'
                              : 'Masukkan nominal dalam Rupiah tanpa titik/koma',
                        ),
                        validator: (value) {
                          final amount = double.tryParse(
                            (value ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                          );
                          if (amount == null || amount <= 0) {
                            return 'Nominal harus lebih dari Rp 0.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Judul Transaksi',
                          hintText: 'Contoh: Makan siang atau Uang saku',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Judul transaksi wajib diisi.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Kategori',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return _CategoryButton(
                            label: cat,
                            selected: isSelected,
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Tanggal Transaksi',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            FinoraFormatters.formatDateTimeShort(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Tambahan (Opsional)',
                          hintText: 'Detail singkat transaksi jika perlu',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveTransaction,
                              child: Text(
                                _isSaving
                                    ? 'Menyimpan...'
                                    : (_isEditing
                                          ? 'Simpan Perubahan'
                                          : 'Simpan Transaksi'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeOptionButton extends StatelessWidget {
  const _TypeOptionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.activeSurface,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final Color activeSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeSurface : colors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? activeColor : colors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? activeColor : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? activeColor : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Kategori $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.accent : colors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onAccent : colors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
