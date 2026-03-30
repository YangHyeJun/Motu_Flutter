import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../repositories/stock_detail_repository.dart';

enum TradeOrderAction { buy, sell }

class DetailActionViewModel {
  DetailActionViewModel({
    required StockDetailRepository stockDetailRepository,
    required KisRealtimeService realtimeService,
  }) : _stockDetailRepository = stockDetailRepository,
       _realtimeService = realtimeService;

  final StockDetailRepository _stockDetailRepository;
  final KisRealtimeService _realtimeService;

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
      await _realtimeService.clearSubscription(ownerId);
      return;
    }

    if (marketType == StockMarketType.domestic) {
      await _realtimeService.setSubscription(
        ownerId: ownerId,
        domesticCodes: [code],
        domesticOrderBookCodes: includeOrderBook ? [code] : const <String>[],
        includeKospi: includeKospi,
      );
      return;
    }

    await _realtimeService.setSubscription(
      ownerId: ownerId,
      overseasTargets: [
        OverseasRealtimeTarget(code: code, exchangeCode: exchangeCode ?? 'NAS'),
      ],
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
}
