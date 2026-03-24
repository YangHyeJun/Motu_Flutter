import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ranking_stock.dart';
import '../../providers/api_provider.dart';
import '../widgets/common_widgets.dart';
import 'detail_screens.dart';

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen> {
  String _selectedMarket = 'domestic';
  String _selectedCategory = 'tradeAmount';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final query = (market: _selectedMarket, category: _selectedCategory);
    final stocksAsync = ref.watch(marketStocksProvider(query));
    final trimmedSearchQuery = _searchQuery.trim();
    final searchResultsAsync = trimmedSearchQuery.isEmpty
        ? null
        : ref.watch(stockSearchProvider(trimmedSearchQuery));

    Future<void> refresh() async {
      if (trimmedSearchQuery.isNotEmpty) {
        ref.invalidate(stockSearchProvider(trimmedSearchQuery));
        await ref.read(stockSearchProvider(trimmedSearchQuery).future);
        return;
      }

      ref.invalidate(marketStocksProvider(query));
      await ref.read(marketStocksProvider(query).future);
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '주식',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: '종목명 또는 종목코드 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: trimmedSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '시장 카테고리'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: '국내',
                        selected: _selectedMarket == 'domestic',
                        onTap: () => setState(() => _selectedMarket = 'domestic'),
                      ),
                      _CategoryChip(
                        label: '해외',
                        selected: _selectedMarket == 'overseas',
                        onTap: () => setState(() => _selectedMarket = 'overseas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: '실시간 거래대금',
                        selected: _selectedCategory == 'tradeAmount',
                        onTap: () => setState(() => _selectedCategory = 'tradeAmount'),
                      ),
                      _CategoryChip(
                        label: '거래량',
                        selected: _selectedCategory == 'volume',
                        onTap: () => setState(() => _selectedCategory = 'volume'),
                      ),
                    ],
                  ),
                  if (_selectedMarket == 'overseas') ...[
                    const SizedBox(height: 12),
                    Text(
                      '해외 목록은 현재 나스닥 기준으로 표시됩니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (trimmedSearchQuery.isNotEmpty)
              searchResultsAsync!.when(
                data: (stocks) => _StocksList(
                  stocks: stocks,
                  title: '검색 결과',
                  emptyMessage: '검색 결과가 없습니다.',
                ),
                loading: () => const AppCard(
                  child: SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, _) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: '검색 결과'),
                      const SizedBox(height: 12),
                      Text(
                        '검색 결과를 불러오지 못했습니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              )
            else
              stocksAsync.when(
                data: (stocks) => _StocksList(
                  stocks: stocks,
                  title:
                      '${_selectedMarket == 'domestic' ? '국내 주식' : '해외 주식'} · ${_selectedCategory == 'tradeAmount' ? '실시간 거래대금' : '거래량'}',
                  emptyMessage: '표시할 종목이 없습니다.',
                ),
                loading: () => const AppCard(
                  child: SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, _) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: '주식 목록'),
                      const SizedBox(height: 12),
                      Text(
                        '주식 목록을 불러오지 못했습니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('재시도'),
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

class _StocksList extends StatelessWidget {
  const _StocksList({
    required this.stocks,
    required this.title,
    required this.emptyMessage,
  });

  final List<RankingStock> stocks;
  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '총 ${stocks.length}종목',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ...stocks.map(
            (stock) => InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen.fromRanking(stock: stock),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${stock.rank}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stock.name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(stock.code, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatPrice(stock.price)}원',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        PercentageText(
                          value: '${stock.changeRate.abs().toStringAsFixed(2)}%',
                          isPositive: stock.isPositive,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stock.extraLabel} ${stock.extraValue}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accentSoft,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
    );
  }
}

String _formatPrice(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final fromEnd = digits.length - i - 1;
    if (fromEnd > 0 && fromEnd % 3 == 0) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
