# Auto Fibonacci Indicator - IBKR Python Version

Port of `AUTOFIB_TEST.mq5` (MetaTrader 5) to Interactive Brokers Python API

## Overview

This indicator automatically calculates Fibonacci retracement and extension levels based on recent price action, identifying key support/resistance zones and the "golden zone" for potential entry points.

## Features

### Core Functionality (Matching MQL5 Version)

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

4. **Output Options**
   - Formatted console reports
   - JSON export for analysis
   - Price position analysis (golden zone detection)

## Installation

### Prerequisites

1. **Interactive Brokers Account**
   - Paper trading or live account
   - TWS (Trader Workstation) or IB Gateway installed

2. **Python Environment**
   ```bash
   cd /home/ubuntu/ibkr-setup
   source ibkr_env/bin/activate
   ```

3. **Dependencies** (already installed)
   - `ibapi` - Interactive Brokers Python API
   - `pandas` - Data manipulation
   - `numpy` - Numerical calculations
   - `matplotlib` - Plotting (optional)

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

### Script Configuration

Edit `autofib_ibkr.py` to customize:

```python
# Connection settings
HOST = "127.0.0.1"
PORT = 7497  # Paper: 7497, Live: 7496
CLIENT_ID = 1

# Symbols to analyze
SYMBOLS = ["AAPL", "MSFT", "SPY"]

# Indicator parameters
indicator = AutoFibIndicator(
    bars_back=20,      # Lookback period
    start_bar=0,       # Starting offset
    fibo_levels=None   # Custom levels (optional)
)
```

## Usage

### Basic Usage

```bash
cd /home/ubuntu/ibkr-setup
source ibkr_env/bin/activate
python3 autofib_ibkr.py
```

### Programmatic Usage

```python
from autofib_ibkr import AutoFibIndicator, IBKRAutoFibClient
import pandas as pd

# Option 1: Standalone calculation (with your own data)
indicator = AutoFibIndicator(bars_back=20)

# Your DataFrame with columns: time, open, high, low, close, volume
bars = pd.DataFrame(your_price_data)

# Calculate Fibonacci levels
results = indicator.calculate(bars)
indicator.print_report()

# Get trading signal
signal = indicator.get_signal()  # Returns: 'BUY', 'SELL', 'HOLD', or 'NO_DATA'

# Option 2: With IBKR connection
client = IBKRAutoFibClient()
# Connect to TWS/Gateway...
results = client.run_indicator(symbol="AAPL", duration="1 D", bar_size="5 mins")
```

### Custom Fibonacci Levels

```python
custom_levels = {
    'level_0': 0.000,
    'level_1': 0.236,
    'level_2': 0.382,
    'level_3': 0.500,
    'level_4': 0.618,
    'level_5': 0.786,  # Custom level
    'level_6': 1.000,
    'level_7': 1.272,  # Custom extension
    'level_8': 1.618,
}

indicator = AutoFibIndicator(bars_back=20, fibo_levels=custom_levels)
```

## Output Examples

### Console Report

```
============================================================
AUTO FIBONACCI INDICATOR REPORT
============================================================
Timestamp: 2025-10-06T18:45:23.123456
Trend: BULLISH
High: 152.34 at 2025-10-06 15:30:00
Low:  148.21 at 2025-10-06 09:15:00
Range: 4.13
Current Price: 150.45

------------------------------------------------------------
FIBONACCI LEVELS:
------------------------------------------------------------
    0.0% ->   148.21
   23.6% ->   149.18
   38.2% ->   149.79
   50.0% ->   150.28
   61.8% ->   150.76
   76.4% ->   151.37
   88.6% ->   151.87
  100.0% ->   152.34
  161.8% ->   155.02
  261.8% ->   159.03

------------------------------------------------------------
GOLDEN ZONE (0.382 - 0.618):
------------------------------------------------------------
  Low:  149.79
  High: 150.76
  Price in Golden Zone: True

------------------------------------------------------------
SIGNAL: BUY
============================================================
```

### JSON Output

Results are automatically saved to timestamped JSON files:
```
/home/ubuntu/ibkr-setup/autofib_AAPL_20251006_184523.json
```

## Comparison: MQL5 vs Python IBKR

| Feature | MQL5 (MT5) | Python (IBKR) |
|---------|------------|---------------|
| Platform | MetaTrader 5 | Interactive Brokers |
| Language | MQL5 | Python 3 |
| Real-time plotting | ✓ Chart objects | ✗ Console/JSON only |
| Fibonacci calculation | ✓ Identical | ✓ Identical |
| Golden zone detection | ✓ Visual highlight | ✓ Boolean flag |
| Lookback period | ✓ Configurable | ✓ Configurable |
| Trend detection | ✓ Automatic | ✓ Automatic |
| Trading signals | ✗ Visual only | ✓ Programmatic |
| Data export | ✗ | ✓ JSON |
| Historical data | ✓ MT5 server | ✓ IBKR API |

## Files

- `autofib_ibkr.py` - Main indicator script
- `README.md` - This file
- `test_autofib.py` - Test script with sample data
- `ibkr_env/` - Python virtual environment

## Troubleshooting

### Connection Errors

**Error: "Connection error - ensure TWS/Gateway is running"**
- Start TWS or IB Gateway
- Verify API settings are enabled
- Check port number matches your configuration

**Error: "Timeout waiting for historical data"**
- Verify symbol is valid
- Check market hours (some data requires active trading)
- Ensure account has data permissions for the symbol

### Data Issues

**Error: "Not enough bars"**
- Reduce `bars_back` parameter
- Increase `duration` in `run_indicator()` call
- Use smaller `bar_size` (e.g., "1 min" instead of "5 mins")

**Error: "Invalid price data"**
- Symbol may not have data available
- Check if market is open
- Verify security type and exchange are correct

## Trading Signals

The indicator generates signals based on price position:

- **BUY**: Price in golden zone during bullish trend
- **SELL**: Price in golden zone during bearish trend
- **HOLD**: Price outside golden zone
- **NO_DATA**: Insufficient data or error

⚠️ **Disclaimer**: This is an educational tool. Signals should not be used as sole basis for trading decisions.

## Advanced Usage

### Real-time Updates

```python
# Monitor symbol continuously
while True:
    results = client.run_indicator(symbol="AAPL")
    signal = client.indicator.get_signal()

    if signal == 'BUY':
        print("🟢 BUY SIGNAL")
        # Place order logic here

    time.sleep(300)  # Update every 5 minutes
```

### Multiple Timeframes

```python
timeframes = [
    ("5 mins", "1 D"),
    ("15 mins", "3 D"),
    ("1 hour", "1 W"),
    ("1 day", "6 M")
]

for bar_size, duration in timeframes:
    results = client.run_indicator(
        symbol="AAPL",
        bar_size=bar_size,
        duration=duration
    )
    print(f"\n{bar_size} timeframe:")
    client.indicator.print_report()
```

## Support

For issues or questions:
- MQL5 original: http://www.xpworx.com
- IBKR API docs: https://interactivebrokers.github.io/tws-api/
- Python API: https://github.com/InteractiveBrokers/tws-api-public

## License

Educational use only. Original MQL5 code by Coders' Guru.
Python port maintains same functionality under same terms.

---

**Last Updated**: 2025-10-06
**Version**: 1.0
