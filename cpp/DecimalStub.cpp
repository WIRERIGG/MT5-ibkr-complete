/**
 * Decimal Stub Implementation
 * Provides stub implementations for Decimal functions
 * (IBKR's Decimal.cpp requires Intel BID library which we don't have)
 */

#include "Decimal.h"
#include <sstream>
#include <cstdlib>

// Stub implementations - just convert to/from double
Decimal DecimalFunctions::add(Decimal decimal1, Decimal decimal2) {
    return decimal1 + decimal2;
}

Decimal DecimalFunctions::sub(Decimal decimal1, Decimal decimal2) {
    return decimal1 - decimal2;
}

Decimal DecimalFunctions::mul(Decimal decimal1, Decimal decimal2) {
    return decimal1 * decimal2;
}

Decimal DecimalFunctions::div(Decimal decimal1, Decimal decimal2) {
    if (decimal2 == 0) return 0;
    return decimal1 / decimal2;
}

double DecimalFunctions::decimalToDouble(Decimal decimal) {
    // Simple conversion - treat as double bits
    return (double)decimal;
}

Decimal DecimalFunctions::doubleToDecimal(double d) {
    // Simple conversion - treat as unsigned long long
    return (Decimal)d;
}

Decimal DecimalFunctions::stringToDecimal(std::string str) {
    // Convert string to decimal via double
    double d = std::stod(str);
    return (Decimal)(d * 1000000); // Store as integer with 6 decimal places
}

std::string DecimalFunctions::decimalToString(Decimal value) {
    // Convert decimal to string via double
    if (value == UNSET_DECIMAL) {
        return "";
    }
    double d = (double)value / 1000000.0;
    std::ostringstream oss;
    oss << d;
    return oss.str();
}

std::string DecimalFunctions::decimalStringToDisplay(Decimal value) {
    return decimalToString(value);
}
