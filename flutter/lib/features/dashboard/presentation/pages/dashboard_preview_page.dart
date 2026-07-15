import 'package:finance_ai/app/constants/app_breakpoints.dart';
import 'package:finance_ai/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DashboardPreviewPage extends StatefulWidget {
  const DashboardPreviewPage({super.key});

  @override
  State<DashboardPreviewPage> createState() => _DashboardPreviewPageState();
}

class _DashboardPreviewPageState extends State<DashboardPreviewPage> {
  bool _hideValues = false;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.expanded;
    final content = _selectedIndex == 0
        ? _DashboardContent(hideValues: _hideValues, onToggleVisibility: () => setState(() => _hideValues = !_hideValues))
        : _SectionPlaceholder(index: _selectedIndex, onBack: () => setState(() => _selectedIndex = 0));

    return Scaffold(
      drawer: isDesktop ? null : const _NavigationDrawer(),
      appBar: AppBar(
        title: const Text('Finance AI'),
        actions: [IconButton(tooltip: _hideValues ? 'Mostrar valores' : 'Ocultar valores', icon: Icon(_hideValues ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hideValues = !_hideValues))],
      ),
      body: Row(
        children: [
          if (isDesktop) _NavigationRail(selectedIndex: _selectedIndex, onSelected: (index) => setState(() => _selectedIndex = index)),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.galaxyStart, AppColors.galaxyEnd], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(child: content),
            ),
          ),
        ],
      ),
      floatingActionButton: isDesktop ? null : FloatingActionButton.extended(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formulário de movimentação em breve'))), icon: const Icon(Icons.add), label: const Text('Adicionar')),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.hideValues, required this.onToggleVisibility});
  final bool hideValues;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= AppBreakpoints.expanded ? 4 : constraints.maxWidth >= AppBreakpoints.medium ? 2 : 1;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Visão geral', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 4), Text('Acompanhe sua vida financeira em um só lugar.', style: Theme.of(context).textTheme.bodyLarge)]),
                  const Chip(avatar: Icon(Icons.auto_awesome, size: 18), label: Text('Preview web')),
                ],
              ),
              const SizedBox(height: 28),
              _MetricGrid(columns: columns, hideValues: hideValues),
              const SizedBox(height: 28),
              _PreviewPanel(title: 'Resumo do mês', child: Row(children: [Expanded(child: _SummaryRow(label: 'Receitas', color: AppColors.positive, value: hideValues ? 'R\$ ••••••' : 'R\$ 0,00')), Expanded(child: _SummaryRow(label: 'Despesas', color: AppColors.negative, value: hideValues ? 'R\$ ••••••' : 'R\$ 0,00')), Expanded(child: _SummaryRow(label: 'Resultado', color: AppColors.brand, value: hideValues ? 'R\$ ••••••' : 'R\$ 0,00'))])),
              const SizedBox(height: 20),
              _PreviewPanel(title: 'Comece por aqui', child: Wrap(spacing: 12, runSpacing: 12, children: const [_QuickAction(icon: Icons.remove_circle_outline, label: 'Adicionar despesa'), _QuickAction(icon: Icons.add_circle_outline, label: 'Adicionar receita'), _QuickAction(icon: Icons.trending_up, label: 'Adicionar investimento'), _QuickAction(icon: Icons.chat_bubble_outline, label: 'Abrir assistente')])),
              const SizedBox(height: 20),
              const _PreviewPanel(title: 'Últimas movimentações', child: _EmptyState(icon: Icons.receipt_long_outlined, text: 'Nenhuma movimentação ainda.\nQuando conectar sua conta, seus lançamentos aparecerão aqui.')),
            ],
          );
        },
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.columns, required this.hideValues});
  final int columns;
  final bool hideValues;
  @override
  Widget build(BuildContext context) {
    const metrics = [(Icons.account_balance_wallet_outlined, 'Saldo atual'), (Icons.pie_chart_outline, 'Patrimônio'), (Icons.arrow_downward, 'Receitas'), (Icons.arrow_upward, 'Despesas')];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: metrics.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: columns == 1 ? 3.2 : 1.7), itemBuilder: (context, index) { final metric = metrics[index]; return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(metric.$1, color: Theme.of(context).colorScheme.primary), Text(metric.$2), Text(hideValues ? 'R\$ ••••••' : 'R\$ 0,00', style: Theme.of(context).textTheme.headlineSmall)]))); });
  }
}

class _PreviewPanel extends StatelessWidget { const _PreviewPanel({required this.title, required this.child}); final String title; final Widget child; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 18), child]))); }
class _SummaryRow extends StatelessWidget { const _SummaryRow({required this.label, required this.color, required this.value}); final String label, value; final Color color; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color))]); }
class _QuickAction extends StatelessWidget { const _QuickAction({required this.icon, required this.label}); final IconData icon; final String label; @override Widget build(BuildContext context) => OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label selecionado'))), icon: Icon(icon), label: Text(label)); }
class _EmptyState extends StatelessWidget { const _EmptyState({required this.icon, required this.text}); final IconData icon; final String text; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(icon, size: 44), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)]))); }
class _NavigationRail extends StatelessWidget { const _NavigationRail({required this.selectedIndex, required this.onSelected}); final int selectedIndex; final ValueChanged<int> onSelected; @override Widget build(BuildContext context) => NavigationRail(selectedIndex: selectedIndex, onDestinationSelected: onSelected, labelType: NavigationRailLabelType.all, destinations: const [NavigationRailDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: Text('Início')), NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Transações')), NavigationRailDestination(icon: Icon(Icons.trending_up), label: Text('Investimentos')), NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline), label: Text('Assistente')), NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Ajustes'))]); }
class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.index, required this.onBack});
  final int index;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const sections = [
      ('Transações', Icons.receipt_long_outlined, 'Registre receitas, despesas, transferências e reembolsos.'),
      ('Investimentos', Icons.trending_up, 'Acompanhe CDB, renda fixa e sua evolução patrimonial.'),
      ('Assistente Financeiro', Icons.auto_awesome, 'Converse com a IA para registrar e consultar sua vida financeira.'),
      ('Ajustes', Icons.settings_outlined, 'Personalize moeda, privacidade e preferências.'),
    ];
    final section = sections[index - 1];
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Card(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(section.$2, size: 56, color: AppColors.brand), const SizedBox(height: 18), Text(section.$1, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), Text(section.$3, textAlign: TextAlign.center), const SizedBox(height: 24), FilledButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Voltar ao Dashboard'))])))));
  }
}
class _NavigationDrawer extends StatelessWidget { const _NavigationDrawer(); @override Widget build(BuildContext context) => const NavigationDrawer(children: [DrawerHeader(child: Text('Finance AI')), NavigationDrawerDestination(icon: Icon(Icons.grid_view_outlined), label: Text('Início')), NavigationDrawerDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Transações')), NavigationDrawerDestination(icon: Icon(Icons.settings_outlined), label: Text('Ajustes'))]); }
