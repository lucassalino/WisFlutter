import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../domain/ministry.dart';
import 'ministries_providers.dart';
import 'ministry_detail_screen.dart';
import 'ministry_form_screen.dart';

enum _MinistryFilter { active, inactive, all }

const _filterLabels = {
  _MinistryFilter.active: 'Activos',
  _MinistryFilter.inactive: 'Inactivos',
  _MinistryFilter.all: 'Todos',
};

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

class MinistriesListScreen extends ConsumerStatefulWidget {
  const MinistriesListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<MinistriesListScreen> createState() =>
      _MinistriesListScreenState();
}

class _MinistriesListScreenState extends ConsumerState<MinistriesListScreen> {
  _MinistryFilter _filter = _MinistryFilter.active;

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.ministries),
      body: SpotlightBackground(
        child: ministriesAsync.when(
          data: (ministries) {
            final activeCount = ministries.where((m) => m.isActive).length;
            final inactiveCount = ministries.length - activeCount;
            final filtered = ministries.where((m) {
              return switch (_filter) {
                _MinistryFilter.active => m.isActive,
                _MinistryFilter.inactive => !m.isActive,
                _MinistryFilter.all => true,
              };
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORGANIZAÇÃO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ministérios',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '$activeCount activo${activeCount != 1 ? 's' : ''} · '
                            '$inactiveCount inactivo${inactiveCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              MinistryFormScreen(orgId: widget.orgId),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Novo Ministério'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FilterTabs(
                  value: _filter,
                  counts: {
                    _MinistryFilter.active: activeCount,
                    _MinistryFilter.inactive: inactiveCount,
                    _MinistryFilter.all: ministries.length,
                  },
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'Nenhum ministério aqui.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _MinistryCard(
                      orgId: widget.orgId,
                      ministry: filtered[index],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Erro ao carregar ministérios: $error')),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  final _MinistryFilter value;
  final Map<_MinistryFilter, int> counts;
  final ValueChanged<_MinistryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          for (final filter in _MinistryFilter.values)
            Expanded(
              child: _FilterTab(
                label: _filterLabels[filter]!,
                count: counts[filter] ?? 0,
                selected: value == filter,
                onTap: () => onChanged(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinistryCard extends StatelessWidget {
  const _MinistryCard({required this.orgId, required this.ministry});

  final String orgId;
  final Ministry ministry;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(ministry.color);
    final initial = ministry.name.isNotEmpty
        ? ministry.name[0].toUpperCase()
        : '?';
    return Opacity(
      opacity: ministry.isActive ? 1 : 0.55,
      child: Stack(
        children: [
          Positioned.fill(
            child: GlassCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MinistryDetailScreen(orgId: orgId, ministry: ministry),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ministry.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ministry.functions.length} '
                    '${ministry.functions.length == 1 ? 'função' : 'funções'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  if (!ministry.isActive) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFFF87171,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'Inactivo',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
