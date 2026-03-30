import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/market/market_session.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../../providers/home_provider.dart';
import '../../viewmodels/home_view_state.dart';
import '../widgets/common_widgets.dart';
import 'detail_screens.dart';

part 'home_screen_sections.dart';
part 'home_screen_formatters.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final portfolioHistoryAsync = ref.watch(portfolioProfitHistoryProvider);
    final usdKrwRateAsync = ref.watch(usdKrwRateProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);
    final selectedAccount = ref.watch(selectedAccountProvider);
    final combinedHoldings = [...state.domesticHoldings, ...state.usHoldings]
      ..sort((left, right) {
        final leftStatus = holdingMarketSessionStatus(left);
        final rightStatus = holdingMarketSessionStatus(right);
        if (leftStatus != rightStatus) {
          return leftStatus == HoldingMarketSessionStatus.open ? -1 : 1;
        }
        return left.name.compareTo(right.name);
      });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: notifier.refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MarketSummaryTickerBar(
                    indexes: state.marketIndexes,
                    usdKrwRateAsync: usdKrwRateAsync,
                    sectionState: state.sectionState(HomeSection.market),
                    onRefresh: () =>
                        notifier.refreshSection(HomeSection.market),
                    syncStatus: state.syncStatus,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '모두투자',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.accountSyncErrorMessage != null) ...[
                    _AccountSyncErrorBanner(
                      title: state.accountSyncErrorTitle ?? '계좌 연동이 원활하지 않습니다',
                      message: state.accountSyncErrorMessage!,
                      onRetry: notifier.refreshAll,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SummaryCard(
                    summary: state.summary,
                    portfolioHistoryAsync: portfolioHistoryAsync,
                    sectionState: state.sectionState(HomeSection.summary),
                    onRefresh: () =>
                        notifier.refreshSection(HomeSection.summary),
                    syncStatus: state.syncStatus,
                    onMore: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PortfolioProfitHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeNewsPreviewCard(
                    items: state.newsItems,
                    sectionState: state.sectionState(HomeSection.news),
                    onRetry: () => notifier.refreshSection(HomeSection.news),
                    onOpenList: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeNewsListScreen(items: state.newsItems),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InvestorFlowPreviewCard(
                    flows: state.investorFlows,
                    sectionState: state.sectionState(HomeSection.investorFlow),
                    onRetry: () =>
                        notifier.refreshSection(HomeSection.investorFlow),
                  ),
                  const SizedBox(height: 16),
                  _MomentumPreviewCard(
                    domesticTopMovers: state.domesticTopMovers,
                    domesticVolumeLeaders: state.domesticVolumeLeaders,
                    overseasTopMovers: state.overseasTopMovers,
                    overseasVolumeLeaders: state.overseasVolumeLeaders,
                    sectionState: state.sectionState(HomeSection.momentum),
                    onRetry: () =>
                        notifier.refreshSection(HomeSection.momentum),
                    onOpenDomesticTopMovers: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeRankingListScreen(
                          title: '국내 급등 상위',
                          stocks: state.domesticTopMovers,
                        ),
                      ),
                    ),
                    onOpenDomesticVolumeLeaders: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeRankingListScreen(
                          title: '국내 거래량 상위',
                          stocks: state.domesticVolumeLeaders,
                        ),
                      ),
                    ),
                    onOpenOverseasTopMovers: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeRankingListScreen(
                          title: '해외 급등 상위',
                          stocks: state.overseasTopMovers,
                        ),
                      ),
                    ),
                    onOpenOverseasVolumeLeaders: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeRankingListScreen(
                          title: '해외 거래량 상위',
                          stocks: state.overseasVolumeLeaders,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedAccount?.isIsa == true) ...[
                    const SizedBox(height: 16),
                    _IsaAccountNoticeCard(
                      onRetry: notifier.refreshAll,
                      message: state.accountSyncErrorMessage,
                      isSyncing: state.isSyncing,
                    ),
                  ] else ...[
                    _HoldingsPreviewCard(
                      title: '보유주식',
                      stocks: combinedHoldings,
                      sectionState: state.sectionState(
                        HomeSection.domesticHoldings,
                      ),
                      onRetry: () => Future.wait([
                        notifier.refreshSection(HomeSection.domesticHoldings),
                        notifier.refreshSection(HomeSection.usHoldings),
                      ]),
                      onMore: combinedHoldings.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HoldingsDetailScreen(
                                  title: '보유주식',
                                  holdings: combinedHoldings,
                                ),
                              ),
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ShortSellPreviewCard(
                    rankings: state.shortSellRankings.take(3).toList(),
                    sectionState: state.sectionState(HomeSection.shortSell),
                    onRetry: () =>
                        notifier.refreshSection(HomeSection.shortSell),
                    onMore: state.shortSellRankings.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ShortSellDetailScreen(
                                rankings: state.shortSellRankings,
                              ),
                            ),
                          ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
