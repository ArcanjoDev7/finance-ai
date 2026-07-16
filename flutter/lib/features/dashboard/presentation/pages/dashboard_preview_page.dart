// ignore_for_file: deprecated_member_use, use_null_aware_elements

import 'package:finance_ai/app/constants/app_breakpoints.dart';
import 'package:finance_ai/app/theme/app_theme.dart';
import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/chat_ai/presentation/chat_page.dart';
import 'package:flutter/material.dart';

enum FinancePage {
  dashboard,
  transactions,
  investments,
  crypto,
  cards,
  goals,
  reports,
  assistant,
  settings,
}

enum EntryKind { income, expense }

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.kind,
    required this.date,
    this.isCard = false,
  });
  final String id;
  final String description;
  final String category;
  final double amount;
  final EntryKind kind;
  final DateTime date;
  final bool isCard;
}

class InvestmentItem {
  const InvestmentItem({
    required this.name,
    required this.institution,
    required this.type,
    required this.amount,
    required this.yieldDescription,
  });
  final String name;
  final String institution;
  final String type;
  final double amount;
  final String yieldDescription;
}

class CryptoItem {
  const CryptoItem({
    required this.asset,
    required this.amount,
    required this.operation,
  });
  final String asset;
  final double amount;
  final String operation;
}

class DashboardPreviewPage extends StatefulWidget {
  const DashboardPreviewPage({super.key});
  @override
  State<DashboardPreviewPage> createState() => _DashboardPreviewPageState();
}

class _DashboardPreviewPageState extends State<DashboardPreviewPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hideValues = false;
  bool _sidebarCollapsed = false;
  FinancePage _page = FinancePage.dashboard;
  String _profileName = 'Minha conta';
  final List<FinanceEntry> _entries = [];
  final List<InvestmentItem> _investments = [];
  final List<CryptoItem> _cryptos = [];

  @override
  void initState() {
    super.initState();
    _restoreDashboard();
    _restoreProfile();
  }

  String get _profileInitials {
    final words = _profileName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'FA';
    if (words.length == 1) {
      final end = words.first.length < 2 ? words.first.length : 2;
      return words.first.substring(0, end).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  Future<void> _restoreProfile() async {
    final client = SupabaseWebClient.instance;
    final cachedName = await client.loadCachedProfileName();
    if (cachedName != null && cachedName.isNotEmpty && mounted) {
      setState(() => _profileName = cachedName);
    }
    final token = await client.restoredSession();
    if (token == null) return;
    try {
      final syncedName = await client.loadProfileName(token);
      if (syncedName != null && syncedName.isNotEmpty && mounted) {
        setState(() => _profileName = syncedName);
      }
    } catch (_) {
      // The cached name remains available when the profile request is offline.
    }
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: _profileName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome exibido',
            hintText: 'Ex.: Miguel Arcanjo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = name?.trim() ?? '';
    if (normalized.isEmpty || !mounted) return;
    try {
      await SupabaseWebClient.instance.saveProfileName(
        normalized,
        token: await SupabaseWebClient.instance.restoredSession(),
      );
      if (mounted) setState(() => _profileName = normalized);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _profileName = normalized);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O nome foi salvo neste navegador e será sincronizado ao reconectar.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _restoreDashboard() async {
    final cached = await SupabaseWebClient.instance.loadLocalDashboard();
    if (cached != null && mounted) _applyLocalDashboard(cached);
    final token = await SupabaseWebClient.instance.restoredSession();
    if (token == null) return;
    try {
      final rows = await SupabaseWebClient.instance.loadTimeline(token);
      if (!mounted) return;
      final entries = <FinanceEntry>[];
      final investments = <InvestmentItem>[];
      final cryptos = <CryptoItem>[];
      for (final row in rows) {
        final amount = ((row['amount_minor'] as num?)?.toDouble() ?? 0) / 100;
        final type = row['transaction_type'] as String? ?? '';
        final metadata = row['metadata'] is Map
            ? Map<String, dynamic>.from(row['metadata'] as Map)
            : const <String, dynamic>{};
        final description = row['description'] as String? ?? '';
        final date =
            DateTime.tryParse(row['occurred_at'] as String? ?? '') ??
            DateTime.now();
        if (type == 'expense' || type == 'income' || type == 'refund') {
          entries.add(
            FinanceEntry(
              id: '${row['id']}',
              description: description,
              category:
                  '${metadata['category'] ?? (type == 'expense' ? 'Outros' : 'Receitas')}',
              amount: amount,
              kind: type == 'expense' ? EntryKind.expense : EntryKind.income,
              date: date,
              isCard: '${metadata['account'] ?? ''}'.toLowerCase().contains(
                'cart',
              ),
            ),
          );
        }
        if (type == 'investment') {
          investments.add(
            InvestmentItem(
              name: '${metadata['investment'] ?? description}',
              institution: 'Carteira principal',
              type: 'Renda fixa',
              amount: amount,
              yieldDescription: 'Sincronizado',
            ),
          );
        }
        if (type == 'crypto_buy' || type == 'crypto_sell') {
          cryptos.add(
            CryptoItem(
              asset: '${metadata['investment'] ?? description}',
              amount: amount,
              operation: type == 'crypto_sell' ? 'Venda' : 'Compra',
            ),
          );
        }
      }
      if (rows.isNotEmpty) {
        setState(() {
          _entries
            ..clear()
            ..addAll(entries);
          _investments
            ..clear()
            ..addAll(investments);
          _cryptos
            ..clear()
            ..addAll(cryptos);
        });
      }
    } catch (_) {
      // The locally cached state remains available while an offline request fails.
    }
  }

  void _applyLocalDashboard(Map<String, dynamic> data) {
    List<Map<String, dynamic>> list(String key) =>
        (data[key] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    setState(() {
      _entries
        ..clear()
        ..addAll(
          list('entries').map(
            (item) => FinanceEntry(
              id: '${item['id']}',
              description: '${item['description']}',
              category: '${item['category']}',
              amount: (item['amount'] as num).toDouble(),
              kind: item['kind'] == 'income'
                  ? EntryKind.income
                  : EntryKind.expense,
              date: DateTime.parse(item['date'] as String),
              isCard: item['isCard'] == true,
            ),
          ),
        );
      _investments
        ..clear()
        ..addAll(
          list('investments').map(
            (item) => InvestmentItem(
              name: '${item['name']}',
              institution: '${item['institution']}',
              type: '${item['type']}',
              amount: (item['amount'] as num).toDouble(),
              yieldDescription: '${item['yieldDescription']}',
            ),
          ),
        );
      _cryptos
        ..clear()
        ..addAll(
          list('cryptos').map(
            (item) => CryptoItem(
              asset: '${item['asset']}',
              amount: (item['amount'] as num).toDouble(),
              operation: '${item['operation']}',
            ),
          ),
        );
    });
  }

  Future<void> _persistLocalDashboard() =>
      SupabaseWebClient.instance.saveLocalDashboard({
        'entries': _entries
            .map(
              (item) => {
                'id': item.id,
                'description': item.description,
                'category': item.category,
                'amount': item.amount,
                'kind': item.kind.name,
                'date': item.date.toIso8601String(),
                'isCard': item.isCard,
              },
            )
            .toList(),
        'investments': _investments
            .map(
              (item) => {
                'name': item.name,
                'institution': item.institution,
                'type': item.type,
                'amount': item.amount,
                'yieldDescription': item.yieldDescription,
              },
            )
            .toList(),
        'cryptos': _cryptos
            .map(
              (item) => {
                'asset': item.asset,
                'amount': item.amount,
                'operation': item.operation,
              },
            )
            .toList(),
      });

  void _go(FinancePage page) => setState(() => _page = page);
  void _addEntry(FinanceEntry entry) {
    setState(() => _entries.insert(0, entry));
    _persistLocalDashboard();
  }

  void _addInvestment(InvestmentItem item) {
    setState(() => _investments.insert(0, item));
    _persistLocalDashboard();
  }

  void _addCrypto(CryptoItem item) {
    setState(() => _cryptos.insert(0, item));
    _persistLocalDashboard();
  }

  Future<void> _showEntryForm({
    EntryKind kind = EntryKind.expense,
    bool isCard = false,
  }) async {
    final entry = await showModalBottomSheet<FinanceEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntryForm(initialKind: kind),
    );
    if (entry == null || !mounted) return;
    _addEntry(
      FinanceEntry(
        id: entry.id,
        description: entry.description,
        category: entry.category,
        amount: entry.amount,
        kind: entry.kind,
        date: entry.date,
        isCard: isCard,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kind == EntryKind.expense
              ? 'Despesa adicionada'
              : 'Receita adicionada',
        ),
      ),
    );
  }

  Future<void> _showInvestmentForm() async {
    final item = await showModalBottomSheet<InvestmentItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InvestmentForm(),
    );
    if (item == null || !mounted) return;
    _addInvestment(item);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Investimento adicionado')));
  }

  Future<void> _showCryptoForm() async {
    final item = await showModalBottomSheet<CryptoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CryptoForm(),
    );
    if (item == null || !mounted) return;
    _addCrypto(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Operação de cripto adicionada')),
    );
  }

  String _idempotencyKey() {
    final raw = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '00000000-0000-4000-8000-${raw.substring(raw.length - 12).padLeft(12, '0')}';
  }

  Future<void> _confirmAccountReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24)),
        title: const Text('Zerar valores da conta?'),
        content: const Text(
          'A confirmação para zerar é necessária porque essa ação apaga a visão financeira da conta; comandos comuns continuam sem confirmação. Seus lançamentos ficam preservados apenas para auditoria e recuperação assistida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar e zerar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await SupabaseWebClient.instance.restoredSession();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sua sessão expirou. Abra o Assistente IA e entre novamente antes de zerar a conta.',
              ),
            ),
          );
        }
        return;
      }
      await SupabaseWebClient.instance.resetAccount(token, _idempotencyKey());
      await SupabaseWebClient.instance.clearLocalDashboard();
      if (!mounted) return;
      setState(() {
        _entries.clear();
        _investments.clear();
        _cryptos.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Os valores da conta foram zerados.')),
      );
    } on AiRequestException catch (error) {
      if (error.code == 'UNAUTHORIZED') {
        await SupabaseWebClient.instance.signOut();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'UNAUTHORIZED'
                  ? 'Sua sessão expirou. Abra o Assistente IA e entre novamente.'
                  : 'Não foi possível zerar a conta (${error.code}).',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final content = switch (_page) {
      FinancePage.dashboard => _DashboardContent(
        entries: _entries,
        investments: _investments,
        hideValues: _hideValues,
        onNavigate: _go,
        onAddEntry: _showEntryForm,
        onAddInvestment: _showInvestmentForm,
      ),
      FinancePage.transactions => _TransactionsPage(
        entries: _entries,
        hideValues: _hideValues,
        onAdd: _showEntryForm,
      ),
      FinancePage.investments => _InvestmentsPage(
        items: _investments,
        hideValues: _hideValues,
        onAdd: _showInvestmentForm,
      ),
      FinancePage.crypto => _CryptoPage(
        items: _cryptos,
        hideValues: _hideValues,
        onAdd: _showCryptoForm,
      ),
      FinancePage.goals => _GoalsPage(
        items: _investments,
        hideValues: _hideValues,
      ),
      FinancePage.cards => _CardsPage(
        entries: _entries,
        hideValues: _hideValues,
        onAdd: _showEntryForm,
      ),
      FinancePage.reports => _ReportsPage(
        entries: _entries,
        hideValues: _hideValues,
      ),
      FinancePage.assistant => ChatPage(
        onTransactionCreated: _addEntry,
        onInvestmentCreated: _addInvestment,
        onCryptoCreated: _addCrypto,
        onAccountReset: _confirmAccountReset,
      ),
      FinancePage.settings => _SettingsPage(
        hideValues: _hideValues,
        sidebarCollapsed: _sidebarCollapsed,
        profileName: _profileName,
        profileInitials: _profileInitials,
        onTogglePrivacy: () => setState(() => _hideValues = !_hideValues),
        onToggleSidebar: () =>
            setState(() => _sidebarCollapsed = !_sidebarCollapsed),
        onResetAccount: _confirmAccountReset,
        onOpenAssistant: () => _go(FinancePage.assistant),
        onEditProfile: _editProfile,
      ),
    };
    return Scaffold(
      key: _scaffoldKey,
      drawer: desktop
          ? null
          : Drawer(
              child: _SideNavigation(
                selected: _page,
                collapsed: false,
                onSelected: (page) {
                  Navigator.pop(context);
                  _go(page);
                },
                onToggle: () {},
              ),
            ),
      appBar: _TopBar(
        page: _page,
        hideValues: _hideValues,
        profileInitials: _profileInitials,
        onTogglePrivacy: () => setState(() => _hideValues = !_hideValues),
        onMenu: desktop ? null : () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: Row(
        children: [
          if (desktop)
            _SideNavigation(
              selected: _page,
              collapsed: _sidebarCollapsed,
              onSelected: _go,
              onToggle: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.galaxyStart, AppColors.galaxyEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_page != FinancePage.assistant)
            FloatingActionButton.small(
              heroTag: 'assistant-fab',
              onPressed: () => _go(FinancePage.assistant),
              tooltip: 'Abrir Assistente IA',
              child: const Icon(Icons.auto_awesome),
            ),
          if (!desktop && _page != FinancePage.assistant)
            const SizedBox(height: 12),
          if (!desktop && _page != FinancePage.assistant)
            FloatingActionButton.extended(
              heroTag: 'entry-fab',
              onPressed: _showEntryForm,
              icon: const Icon(Icons.add),
              label: const Text('Movimentação'),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.page,
    required this.hideValues,
    required this.profileInitials,
    required this.onTogglePrivacy,
    this.onMenu,
  });
  final FinancePage page;
  final bool hideValues;
  final String profileInitials;
  final VoidCallback onTogglePrivacy;
  final VoidCallback? onMenu;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    leading: onMenu == null
        ? null
        : IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: onMenu,
          ),
    title: Text(_pageTitle(page)),
    actions: [
      if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded)
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar movimentações',
            ),
          ),
        ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Notificações',
        icon: const Badge(
          smallSize: 7,
          child: Icon(Icons.notifications_none_rounded),
        ),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você está em dia. Sem novas notificações.'),
          ),
        ),
      ),
      IconButton(
        tooltip: hideValues ? 'Mostrar valores' : 'Ocultar valores',
        icon: Icon(
          hideValues
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        onPressed: onTogglePrivacy,
      ),
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: CircleAvatar(radius: 17, child: Text(profileInitials)),
      ),
    ],
  );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selected,
    required this.collapsed,
    required this.onSelected,
    required this.onToggle,
  });
  final FinancePage selected;
  final bool collapsed;
  final ValueChanged<FinancePage> onSelected;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    const primary = [
      (FinancePage.dashboard, Icons.grid_view_rounded, 'Dashboard'),
      (FinancePage.transactions, Icons.receipt_long_outlined, 'Movimentações'),
      (FinancePage.investments, Icons.show_chart_rounded, 'Investimentos'),
      (FinancePage.crypto, Icons.currency_bitcoin, 'Criptomoedas'),
      (FinancePage.cards, Icons.credit_card_outlined, 'Cartões'),
      (FinancePage.goals, Icons.flag_outlined, 'Metas'),
      (FinancePage.reports, Icons.insights_outlined, 'Relatórios'),
      (FinancePage.assistant, Icons.auto_awesome_outlined, 'Assistente IA'),
    ];
    return AnimatedContainer(
      duration: AppAnimations.standard,
      width: collapsed ? 78 : 248,
      color: const Color(0xFF17141F),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 12, 16),
            child: Row(
              children: [
                const Icon(Icons.auto_graph_rounded, color: AppColors.brand),
                if (!collapsed) const SizedBox(width: 10),
                if (!collapsed)
                  const Expanded(
                    child: Text(
                      'Finance AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onToggle,
                  tooltip: collapsed ? 'Expandir menu' : 'Recolher menu',
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in primary)
                  _NavItem(
                    page: item.$1,
                    icon: item.$2,
                    label: item.$3,
                    selected: selected == item.$1,
                    collapsed: collapsed,
                    onTap: () => onSelected(item.$1),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _NavItem(
              page: FinancePage.settings,
              icon: Icons.settings_outlined,
              label: 'Configurações',
              selected: selected == FinancePage.settings,
              collapsed: collapsed,
              onTap: () => onSelected(FinancePage.settings),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });
  final FinancePage page;
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: collapsed ? label : '',
    child: Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xFF4C465B) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 17 : 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(icon, size: 21),
                if (!collapsed) const SizedBox(width: 14),
                if (!collapsed)
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.entries,
    required this.investments,
    required this.hideValues,
    required this.onNavigate,
    required this.onAddEntry,
    required this.onAddInvestment,
  });
  final List<FinanceEntry> entries;
  final List<InvestmentItem> investments;
  final bool hideValues;
  final ValueChanged<FinancePage> onNavigate;
  final Future<void> Function({EntryKind kind}) onAddEntry;
  final Future<void> Function() onAddInvestment;
  @override
  Widget build(BuildContext context) {
    final income = entries
        .where((item) => item.kind == EntryKind.income)
        .fold(0.0, (sum, item) => sum + item.amount);
    final expense = entries
        .where((item) => item.kind == EntryKind.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
    final investmentsTotal = investments.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const _PageHeader(
          title: 'Visão geral',
          subtitle: 'Controle suas decisões financeiras em um só lugar.',
        ),
        const SizedBox(height: 24),
        _HeroCard(
          value: income - expense + investmentsTotal,
          hideValues: hideValues,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: columns == 1 ? 3.8 : 2.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _MetricCard(
                  label: 'Saldo disponível',
                  icon: Icons.account_balance_wallet_outlined,
                  value: income - expense,
                  color: AppColors.brand,
                  hideValues: hideValues,
                ),
                _MetricCard(
                  label: 'Resultado do mês',
                  icon: Icons.trending_up_rounded,
                  value: income - expense,
                  color: income >= expense
                      ? AppColors.positive
                      : AppColors.negative,
                  hideValues: hideValues,
                ),
                _MetricCard(
                  label: 'Investido',
                  icon: Icons.pie_chart_outline_rounded,
                  value: investmentsTotal,
                  color: const Color(0xFF60A5FA),
                  hideValues: hideValues,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        _Panel(
          title: 'Visão do período',
          action: TextButton(
            onPressed: () => onNavigate(FinancePage.reports),
            child: const Text('Relatório completo'),
          ),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 860
                ? Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _CashflowChart(income: income, expense: expense),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _AllocationSummary(
                          investments: investmentsTotal,
                          available: income - expense,
                          hideValues: hideValues,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _CashflowChart(income: income, expense: expense),
                      const SizedBox(height: 24),
                      _AllocationSummary(
                        investments: investmentsTotal,
                        available: income - expense,
                        hideValues: hideValues,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Comece por aqui',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => onAddEntry(kind: EntryKind.expense),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Adicionar despesa'),
              ),
              OutlinedButton.icon(
                onPressed: () => onAddEntry(kind: EntryKind.income),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Adicionar receita'),
              ),
              OutlinedButton.icon(
                onPressed: onAddInvestment,
                icon: const Icon(Icons.show_chart_rounded),
                label: const Text('Adicionar investimento'),
              ),
              FilledButton.icon(
                onPressed: () => onNavigate(FinancePage.assistant),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Usar assistente IA'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Últimas movimentações',
          action: TextButton(
            onPressed: () => onNavigate(FinancePage.transactions),
            child: const Text('Ver todas'),
          ),
          child: entries.isEmpty
              ? const _HelpfulEmpty(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sua linha do tempo começa aqui',
                  text:
                      'Registre uma receita ou despesa para visualizar seu resumo mensal.',
                )
              : Column(
                  children: entries
                      .take(5)
                      .map(
                        (entry) =>
                            _EntryRow(entry: entry, hideValues: hideValues),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({
    required this.entries,
    required this.hideValues,
    required this.onAdd,
  });
  final List<FinanceEntry> entries;
  final bool hideValues;
  final Future<void> Function({EntryKind kind}) onAdd;
  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  String _query = '';
  EntryKind? _filter;
  @override
  Widget build(BuildContext context) {
    final items = widget.entries
        .where(
          (entry) =>
              (_filter == null || entry.kind == _filter) &&
              ('${entry.description} ${entry.category}').toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Movimentações',
          subtitle: 'Receitas e despesas em uma única linha do tempo.',
          action: FilledButton.icon(
            onPressed: () => widget.onAdd(kind: EntryKind.expense),
            icon: const Icon(Icons.add),
            label: const Text('Nova movimentação'),
          ),
        ),
        const SizedBox(height: 22),
        _Panel(
          title: 'Filtros',
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 290,
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar descrição ou categoria',
                  ),
                ),
              ),
              ChoiceChip(
                label: const Text('Todas'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              ChoiceChip(
                label: const Text('Receitas'),
                selected: _filter == EntryKind.income,
                onSelected: (_) => setState(() => _filter = EntryKind.income),
              ),
              ChoiceChip(
                label: const Text('Despesas'),
                selected: _filter == EntryKind.expense,
                onSelected: (_) => setState(() => _filter = EntryKind.expense),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: '${items.length} movimentação(ões)',
          child: items.isEmpty
              ? _HelpfulEmpty(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nada por aqui ainda',
                  text: 'Ajuste seus filtros ou adicione uma movimentação.',
                  action: FilledButton(
                    onPressed: () => widget.onAdd(kind: EntryKind.expense),
                    child: const Text('Adicionar despesa'),
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (entry) => _EntryRow(
                          entry: entry,
                          hideValues: widget.hideValues,
                          detailed: true,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _InvestmentsPage extends StatelessWidget {
  const _InvestmentsPage({
    required this.items,
    required this.hideValues,
    required this.onAdd,
  });
  final List<InvestmentItem> items;
  final bool hideValues;
  final Future<void> Function() onAdd;
  @override
  Widget build(BuildContext context) {
    final total = items.fold(0.0, (sum, item) => sum + item.amount);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Investimentos',
          subtitle: 'Acompanhe patrimônio, renda fixa e evolução.',
          action: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar investimento'),
          ),
        ),
        const SizedBox(height: 22),
        _HeroCard(
          value: total,
          hideValues: hideValues,
          label: 'Total investido',
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Sua carteira',
          child: items.isEmpty
              ? _HelpfulEmpty(
                  icon: Icons.show_chart_rounded,
                  title: 'Comece sua carteira',
                  text:
                      'Adicione um CDB, ação, ETF ou outro investimento para acompanhar o patrimônio.',
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar investimento'),
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF173C6B),
                            child: const Icon(Icons.show_chart_rounded),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.type} · ${item.institution} · ${item.yieldDescription}',
                          ),
                          trailing: _FinancialValue(
                            value: item.amount,
                            hidden: hideValues,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _CryptoPage extends StatelessWidget {
  const _CryptoPage({
    required this.items,
    required this.hideValues,
    required this.onAdd,
  });
  final List<CryptoItem> items;
  final bool hideValues;
  final Future<void> Function() onAdd;
  @override
  Widget build(BuildContext context) {
    final total = items.fold(
      0.0,
      (sum, item) =>
          sum + (item.operation == 'Venda' ? -item.amount : item.amount),
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Criptomoedas',
          subtitle:
              'Registre compras, vendas e conversões com o assistente ou manualmente.',
          action: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Nova operação'),
          ),
        ),
        const SizedBox(height: 22),
        _HeroCard(
          value: total,
          hideValues: hideValues,
          label: 'Alocado em cripto',
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Operações recentes',
          child: items.isEmpty
              ? _HelpfulEmpty(
                  icon: Icons.currency_bitcoin,
                  title: 'Sua carteira cripto está vazia',
                  text:
                      'Diga “comprei 5.000 reais de Bitcoin” ao assistente ou registre uma operação.',
                  action: FilledButton(
                    onPressed: onAdd,
                    child: const Text('Adicionar operação'),
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5A3D12),
                            child: const Icon(Icons.currency_bitcoin),
                          ),
                          title: Text(item.asset),
                          subtitle: Text(item.operation),
                          trailing: _FinancialValue(
                            value: item.amount,
                            hidden: hideValues,
                            negative: item.operation == 'Venda',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _GoalsPage extends StatelessWidget {
  const _GoalsPage({required this.items, required this.hideValues});
  final List<InvestmentItem> items;
  final bool hideValues;
  @override
  Widget build(BuildContext context) {
    final fixed = items
        .where(
          (item) => const ['CDB', 'LCI', 'LCA', 'Tesouro'].contains(item.type),
        )
        .toList();
    final total = fixed.fold(0.0, (sum, item) => sum + item.amount);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Metas',
          subtitle: 'Acompanhe somente sua reserva e renda fixa.',
        ),
        const SizedBox(height: 22),
        _Panel(
          title: 'Progresso da renda fixa',
          child: fixed.isEmpty
              ? const _HelpfulEmpty(
                  icon: Icons.flag_outlined,
                  title: 'Nenhuma meta de renda fixa ainda',
                  text:
                      'CDB, LCI, LCA e Tesouro aparecem aqui. Ações e criptomoedas ficam fora desta visão.',
                )
              : Center(
                  child: SizedBox(
                    width: 230,
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 0.72,
                          strokeWidth: 18,
                          backgroundColor: const Color(0xFF342E3D),
                          color: AppColors.brand,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Renda fixa'),
                            _FinancialValue(
                              value: total,
                              hidden: hideValues,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Composição',
          child: fixed.isEmpty
              ? const Text(
                  'Adicione um investimento de renda fixa para iniciar.',
                )
              : Column(
                  children: fixed
                      .map(
                        (item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.type),
                          trailing: _FinancialValue(
                            value: item.amount,
                            hidden: hideValues,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _CardsPage extends StatelessWidget {
  const _CardsPage({
    required this.entries,
    required this.hideValues,
    required this.onAdd,
  });
  final List<FinanceEntry> entries;
  final bool hideValues;
  final Future<void> Function({EntryKind kind, bool isCard}) onAdd;
  @override
  Widget build(BuildContext context) {
    final cardEntries = entries
        .where((item) => item.kind == EntryKind.expense && item.isCard)
        .toList();
    final invoice = cardEntries.fold(0.0, (sum, item) => sum + item.amount);
    const limit = 5000.0;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Cartões',
          subtitle: 'Somente despesas informadas como cartão entram na fatura.',
          action: FilledButton.icon(
            onPressed: () => onAdd(kind: EntryKind.expense, isCard: true),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar lançamento'),
          ),
        ),
        const SizedBox(height: 22),
        _Panel(
          title: 'Fatura atual',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinancialValue(
                value: invoice,
                hidden: hideValues,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (invoice / limit).clamp(0.0, 1.0)),
              const SizedBox(height: 8),
              const Text(
                'Limite de referência: R\$ 5.000,00',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Lançamentos',
          child: cardEntries.isEmpty
              ? _HelpfulEmpty(
                  icon: Icons.credit_card_outlined,
                  title: 'Nenhum lançamento na fatura',
                  text:
                      'Diga “paguei R\$ 50 no cartão” ou adicione uma despesa nesta tela.',
                  action: FilledButton(
                    onPressed: () =>
                        onAdd(kind: EntryKind.expense, isCard: true),
                    child: const Text('Adicionar despesa'),
                  ),
                )
              : Column(
                  children: cardEntries
                      .map(
                        (item) =>
                            _EntryRow(entry: item, hideValues: hideValues),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage({required this.entries, required this.hideValues});
  final List<FinanceEntry> entries;
  final bool hideValues;
  @override
  Widget build(BuildContext context) {
    final income = entries
        .where((item) => item.kind == EntryKind.income)
        .fold(0.0, (sum, item) => sum + item.amount);
    final expense = entries
        .where((item) => item.kind == EntryKind.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _PageHeader(
          title: 'Relatórios',
          subtitle: 'Resumo financeiro do período atual.',
        ),
        const SizedBox(height: 22),
        _Panel(
          title: 'Fluxo mensal',
          child: entries.isEmpty
              ? const _HelpfulEmpty(
                  icon: Icons.insights_outlined,
                  title: 'Ainda não há dados suficientes',
                  text:
                      'Adicione receitas ou despesas para gerar seus relatórios.',
                )
              : Column(
                  children: [
                    _ReportRow(
                      label: 'Receitas',
                      value: income,
                      hideValues: hideValues,
                      color: AppColors.positive,
                    ),
                    _ReportRow(
                      label: 'Despesas',
                      value: expense,
                      hideValues: hideValues,
                      color: AppColors.negative,
                    ),
                    const Divider(),
                    _ReportRow(
                      label: 'Resultado',
                      value: income - expense,
                      hideValues: hideValues,
                      color: AppColors.brand,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.hideValues,
    required this.sidebarCollapsed,
    required this.profileName,
    required this.profileInitials,
    required this.onTogglePrivacy,
    required this.onToggleSidebar,
    required this.onResetAccount,
    required this.onOpenAssistant,
    required this.onEditProfile,
  });
  final bool hideValues;
  final bool sidebarCollapsed;
  final String profileName;
  final String profileInitials;
  final VoidCallback onTogglePrivacy;
  final VoidCallback onToggleSidebar;
  final Future<void> Function() onResetAccount;
  final VoidCallback onOpenAssistant;
  final Future<void> Function() onEditProfile;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const _PageHeader(
        title: 'Configurações',
        subtitle: 'Privacidade, experiência e dados da sua conta.',
      ),
      const SizedBox(height: 22),
      _Panel(
        title: 'Perfil',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(profileInitials)),
          title: Text(profileName),
          subtitle: const Text('Nome exibido no avatar e em sua conta.'),
          trailing: OutlinedButton(
            onPressed: onEditProfile,
            child: const Text('Editar'),
          ),
        ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: 'Privacidade e aparência',
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text('Ocultar valores financeiros'),
              subtitle: const Text(
                'Esconde saldos e valores em todas as telas.',
              ),
              value: hideValues,
              onChanged: (_) => onTogglePrivacy(),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.vertical_split_outlined),
              title: const Text('Menu compacto'),
              subtitle: const Text('Reduz a barra lateral em telas grandes.'),
              value: sidebarCollapsed,
              onChanged: (_) => onToggleSidebar(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: 'Assistente Financeiro',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
          title: const Text('Assistente sempre disponível'),
          subtitle: const Text(
            'Use a bolha fixa para registrar movimentações por linguagem natural.',
          ),
          trailing: OutlinedButton(
            onPressed: onOpenAssistant,
            child: const Text('Abrir IA'),
          ),
        ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: 'Dados da conta',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF5A2933),
            child: Icon(Icons.delete_outline_rounded),
          ),
          title: const Text('Zerar valores da conta'),
          subtitle: const Text(
            'Remove todos os valores ativos do saldo, relatórios, investimentos e fatura. A confirmação é obrigatória.',
          ),
          trailing: FilledButton.tonal(
            onPressed: onResetAccount,
            child: const Text('Zerar conta'),
          ),
        ),
      ),
    ],
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    required this.hideValues,
    required this.color,
  });
  final String label;
  final double value;
  final bool hideValues;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 130,
          child: LinearProgressIndicator(
            value: value <= 0 ? 0 : (value / 10000).clamp(0.0, 1.0),
            color: color,
            backgroundColor: const Color(0xFF342E3D),
          ),
        ),
        const SizedBox(width: 16),
        _FinancialValue(
          value: value,
          hidden: hideValues,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _CashflowChart extends StatelessWidget {
  const _CashflowChart({required this.income, required this.expense});
  final double income;
  final double expense;
  @override
  Widget build(BuildContext context) {
    final max = [income, expense, 1.0].reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entradas e saídas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ChartBar(
                  label: 'Receitas',
                  value: income,
                  height: income / max,
                  color: AppColors.positive,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ChartBar(
                  label: 'Despesas',
                  value: expense,
                  height: expense / max,
                  color: AppColors.negative,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ChartBar(
                  label: 'Resultado',
                  value: income - expense,
                  height: (income - expense).abs() / max,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.label,
    required this.value,
    required this.height,
    required this.color,
  });
  final String label;
  final double value;
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Tooltip(
            message: 'R\$ ${value.toStringAsFixed(2)}',
            child: AnimatedContainer(
              duration: AppAnimations.standard,
              width: 48,
              height: (118 * height.clamp(0.06, 1.0)).toDouble(),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.investments,
    required this.available,
    required this.hideValues,
  });
  final double investments;
  final double available;
  final bool hideValues;
  @override
  Widget build(BuildContext context) {
    final total = investments + available;
    final ratio = total <= 0 ? 0.0 : investments / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribuição',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 9,
                    color: AppColors.info,
                    backgroundColor: AppColors.border,
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AllocationLine(
                    label: 'Disponível',
                    value: available,
                    hidden: hideValues,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 9),
                  _AllocationLine(
                    label: 'Investimentos',
                    value: investments,
                    hidden: hideValues,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AllocationLine extends StatelessWidget {
  const _AllocationLine({
    required this.label,
    required this.value,
    required this.hidden,
    required this.color,
  });
  final String label;
  final double value;
  final bool hidden;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
      _FinancialValue(
        value: value,
        hidden: hidden,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
      if (action != null) action!,
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xCC1B1722),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.value,
    required this.hideValues,
    this.label = 'Patrimônio total',
  });
  final double value;
  final bool hideValues;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF41247D), Color(0xFF112E63)],
      ),
      boxShadow: AppShadows.card,
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 20,
      runSpacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            _FinancialValue(
              value: value,
              hidden: hideValues,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Atualizado agora · período atual',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
    required this.hideValues,
  });
  final String label;
  final IconData icon;
  final double value;
  final Color color;
  final bool hideValues;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xD91B1722),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(label, style: const TextStyle(color: Colors.white70)),
          _FinancialValue(
            value: value,
            hidden: hideValues,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.hideValues,
    this.detailed = false,
  });
  final FinanceEntry entry;
  final bool hideValues;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final expense = entry.kind == EntryKind.expense;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: CircleAvatar(
        backgroundColor: expense
            ? const Color(0xFF4A202D)
            : const Color(0xFF153D35),
        child: Icon(
          expense ? Icons.arrow_upward : Icons.arrow_downward,
          color: expense ? AppColors.negative : AppColors.positive,
        ),
      ),
      title: Text(entry.description),
      subtitle: Text(
        detailed
            ? '${entry.category} · ${_date(entry.date)} · Conta principal'
            : '${entry.category} · ${_date(entry.date)}',
      ),
      trailing: _FinancialValue(
        value: entry.amount,
        hidden: hideValues,
        negative: expense,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FinancialValue extends StatelessWidget {
  const _FinancialValue({
    required this.value,
    required this.hidden,
    required this.style,
    this.negative = false,
  });
  final double value;
  final bool hidden, negative;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text(
    hidden
        ? 'R\$ ••••••'
        : '${negative ? '-' : ''}R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
    style: style?.copyWith(color: negative ? AppColors.negative : style?.color),
    textAlign: TextAlign.right,
  );
}

class _HelpfulEmpty extends StatelessWidget {
  const _HelpfulEmpty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: AppColors.brand),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.initialKind});
  final EntryKind initialKind;
  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final amount = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  late EntryKind kind;
  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    category.dispose();
    super.dispose();
  }

  void save() {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (value == null || value <= 0 || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe valor e descrição válidos.')),
      );
      return;
    }
    Navigator.pop(
      context,
      FinanceEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        description: description.text.trim(),
        category: category.text.trim().isEmpty
            ? (kind == EntryKind.expense ? 'Outros' : 'Receitas')
            : category.text.trim(),
        amount: value,
        kind: kind,
        date: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: kind == EntryKind.expense ? 'Nova despesa' : 'Nova receita',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<EntryKind>(
          segments: const [
            ButtonSegment(
              value: EntryKind.expense,
              label: Text('Despesa'),
              icon: Icon(Icons.arrow_upward),
            ),
            ButtonSegment(
              value: EntryKind.income,
              label: Text('Receita'),
              icon: Icon(Icons.arrow_downward),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (value) => setState(() => kind = value.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor',
            prefixText: 'R\$ ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            hintText: 'Ex.: Mercado do bairro',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: category,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            hintText: 'Ex.: Alimentação',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: save, child: const Text('Salvar movimentação')),
      ],
    ),
  );
}

class _InvestmentForm extends StatefulWidget {
  const _InvestmentForm();
  @override
  State<_InvestmentForm> createState() => _InvestmentFormState();
}

class _InvestmentFormState extends State<_InvestmentForm> {
  final name = TextEditingController();
  final institution = TextEditingController();
  final amount = TextEditingController();
  String type = 'CDB';
  @override
  void dispose() {
    name.dispose();
    institution.dispose();
    amount.dispose();
    super.dispose();
  }

  void save() {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (value == null || value <= 0 || name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e valor válidos.')),
      );
      return;
    }
    Navigator.pop(
      context,
      InvestmentItem(
        name: name.text.trim(),
        institution: institution.text.trim().isEmpty
            ? 'Instituição não informada'
            : institution.text.trim(),
        type: type,
        amount: value,
        yieldDescription: type == 'CDB' ? '100% do CDI' : 'Em acompanhamento',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Novo investimento',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField(
          value: type,
          items: const [
            DropdownMenuItem(value: 'CDB', child: Text('CDB')),
            DropdownMenuItem(value: 'Ação', child: Text('Ação')),
            DropdownMenuItem(value: 'ETF', child: Text('ETF')),
            DropdownMenuItem(value: 'FII', child: Text('FII')),
          ],
          onChanged: (value) => setState(() => type = value!),
          decoration: const InputDecoration(labelText: 'Tipo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Ex.: CDB Liquidez Diária',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: institution,
          decoration: const InputDecoration(labelText: 'Instituição'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor investido',
            prefixText: 'R\$ ',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: save, child: const Text('Salvar investimento')),
      ],
    ),
  );
}

class _CryptoForm extends StatefulWidget {
  const _CryptoForm();
  @override
  State<_CryptoForm> createState() => _CryptoFormState();
}

class _CryptoFormState extends State<_CryptoForm> {
  final asset = TextEditingController(text: 'Bitcoin');
  final amount = TextEditingController();
  String operation = 'Compra';
  @override
  void dispose() {
    asset.dispose();
    amount.dispose();
    super.dispose();
  }

  void save() {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (value == null || value <= 0 || asset.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ativo e valor válidos.')),
      );
      return;
    }
    Navigator.pop(
      context,
      CryptoItem(asset: asset.text.trim(), amount: value, operation: operation),
    );
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Operação em cripto',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Compra', label: Text('Compra')),
            ButtonSegment(value: 'Venda', label: Text('Venda')),
            ButtonSegment(value: 'Conversão', label: Text('Conversão')),
          ],
          selected: {operation},
          onSelectionChanged: (value) =>
              setState(() => operation = value.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: asset,
          decoration: const InputDecoration(
            labelText: 'Ativo',
            hintText: 'Ex.: Bitcoin ou Ethereum',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor da operação',
            prefixText: 'R\$ ',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: save, child: const Text('Salvar operação')),
      ],
    ),
  );
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          color: const Color(0xFF211C29),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
String _pageTitle(FinancePage page) => switch (page) {
  FinancePage.dashboard => 'Finance AI',
  FinancePage.transactions => 'Movimentações',
  FinancePage.investments => 'Investimentos',
  FinancePage.crypto => 'Criptomoedas',
  FinancePage.cards => 'Cartões',
  FinancePage.goals => 'Metas',
  FinancePage.reports => 'Relatórios',
  FinancePage.assistant => 'Assistente IA',
  FinancePage.settings => 'Configurações',
};
