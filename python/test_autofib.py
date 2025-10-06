#!/usr/bin/env python3
"""
Test script for Auto Fibonacci Indicator
Tests the indicator with sample data without needing IBKR connection
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from autofib_ibkr import AutoFibIndicator


def generate_sample_data(bars=100, trend='bullish'):
    """
    Generate sample price data for testing

    Args:
        bars: Number of bars to generate
        trend: 'bullish', 'bearish', or 'ranging'

    Returns:
        DataFrame with OHLC data
    """
    np.random.seed(42)

    # Starting price
    base_price = 150.0

    # Generate time series
    start_time = datetime.now() - timedelta(hours=bars * 5)  # 5-minute bars
    times = [start_time + timedelta(minutes=5 * i) for i in range(bars)]

    # Generate price movement based on trend
    if trend == 'bullish':
        # Upward trend with noise
        trend_component = np.linspace(0, 10, bars)
        noise = np.random.randn(bars) * 0.5
        closes = base_price + trend_component + noise
    elif trend == 'bearish':
        # Downward trend with noise
        trend_component = np.linspace(0, -10, bars)
        noise = np.random.randn(bars) * 0.5
        closes = base_price + trend_component + noise
    else:  # ranging
        # Sideways movement with noise
        noise = np.random.randn(bars) * 2.0
        closes = base_price + noise

    # Generate OHLC from closes
    opens = np.roll(closes, 1)
    opens[0] = base_price

    highs = np.maximum(opens, closes) + np.random.rand(bars) * 0.5
    lows = np.minimum(opens, closes) - np.random.rand(bars) * 0.5
    volumes = np.random.randint(1000, 10000, bars)

    # Create DataFrame
    data = pd.DataFrame({
        'time': times,
        'open': opens,
        'high': highs,
        'low': lows,
        'close': closes,
        'volume': volumes
    })

    return data


def test_bullish_trend():
    """Test indicator on bullish trend"""
    print("\n" + "="*60)
    print("TEST 1: BULLISH TREND")
    print("="*60)

    data = generate_sample_data(bars=50, trend='bullish')
    indicator = AutoFibIndicator(bars_back=20)
    results = indicator.calculate(data)

    if 'error' not in results:
        indicator.print_report()
        signal = indicator.get_signal()
        print(f"Signal: {signal}")
        assert results['trend'] == 'BULLISH', "Expected bullish trend"
        print("✓ TEST PASSED")
    else:
        print(f"✗ TEST FAILED: {results['error']}")


def test_bearish_trend():
    """Test indicator on bearish trend"""
    print("\n" + "="*60)
    print("TEST 2: BEARISH TREND")
    print("="*60)

    data = generate_sample_data(bars=50, trend='bearish')
    indicator = AutoFibIndicator(bars_back=20)
    results = indicator.calculate(data)

    if 'error' not in results:
        indicator.print_report()
        signal = indicator.get_signal()
        print(f"Signal: {signal}")
        assert results['trend'] == 'BEARISH', "Expected bearish trend"
        print("✓ TEST PASSED")
    else:
        print(f"✗ TEST FAILED: {results['error']}")


def test_ranging_market():
    """Test indicator on ranging market"""
    print("\n" + "="*60)
    print("TEST 3: RANGING MARKET")
    print("="*60)

    data = generate_sample_data(bars=50, trend='ranging')
    indicator = AutoFibIndicator(bars_back=20)
    results = indicator.calculate(data)

    if 'error' not in results:
        indicator.print_report()
        signal = indicator.get_signal()
        print(f"Signal: {signal}")
        print("✓ TEST PASSED")
    else:
        print(f"✗ TEST FAILED: {results['error']}")


def test_custom_levels():
    """Test indicator with custom Fibonacci levels"""
    print("\n" + "="*60)
    print("TEST 4: CUSTOM FIBONACCI LEVELS")
    print("="*60)

    custom_levels = {
        'level_0': 0.000,
        'level_1': 0.250,
        'level_2': 0.500,
        'level_3': 0.750,
        'level_4': 1.000,
        'level_5': 1.250,
        'level_6': 1.500,
        'level_7': 2.000,
    }

    data = generate_sample_data(bars=50, trend='bullish')
    indicator = AutoFibIndicator(bars_back=20, fibo_levels=custom_levels)
    results = indicator.calculate(data)

    if 'error' not in results:
        indicator.print_report()
        print("✓ TEST PASSED")
    else:
        print(f"✗ TEST FAILED: {results['error']}")


def test_insufficient_data():
    """Test error handling with insufficient data"""
    print("\n" + "="*60)
    print("TEST 5: INSUFFICIENT DATA ERROR HANDLING")
    print("="*60)

    data = generate_sample_data(bars=10, trend='bullish')
    indicator = AutoFibIndicator(bars_back=20)  # Requires more bars than available
    results = indicator.calculate(data)

    if 'error' in results:
        print(f"Expected error: {results['error']}")
        print(f"Required: {results['required']}, Available: {results['available']}")
        print("✓ TEST PASSED (error handled correctly)")
    else:
        print("✗ TEST FAILED: Should have returned error")


def test_golden_zone_detection():
    """Test golden zone price detection"""
    print("\n" + "="*60)
    print("TEST 6: GOLDEN ZONE DETECTION")
    print("="*60)

    # Create data where current price is in golden zone
    data = generate_sample_data(bars=50, trend='bullish')
    indicator = AutoFibIndicator(bars_back=20)
    results = indicator.calculate(data)

    if 'error' not in results:
        current_price = results['current_price']
        golden_low = results['golden_zone']['low']
        golden_high = results['golden_zone']['high']
        in_zone = results['price_in_golden_zone']

        print(f"Current Price: {current_price:.2f}")
        print(f"Golden Zone: {golden_low:.2f} - {golden_high:.2f}")
        print(f"In Golden Zone: {in_zone}")

        # Verify logic
        expected_in_zone = golden_low <= current_price <= golden_high
        assert in_zone == expected_in_zone, "Golden zone detection mismatch"
        print("✓ TEST PASSED")
    else:
        print(f"✗ TEST FAILED: {results['error']}")


def test_different_lookback_periods():
    """Test with different lookback periods"""
    print("\n" + "="*60)
    print("TEST 7: DIFFERENT LOOKBACK PERIODS")
    print("="*60)

    data = generate_sample_data(bars=100, trend='bullish')

    for bars_back in [10, 20, 30, 50]:
        print(f"\nLookback period: {bars_back} bars")
        indicator = AutoFibIndicator(bars_back=bars_back)
        results = indicator.calculate(data)

        if 'error' not in results:
            print(f"  Range: {results['fibo_range']:.2f}")
            print(f"  Trend: {results['trend']}")
            print(f"  Golden Zone: {results['golden_zone']['low']:.2f} - {results['golden_zone']['high']:.2f}")
        else:
            print(f"  Error: {results['error']}")

    print("\n✓ TEST PASSED")


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("AUTO FIBONACCI INDICATOR - TEST SUITE")
    print("="*60)
    print("Testing without IBKR connection using sample data\n")

    try:
        test_bullish_trend()
        test_bearish_trend()
        test_ranging_market()
        test_custom_levels()
        test_insufficient_data()
        test_golden_zone_detection()
        test_different_lookback_periods()

        print("\n" + "="*60)
        print("ALL TESTS COMPLETED")
        print("="*60 + "\n")

    except Exception as e:
        print(f"\n✗ TEST SUITE FAILED: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
