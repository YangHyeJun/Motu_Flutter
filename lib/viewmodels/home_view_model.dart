import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'home_view_state.dart';

class HomeViewModel extends Notifier<HomeViewState> {
  @override
  HomeViewState build() {
    return HomeViewState(
      summary: const PortfolioSummary(
        asset: 12340000,
        invested: 10000000,
        profitRate: 23.4,
        profitAmount: 2340000,
      ),
      marketIndexes: const [
        MarketIndex(
          name: '코스피',
          value: '2,587.34',
          changeRate: '+0.75%',
          isPositive: true,
        ),
        MarketIndex(
          name: '코스닥',
          value: '754.21',
          changeRate: '-0.42%',
          isPositive: false,
        ),
        MarketIndex(
          name: '나스닥',
          value: '16,847.12',
          changeRate: '+1.23%',
          isPositive: true,
        ),
      ],
      domesticHoldings: const [
        HoldingStock(
          name: '삼성전자',
          code: '005930',
          quantity: 10,
          buyPrice: 74500,
          currentPrice: 78200,
          evaluationAmount: 9384000,
          profitAmount: 3984000,
          profitRate: 42.4,
          isPositive: true,
        ),
        HoldingStock(
          name: '카카오',
          code: '035720',
          quantity: 30,
          buyPrice: 42300,
          currentPrice: 51200,
          evaluationAmount: 1536000,
          profitAmount: 267000,
          profitRate: 12.8,
          isPositive: true,
        ),
        HoldingStock(
          name: '현대차',
          code: '005380',
          quantity: 1090,
          buyPrice: 233200,
          currentPrice: 218000,
          evaluationAmount: 237620000,
          profitAmount: -16568000,
          profitRate: -7.8,
          isPositive: false,
        ),
      ],
      usHoldings: const [
        HoldingStock(
          name: 'Apple Inc.',
          code: 'AAPL',
          quantity: 3,
          buyPrice: 175000,
          currentPrice: 193523,
          evaluationAmount: 580569,
          profitAmount: 12195,
          profitRate: 2.1,
          isPositive: true,
        ),
        HoldingStock(
          name: 'Tesla Inc.',
          code: 'TSLA',
          quantity: 2,
          buyPrice: 252200,
          currentPrice: 248500,
          evaluationAmount: 497000,
          profitAmount: -7600,
          profitRate: -1.5,
          isPositive: false,
        ),
      ],
      shortSellRankings: const [
        RankingStock(
          rank: 1,
          name: '삼성전자',
          code: '005930',
          price: 78200,
          changeRate: 1.4,
          extraLabel: '공매도량',
          extraValue: '1.2M주',
          isPositive: true,
        ),
        RankingStock(
          rank: 2,
          name: '카카오',
          code: '035720',
          price: 51200,
          changeRate: -2.1,
          extraLabel: '공매도량',
          extraValue: '890K주',
          isPositive: false,
        ),
        RankingStock(
          rank: 3,
          name: '현대차',
          code: '005380',
          price: 218000,
          changeRate: -8.9,
          extraLabel: '공매도량',
          extraValue: '650K주',
          isPositive: false,
        ),
        RankingStock(
          rank: 4,
          name: 'SK하이닉스',
          code: '000660',
          price: 142000,
          changeRate: -1.38,
          extraLabel: '공매도량',
          extraValue: '780K주',
          isPositive: false,
        ),
        RankingStock(
          rank: 5,
          name: 'NAVER',
          code: '035420',
          price: 168000,
          changeRate: -3.3,
          extraLabel: '공매도량',
          extraValue: '530K주',
          isPositive: false,
        ),
        RankingStock(
          rank: 6,
          name: 'LG에너지솔루션',
          code: '373220',
          price: 218000,
          changeRate: -0.72,
          extraLabel: '공매도량',
          extraValue: '192K주',
          isPositive: false,
        ),
        RankingStock(
          rank: 7,
          name: '삼성SDI',
          code: '006400',
          price: 182000,
          changeRate: -1.9,
          extraLabel: '공매도량',
          extraValue: '1.2M주',
          isPositive: false,
        ),
        RankingStock(
          rank: 8,
          name: '기아',
          code: '000270',
          price: 98000,
          changeRate: -0.95,
          extraLabel: '공매도량',
          extraValue: '450K주',
          isPositive: false,
        ),
      ],
      tips: const [
        TipCard(
          title: '분산투자의 중요성',
          description: '한 종목에 집중하기보다는 여러 종목에 분산하여 투자하면 리스크를 줄일 수 있습니다.',
        ),
        TipCard(
          title: '장기투자 관점',
          description: '단기적인 등락에 일희일비하지 말고, 기업의 펀더멘털을 보고 장기적으로 투자하세요.',
        ),
      ],
      chartPoints: const [
        0.18,
        0.16,
        0.31,
        0.27,
        0.30,
        0.25,
        0.14,
        0.10,
        0.08,
        0.32,
        0.12,
        0.22,
        0.58,
        0.47,
        0.66,
        0.60,
        0.73,
        0.50,
        0.57,
        0.70,
        0.55,
        0.58,
        0.72,
        0.61,
        0.79,
        0.88,
        0.80,
        0.83,
        0.71,
        0.74,
        0.62,
        0.68,
      ],
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> refreshAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    state = state.copyWith(lastUpdated: DateTime.now());
  }

  Future<void> refreshRealtimeSections() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(lastUpdated: DateTime.now());
  }
}
