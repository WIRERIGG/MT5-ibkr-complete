/**
 * IBKR Auto Fibonacci Client
 * Interactive Brokers API Client with Auto Fibonacci Indicator
 */

#ifndef IBKR_AUTOFIB_CLIENT_H
#define IBKR_AUTOFIB_CLIENT_H

#include "EWrapper.h"
#include "EClientSocket.h"
#include "EReader.h"
#include "EReaderOSSignal.h"
#include "bar.h"
#include "AutoFibIndicator.h"
#include <memory>
#include <vector>
#include <mutex>
#include <condition_variable>
#include <atomic>

class IBKRAutoFibClient : public EWrapper {
private:
    std::unique_ptr<EReaderOSSignal> os_signal;
    std::unique_ptr<EClientSocket> client_socket;
    std::unique_ptr<EReader> reader;
    std::unique_ptr<AutoFibIndicator> indicator;

    std::vector<Bar> historical_data;
    std::mutex data_mutex;
    std::condition_variable data_cv;
    std::atomic<bool> data_ready;
    std::atomic<bool> data_end_received;

    int next_order_id;

public:
    IBKRAutoFibClient();
    virtual ~IBKRAutoFibClient();

    // Connection methods
    bool connect(const char* host, int port, int clientId);
    void disconnect();
    bool isConnected() const;

    // Historical data request
    bool requestHistoricalData(
        const std::string& symbol,
        const std::string& secType = "STK",
        const std::string& exchange = "SMART",
        const std::string& currency = "USD",
        const std::string& duration = "1 D",
        const std::string& barSize = "5 mins"
    );

    // Get historical data
    std::vector<Bar> getHistoricalData();

    // Run indicator
    FibonacciResults runIndicator(
        const std::string& symbol,
        const std::string& secType = "STK",
        const std::string& exchange = "SMART",
        const std::string& currency = "USD",
        const std::string& duration = "1 D",
        const std::string& barSize = "5 mins"
    );

    // Process messages
    void processMessages();

    // EWrapper interface implementations
    void tickPrice(TickerId tickerId, TickType field, double price, const TickAttrib& attribs) override;
    void tickSize(TickerId tickerId, TickType field, Decimal size) override;
    void tickOptionComputation(TickerId tickerId, TickType tickType, int tickAttrib, double impliedVol, double delta,
                                double optPrice, double pvDividend, double gamma, double vega, double theta, double undPrice) override;
    void tickGeneric(TickerId tickerId, TickType tickType, double value) override;
    void tickString(TickerId tickerId, TickType tickType, const std::string& value) override;
    void tickEFP(TickerId tickerId, TickType tickType, double basisPoints, const std::string& formattedBasisPoints,
                 double totalDividends, int holdDays, const std::string& futureLastTradeDate, double dividendImpact, double dividendsToLastTradeDate) override;
    void orderStatus(OrderId orderId, const std::string& status, Decimal filled, Decimal remaining, double avgFillPrice, int permId, int parentId,
                     double lastFillPrice, int clientId, const std::string& whyHeld, double mktCapPrice) override;
    void openOrder(OrderId orderId, const Contract&, const Order&, const OrderState&) override;
    void openOrderEnd() override;
    void winError(const std::string& str, int lastError) override;
    void connectionClosed() override;
    void updateAccountValue(const std::string& key, const std::string& val, const std::string& currency, const std::string& accountName) override;
    void updatePortfolio(const Contract& contract, Decimal position, double marketPrice, double marketValue, double averageCost,
                         double unrealizedPNL, double realizedPNL, const std::string& accountName) override;
    void updateAccountTime(const std::string& timeStamp) override;
    void accountDownloadEnd(const std::string& accountName) override;
    void nextValidId(OrderId orderId) override;
    void contractDetails(int reqId, const ContractDetails& contractDetails) override;
    void bondContractDetails(int reqId, const ContractDetails& contractDetails) override;
    void contractDetailsEnd(int reqId) override;
    void execDetails(int reqId, const Contract& contract, const Execution& execution) override;
    void execDetailsEnd(int reqId) override;
    void error(int id, int errorCode, const std::string& errorString, const std::string& advancedOrderRejectJson) override;
    void updateMktDepth(TickerId id, int position, int operation, int side, double price, Decimal size) override;
    void updateMktDepthL2(TickerId id, int position, const std::string& marketMaker, int operation, int side, double price, Decimal size, bool isSmartDepth) override;
    void updateNewsBulletin(int msgId, int msgType, const std::string& newsMessage, const std::string& originExch) override;
    void managedAccounts(const std::string& accountsList) override;
    void receiveFA(faDataType pFaDataType, const std::string& cxml) override;
    void historicalData(TickerId reqId, const Bar& bar) override;
    void historicalDataEnd(int reqId, const std::string& startDateStr, const std::string& endDateStr) override;
    void scannerParameters(const std::string& xml) override;
    void scannerData(int reqId, int rank, const ContractDetails& contractDetails, const std::string& distance, const std::string& benchmark, const std::string& projection, const std::string& legsStr) override;
    void scannerDataEnd(int reqId) override;
    void realtimeBar(TickerId reqId, long time, double open, double high, double low, double close, Decimal volume, Decimal wap, int count) override;
    void currentTime(long time) override;
    void fundamentalData(TickerId reqId, const std::string& data) override;
    void deltaNeutralValidation(int reqId, const DeltaNeutralContract& deltaNeutralContract) override;
    void tickSnapshotEnd(int reqId) override;
    void marketDataType(TickerId reqId, int marketDataType) override;
    void commissionReport(const CommissionReport& commissionReport) override;
    void position(const std::string& account, const Contract& contract, Decimal position, double avgCost) override;
    void positionEnd() override;
    void accountSummary(int reqId, const std::string& account, const std::string& tag, const std::string& value, const std::string& currency) override;
    void accountSummaryEnd(int reqId) override;
    void verifyMessageAPI(const std::string& apiData) override;
    void verifyCompleted(bool isSuccessful, const std::string& errorText) override;
    void displayGroupList(int reqId, const std::string& groups) override;
    void displayGroupUpdated(int reqId, const std::string& contractInfo) override;
    void verifyAndAuthMessageAPI(const std::string& apiData, const std::string& xyzChallenge) override;
    void verifyAndAuthCompleted(bool isSuccessful, const std::string& errorText) override;
    void connectAck() override;
    void positionMulti(int reqId, const std::string& account, const std::string& modelCode, const Contract& contract, Decimal pos, double avgCost) override;
    void positionMultiEnd(int reqId) override;
    void accountUpdateMulti(int reqId, const std::string& account, const std::string& modelCode, const std::string& key, const std::string& value, const std::string& currency) override;
    void accountUpdateMultiEnd(int reqId) override;
    void securityDefinitionOptionalParameter(int reqId, const std::string& exchange, int underlyingConId, const std::string& tradingClass,
                                              const std::string& multiplier, const std::set<std::string>& expirations, const std::set<double>& strikes) override;
    void securityDefinitionOptionalParameterEnd(int reqId) override;
    void softDollarTiers(int reqId, const std::vector<SoftDollarTier> &tiers) override;
    void familyCodes(const std::vector<FamilyCode> &familyCodes) override;
    void symbolSamples(int reqId, const std::vector<ContractDescription> &contractDescriptions) override;
    void mktDepthExchanges(const std::vector<DepthMktDataDescription> &depthMktDataDescriptions) override;
    void tickNews(int tickerId, time_t timeStamp, const std::string& providerCode, const std::string& articleId, const std::string& headline, const std::string& extraData) override;
    void smartComponents(int reqId, const SmartComponentsMap& theMap) override;
    void tickReqParams(int tickerId, double minTick, const std::string& bboExchange, int snapshotPermissions) override;
    void newsProviders(const std::vector<NewsProvider> &newsProviders) override;
    void newsArticle(int requestId, int articleType, const std::string& articleText) override;
    void historicalNews(int requestId, const std::string& time, const std::string& providerCode, const std::string& articleId, const std::string& headline) override;
    void historicalNewsEnd(int requestId, bool hasMore) override;
    void headTimestamp(int reqId, const std::string& headTimestamp) override;
    void histogramData(int reqId, const HistogramDataVector& data) override;
    void historicalDataUpdate(TickerId reqId, const Bar& bar) override;
    void rerouteMktDataReq(int reqId, int conid, const std::string& exchange) override;
    void rerouteMktDepthReq(int reqId, int conid, const std::string& exchange) override;
    void marketRule(int marketRuleId, const std::vector<PriceIncrement> &priceIncrements) override;
    void pnl(int reqId, double dailyPnL, double unrealizedPnL, double realizedPnL) override;
    void pnlSingle(int reqId, Decimal pos, double dailyPnL, double unrealizedPnL, double realizedPnL, double value) override;
    void historicalTicks(int reqId, const std::vector<HistoricalTick>& ticks, bool done) override;
    void historicalTicksBidAsk(int reqId, const std::vector<HistoricalTickBidAsk>& ticks, bool done) override;
    void historicalTicksLast(int reqId, const std::vector<HistoricalTickLast>& ticks, bool done) override;
    void tickByTickAllLast(int reqId, int tickType, time_t time, double price, Decimal size, const TickAttribLast& tickAttribLast, const std::string& exchange, const std::string& specialConditions) override;
    void tickByTickBidAsk(int reqId, time_t time, double bidPrice, double askPrice, Decimal bidSize, Decimal askSize, const TickAttribBidAsk& tickAttribBidAsk) override;
    void tickByTickMidPoint(int reqId, time_t time, double midPoint) override;
    void orderBound(long long orderId, int apiClientId, int apiOrderId) override;
    void completedOrder(const Contract& contract, const Order& order, const OrderState& orderState) override;
    void completedOrdersEnd() override;
    void replaceFAEnd(int reqId, const std::string& text) override;
    void wshMetaData(int reqId, const std::string& dataJson) override;
    void wshEventData(int reqId, const std::string& dataJson) override;
    void historicalSchedule(int reqId, const std::string& startDateTime, const std::string& endDateTime, const std::string& timeZone, const std::vector<HistoricalSession>& sessions) override;
    void userInfo(int reqId, const std::string& whiteBrandingId) override;
};

#endif // IBKR_AUTOFIB_CLIENT_H
