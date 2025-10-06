#!/usr/bin/env python3
"""
Auto Fibonacci Indicator for Interactive Brokers
Port of AUTOFIB_TEST.mq5 to IBKR Python API

This indicator:
- Finds highest and lowest price points in a lookback period
- Calculates Fibonacci retracement levels (0.236, 0.382, 0.5, 0.618, 0.764, 0.886, 1.0)
- Calculates Fibonacci extension levels (1.618, 2.618)
- Identifies the "golden zone" (0.382 to 0.618)
- Provides trend direction (bullish/bearish)

Author: Ported from MQL5 for IBKR
Last Modified: 2025-10-06
"""

from ibapi.client import EClient
from ibapi.wrapper import EWrapper
from ibapi.contract import Contract
from ibapi.common import BarData
import threading
import time
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import List, Dict, Tuple, Optional
import json


class AutoFibIndicator:
    """
    Auto Fibonacci Indicator Calculator
    Replicates functionality from AUTOFIB_TEST.mq5
    """

    def __init__(
        self,
        bars_back: int = 20,
        start_bar: int = 0,
        fibo_levels: Optional[Dict[str, float]] = None
    ):
        """
        Initialize the Auto Fibonacci Indicator

        Args:
            bars_back: Number of bars to look back for high/low (default 20)
            start_bar: Starting bar offset (default 0)
            fibo_levels: Custom Fibonacci levels (optional)
        """
        self.bars_back = bars_back
        self.start_bar = start_bar

        # Default Fibonacci levels (matching MQL5 version)
        if fibo_levels is None:
            self.fibo_levels = {
                'level_0': 0.000,
                'level_1': 0.236,
                'level_2': 0.382,
                'level_3': 0.500,
                'level_4': 0.618,
                'level_5': 0.764,
                'level_6': 0.886,
                'level_7': 1.000,
                'level_8': 1.618,  # Extension
                'level_9': 2.618   # Extension
            }
        else:
            self.fibo_levels = fibo_levels

        # Cache variables (matching MQL5 optimization)
        self.last_lowest_bar = -1
        self.last_highest_bar = -1
        self.last_high_value = 0
        self.last_low_value = 0
        self.last_is_bullish = True

        # Results storage
        self.results = {}

    def calculate(self, bars: pd.DataFrame) -> Dict:
        """
        Calculate Fibonacci levels from price bars

        Args:
            bars: DataFrame with columns ['time', 'open', 'high', 'low', 'close', 'volume']

        Returns:
            Dictionary containing Fibonacci levels and analysis
        """
        if len(bars) < self.bars_back + self.start_bar:
            return {
                'error': 'Not enough bars',
                'required': self.bars_back + self.start_bar,
                'available': len(bars)
            }

        # Find highest and lowest bars in lookback period
        lookback_bars = bars.iloc[self.start_bar:self.start_bar + self.bars_back]

        lowest_idx = lookback_bars['low'].idxmin()
        highest_idx = lookback_bars['high'].idxmax()

        low_value = lookback_bars.loc[lowest_idx, 'low']
        high_value = lookback_bars.loc[highest_idx, 'high']
        low_time = lookback_bars.loc[lowest_idx, 'time']
        high_time = lookback_bars.loc[highest_idx, 'time']

        # Validate price data
        if high_value <= 0 or low_value <= 0 or high_value <= low_value:
            return {
                'error': 'Invalid price data',
                'high': high_value,
                'low': low_value
            }

        # Determine trend direction (bullish if high came after low)
        is_bullish = high_time > low_time

        # Calculate Fibonacci range
        fibo_range = high_value - low_value

        # Calculate all Fibonacci levels
        fibo_prices = {}

        if is_bullish:
            # Bullish: levels calculated from low upward
            for level_name, level_value in self.fibo_levels.items():
                fibo_prices[level_name] = low_value + (fibo_range * level_value)
        else:
            # Bearish: levels calculated from high downward
            for level_name, level_value in self.fibo_levels.items():
                fibo_prices[level_name] = high_value - (fibo_range * level_value)

        # Calculate golden zone boundaries (0.382 to 0.618)
        if is_bullish:
            golden_zone_low = low_value + (fibo_range * self.fibo_levels['level_2'])
            golden_zone_high = low_value + (fibo_range * self.fibo_levels['level_4'])
        else:
            golden_zone_low = high_value - (fibo_range * self.fibo_levels['level_4'])
            golden_zone_high = high_value - (fibo_range * self.fibo_levels['level_2'])

        # Store results
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'trend': 'BULLISH' if is_bullish else 'BEARISH',
            'high_value': high_value,
            'low_value': low_value,
            'high_time': str(high_time),
            'low_time': str(low_time),
            'high_bar_index': int(highest_idx),
            'low_bar_index': int(lowest_idx),
            'fibo_range': fibo_range,
            'fibo_levels': fibo_prices,
            'golden_zone': {
                'low': golden_zone_low,
                'high': golden_zone_high
            },
            'current_price': float(bars.iloc[-1]['close']),
            'price_in_golden_zone': golden_zone_low <= bars.iloc[-1]['close'] <= golden_zone_high
        }

        # Update cache
        self.last_lowest_bar = lowest_idx
        self.last_highest_bar = highest_idx
        self.last_high_value = high_value
        self.last_low_value = low_value
        self.last_is_bullish = is_bullish

        return self.results

    def get_signal(self) -> str:
        """
        Get trading signal based on price position relative to Fibonacci levels

        Returns:
            Signal string: 'BUY', 'SELL', 'HOLD', or 'NO_DATA'
        """
        if not self.results or 'error' in self.results:
            return 'NO_DATA'

        current_price = self.results['current_price']
        golden_zone_low = self.results['golden_zone']['low']
        golden_zone_high = self.results['golden_zone']['high']
        is_bullish = self.results['trend'] == 'BULLISH'

        # Trading logic: Buy in golden zone during uptrend
        if self.results['price_in_golden_zone']:
            if is_bullish:
                return 'BUY'
            else:
                return 'SELL'

        return 'HOLD'

    def print_report(self):
        """Print formatted Fibonacci analysis report"""
        if not self.results or 'error' in self.results:
            print("ERROR:", self.results.get('error', 'No data available'))
            return

        print("\n" + "="*60)
        print("AUTO FIBONACCI INDICATOR REPORT")
        print("="*60)
        print(f"Timestamp: {self.results['timestamp']}")
        print(f"Trend: {self.results['trend']}")
        print(f"High: {self.results['high_value']:.2f} at {self.results['high_time']}")
        print(f"Low:  {self.results['low_value']:.2f} at {self.results['low_time']}")
        print(f"Range: {self.results['fibo_range']:.2f}")
        print(f"Current Price: {self.results['current_price']:.2f}")
        print("\n" + "-"*60)
        print("FIBONACCI LEVELS:")
        print("-"*60)

        for level_name in sorted(self.results['fibo_levels'].keys()):
            level_price = self.results['fibo_levels'][level_name]
            level_pct = self.fibo_levels[level_name] * 100
            print(f"  {level_pct:6.1f}% -> {level_price:8.2f}")

        print("\n" + "-"*60)
        print("GOLDEN ZONE (0.382 - 0.618):")
        print("-"*60)
        print(f"  Low:  {self.results['golden_zone']['low']:.2f}")
        print(f"  High: {self.results['golden_zone']['high']:.2f}")
        print(f"  Price in Golden Zone: {self.results['price_in_golden_zone']}")

        signal = self.get_signal()
        print("\n" + "-"*60)
        print(f"SIGNAL: {signal}")
        print("="*60 + "\n")


class IBKRAutoFibClient(EWrapper, EClient):
    """
    Interactive Brokers API Client with Auto Fibonacci Indicator
    """

    def __init__(self):
        EClient.__init__(self, self)
        self.data = []
        self.data_ready = threading.Event()
        self.indicator = AutoFibIndicator(bars_back=20)

    def error(self, reqId, errorCode, errorString, advancedOrderRejectJson=""):
        """Handle error messages"""
        print(f"Error {errorCode}: {errorString}")
        if errorCode in [502, 503]:  # Connection errors
            print("Connection error - ensure TWS/Gateway is running")

    def historicalData(self, reqId, bar: BarData):
        """Receive historical bar data"""
        self.data.append({
            'time': bar.date,
            'open': bar.open,
            'high': bar.high,
            'low': bar.low,
            'close': bar.close,
            'volume': bar.volume
        })

    def historicalDataEnd(self, reqId, start, end):
        """Called when all historical data received"""
        print(f"Historical data received: {len(self.data)} bars")
        self.data_ready.set()

    def get_historical_data(
        self,
        symbol: str,
        sec_type: str = "STK",
        exchange: str = "SMART",
        currency: str = "USD",
        duration: str = "1 D",
        bar_size: str = "5 mins"
    ) -> pd.DataFrame:
        """
        Request historical data from IBKR

        Args:
            symbol: Ticker symbol
            sec_type: Security type (STK, FUT, OPT, etc.)
            exchange: Exchange (SMART, NYSE, NASDAQ, etc.)
            currency: Currency code
            duration: Duration string (e.g., "1 D", "1 W", "1 M")
            bar_size: Bar size (e.g., "1 min", "5 mins", "1 hour", "1 day")

        Returns:
            DataFrame with historical bars
        """
        contract = Contract()
        contract.symbol = symbol
        contract.secType = sec_type
        contract.exchange = exchange
        contract.currency = currency

        self.data = []
        self.data_ready.clear()

        # Request historical data
        self.reqHistoricalData(
            reqId=1,
            contract=contract,
            endDateTime='',
            durationStr=duration,
            barSizeSetting=bar_size,
            whatToShow='TRADES',
            useRTH=1,
            formatDate=1,
            keepUpToDate=False,
            chartOptions=[]
        )

        # Wait for data with timeout
        if not self.data_ready.wait(timeout=30):
            print("Timeout waiting for historical data")
            return pd.DataFrame()

        return pd.DataFrame(self.data)

    def run_indicator(
        self,
        symbol: str,
        sec_type: str = "STK",
        exchange: str = "SMART",
        currency: str = "USD",
        duration: str = "1 D",
        bar_size: str = "5 mins"
    ) -> Dict:
        """
        Run Auto Fibonacci indicator on symbol

        Args:
            symbol: Ticker symbol
            sec_type: Security type
            exchange: Exchange
            currency: Currency
            duration: Historical data duration
            bar_size: Bar size

        Returns:
            Fibonacci analysis results
        """
        print(f"\nFetching data for {symbol}...")
        bars = self.get_historical_data(symbol, sec_type, exchange, currency, duration, bar_size)

        if bars.empty:
            return {'error': 'No data received'}

        print(f"Calculating Fibonacci levels...")
        results = self.indicator.calculate(bars)

        return results


def run_api_thread(client: IBKRAutoFibClient, host: str, port: int, client_id: int):
    """Run the API in a separate thread"""
    client.connect(host, port, client_id)
    client.run()


def main():
    """
    Main function - Example usage
    """
    print("="*60)
    print("AUTO FIBONACCI INDICATOR FOR INTERACTIVE BROKERS")
    print("="*60)
    print("\nPort of AUTOFIB_TEST.mq5 to IBKR Python API")
    print("Ensure TWS or IB Gateway is running before proceeding.\n")

    # Configuration
    HOST = "127.0.0.1"
    PORT = 7497  # Paper trading: 7497, Live: 7496
    CLIENT_ID = 1

    # Symbols to analyze
    SYMBOLS = ["AAPL", "MSFT", "SPY"]

    # Create client
    client = IBKRAutoFibClient()

    # Start API thread
    api_thread = threading.Thread(
        target=run_api_thread,
        args=(client, HOST, PORT, CLIENT_ID),
        daemon=True
    )
    api_thread.start()

    # Wait for connection
    print(f"Connecting to TWS/Gateway at {HOST}:{PORT}...")
    time.sleep(2)

    if not client.isConnected():
        print("\n❌ CONNECTION FAILED")
        print("Please ensure TWS or IB Gateway is running and accepting API connections.")
        print("\nSetup instructions:")
        print("1. Open TWS or IB Gateway")
        print("2. Navigate to: Edit -> Global Configuration -> API -> Settings")
        print("3. Enable 'Enable ActiveX and Socket Clients'")
        print(f"4. Ensure port {PORT} is configured")
        print("5. Add 127.0.0.1 to trusted IP addresses")
        return

    print("✓ Connected successfully\n")

    # Run indicator on multiple symbols
    for symbol in SYMBOLS:
        try:
            results = client.run_indicator(
                symbol=symbol,
                duration="1 D",
                bar_size="5 mins"
            )

            if 'error' not in results:
                client.indicator.print_report()

                # Save results to JSON
                filename = f"/home/ubuntu/ibkr-setup/autofib_{symbol}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                with open(filename, 'w') as f:
                    json.dump(results, f, indent=2)
                print(f"Results saved to: {filename}\n")
            else:
                print(f"Error analyzing {symbol}: {results['error']}\n")

            time.sleep(1)  # Rate limiting

        except Exception as e:
            print(f"Error processing {symbol}: {e}\n")

    # Disconnect
    print("Disconnecting...")
    client.disconnect()
    print("✓ Done\n")


if __name__ == "__main__":
    main()
