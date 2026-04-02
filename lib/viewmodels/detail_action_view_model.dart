import '../core/network/kis_realtime_conf.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../repositories/stock_detail_repository.dart';

enum TradeOrderAction { buy, sell }

class DetailActionViewModel {
  DetailActionViewModel({
    required StockDetailRepository stockDetailRepository,
    required KisRealtimeConf realtimeConf,
  }) : _stockDetailRepository = stockDetailRepository,
       _realtimeConf = realtimeConf;

  final StockDetailRepository _stockDetailRepository;
  final KisRealtimeConf _realtimeConf;

  Future<void> refreshStockDetail({
    required Future<void> Function() reload,
  }) async {
    await reload();
  }

  Future<void> refreshMarketIndexDetail({
    required Future<void> Function() reload,
  }) async {
    await reload();
  }

  Future<void> syncStockRealtimeSubscription({
    required String ownerId,
    required StockMarketType marketType,
    required String code,
    String? exchangeCode,
    required bool includeOrderBook,
    required bool active,
    bool includeKospi = false,
  }) async {
    if (!active) {
      await _realtimeConf.clearSubscription(ownerId);
      return;
    }

    if (marketType == StockMarketType.domestic) {
      await _realtimeConf.setSubscription(
        ownerId: ownerId,
        domesticCodes: [code],
        domesticOrderBookCodes: includeOrderBook ? [code] : const <String>[],
        includeKospi: includeKospi,
      );
      return;
    }

    await _realtimeConf.setSubscription(
      ownerId: ownerId,
      overseasTargets: [
        OverseasRealtimeTarget(code: code, exchangeCode: exchangeCode ?? 'NAS'),
      ],
      overseasOrderBookTargets: includeOrderBook
          ? [
              OverseasRealtimeTarget(
                code: code,
                exchangeCode: exchangeCode ?? 'NAS',
              ),
            ]
          : const <OverseasRealtimeTarget>[],
      includeKospi: false,
    );
  }

  Future<String> submitDomesticOrder({
    required TradeOrderAction action,
    required String stockCode,
    required int quantity,
    required int price,
  }) async {
    final message = action == TradeOrderAction.buy
        ? await _stockDetailRepository.placeBuyOrder(
            code: stockCode,
            quantity: quantity,
            price: price,
          )
        : await _stockDetailRepository.placeSellOrder(
            code: stockCode,
            quantity: quantity,
            price: price,
          );
    return message;
  }

  Future<StockLiveQuote> fetchLiveQuote({
    required String code,
    required StockMarketType marketType,
    String? exchangeCode,
  }) {
    return _stockDetailRepository.fetchLiveQuote(
      code: code,
      marketType: marketType,
      exchangeCode: exchangeCode,
    );
  }

  Future<List<StockOrderBookLevel>> fetchLiveOrderBook({
    required String code,
    required StockMarketType marketType,
    String? exchangeCode,
    int? priceDecimals,
  }) {
    return _stockDetailRepository.fetchLiveOrderBook(
      code: code,
      marketType: marketType,
      exchangeCode: exchangeCode,
      priceDecimals: priceDecimals,
    );
  }
}
