import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/transaction_viewmodel.dart';
import 'add_transaction_screen.dart';
import 'auth_dialog.dart';

/// Halaman utama buku kas Finora dengan tata letak responsif 3 breakpoint.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _converterController = TextEditingController(
    text: '1',
  );
  bool _convertUsdToIdr = true;

  @override
  void dispose() {
    _searchController.dispose();
    _converterController.dispose();
    super.dispose();
  }

  Future<void> _openAddOrEdit([TransactionModel? existing]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(existingTransaction: existing),
      ),
    );
  }

  Future<void> _openAuthDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const AuthDialog(),
    );
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
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
          'Catatan "${tx.title}" sebesar ${FinoraFormatters.formatIdr(tx.amount)} akan dihapus dari perangkat ini.',
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

    if (confirmed == true && mounted) {
      await context.read<TransactionViewModel>().deleteTransaction(tx.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final txVm = context.watch<TransactionViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 640;
        final isWide = width > 1024;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: _FinoraAppBar(
            authVm: authVm,
            themeVm: themeVm,
            isNarrow: isNarrow,
            onAuthPressed: _openAuthDialog,
          ),
          floatingActionButton: isNarrow
              ? FloatingActionButton.extended(
                  onPressed: () => _openAddOrEdit(),
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  icon: const Icon(Icons.add),
                  label: const Text('Catat Transaksi'),
                )
              : null,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 24,
                16,
                isNarrow ? 16 : 24,
                isNarrow ? 92 : 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide
                        ? 1160
                        : (isNarrow ? double.infinity : 880),
                  ),
                  child: _buildResponsiveContent(
                    txVm: txVm,
                    authVm: authVm,
                    isNarrow: isNarrow,
                    isWide: isWide,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveContent({
    required TransactionViewModel txVm,
    required AuthViewModel authVm,
    required bool isNarrow,
    required bool isWide,
  }) {
    final summaryCard = _BalanceSummaryCard(txVm: txVm);
    final currencyCard = _CurrencyConverterCard(
      txVm: txVm,
      controller: _converterController,
      usdToIdr: _convertUsdToIdr,
      onSwapDirection: () {
        setState(() {
          _convertUsdToIdr = !_convertUsdToIdr;
        });
      },
      onAmountChanged: (_) => setState(() {}),
    );
    final syncCard = _SyncBackupCard(
      txVm: txVm,
      authVm: authVm,
      onOpenAuth: _openAuthDialog,
    );
    final ledgerSection = _TransactionsLedgerSection(
      txVm: txVm,
      searchController: _searchController,
      showAddButton: !isNarrow,
      onAddPressed: () => _openAddOrEdit(),
      onEditTransaction: (tx) => _openAddOrEdit(tx),
      onDeleteTransaction: _confirmDelete,
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summaryCard,
                const SizedBox(height: 16),
                currencyCard,
                const SizedBox(height: 16),
                syncCard,
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: ledgerSection),
        ],
      );
    }

    if (!isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: summaryCard),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    currencyCard,
                    const SizedBox(height: 16),
                    syncCard,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ledgerSection,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryCard,
        const SizedBox(height: 14),
        currencyCard,
        const SizedBox(height: 14),
        syncCard,
        const SizedBox(height: 18),
        ledgerSection,
      ],
    );
  }
}

class _FinoraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FinoraAppBar({
    required this.authVm,
    required this.themeVm,
    required this.isNarrow,
    required this.onAuthPressed,
  });

  final AuthViewModel authVm;
  final ThemeViewModel themeVm;
  final bool isNarrow;
  final VoidCallback onAuthPressed;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final user = authVm.currentUser;

    return AppBar(
      titleSpacing: isNarrow ? 16 : 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Finora',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (!isNarrow) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.divider),
              ),
              child: Text(
                'Stay on Track, Stay in Control',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: colors.divider),
      ),
      actions: [
        IconButton(
          tooltip: themeVm.isDarkMode
              ? 'Ganti ke mode terang'
              : 'Ganti ke mode gelap',
          onPressed: themeVm.toggleTheme,
          icon: Icon(
            themeVm.isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: EdgeInsets.only(right: isNarrow ? 12 : 20),
          child: OutlinedButton.icon(
            onPressed: onAuthPressed,
            icon: Icon(
              user != null
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
              size: 18,
            ),
            label: Text(
              user != null
                  ? (isNarrow ? 'Akun' : _shortenEmail(user.email))
                  : (isNarrow ? 'Masuk' : 'Masuk Akun'),
            ),
          ),
        ),
      ],
    );
  }

  String _shortenEmail(String email) {
    if (email.length <= 18) return email;
    return '${email.substring(0, 15)}...';
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.txVm});

  final TransactionViewModel txVm;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final usdBalance = txVm.totalBalanceInUsd;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo Bersih',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              FinoraFormatters.formatIdr(txVm.totalBalance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usdBalance != null
                ? 'Setara ${FinoraFormatters.formatUsd(usdBalance)} USD'
                : 'Kurs USD belum tersedia',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CashflowColumn(
                  label: 'Pemasukan',
                  amountText: FinoraFormatters.formatIdr(
                    txVm.totalIncome,
                    type: TransactionType.income,
                  ),
                  icon: Icons.arrow_downward,
                  color: colors.income,
                  badgeBg: colors.incomeSurface,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: colors.divider,
              ),
              Expanded(
                child: _CashflowColumn(
                  label: 'Pengeluaran',
                  amountText: FinoraFormatters.formatIdr(
                    txVm.totalExpense,
                    type: TransactionType.expense,
                  ),
                  icon: Icons.arrow_upward,
                  color: colors.expense,
                  badgeBg: colors.expenseSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashflowColumn extends StatelessWidget {
  const _CashflowColumn({
    required this.label,
    required this.amountText,
    required this.icon,
    required this.color,
    required this.badgeBg,
  });

  final String label;
  final String amountText;
  final IconData icon;
  final Color color;
  final Color badgeBg;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amountText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencyConverterCard extends StatelessWidget {
  const _CurrencyConverterCard({
    required this.txVm,
    required this.controller,
    required this.usdToIdr,
    required this.onSwapDirection,
    required this.onAmountChanged,
  });

  final TransactionViewModel txVm;
  final TextEditingController controller;
  final bool usdToIdr;
  final VoidCallback onSwapDirection;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final rate = txVm.exchangeRate;
    final rawInput = double.tryParse(
      controller.text.replaceAll(',', '.').trim(),
    );
    final hasRate = rate != null && rate.usdToIdrRate > 0;
    final convertedText = (hasRate && rawInput != null && rawInput >= 0)
        ? (usdToIdr
              ? FinoraFormatters.formatIdr(txVm.convertUsdToIdr(rawInput))
              : FinoraFormatters.formatUsd(txVm.convertIdrToUsd(rawInput)))
        : '-';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Konversi Kurs USD / IDR',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: txVm.isLoadingRate ? null : txVm.fetchExchangeRate,
                icon: txVm.isLoadingRate
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(txVm.isLoadingRate ? 'Memuat...' : 'Perbarui'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasRate)
            Text(
              '1 USD = ${FinoraFormatters.formatIdr(rate.usdToIdrRate)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Text(
              txVm.isLoadingRate
                  ? 'Mengambil kurs USD/IDR...'
                  : 'Kurs belum tersedia',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          if (hasRate) ...[
            const SizedBox(height: 4),
            Text(
              '${rate.isFromCache ? 'Cache offline' : 'Kurs langsung'} (${FinoraFormatters.formatDateTimeShort(rate.updatedAt)})',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          if (txVm.rateError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.unsyncedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.unsynced),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: colors.unsynced),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txVm.rateError!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.unsynced),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onAmountChanged,
                  decoration: InputDecoration(
                    labelText: usdToIdr ? 'Jumlah (USD)' : 'Jumlah (IDR)',
                    prefixText: usdToIdr ? '\$ ' : 'Rp ',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Tukar arah konversi',
                onPressed: onSwapDirection,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.swap_horiz),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    usdToIdr ? 'Hasil dalam IDR' : 'Hasil dalam USD',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    convertedText,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBackupCard extends StatelessWidget {
  const _SyncBackupCard({
    required this.txVm,
    required this.authVm,
    required this.onOpenAuth,
  });

  final TransactionViewModel txVm;
  final AuthViewModel authVm;
  final VoidCallback onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final pendingCount = txVm.unsyncedCount;
    final hasPending = pendingCount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hasPending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                size: 20,
                color: hasPending ? colors.unsynced : colors.income,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cadangan Cloud Firestore',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? '$pendingCount catatan lokal belum dicadangkan.'
                : 'Seluruh catatan lokal sudah tersinkron.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (!authVm.isAuthenticated) ...[
            const SizedBox(height: 8),
            Text(
              'Masuk akun untuk mencadangkan catatan saat terhubung internet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          if (txVm.syncMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: txVm.syncHasError
                    ? colors.expenseSurface
                    : colors.incomeSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: txVm.syncHasError ? colors.expense : colors.income,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    txVm.syncHasError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: txVm.syncHasError ? colors.expense : colors.income,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txVm.syncMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: txVm.syncHasError
                            ? colors.expense
                            : colors.income,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (authVm.isAuthenticated)
            OutlinedButton.icon(
              onPressed: txVm.isSyncing ? null : txVm.syncPendingTransactions,
              icon: txVm.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                txVm.isSyncing ? 'Menyinkronkan...' : 'Cadangkan Sekarang',
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onOpenAuth,
              icon: const Icon(Icons.login),
              label: const Text('Masuk untuk Sinkronisasi'),
            ),
        ],
      ),
    );
  }
}

class _TransactionsLedgerSection extends StatelessWidget {
  const _TransactionsLedgerSection({
    required this.txVm,
    required this.searchController,
    required this.showAddButton,
    required this.onAddPressed,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final TransactionViewModel txVm;
  final TextEditingController searchController;
  final bool showAddButton;
  final VoidCallback onAddPressed;
  final ValueChanged<TransactionModel> onEditTransaction;
  final ValueChanged<TransactionModel> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan Transaksi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${txVm.filteredTransactions.length} catatan ditampilkan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showAddButton)
                FilledButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Catat Transaksi'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: txVm.setSearchQuery,
            decoration: InputDecoration(
              labelText: 'Cari transaksi',
              hintText: 'Cari judul, kategori, atau catatan',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: txVm.searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Bersihkan pencarian',
                      onPressed: () {
                        searchController.clear();
                        txVm.setSearchQuery('');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterTabButton(
                label: 'Semua',
                selected: txVm.filterType == TransactionFilterType.all,
                onTap: () => txVm.setFilterType(TransactionFilterType.all),
              ),
              _FilterTabButton(
                label: 'Pemasukan',
                selected: txVm.filterType == TransactionFilterType.income,
                onTap: () => txVm.setFilterType(TransactionFilterType.income),
              ),
              _FilterTabButton(
                label: 'Pengeluaran',
                selected: txVm.filterType == TransactionFilterType.expense,
                onTap: () => txVm.setFilterType(TransactionFilterType.expense),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 12),
          _buildStateContent(context, colors),
        ],
      ),
    );
  }

  Widget _buildStateContent(BuildContext context, FinoraColors colors) {
    if (txVm.isLoadingTransactions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Memuat catatan transaksi...'),
          ],
        ),
      );
    }

    if (txVm.transactionsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 32, color: colors.expense),
            const SizedBox(height: 10),
            Text(
              txVm.transactionsError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.expense),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: txVm.fetchTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (txVm.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi tercatat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan pemasukan atau pengeluaran pertama Anda. Catatan tersimpan lokal meski tanpa internet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Catat Transaksi'),
            ),
          ],
        ),
      );
    }

    final items = txVm.filteredTransactions;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 34, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Tidak ada transaksi yang cocok dengan filter ini.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                searchController.clear();
                txVm.clearFilters();
              },
              child: const Text('Reset Filter'),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<TransactionModel>>{};
    for (final tx in items) {
      final header = FinoraFormatters.formatDateHeader(tx.createdAt);
      grouped.putIfAbsent(header, () => []).add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...entry.value.asMap().entries.map((rowEntry) {
              final tx = rowEntry.value;
              final isLastInGroup = rowEntry.key == entry.value.length - 1;
              return Column(
                children: [
                  _TransactionRow(
                    transaction: tx,
                    onTap: () => onEditTransaction(tx),
                    onDelete: () => onDeleteTransaction(tx),
                  ),
                  if (!isLastInGroup) Divider(height: 1, color: colors.divider),
                ],
              );
            }),
            const SizedBox(height: 6),
          ],
        );
      }).toList(),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  const _FilterTabButton({
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
      label: 'Filter $label',
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
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? colors.income : colors.expense;
    final badgeBg = isIncome ? colors.incomeSurface : colors.expenseSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon(transaction.category, transaction.type),
                size: 20,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${transaction.category} • ${FinoraFormatters.formatTime(transaction.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      _SyncStatusBadge(isSynced: transaction.isSynced),
                    ],
                  ),
                  if (transaction.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FinoraFormatters.formatIdr(
                    transaction.amount,
                    type: transaction.type,
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Hapus transaksi',
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category, TransactionType type) {
    return switch (category) {
      'Gaji' ||
      'Uang Saku' ||
      'Bonus' ||
      'Freelance' => Icons.account_balance_wallet_outlined,
      'Makan & Minum' => Icons.restaurant_outlined,
      'Transportasi' => Icons.directions_bus_outlined,
      'Belanja' => Icons.shopping_bag_outlined,
      'Tagihan' => Icons.receipt_outlined,
      'Pendidikan' => Icons.school_outlined,
      'Hiburan' => Icons.movie_outlined,
      'Kesehatan' => Icons.medical_services_outlined,
      _ =>
        type == TransactionType.income
            ? Icons.arrow_downward
            : Icons.arrow_upward,
    };
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.isSynced});

  final bool isSynced;

  @override
  Widget build(BuildContext context) {
    final colors = context.finoraColors;
    final fg = isSynced ? colors.income : colors.unsynced;
    final bg = isSynced ? colors.incomeSurface : colors.unsyncedSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done_outlined : Icons.schedule,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            isSynced ? 'Tersinkron' : 'Menunggu sync',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
