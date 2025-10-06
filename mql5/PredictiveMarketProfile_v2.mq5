//+------------------------------------------------------------------+
//|                            PredictiveMarketProfile_v2.mq5        |
//|                             Copyright © 2025, WIRERIGG           |
//|                    REFACTORED for real-time updates              |
//+------------------------------------------------------------------+
#property copyright "WIRERIGG"
#property link      "https://github.com/WIRERIGG"
#property version   "2.00"
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
double onetick;
int bars_per_session;
int ema_handle;
string prefix_unique;

// Static variables for session tracking
static datetime last_session_time = 0;
static double last_poc = 0;
static double last_vah = 0;
static double last_val = 0;
static string last_prediction = "";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   // Bind buffers to indicator plots
   SetIndexBuffer(0, POCBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, VAHBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, VALBuffer, INDICATOR_DATA);

   // Set drawing begin for plots
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, SessionBars);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, SessionBars);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, SessionBars);

   // Calculate normalized tick size
   onetick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (onetick < tick_size) onetick = tick_size;
   if (onetick <= 0) onetick = 0.00001;

   // Adjust session bars based on timeframe
   int period_seconds = PeriodSeconds(_Period);
   if (period_seconds <= 0) period_seconds = 60;
   bars_per_session = (int)(SessionBars / (period_seconds / 60));
   if (bars_per_session < 1) bars_per_session = 1;

   // Create unique prefix for objects
   prefix_unique = "PMP_" + IntegerToString(GetTickCount64() % 10000);

   // Create EMA handle
   ema_handle = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if (ema_handle == INVALID_HANDLE) {
      Print("Failed to create EMA handle");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "Predictive Market Profile v2");
   Print("Predictive Market Profile v2 started. Bars per session: ", bars_per_session);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, prefix_unique);
   if (ema_handle != INVALID_HANDLE) IndicatorRelease(ema_handle);
   ChartRedraw(0);
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

   // Check if we need a full recalculation
   bool full_recalc = (prev_calculated == 0);

   // Get current session time
   datetime current_session = GetSessionTime(time, rates_total - 1);

   // Check if new session started
   bool new_session = (current_session != last_session_time);

   // If it's a new session or first calculation, recalculate session
   if (full_recalc || new_session) {
      if (CalculateSession(rates_total, time, high, low, close, tick_volume)) {
         last_session_time = current_session;
      }
   }

   // Calculate start position for incremental update
   int start = prev_calculated;
   if (start > 0) start--;  // Recalculate last bar
   else start = bars_per_session; // First run

   // Update buffers incrementally
   for (int i = start; i < rates_total; i++) {
      POCBuffer[i] = last_poc;
      VAHBuffer[i] = last_vah;
      VALBuffer[i] = last_val;
   }

   // Update prediction only for current bar (rates_total - 1)
   if (rates_total > MomentumPeriod && rates_total > VolumePeriod && rates_total > EMAPeriod) {
      double ema[];
      ArraySetAsSeries(ema, true);
      if (CopyBuffer(ema_handle, 0, 0, EMAPeriod + 1, ema) > EMAPeriod) {
         UpdatePrediction(rates_total, time, high, low, close, tick_volume, ema[0]);
      }
   }

   // Redraw chart objects
   if (full_recalc || new_session || rates_total > prev_calculated) {
      ChartRedraw(0);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get session time (beginning of day)                              |
//+------------------------------------------------------------------+
datetime GetSessionTime(const datetime &time[], int index) {
   MqlDateTime dt;
   TimeToStruct(time[index], dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Calculate session volume profile                                 |
//+------------------------------------------------------------------+
bool CalculateSession(const int rates_total,
                     const datetime &time[],
                     const double &high[],
                     const double &low[],
                     const double &close[],
                     const long &tick_volume[]) {

   int start_bar = rates_total - 1;
   int end_bar = start_bar - bars_per_session + 1;
   if (end_bar < 0) end_bar = 0;

   // Calculate session high and low
   double session_high = -DBL_MAX;
   double session_low = DBL_MAX;

   for (int i = start_bar; i >= end_bar; i--) {
      if (high[i] > session_high) session_high = high[i];
      if (low[i] < session_low) session_low = low[i];
   }

   if (session_high <= session_low || session_high <= 0 || session_low <= 0) {
      return false;
   }

   int price_levels = (int)((session_high - session_low) / onetick) + 1;
   if (price_levels <= 0 || price_levels > 100000) {
      return false;
   }

   // Initialize volume profile array
   double volume_profile[];
   ArrayResize(volume_profile, price_levels);
   ArrayInitialize(volume_profile, 0.0);

   // Build Volume Profile
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

   last_poc = session_low + poc_level * onetick;

   // Calculate Value Area (VA)
   double total_volume = 0.0;
   for (int i = 0; i < price_levels; i++) total_volume += volume_profile[i];

   if (total_volume <= 0) {
      return false;
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

   last_vah = session_low + va_high_level * onetick;
   last_val = session_low + va_low_level * onetick;

   return true;
}

//+------------------------------------------------------------------+
//| Update prediction for current bar                                |
//+------------------------------------------------------------------+
void UpdatePrediction(const int rates_total,
                     const datetime &time[],
                     const double &high[],
                     const double &low[],
                     const double &close[],
                     const long &tick_volume[],
                     double ema) {

   int current = rates_total - 1;
   double current_price = close[current];
   double momentum = close[current] - close[current - MomentumPeriod];

   // Calculate average volume
   double avg_volume = 0.0;
   for (int k = 1; k <= VolumePeriod; k++) {
      avg_volume += (double)tick_volume[current - k];
   }
   avg_volume /= VolumePeriod;

   double current_volume = (double)tick_volume[current];
   double momentum_threshold = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

   string prediction = "Neutral";

   // Breakout logic
   if (current_price > last_vah && momentum > momentum_threshold && current_volume > avg_volume && current_price > ema) {
      prediction = "Up (Breakout Above VAH)";
   } else if (current_price < last_val && momentum < -momentum_threshold && current_volume > avg_volume && current_price < ema) {
      prediction = "Down (Breakout Below VAL)";
   }
   // Rejection patterns
   else if (high[current] >= last_vah && current_price < last_vah && current_volume > avg_volume && close[current - 1] < last_vah) {
      prediction = "Down (Rejection at VAH)";
   } else if (low[current] <= last_val && current_price > last_val && current_volume > avg_volume && close[current - 1] > last_val) {
      prediction = "Up (Rejection at VAL)";
   }
   // Movement toward VAH/VAL
   else if (current_price > last_poc && current_price < last_vah) {
      prediction = "Up (Toward VAH)";
   } else if (current_price < last_poc && current_price > last_val) {
      prediction = "Down (Toward VAL)";
   } else if (MathAbs(momentum) < momentum_threshold && current_price >= last_val && current_price <= last_vah) {
      prediction = "Consolidation";
   }

   // Only update object if prediction changed
   if (prediction != last_prediction) {
      string obj_name = prefix_unique + "_Prediction";
      if (ObjectFind(0, obj_name) < 0) {
         ObjectCreate(0, obj_name, OBJ_TEXT, 0, time[current], current_price);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      }
      ObjectMove(0, obj_name, 0, time[current], current_price + onetick * 10);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, "Prediction: " + prediction + " | Mom: " + DoubleToString(momentum, 5));

      // Trigger alert if enabled
      if (ShowAlerts && prediction != "Neutral" && prediction != last_prediction) {
         Alert("Predictive MP: " + _Symbol + " - " + prediction + " at " + DoubleToString(current_price, _Digits));
      }

      last_prediction = prediction;
   }
}
//+------------------------------------------------------------------+
