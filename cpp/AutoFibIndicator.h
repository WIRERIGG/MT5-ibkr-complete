/**
 * Auto Fibonacci Indicator for Interactive Brokers (C++)
 * Port of AUTOFIB_TEST.mq5 to IBKR C++ API
 *
 * Author: Ported from MQL5 for IBKR
 * Last Modified: 2025-10-06
 */

#ifndef AUTOFIB_INDICATOR_H
#define AUTOFIB_INDICATOR_H

#include <vector>
#include <string>
#include <map>
#include <ctime>
#include <algorithm>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <cmath>

// Forward declaration - use IBKR's Bar struct
struct Bar;

/**
 * Structure to hold Fibonacci analysis results
 */
struct FibonacciResults {
    std::string timestamp;
    std::string trend;              // "BULLISH" or "BEARISH"
    double high_value;
    double low_value;
    std::string high_time;
    std::string low_time;
    int high_bar_index;
    int low_bar_index;
    double fibo_range;
    std::map<std::string, double> fibo_levels;
    double golden_zone_low;
    double golden_zone_high;
    double current_price;
    bool price_in_golden_zone;
    std::string error;

    FibonacciResults() : high_value(0), low_value(0), high_bar_index(0),
                         low_bar_index(0), fibo_range(0), golden_zone_low(0),
                         golden_zone_high(0), current_price(0),
                         price_in_golden_zone(false) {}
};

/**
 * Auto Fibonacci Indicator Calculator
 * Replicates functionality from AUTOFIB_TEST.mq5
 */
class AutoFibIndicator {
private:
    int bars_back;
    int start_bar;
    std::map<std::string, double> fibo_level_values;

    // Cache variables (matching MQL5 optimization)
    int last_lowest_bar;
    int last_highest_bar;
    double last_high_value;
    double last_low_value;
    bool last_is_bullish;

    FibonacciResults results;

    std::string getCurrentTimestamp() const;
    int findLowestBar(const std::vector<Bar>& bars, int start, int count) const;
    int findHighestBar(const std::vector<Bar>& bars, int start, int count) const;

public:
    /**
     * Constructor
     * @param barsBack Number of bars to look back for high/low (default 20)
     * @param startBar Starting bar offset (default 0)
     */
    AutoFibIndicator(int barsBack = 20, int startBar = 0);

    /**
     * Set custom Fibonacci levels
     * @param levels Map of level names to values
     */
    void setFibonacciLevels(const std::map<std::string, double>& levels);

    /**
     * Calculate Fibonacci levels from price bars
     * @param bars Vector of OHLC bars
     * @return FibonacciResults structure
     */
    FibonacciResults calculate(const std::vector<Bar>& bars);

    /**
     * Get trading signal based on price position
     * @return Signal string: "BUY", "SELL", "HOLD", or "NO_DATA"
     */
    std::string getSignal() const;

    /**
     * Print formatted Fibonacci analysis report
     */
    void printReport() const;

    /**
     * Get results as JSON string
     * @return JSON formatted results
     */
    std::string toJSON() const;

    /**
     * Get the last calculated results
     * @return FibonacciResults structure
     */
    const FibonacciResults& getResults() const { return results; }
};

#endif // AUTOFIB_INDICATOR_H
