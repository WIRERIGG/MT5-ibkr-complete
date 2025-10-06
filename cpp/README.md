# Auto Fibonacci Indicator - IBKR C++ Version

Port of `AUTOFIB_TEST.mq5` (MetaTrader 5) to Interactive Brokers C++ API

## Overview

This is a high-performance C++ implementation of the Auto Fibonacci indicator, providing the same functionality as the MQL5 and Python versions but with native performance.

## Features

### Core Functionality (Matching MQL5/Python Versions)

1. **Automatic High/Low Detection**
   - Finds highest and lowest price points in lookback period (default: 20 bars)
   - Determines trend direction (bullish/bearish)

2. **Fibonacci Levels**
   - **Retracement Levels**: 0.0, 0.236, 0.382, 0.500, 0.618, 0.764, 0.886, 1.000
   - **Extension Levels**: 1.618, 2.618
   - **Golden Zone**: 0.382 to 0.618 (key reversal zone)

3. **Real-time Analysis**
   - Connects to Interactive Brokers TWS/Gateway
   - Retrieves historical price data
   - Calculates Fibonacci levels
   - Generates trading signals

4. **Performance**
   - Native C++ performance
   - Multi-threaded data processing
   - Efficient memory management
   - Low latency

## Build Instructions

### Prerequisites

1. **Development Tools**
   ```bash
   sudo apt-get install build-essential cmake
   ```

2. **IBKR C++ API** (already downloaded in setup)
   - Located in: `/home/ubuntu/ibkr-cpp/IBJts/`

3. **Interactive Brokers Account**
   - Paper trading or live account
   - TWS or IB Gateway installed

### Building

```bash
cd /home/ubuntu/ibkr-cpp
mkdir build
cd build
cmake ..
make
```

This will create the executable: `autofib_ibkr`

### Quick Build Script

```bash
#!/bin/bash
cd /home/ubuntu/ibkr-cpp
rm -rf build
mkdir build
cd build
cmake ..
make -j$(nproc)
echo "Build complete: ./autofib_ibkr"
```

## Configuration

### TWS/IB Gateway Setup

1. Open TWS or IB Gateway
2. Navigate to: **Edit → Global Configuration → API → Settings**
3. Enable: **"Enable ActiveX and Socket Clients"**
4. Configure ports:
   - Paper trading: `7497`
   - Live trading: `7496`
5. Add `127.0.0.1` to **Trusted IP Addresses**
6. Click **OK** and restart TWS/Gateway

## Usage

### Basic Usage

```bash
cd /home/ubuntu/ibkr-cpp/build
./autofib_ibkr
```

### Custom Connection Parameters

```bash
# Syntax: ./autofib_ibkr [host] [port] [clientId]

# Paper trading (default)
./autofib_ibkr 127.0.0.1 7497 1

# Live trading
./autofib_ibkr 127.0.0.1 7496 1

# Remote TWS
./autofib_ibkr 192.168.1.100 7497 1
```

### Modifying Analyzed Symbols

Edit `main.cpp` line ~75:

```cpp
std::vector<std::string> symbols = {"AAPL", "MSFT", "SPY"};
```

Then rebuild:
```bash
cd build && make
```

### Customizing Indicator Parameters

Edit `IBKRAutoFibClient.cpp` constructor:

```cpp
IBKRAutoFibClient::IBKRAutoFibClient()
    : next_order_id(0), data_ready(false), data_end_received(false) {

    client_socket = std::make_unique<EClientSocket>(this, nullptr);
    indicator = std::make_unique<AutoFibIndicator>(20);  // Change lookback period here
}
```

## Output

### Console Output

```
============================================================
AUTO FIBONACCI INDICATOR FOR INTERACTIVE BROKERS
============================================================

C++ Port of AUTOFIB_TEST.mq5 to IBKR C++ API
Ensure TWS or IB Gateway is running before proceeding.

Connecting to TWS/Gateway at 127.0.0.1:7497...
Connected successfully
✓ Connected successfully

Fetching data for AAPL...
Requesting historical data for AAPL...
Historical data received: 78 bars
Received 78 bars
Calculating Fibonacci levels...

============================================================
AUTO FIBONACCI INDICATOR REPORT - AAPL
============================================================
Timestamp: 2025-10-06T18:55:23
Trend: BULLISH
High: 152.34 at 20251006  15:30:00
Low:  148.21 at 20251006  09:15:00
Range: 4.13
Current Price: 150.45

------------------------------------------------------------
GOLDEN ZONE (0.382 - 0.618):
------------------------------------------------------------
  Low:  149.79
  High: 150.76
  Price in Golden Zone: true

------------------------------------------------------------
SIGNAL: BUY
============================================================

Results saved to: autofib_AAPL_20251006_185523.json
```

### JSON Output

Automatically saves results to timestamped JSON files:

```json
{
  "symbol": "AAPL",
  "timestamp": "2025-10-06T18:55:23",
  "trend": "BULLISH",
  "high_value": 152.34,
  "low_value": 148.21,
  "fibo_range": 4.13,
  "current_price": 150.45,
  "golden_zone_low": 149.79,
  "golden_zone_high": 150.76,
  "price_in_golden_zone": true,
  "signal": "BUY"
}
```

## Project Structure

```
/home/ubuntu/ibkr-cpp/
├── IBJts/                      # IBKR C++ API
│   └── source/cppclient/
│       └── client/             # API source files
├── AutoFibIndicator.h          # Indicator header
├── AutoFibIndicator.cpp        # Indicator implementation
├── IBKRAutoFibClient.h         # IBKR client header
├── IBKRAutoFibClient.cpp       # IBKR client implementation
├── main.cpp                    # Main application
├── CMakeLists.txt              # Build configuration
└── README.md                   # This file
```

## Comparison: MQL5 vs Python vs C++

| Feature | MQL5 (MT5) | Python (IBKR) | C++ (IBKR) |
|---------|------------|---------------|------------|
| Platform | MetaTrader 5 | Interactive Brokers | Interactive Brokers |
| Language | MQL5 | Python 3 | C++14 |
| Performance | Fast | Moderate | Very Fast |
| Real-time plotting | ✓ Chart objects | ✗ | ✗ Console only |
| Fibonacci calculation | ✓ Identical | ✓ Identical | ✓ Identical |
| Golden zone detection | ✓ Visual | ✓ Programmatic | ✓ Programmatic |
| Trading signals | ✗ Visual only | ✓ | ✓ |
| Data export | ✗ | ✓ JSON | ✓ JSON |
| Multi-threading | ✗ | ✓ | ✓ |
| Memory efficiency | Moderate | Low | High |
| Startup time | Instant | ~1s | ~100ms |

## Advanced Usage

### Integration with Trading System

```cpp
// In your trading system
IBKRAutoFibClient client;
client.connect("127.0.0.1", 7497, 1);

FibonacciResults results = client.runIndicator("AAPL");

if (results.error.empty()) {
    std::string signal = "HOLD";
    if (results.price_in_golden_zone) {
        signal = (results.trend == "BULLISH") ? "BUY" : "SELL";
    }

    if (signal == "BUY") {
        // Execute buy order
        std::cout << "Executing BUY for AAPL" << std::endl;
        // Order logic here...
    }
}

client.disconnect();
```

### Custom Fibonacci Levels

Modify `AutoFibIndicator.cpp` constructor:

```cpp
AutoFibIndicator::AutoFibIndicator(int barsBack, int startBar)
    : bars_back(barsBack), start_bar(startBar),
      last_lowest_bar(-1), last_highest_bar(-1),
      last_high_value(0), last_low_value(0),
      last_is_bullish(true) {

    // Custom Fibonacci levels
    fibo_level_values["level_0"] = 0.000;
    fibo_level_values["level_1"] = 0.250;  // Custom
    fibo_level_values["level_2"] = 0.382;
    fibo_level_values["level_3"] = 0.500;
    fibo_level_values["level_4"] = 0.618;
    fibo_level_values["level_5"] = 0.786;  // Custom
    fibo_level_values["level_6"] = 1.000;
    fibo_level_values["level_7"] = 1.272;  // Custom extension
    fibo_level_values["level_8"] = 1.618;
    fibo_level_values["level_9"] = 2.618;
}
```

### Continuous Monitoring

```cpp
while (true) {
    FibonacciResults results = client.runIndicator("AAPL");

    if (results.error.empty()) {
        // Process results
        std::cout << "Price: " << results.current_price
                  << " | Signal: " << getSignal(results) << std::endl;
    }

    std::this_thread::sleep_for(std::chrono::minutes(5));
}
```

## Troubleshooting

### Build Errors

**Error: "Cannot find IBKR API files"**
```bash
# Ensure API is extracted
ls /home/ubuntu/ibkr-cpp/IBJts/source/cppclient/client/
```

**Error: "undefined reference to pthread"**
```bash
# Ensure pthread is linked (already in CMakeLists.txt)
# If issue persists, add to CMakeLists.txt:
target_link_libraries(autofib_ibkr pthread dl)
```

### Connection Errors

**Error: "Connection failed"**
- Verify TWS/Gateway is running
- Check API settings are enabled
- Verify port number (7497 for paper, 7496 for live)
- Add 127.0.0.1 to trusted IPs

**Error: "Socket exception"**
- Firewall may be blocking connection
- Check if another client is using the same clientId

### Runtime Errors

**Error: "Timeout waiting for historical data"**
- Symbol may not have data available
- Check if market is open
- Verify symbol spelling and security type

**Error: "Not enough bars"**
- Reduce lookback period in AutoFibIndicator constructor
- Request longer duration (e.g., "2 D" instead of "1 D")

## Performance Optimization

### Compiler Optimizations

Build with optimizations:
```bash
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

### Memory Profiling

```bash
valgrind --leak-check=full ./autofib_ibkr
```

### CPU Profiling

```bash
valgrind --tool=callgrind ./autofib_ibkr
```

## Development

### Adding New Features

1. Modify `AutoFibIndicator.h` to add new methods
2. Implement in `AutoFibIndicator.cpp`
3. Update `main.cpp` to use new features
4. Rebuild: `cd build && make`

### Testing

Create a test file `test_autofib.cpp`:

```cpp
#include "AutoFibIndicator.h"
#include <cassert>

void testBullishTrend() {
    std::vector<Bar> bars;
    // Add test data...

    AutoFibIndicator indicator(20);
    FibonacciResults results = indicator.calculate(bars);

    assert(results.trend == "BULLISH");
    assert(results.error.empty());
}

int main() {
    testBullishTrend();
    std::cout << "All tests passed!" << std::endl;
    return 0;
}
```

Build and run tests:
```bash
g++ -std=c++14 test_autofib.cpp AutoFibIndicator.cpp -o test_autofib
./test_autofib
```

## Security Considerations

⚠️ **Important**: This is an educational tool

- Always test with paper trading first
- Never commit API credentials to version control
- Validate all signals before executing trades
- Implement proper risk management
- Monitor for unexpected behavior

## API Documentation

**IBKR C++ API Reference**:
- https://interactivebrokers.github.io/tws-api/cpp_api.html

**Class Documentation**:
- `AutoFibIndicator`: Core indicator calculation engine
- `IBKRAutoFibClient`: IBKR API wrapper with EWrapper implementation
- `Bar`: OHLC data structure
- `FibonacciResults`: Analysis results structure

## Support

For issues or questions:
- MQL5 original: http://www.xpworx.com
- IBKR C++ API: https://interactivebrokers.github.io/tws-api/
- Project issues: Check build errors with verbose output: `make VERBOSE=1`

## License

Educational use only. Original MQL5 code by Coders' Guru.
C++ port maintains same functionality under same terms.

---

**Last Updated**: 2025-10-06
**Version**: 1.0
**Language**: C++14
**API Version**: TWS API 10.26.01
