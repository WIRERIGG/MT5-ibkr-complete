/**
 * IBKR Auto Fibonacci Client Implementation
 */

#include "IBKRAutoFibClient.h"
#include "Contract.h"
#include "Order.h"
#include <iostream>
#include <thread>
#include <chrono>
#include <ctime>

IBKRAutoFibClient::IBKRAutoFibClient()
    : data_ready(false), data_end_received(false), next_order_id(0) {

    os_signal = std::make_unique<EReaderOSSignal>();
    client_socket = std::make_unique<EClientSocket>(this, os_signal.get());
    indicator = std::make_unique<AutoFibIndicator>(20);  // 20 bars lookback
}

IBKRAutoFibClient::~IBKRAutoFibClient() {
    if (isConnected()) {
        disconnect();
    }
}

bool IBKRAutoFibClient::connect(const char* host, int port, int clientId) {
    std::cout << "Connecting to " << host << ":" << port << "..." << std::endl;
    bool result = client_socket->eConnect(host, port, clientId, false);

    if (result) {
        std::cout << "Connected successfully" << std::endl;

        // Create reader for message processing
        reader = std::make_unique<EReader>(client_socket.get(), os_signal.get());
        reader->start();

        // Wait a bit for connection to establish
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    } else {
        std::cout << "Connection failed" << std::endl;
    }

    return result;
}

void IBKRAutoFibClient::disconnect() {
    client_socket->eDisconnect();
    std::cout << "Disconnected" << std::endl;
}

bool IBKRAutoFibClient::isConnected() const {
    return client_socket->isConnected();
}

bool IBKRAutoFibClient::requestHistoricalData(
    const std::string& symbol,
    const std::string& secType,
    const std::string& exchange,
    const std::string& currency,
    const std::string& duration,
    const std::string& barSize
) {
    if (!isConnected()) {
        std::cout << "Not connected to TWS/Gateway" << std::endl;
        return false;
    }

    Contract contract;
    contract.symbol = symbol;
    contract.secType = secType;
    contract.exchange = exchange;
    contract.currency = currency;

    // Clear previous data
    {
        std::lock_guard<std::mutex> lock(data_mutex);
        historical_data.clear();
        data_ready = false;
        data_end_received = false;
    }

    std::cout << "Requesting historical data for " << symbol << "..." << std::endl;

    client_socket->reqHistoricalData(
        1,                  // reqId
        contract,
        "",                 // endDateTime (empty = now)
        duration,           // durationStr
        barSize,            // barSizeSetting
        "TRADES",           // whatToShow
        1,                  // useRTH (regular trading hours)
        1,                  // formatDate (1 = yyyyMMdd HH:mm:ss)
        false,              // keepUpToDate
        TagValueListSPtr()  // chartOptions
    );

    return true;
}

std::vector<Bar> IBKRAutoFibClient::getHistoricalData() {
    std::unique_lock<std::mutex> lock(data_mutex);

    // Wait for data with timeout
    if (!data_cv.wait_for(lock, std::chrono::seconds(30),
        [this] { return data_end_received.load(); })) {
        std::cout << "Timeout waiting for historical data" << std::endl;
        return std::vector<Bar>();
    }

    return historical_data;
}

FibonacciResults IBKRAutoFibClient::runIndicator(
    const std::string& symbol,
    const std::string& secType,
    const std::string& exchange,
    const std::string& currency,
    const std::string& duration,
    const std::string& barSize
) {
    FibonacciResults results;

    std::cout << "\nFetching data for " << symbol << "..." << std::endl;

    if (!requestHistoricalData(symbol, secType, exchange, currency, duration, barSize)) {
        results.error = "Failed to request historical data";
        return results;
    }

    // Process messages while waiting for data
    auto start = std::chrono::steady_clock::now();
    while (!data_end_received &&
           std::chrono::steady_clock::now() - start < std::chrono::seconds(30)) {
        os_signal->waitForSignal();
        reader->processMsgs();
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    std::vector<Bar> bars = getHistoricalData();

    if (bars.empty()) {
        results.error = "No data received";
        return results;
    }

    std::cout << "Received " << bars.size() << " bars" << std::endl;
    std::cout << "Calculating Fibonacci levels..." << std::endl;

    results = indicator->calculate(bars);
    return results;
}

void IBKRAutoFibClient::processMessages() {
    if (reader) {
        os_signal->waitForSignal();
        reader->processMsgs();
    }
}

// EWrapper implementations

void IBKRAutoFibClient::error(int id, int errorCode, const std::string& errorString, const std::string& advancedOrderRejectJson) {
    std::cout << "Error [" << id << "][" << errorCode << "]: " << errorString << std::endl;

    if (errorCode == 502 || errorCode == 503) {
        std::cout << "Connection error - ensure TWS/Gateway is running" << std::endl;
    }
}

void IBKRAutoFibClient::nextValidId(OrderId orderId) {
    next_order_id = orderId;
    std::cout << "Next valid order ID: " << orderId << std::endl;
}

void IBKRAutoFibClient::historicalData(TickerId reqId, const Bar& bar) {
    std::lock_guard<std::mutex> lock(data_mutex);

    // IBKR's Bar already has the correct format
    historical_data.push_back(bar);
}

void IBKRAutoFibClient::historicalDataEnd(int reqId, const std::string& startDateStr, const std::string& endDateStr) {
    std::lock_guard<std::mutex> lock(data_mutex);
    std::cout << "Historical data received: " << historical_data.size() << " bars" << std::endl;
    data_end_received = true;
    data_ready = true;
    data_cv.notify_all();
}

void IBKRAutoFibClient::connectionClosed() {
    std::cout << "Connection closed" << std::endl;
}

void IBKRAutoFibClient::connectAck() {
    std::cout << "Connection acknowledged" << std::endl;
}

// Empty implementations for unused callbacks
void IBKRAutoFibClient::tickPrice(TickerId, TickType, double, const TickAttrib&) {}
void IBKRAutoFibClient::tickSize(TickerId, TickType, Decimal) {}
void IBKRAutoFibClient::tickOptionComputation(TickerId, TickType, int, double, double, double, double, double, double, double, double) {}
void IBKRAutoFibClient::tickGeneric(TickerId, TickType, double) {}
void IBKRAutoFibClient::tickString(TickerId, TickType, const std::string&) {}
void IBKRAutoFibClient::tickEFP(TickerId, TickType, double, const std::string&, double, int, const std::string&, double, double) {}
void IBKRAutoFibClient::orderStatus(OrderId, const std::string&, Decimal, Decimal, double, int, int, double, int, const std::string&, double) {}
void IBKRAutoFibClient::openOrder(OrderId, const Contract&, const Order&, const OrderState&) {}
void IBKRAutoFibClient::openOrderEnd() {}
void IBKRAutoFibClient::winError(const std::string&, int) {}
void IBKRAutoFibClient::updateAccountValue(const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::updatePortfolio(const Contract&, Decimal, double, double, double, double, double, const std::string&) {}
void IBKRAutoFibClient::updateAccountTime(const std::string&) {}
void IBKRAutoFibClient::accountDownloadEnd(const std::string&) {}
void IBKRAutoFibClient::contractDetails(int, const ContractDetails&) {}
void IBKRAutoFibClient::bondContractDetails(int, const ContractDetails&) {}
void IBKRAutoFibClient::contractDetailsEnd(int) {}
void IBKRAutoFibClient::execDetails(int, const Contract&, const Execution&) {}
void IBKRAutoFibClient::execDetailsEnd(int) {}
void IBKRAutoFibClient::updateMktDepth(TickerId, int, int, int, double, Decimal) {}
void IBKRAutoFibClient::updateMktDepthL2(TickerId, int, const std::string&, int, int, double, Decimal, bool) {}
void IBKRAutoFibClient::updateNewsBulletin(int, int, const std::string&, const std::string&) {}
void IBKRAutoFibClient::managedAccounts(const std::string&) {}
void IBKRAutoFibClient::receiveFA(faDataType, const std::string&) {}
void IBKRAutoFibClient::scannerParameters(const std::string&) {}
void IBKRAutoFibClient::scannerData(int, int, const ContractDetails&, const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::scannerDataEnd(int) {}
void IBKRAutoFibClient::realtimeBar(TickerId, long, double, double, double, double, Decimal, Decimal, int) {}
void IBKRAutoFibClient::currentTime(long) {}
void IBKRAutoFibClient::fundamentalData(TickerId, const std::string&) {}
void IBKRAutoFibClient::deltaNeutralValidation(int, const DeltaNeutralContract&) {}
void IBKRAutoFibClient::tickSnapshotEnd(int) {}
void IBKRAutoFibClient::marketDataType(TickerId, int) {}
void IBKRAutoFibClient::commissionReport(const CommissionReport&) {}
void IBKRAutoFibClient::position(const std::string&, const Contract&, Decimal, double) {}
void IBKRAutoFibClient::positionEnd() {}
void IBKRAutoFibClient::accountSummary(int, const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::accountSummaryEnd(int) {}
void IBKRAutoFibClient::verifyMessageAPI(const std::string&) {}
void IBKRAutoFibClient::verifyCompleted(bool, const std::string&) {}
void IBKRAutoFibClient::displayGroupList(int, const std::string&) {}
void IBKRAutoFibClient::displayGroupUpdated(int, const std::string&) {}
void IBKRAutoFibClient::verifyAndAuthMessageAPI(const std::string&, const std::string&) {}
void IBKRAutoFibClient::verifyAndAuthCompleted(bool, const std::string&) {}
void IBKRAutoFibClient::positionMulti(int, const std::string&, const std::string&, const Contract&, Decimal, double) {}
void IBKRAutoFibClient::positionMultiEnd(int) {}
void IBKRAutoFibClient::accountUpdateMulti(int, const std::string&, const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::accountUpdateMultiEnd(int) {}
void IBKRAutoFibClient::securityDefinitionOptionalParameter(int, const std::string&, int, const std::string&, const std::string&, const std::set<std::string>&, const std::set<double>&) {}
void IBKRAutoFibClient::securityDefinitionOptionalParameterEnd(int) {}
void IBKRAutoFibClient::softDollarTiers(int, const std::vector<SoftDollarTier>&) {}
void IBKRAutoFibClient::familyCodes(const std::vector<FamilyCode>&) {}
void IBKRAutoFibClient::symbolSamples(int, const std::vector<ContractDescription>&) {}
void IBKRAutoFibClient::mktDepthExchanges(const std::vector<DepthMktDataDescription>&) {}
void IBKRAutoFibClient::tickNews(int, time_t, const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::smartComponents(int, const SmartComponentsMap&) {}
void IBKRAutoFibClient::tickReqParams(int, double, const std::string&, int) {}
void IBKRAutoFibClient::newsProviders(const std::vector<NewsProvider>&) {}
void IBKRAutoFibClient::newsArticle(int, int, const std::string&) {}
void IBKRAutoFibClient::historicalNews(int, const std::string&, const std::string&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::historicalNewsEnd(int, bool) {}
void IBKRAutoFibClient::headTimestamp(int, const std::string&) {}
void IBKRAutoFibClient::histogramData(int, const HistogramDataVector&) {}
void IBKRAutoFibClient::historicalDataUpdate(TickerId, const Bar&) {}
void IBKRAutoFibClient::rerouteMktDataReq(int, int, const std::string&) {}
void IBKRAutoFibClient::rerouteMktDepthReq(int, int, const std::string&) {}
void IBKRAutoFibClient::marketRule(int, const std::vector<PriceIncrement>&) {}
void IBKRAutoFibClient::pnl(int, double, double, double) {}
void IBKRAutoFibClient::pnlSingle(int, Decimal, double, double, double, double) {}
void IBKRAutoFibClient::historicalTicks(int, const std::vector<HistoricalTick>&, bool) {}
void IBKRAutoFibClient::historicalTicksBidAsk(int, const std::vector<HistoricalTickBidAsk>&, bool) {}
void IBKRAutoFibClient::historicalTicksLast(int, const std::vector<HistoricalTickLast>&, bool) {}
void IBKRAutoFibClient::tickByTickAllLast(int, int, time_t, double, Decimal, const TickAttribLast&, const std::string&, const std::string&) {}
void IBKRAutoFibClient::tickByTickBidAsk(int, time_t, double, double, Decimal, Decimal, const TickAttribBidAsk&) {}
void IBKRAutoFibClient::tickByTickMidPoint(int, time_t, double) {}
void IBKRAutoFibClient::orderBound(long long, int, int) {}
void IBKRAutoFibClient::completedOrder(const Contract&, const Order&, const OrderState&) {}
void IBKRAutoFibClient::completedOrdersEnd() {}
void IBKRAutoFibClient::replaceFAEnd(int, const std::string&) {}
void IBKRAutoFibClient::wshMetaData(int, const std::string&) {}
void IBKRAutoFibClient::wshEventData(int, const std::string&) {}
void IBKRAutoFibClient::historicalSchedule(int, const std::string&, const std::string&, const std::string&, const std::vector<HistoricalSession>&) {}
void IBKRAutoFibClient::userInfo(int, const std::string&) {}
