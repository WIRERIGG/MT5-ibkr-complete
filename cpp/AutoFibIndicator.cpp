/**
 * Auto Fibonacci Indicator Implementation
 */

#include "AutoFibIndicator.h"
#include "bar.h"

AutoFibIndicator::AutoFibIndicator(int barsBack, int startBar)
    : bars_back(barsBack), start_bar(startBar),
      last_lowest_bar(-1), last_highest_bar(-1),
      last_high_value(0), last_low_value(0),
      last_is_bullish(true) {

    // Default Fibonacci levels (matching MQL5 version)
    fibo_level_values["level_0"] = 0.000;
    fibo_level_values["level_1"] = 0.236;
    fibo_level_values["level_2"] = 0.382;
    fibo_level_values["level_3"] = 0.500;
    fibo_level_values["level_4"] = 0.618;
    fibo_level_values["level_5"] = 0.764;
    fibo_level_values["level_6"] = 0.886;
    fibo_level_values["level_7"] = 1.000;
    fibo_level_values["level_8"] = 1.618;  // Extension
    fibo_level_values["level_9"] = 2.618;  // Extension
}

void AutoFibIndicator::setFibonacciLevels(const std::map<std::string, double>& levels) {
    fibo_level_values = levels;
}

std::string AutoFibIndicator::getCurrentTimestamp() const {
    std::time_t now = std::time(nullptr);
    char buf[100];
    std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", std::localtime(&now));
    return std::string(buf);
}

int AutoFibIndicator::findLowestBar(const std::vector<Bar>& bars, int start, int count) const {
    if (start < 0 || count <= 0 || start + count > static_cast<int>(bars.size())) {
        return -1;
    }

    int lowest_idx = start;
    double lowest_value = bars[start].low;

    for (int i = start; i < start + count; ++i) {
        if (bars[i].low < lowest_value) {
            lowest_value = bars[i].low;
            lowest_idx = i;
        }
    }

    return lowest_idx;
}

int AutoFibIndicator::findHighestBar(const std::vector<Bar>& bars, int start, int count) const {
    if (start < 0 || count <= 0 || start + count > static_cast<int>(bars.size())) {
        return -1;
    }

    int highest_idx = start;
    double highest_value = bars[start].high;

    for (int i = start; i < start + count; ++i) {
        if (bars[i].high > highest_value) {
            highest_value = bars[i].high;
            highest_idx = i;
        }
    }

    return highest_idx;
}

FibonacciResults AutoFibIndicator::calculate(const std::vector<Bar>& bars) {
    results = FibonacciResults();  // Reset results

    // Validate input
    if (static_cast<int>(bars.size()) < bars_back + start_bar) {
        results.error = "Not enough bars";
        return results;
    }

    // Find highest and lowest bars in lookback period
    int lowest_idx = findLowestBar(bars, start_bar, bars_back);
    int highest_idx = findHighestBar(bars, start_bar, bars_back);

    // Error checking
    if (lowest_idx < 0 || highest_idx < 0) {
        results.error = "Could not find highest/lowest bar";
        return results;
    }

    double high_value = bars[highest_idx].high;
    double low_value = bars[lowest_idx].low;

    // Validate price data
    if (high_value <= 0 || low_value <= 0 || high_value <= low_value) {
        results.error = "Invalid price data";
        return results;
    }

    std::string high_time = bars[highest_idx].time;
    std::string low_time = bars[lowest_idx].time;

    // Determine trend direction (bullish if high came after low)
    bool is_bullish = high_time > low_time;

    // Calculate Fibonacci range
    double fibo_range = high_value - low_value;

    // Calculate all Fibonacci levels
    std::map<std::string, double> fibo_prices;

    if (is_bullish) {
        // Bullish: levels calculated from low upward
        for (const auto& level : fibo_level_values) {
            fibo_prices[level.first] = low_value + (fibo_range * level.second);
        }
    } else {
        // Bearish: levels calculated from high downward
        for (const auto& level : fibo_level_values) {
            fibo_prices[level.first] = high_value - (fibo_range * level.second);
        }
    }

    // Calculate golden zone boundaries (0.382 to 0.618)
    double golden_zone_low, golden_zone_high;
    if (is_bullish) {
        golden_zone_low = low_value + (fibo_range * fibo_level_values["level_2"]);
        golden_zone_high = low_value + (fibo_range * fibo_level_values["level_4"]);
    } else {
        golden_zone_low = high_value - (fibo_range * fibo_level_values["level_4"]);
        golden_zone_high = high_value - (fibo_range * fibo_level_values["level_2"]);
    }

    // Store results
    results.timestamp = getCurrentTimestamp();
    results.trend = is_bullish ? "BULLISH" : "BEARISH";
    results.high_value = high_value;
    results.low_value = low_value;
    results.high_time = high_time;
    results.low_time = low_time;
    results.high_bar_index = highest_idx;
    results.low_bar_index = lowest_idx;
    results.fibo_range = fibo_range;
    results.fibo_levels = fibo_prices;
    results.golden_zone_low = golden_zone_low;
    results.golden_zone_high = golden_zone_high;
    results.current_price = bars.back().close;
    results.price_in_golden_zone = (results.current_price >= golden_zone_low &&
                                     results.current_price <= golden_zone_high);

    // Update cache
    last_lowest_bar = lowest_idx;
    last_highest_bar = highest_idx;
    last_high_value = high_value;
    last_low_value = low_value;
    last_is_bullish = is_bullish;

    return results;
}

std::string AutoFibIndicator::getSignal() const {
    if (!results.error.empty()) {
        return "NO_DATA";
    }

    // Trading logic: Buy in golden zone during uptrend
    if (results.price_in_golden_zone) {
        if (results.trend == "BULLISH") {
            return "BUY";
        } else {
            return "SELL";
        }
    }

    return "HOLD";
}

void AutoFibIndicator::printReport() const {
    if (!results.error.empty()) {
        std::cout << "ERROR: " << results.error << std::endl;
        return;
    }

    std::cout << "\n" << std::string(60, '=') << std::endl;
    std::cout << "AUTO FIBONACCI INDICATOR REPORT" << std::endl;
    std::cout << std::string(60, '=') << std::endl;
    std::cout << "Timestamp: " << results.timestamp << std::endl;
    std::cout << "Trend: " << results.trend << std::endl;
    std::cout << std::fixed << std::setprecision(2);
    std::cout << "High: " << results.high_value << " at " << results.high_time << std::endl;
    std::cout << "Low:  " << results.low_value << " at " << results.low_time << std::endl;
    std::cout << "Range: " << results.fibo_range << std::endl;
    std::cout << "Current Price: " << results.current_price << std::endl;

    std::cout << "\n" << std::string(60, '-') << std::endl;
    std::cout << "FIBONACCI LEVELS:" << std::endl;
    std::cout << std::string(60, '-') << std::endl;

    // Print levels in order
    std::vector<std::pair<double, double>> levels_sorted;
    for (const auto& level : results.fibo_levels) {
        double pct = fibo_level_values.at(level.first) * 100.0;
        levels_sorted.push_back({pct, level.second});
    }
    std::sort(levels_sorted.begin(), levels_sorted.end());

    for (const auto& level : levels_sorted) {
        std::cout << "  " << std::setw(6) << std::setprecision(1) << level.first
                  << "% -> " << std::setw(8) << std::setprecision(2) << level.second << std::endl;
    }

    std::cout << "\n" << std::string(60, '-') << std::endl;
    std::cout << "GOLDEN ZONE (0.382 - 0.618):" << std::endl;
    std::cout << std::string(60, '-') << std::endl;
    std::cout << "  Low:  " << results.golden_zone_low << std::endl;
    std::cout << "  High: " << results.golden_zone_high << std::endl;
    std::cout << "  Price in Golden Zone: " << (results.price_in_golden_zone ? "true" : "false") << std::endl;

    std::string signal = getSignal();
    std::cout << "\n" << std::string(60, '-') << std::endl;
    std::cout << "SIGNAL: " << signal << std::endl;
    std::cout << std::string(60, '=') << "\n" << std::endl;
}

std::string AutoFibIndicator::toJSON() const {
    std::ostringstream json;
    json << std::fixed << std::setprecision(2);

    json << "{\n";

    if (!results.error.empty()) {
        json << "  \"error\": \"" << results.error << "\"\n";
    } else {
        json << "  \"timestamp\": \"" << results.timestamp << "\",\n";
        json << "  \"trend\": \"" << results.trend << "\",\n";
        json << "  \"high_value\": " << results.high_value << ",\n";
        json << "  \"low_value\": " << results.low_value << ",\n";
        json << "  \"high_time\": \"" << results.high_time << "\",\n";
        json << "  \"low_time\": \"" << results.low_time << "\",\n";
        json << "  \"fibo_range\": " << results.fibo_range << ",\n";
        json << "  \"current_price\": " << results.current_price << ",\n";
        json << "  \"price_in_golden_zone\": " << (results.price_in_golden_zone ? "true" : "false") << ",\n";
        json << "  \"golden_zone\": {\n";
        json << "    \"low\": " << results.golden_zone_low << ",\n";
        json << "    \"high\": " << results.golden_zone_high << "\n";
        json << "  },\n";
        json << "  \"signal\": \"" << getSignal() << "\"\n";
    }

    json << "}";

    return json.str();
}
