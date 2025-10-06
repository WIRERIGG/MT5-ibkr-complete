/**
 * Auto Fibonacci Indicator for Interactive Brokers - Main Application
 * C++ Version
 *
 * Port of AUTOFIB_TEST.mq5 to IBKR C++ API
 * Author: Ported from MQL5 for IBKR
 * Last Modified: 2025-10-06
 */

#include "IBKRAutoFibClient.h"
#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <chrono>
#include <fstream>

void printBanner() {
    std::cout << std::string(60, '=') << std::endl;
    std::cout << "AUTO FIBONACCI INDICATOR FOR INTERACTIVE BROKERS" << std::endl;
    std::cout << std::string(60, '=') << std::endl;
    std::cout << "\nC++ Port of AUTOFIB_TEST.mq5 to IBKR C++ API" << std::endl;
    std::cout << "Ensure TWS or IB Gateway is running before proceeding.\n" << std::endl;
}

void printUsage() {
    std::cout << "\nUsage:" << std::endl;
    std::cout << "  ./autofib_ibkr [host] [port] [clientId]" << std::endl;
    std::cout << "\nDefault values:" << std::endl;
    std::cout << "  host:     127.0.0.1" << std::endl;
    std::cout << "  port:     7497 (paper trading)" << std::endl;
    std::cout << "  clientId: 1" << std::endl;
    std::cout << "\nExamples:" << std::endl;
    std::cout << "  ./autofib_ibkr                    # Use defaults" << std::endl;
    std::cout << "  ./autofib_ibkr 127.0.0.1 7496 1   # Live trading" << std::endl;
}

void saveToFile(const std::string& symbol, const std::string& json) {
    std::time_t now = std::time(nullptr);
    char timestamp[100];
    std::strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", std::localtime(&now));

    std::string filename = "autofib_" + symbol + "_" + timestamp + ".json";
    std::ofstream outfile(filename);
    if (outfile.is_open()) {
        outfile << json;
        outfile.close();
        std::cout << "Results saved to: " << filename << std::endl;
    }
}

int main(int argc, char* argv[]) {
    printBanner();

    // Parse command line arguments
    std::string host = "127.0.0.1";
    int port = 7497;  // Paper trading: 7497, Live: 7496
    int clientId = 1;

    if (argc > 1) {
        host = argv[1];
    }
    if (argc > 2) {
        port = std::atoi(argv[2]);
    }
    if (argc > 3) {
        clientId = std::atoi(argv[3]);
    }

    // Symbols to analyze
    std::vector<std::string> symbols = {"AAPL", "MSFT", "SPY"};

    // Create client
    IBKRAutoFibClient client;

    // Connect to TWS/Gateway
    std::cout << "Connecting to TWS/Gateway at " << host << ":" << port << "..." << std::endl;

    if (!client.connect(host.c_str(), port, clientId)) {
        std::cout << "\n❌ CONNECTION FAILED" << std::endl;
        std::cout << "Please ensure TWS or IB Gateway is running and accepting API connections." << std::endl;
        std::cout << "\nSetup instructions:" << std::endl;
        std::cout << "1. Open TWS or IB Gateway" << std::endl;
        std::cout << "2. Navigate to: Edit -> Global Configuration -> API -> Settings" << std::endl;
        std::cout << "3. Enable 'Enable ActiveX and Socket Clients'" << std::endl;
        std::cout << "4. Ensure port " << port << " is configured" << std::endl;
        std::cout << "5. Add 127.0.0.1 to trusted IP addresses" << std::endl;
        printUsage();
        return 1;
    }

    std::cout << "✓ Connected successfully\n" << std::endl;

    // Wait for connection to fully establish
    std::this_thread::sleep_for(std::chrono::seconds(2));

    // Run indicator on multiple symbols
    for (const auto& symbol : symbols) {
        try {
            FibonacciResults results = client.runIndicator(
                symbol,
                "STK",      // secType
                "SMART",    // exchange
                "USD",      // currency
                "1 D",      // duration
                "5 mins"    // barSize
            );

            if (results.error.empty()) {
                // Print report
                AutoFibIndicator indicator;
                indicator.calculate(std::vector<Bar>());  // Dummy call to set up
                // We'll use the client's indicator directly
                std::cout << "\n" << std::string(60, '=') << std::endl;
                std::cout << "AUTO FIBONACCI INDICATOR REPORT - " << symbol << std::endl;
                std::cout << std::string(60, '=') << std::endl;
                std::cout << "Timestamp: " << results.timestamp << std::endl;
                std::cout << "Trend: " << results.trend << std::endl;
                std::cout << std::fixed << std::setprecision(2);
                std::cout << "High: " << results.high_value << " at " << results.high_time << std::endl;
                std::cout << "Low:  " << results.low_value << " at " << results.low_time << std::endl;
                std::cout << "Range: " << results.fibo_range << std::endl;
                std::cout << "Current Price: " << results.current_price << std::endl;

                std::cout << "\n" << std::string(60, '-') << std::endl;
                std::cout << "GOLDEN ZONE (0.382 - 0.618):" << std::endl;
                std::cout << std::string(60, '-') << std::endl;
                std::cout << "  Low:  " << results.golden_zone_low << std::endl;
                std::cout << "  High: " << results.golden_zone_high << std::endl;
                std::cout << "  Price in Golden Zone: " << (results.price_in_golden_zone ? "true" : "false") << std::endl;

                // Determine signal
                std::string signal = "HOLD";
                if (results.price_in_golden_zone) {
                    signal = (results.trend == "BULLISH") ? "BUY" : "SELL";
                }

                std::cout << "\n" << std::string(60, '-') << std::endl;
                std::cout << "SIGNAL: " << signal << std::endl;
                std::cout << std::string(60, '=') << "\n" << std::endl;

                // Save to JSON (simplified version)
                std::ostringstream json;
                json << "{\n";
                json << "  \"symbol\": \"" << symbol << "\",\n";
                json << "  \"timestamp\": \"" << results.timestamp << "\",\n";
                json << "  \"trend\": \"" << results.trend << "\",\n";
                json << "  \"high_value\": " << results.high_value << ",\n";
                json << "  \"low_value\": " << results.low_value << ",\n";
                json << "  \"fibo_range\": " << results.fibo_range << ",\n";
                json << "  \"current_price\": " << results.current_price << ",\n";
                json << "  \"golden_zone_low\": " << results.golden_zone_low << ",\n";
                json << "  \"golden_zone_high\": " << results.golden_zone_high << ",\n";
                json << "  \"price_in_golden_zone\": " << (results.price_in_golden_zone ? "true" : "false") << ",\n";
                json << "  \"signal\": \"" << signal << "\"\n";
                json << "}";

                saveToFile(symbol, json.str());

            } else {
                std::cout << "Error analyzing " << symbol << ": " << results.error << "\n" << std::endl;
            }

            // Rate limiting
            std::this_thread::sleep_for(std::chrono::seconds(1));

        } catch (const std::exception& e) {
            std::cout << "Error processing " << symbol << ": " << e.what() << "\n" << std::endl;
        }
    }

    // Disconnect
    std::cout << "Disconnecting..." << std::endl;
    client.disconnect();
    std::cout << "✓ Done\n" << std::endl;

    return 0;
}
