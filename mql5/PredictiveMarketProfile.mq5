//+------------------------------------------------------------------+
//|                                       PredictiveMarketProfile.mq5 |
//|                             Copyright © 2025, Your Name           |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_type3   DRAW_LINE
#property indicator_color1  clrYellow // POC
#property indicator_color2  clrBlue   // VAH
#property indicator_color3  clrRed    // VAL
#property indicator_width1  2
#property indicator_width2  1
#property indicator_width3  1
#property indicator_label1  "POC"
#property indicator_label2  "VAH"
#property indicator_label3  "VAL"

// Inputs
input int SessionBars = 1440;         // Number of bars per session (1440 M1 bars = 1 day)
input int MomentumPeriod = 5;         // Lookback period for momentum
input double ValueAreaPercent = 70.0; // Value Area percentage
input bool ShowAlerts = true;         // Enable directional alerts
input int EMAPeriod = 50;             // Period for EMA trend context
input int VolumePeriod = 10;          // Period for average volume calculation

// Buffers
double POCBuffer[];
double VAHBuffer[];
double VALBuffer[];

// Global variables
double onetick; // Normalized tick size
int bars_per_session;
int ema_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   // Bind buffers to indicator plots
   SetIndexBuffer(0, POCBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, VAHBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, VALBuffer, INDICATOR_DATA);
   ArraySetAsSeries(POCBuffer, true);
   ArraySetAsSeries(VAHBuffer, true);
   ArraySetAsSeries(VALBuffer, true);

   // Calculate normalized tick size
   onetick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (onetick < tick_size) onetick = tick_size;
   if (onetick <= 0) onetick = 0.00001; // Fallback value

   // Adjust session bars based on timeframe
   int period_seconds = PeriodSeconds(_Period);
   if (period_seconds <= 0) period_seconds = 60; // Fallback to M1

   bars_per_session = (int)(SessionBars / (period_seconds / 60));
   if (bars_per_session < 1) bars_per_session = 1;

   Print("Bars per session: ", bars_per_session, " | Period seconds: ", period_seconds);

   // Create EMA handle
   ema_handle = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if (ema_handle == INVALID_HANDLE) {
      Print("Failed to create EMA handle");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "Predictive Market Profile");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "PMP_");
   if (ema_handle != INVALID_HANDLE) IndicatorRelease(ema_handle);
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

   if (rates_total < bars_per_session) return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);

   // Initialize buffers on first run
   if (prev_calculated == 0) {
      ArrayInitialize(POCBuffer, EMPTY_VALUE);
      ArrayInitialize(VAHBuffer, EMPTY_VALUE);
      ArrayInitialize(VALBuffer, EMPTY_VALUE);
   }

   // Copy EMA values
   double ema[];
   ArraySetAsSeries(ema, true);
   if (CopyBuffer(ema_handle, 0, 0, rates_total, ema) < rates_total) {
      Print("Failed to copy EMA buffer");
      return(prev_calculated);
   }

   // Process each session
   int start_bar = rates_total - 1;
   while (start_bar >= bars_per_session - 1) {
      int end_bar = start_bar - bars_per_session + 1;
      if (end_bar < 0) break;

      // Calculate session high and low
      double session_high = -DBL_MAX;
      double session_low = DBL_MAX;

      for (int i = start_bar; i >= end_bar; i--) {
         if (high[i] > session_high) session_high = high[i];
         if (low[i] < session_low) session_low = low[i];
      }

      if (session_high <= session_low || session_high <= 0 || session_low <= 0) {
         start_bar = end_bar - 1;
         continue;
      }

      int price_levels = (int)((session_high - session_low) / onetick) + 1;
      if (price_levels <= 0 || price_levels > 100000) { // Safety check
         start_bar = end_bar - 1;
         continue;
      }

      // Initialize volume profile array
      double volume_profile[];
      ArrayResize(volume_profile, price_levels);
      ArrayInitialize(volume_profile, 0.0);

      // Build Volume Profile using tick_volume
      for (int i = start_bar; i >= end_bar; i--) {
         double bar_low = low[i];
         double bar_high = high[i];
         int level_low = (int)((bar_low - session_low) / onetick);
         int level_high = (int)((bar_high - session_low) / onetick);

         if (level_low < 0) level_low = 0;
         if (level_high >= price_levels) level_high = price_levels - 1;

         int levels_covered = level_high - level_low + 1;
         if (levels_covered > 0 && tick_volume[i] > 0) {
            double vol_per_level = (double)tick_volume[i] / (double)levels_covered;
            for (int level = level_low; level <= level_high; level++) {
               if (level >= 0 && level < price_levels) {
                  volume_profile[level] += vol_per_level;
               }
            }
         }
      }

      // Find Point of Control (POC)
      int poc_level = 0;
      double max_volume = 0.0;
      for (int i = 0; i < price_levels; i++) {
         if (volume_profile[i] > max_volume) {
            max_volume = volume_profile[i];
            poc_level = i;
         }
      }

      double poc_price = session_low + poc_level * onetick;

      // Calculate Value Area (VA)
      double total_volume = 0.0;
      for (int i = 0; i < price_levels; i++) total_volume += volume_profile[i];

      if (total_volume <= 0) {
         start_bar = end_bar - 1;
         continue;
      }

      double va_volume = total_volume * (ValueAreaPercent / 100.0);
      double cumulative_volume = volume_profile[poc_level];
      int va_high_level = poc_level;
      int va_low_level = poc_level;

      while (cumulative_volume < va_volume && (va_high_level < price_levels - 1 || va_low_level > 0)) {
         double upper_volume = (va_high_level < price_levels - 1) ? volume_profile[va_high_level + 1] : 0.0;
         double lower_volume = (va_low_level > 0) ? volume_profile[va_low_level - 1] : 0.0;

         if (upper_volume > lower_volume && va_high_level < price_levels - 1) {
            va_high_level++;
            cumulative_volume += upper_volume;
         } else if (va_low_level > 0) {
            va_low_level--;
            cumulative_volume += lower_volume;
         } else {
            break;
         }
      }

      double va_high = session_low + va_high_level * onetick;
      double va_low = session_low + va_low_level * onetick;

      // Assign values to buffers
      for (int i = start_bar; i >= end_bar; i--) {
         POCBuffer[i] = poc_price;
         VAHBuffer[i] = va_high;
         VALBuffer[i] = va_low;
      }

      // Predict direction for the latest session
      if (start_bar == rates_total - 1 && rates_total > MomentumPeriod && rates_total > VolumePeriod) {
         double momentum = close[0] - close[MomentumPeriod];

         double avg_volume = 0.0;
         for (int k = 1; k <= VolumePeriod; k++) {
            avg_volume += (double)tick_volume[k];
         }
         avg_volume /= VolumePeriod;

         PredictDirection(
            close[0], poc_price, va_high, va_low, momentum,
            (double)tick_volume[0], avg_volume, ema[0],
            high[0], low[0], close[1],
            time[0], rates_total, prev_calculated
         );
      }

      start_bar = end_bar - 1;
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Predict price direction based on momentum and key levels         |
//+------------------------------------------------------------------+
void PredictDirection(double current_price, double poc, double vah, double val,
                     double momentum, double current_volume, double avg_volume,
                     double ema, double high, double low, double prev_close,
                     datetime time, int rates_total, int prev_calculated) {
   string prediction = "Neutral";
   double momentum_threshold = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10; // Dynamic threshold

   // Breakout logic with volume confirmation and trend context
   if (current_price > vah && momentum > momentum_threshold && current_volume > avg_volume && current_price > ema) {
      prediction = "Up (Breakout Above VAH)";
   } else if (current_price < val && momentum < -momentum_threshold && current_volume > avg_volume && current_price < ema) {
      prediction = "Down (Breakout Below VAL)";
   }
   // Rejection patterns
   else if (high >= vah && current_price < vah && current_volume > avg_volume && prev_close < vah) {
      prediction = "Down (Rejection at VAH)";
   } else if (low <= val && current_price > val && current_volume > avg_volume && prev_close > val) {
      prediction = "Up (Rejection at VAL)";
   }
   // Movement toward VAH/VAL
   else if (current_price > poc && current_price < vah) {
      prediction = "Up (Toward VAH)";
   } else if (current_price < poc && current_price > val) {
      prediction = "Down (Toward VAL)";
   } else if (MathAbs(momentum) < momentum_threshold && current_price >= val && current_price <= vah) {
      prediction = "Consolidation";
   }

   // Display prediction on chart
   string obj_name = "PMP_Prediction";
   if (ObjectFind(0, obj_name) < 0) {
      ObjectCreate(0, obj_name, OBJ_TEXT, 0, time, current_price);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   }
   ObjectMove(0, obj_name, 0, time, current_price + onetick * 10);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, "Prediction: " + prediction + " | Mom: " + DoubleToString(momentum, 5));

   // Trigger alert if enabled and prediction changed
   static string last_prediction = "";
   if (ShowAlerts && prediction != last_prediction && prediction != "Neutral") {
      Alert("Predictive MP: " + _Symbol + " - " + prediction + " at " + DoubleToString(current_price, _Digits));
      last_prediction = prediction;
   }
}

//+------------------------------------------------------------------+
