//+------------------------------------------------------------------+
//|                                                AUTOFIB TEST.mq5 |
//|                                        Developed by Coders' Guru |
//|                                            http://www.xpworx.com |
//|                                        Modified for Auto Trend   |
//|                                        Last Modified: 2025.04.19 |
//|                                        Optimized Version         |
//+------------------------------------------------------------------+
#property copyright "Coders' Guru, Modified for Auto Trend"
#property link      "http://www.xpworx.com"
#property version   "2.10"
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   10
//+------------------------------------------------------------------+
input double Fibo_Level_1 = 0.236;
input double Fibo_Level_2 = 0.382;
input double Fibo_Level_3 = 0.500;
input double Fibo_Level_4 = 0.618;
input double Fibo_Level_5 = 0.764;
input double Fibo_Level_6 = 0.886;
input double Fibo_Level_7 = 1.000;
input double Fibo_Level_8 = 1.618; // Extension level
input double Fibo_Level_9 = 2.618; // Extension level
input int    StartBar     = 0;
input int    BarsBack     = 20;
input bool   Pause        = false;
input color  VerticalLinesColor = clrRed;          // Color for vertical lines and 0.0 level
input color  TrendLineColor     = clrRed;          // Color for trend line
input color  FiboBaseColor      = clrBlue;         // Color for base Fibonacci levels
input color  GoldenZoneColor    = clrGold;         // Color for golden zone (0.382, 0.5, 0.618)
input color  ExtensionColor     = clrGreenYellow;  // Color for extension levels (1.618, 2.618)
input color  GoldenZoneBgColor  = clrGold;         // Background color for golden zone
input uchar  GoldenZoneOpacity  = 50;              // Opacity for golden zone background (0-255)
//+------------------------------------------------------------------+
double Fibo_Level_0 = 0.000;
//+------------------------------------------------------------------+
double f_1[], f_2[], f_3[], f_4[], f_5[], f_6[], f_7[], f_8[], f_9[], f_10[];
//+------------------------------------------------------------------+
// Cache variables to avoid redundant calculations
static int last_lowest_bar = -1;
static int last_highest_bar = -1;
static double last_high_value = 0;
static double last_low_value = 0;
static bool last_is_bullish = true;
static int last_rates_total = 0;
//+------------------------------------------------------------------+
#define MODE_OPEN 0
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_CLOSE 3
#define MODE_VOLUME 4
#define MODE_TIME 5
#define MODE_REAL_VOLUME 5
//+------------------------------------------------------------------+
// Object name constants
const string OBJ_VLINE_HIGH = "v_high";
const string OBJ_VLINE_LOW = "v_low";
const string OBJ_TREND_NAME = "trend_hl";
const string OBJ_FIBO_NAME = "Fibo_hl";
const string OBJ_RECT_NAME = "GoldenZoneBg";

//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, f_1, INDICATOR_DATA);
   SetIndexBuffer(1, f_2, INDICATOR_DATA);
   SetIndexBuffer(2, f_3, INDICATOR_DATA);
   SetIndexBuffer(3, f_4, INDICATOR_DATA);
   SetIndexBuffer(4, f_5, INDICATOR_DATA);
   SetIndexBuffer(5, f_6, INDICATOR_DATA);
   SetIndexBuffer(6, f_7, INDICATOR_DATA);
   SetIndexBuffer(7, f_8, INDICATOR_DATA);
   SetIndexBuffer(8, f_9, INDICATOR_DATA);
   SetIndexBuffer(9, f_10, INDICATOR_DATA);

   // Set plot labels
   PlotIndexSetString(0, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_0, 3));
   PlotIndexSetString(1, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_1, 3));
   PlotIndexSetString(2, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_2, 3));
   PlotIndexSetString(3, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_3, 3));
   PlotIndexSetString(4, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_4, 3));
   PlotIndexSetString(5, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_5, 3));
   PlotIndexSetString(6, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_6, 3));
   PlotIndexSetString(7, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_7, 3));
   PlotIndexSetString(8, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_8, 3));
   PlotIndexSetString(9, PLOT_LABEL, "Fibo_" + DoubleToString(Fibo_Level_9, 3));

   // Validate inputs
   if(BarsBack < 2)
   {
      Print("Error: BarsBack must be at least 2");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(StartBar < 0)
   {
      Print("Error: StartBar cannot be negative");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Clean up any existing objects
   CleanupObjects();

   return(INIT_SUCCEEDED);
}

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
                const int &spread[])
{
   if(Pause) return(rates_total);

   // Ensure we have enough bars
   if(rates_total < BarsBack + StartBar)
      return(0);

   // Find highest and lowest bars
   int lowest_bar = iLowest(NULL, 0, MODE_LOW, BarsBack, StartBar);
   int highest_bar = iHighest(NULL, 0, MODE_HIGH, BarsBack, StartBar);

   // Error checking
   if(lowest_bar < 0 || highest_bar < 0)
   {
      Print("Error: Could not find highest/lowest bar");
      return(rates_total);
   }

   double high_value = High(highest_bar);
   double low_value = Low(lowest_bar);

   // Validate price data
   if(high_value <= 0 || low_value <= 0 || high_value <= low_value)
   {
      Print("Error: Invalid price data - High: ", high_value, " Low: ", low_value);
      return(rates_total);
   }

   datetime high_time = Time(highest_bar);
   datetime low_time = Time(lowest_bar);

   if(high_time == 0 || low_time == 0)
   {
      Print("Error: Invalid time data");
      return(rates_total);
   }

   bool is_bullish = high_time > low_time;

   // Check if we need to recalculate (optimization)
   bool need_recalc = (prev_calculated == 0 ||
                       last_lowest_bar != lowest_bar ||
                       last_highest_bar != highest_bar ||
                       last_rates_total != rates_total);

   if(need_recalc)
   {
      // Update cache
      last_lowest_bar = lowest_bar;
      last_highest_bar = highest_bar;
      last_high_value = high_value;
      last_low_value = low_value;
      last_is_bullish = is_bullish;
      last_rates_total = rates_total;

      datetime start_time = is_bullish ? low_time : high_time;
      double fibo_range = high_value - low_value;

      // Draw vertical lines
      DrawVerticalLine(OBJ_VLINE_HIGH, highest_bar, VerticalLinesColor);
      DrawVerticalLine(OBJ_VLINE_LOW, lowest_bar, VerticalLinesColor);

      // Draw trend line
      UpdateTrendLine(start_time, high_time, low_time, high_value, low_value, is_bullish);

      // Draw Fibonacci object
      UpdateFibonacci(start_time, high_time, low_time, high_value, low_value, is_bullish);

      // Draw golden zone background
      double price_low = is_bullish ? low_value + fibo_range * Fibo_Level_2 : high_value - fibo_range * Fibo_Level_4;
      double price_high = is_bullish ? low_value + fibo_range * Fibo_Level_4 : high_value - fibo_range * Fibo_Level_2;
      UpdateGoldenZone(start_time, time[rates_total - 1], price_low, price_high);

      // Calculate buffer values efficiently
      CalculateFibonacciBuffers(rates_total, prev_calculated, high_value, low_value, fibo_range, is_bullish);
   }
   else if(rates_total > prev_calculated)
   {
      // Just update the golden zone rectangle for new bars
      double fibo_range = last_high_value - last_low_value;
      double price_low = last_is_bullish ? last_low_value + fibo_range * Fibo_Level_2 : last_high_value - fibo_range * Fibo_Level_4;
      double price_high = last_is_bullish ? last_low_value + fibo_range * Fibo_Level_4 : last_high_value - fibo_range * Fibo_Level_2;
      datetime start_time = last_is_bullish ? Time(last_lowest_bar) : Time(last_highest_bar);

      UpdateGoldenZoneTime(time[rates_total - 1]);

      // Extend buffers to new bars
      ExtendBuffers(prev_calculated, rates_total);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
void CalculateFibonacciBuffers(int rates_total, int prev_calculated,
                                double high_value, double low_value,
                                double fibo_range, bool is_bullish)
{
   int limit = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(is_bullish)
   {
      double fibo_0 = low_value;
      double fibo_1 = low_value + fibo_range * Fibo_Level_1;
      double fibo_2 = low_value + fibo_range * Fibo_Level_2;
      double fibo_3 = low_value + fibo_range * Fibo_Level_3;
      double fibo_4 = low_value + fibo_range * Fibo_Level_4;
      double fibo_5 = low_value + fibo_range * Fibo_Level_5;
      double fibo_6 = low_value + fibo_range * Fibo_Level_6;
      double fibo_7 = low_value + fibo_range * Fibo_Level_7;
      double fibo_8 = low_value + fibo_range * Fibo_Level_8;
      double fibo_9 = low_value + fibo_range * Fibo_Level_9;

      for(int i = limit; i < rates_total; i++)
      {
         f_1[i] = fibo_0;
         f_2[i] = fibo_1;
         f_3[i] = fibo_2;
         f_4[i] = fibo_3;
         f_5[i] = fibo_4;
         f_6[i] = fibo_5;
         f_7[i] = fibo_6;
         f_8[i] = fibo_7;
         f_9[i] = fibo_8;
         f_10[i] = fibo_9;
      }
   }
   else
   {
      double fibo_0 = high_value;
      double fibo_1 = high_value - fibo_range * Fibo_Level_1;
      double fibo_2 = high_value - fibo_range * Fibo_Level_2;
      double fibo_3 = high_value - fibo_range * Fibo_Level_3;
      double fibo_4 = high_value - fibo_range * Fibo_Level_4;
      double fibo_5 = high_value - fibo_range * Fibo_Level_5;
      double fibo_6 = high_value - fibo_range * Fibo_Level_6;
      double fibo_7 = high_value - fibo_range * Fibo_Level_7;
      double fibo_8 = high_value - fibo_range * Fibo_Level_8;
      double fibo_9 = high_value - fibo_range * Fibo_Level_9;

      for(int i = limit; i < rates_total; i++)
      {
         f_1[i] = fibo_0;
         f_2[i] = fibo_1;
         f_3[i] = fibo_2;
         f_4[i] = fibo_3;
         f_5[i] = fibo_4;
         f_6[i] = fibo_5;
         f_7[i] = fibo_6;
         f_8[i] = fibo_7;
         f_9[i] = fibo_8;
         f_10[i] = fibo_9;
      }
   }
}

//+------------------------------------------------------------------+
void ExtendBuffers(int from, int to)
{
   for(int i = from; i < to; i++)
   {
      f_1[i] = f_1[from - 1];
      f_2[i] = f_2[from - 1];
      f_3[i] = f_3[from - 1];
      f_4[i] = f_4[from - 1];
      f_5[i] = f_5[from - 1];
      f_6[i] = f_6[from - 1];
      f_7[i] = f_7[from - 1];
      f_8[i] = f_8[from - 1];
      f_9[i] = f_9[from - 1];
      f_10[i] = f_10[from - 1];
   }
}

//+------------------------------------------------------------------+
void DrawVerticalLine(string name, int bar, color clr)
{
   datetime bar_time = Time(bar);
   if(bar_time == 0) return;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_VLINE, 0, bar_time, 0);
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, bar_time);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void UpdateTrendLine(datetime start_time, datetime high_time, datetime low_time,
                     double high_value, double low_value, bool is_bullish)
{
   if(ObjectFind(0, OBJ_TREND_NAME) < 0)
   {
      ObjectCreate(0, OBJ_TREND_NAME, OBJ_TREND, 0,
                   start_time, is_bullish ? low_value : high_value,
                   is_bullish ? high_time : low_time, is_bullish ? high_value : low_value);
   }

   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_TIME, 0, start_time);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_TIME, 1, is_bullish ? high_time : low_time);
   ObjectSetDouble(0, OBJ_TREND_NAME, OBJPROP_PRICE, 0, is_bullish ? low_value : high_value);
   ObjectSetDouble(0, OBJ_TREND_NAME, OBJPROP_PRICE, 1, is_bullish ? high_value : low_value);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_COLOR, TrendLineColor);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_RAY, false);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_TREND_NAME, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
void UpdateFibonacci(datetime start_time, datetime high_time, datetime low_time,
                     double high_value, double low_value, bool is_bullish)
{
   if(ObjectFind(0, OBJ_FIBO_NAME) < 0)
   {
      ObjectCreate(0, OBJ_FIBO_NAME, OBJ_FIBO, 0,
                   start_time, is_bullish ? low_value : high_value,
                   is_bullish ? high_time : low_time, is_bullish ? high_value : low_value);
   }

   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_PRICE, 0, is_bullish ? low_value : high_value);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_PRICE, 1, is_bullish ? high_value : low_value);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_TIME, 0, start_time);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_TIME, 1, is_bullish ? high_time : low_time);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_COLOR, clrNONE);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_BACK, true);

   // Set Fibonacci levels
   ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_LEVELS, 10);

   // Level values
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 0, Fibo_Level_0);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 1, Fibo_Level_1);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 2, Fibo_Level_2);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 3, Fibo_Level_3);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 4, Fibo_Level_4);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 5, Fibo_Level_5);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 6, Fibo_Level_6);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 7, Fibo_Level_7);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 8, Fibo_Level_8);
   ObjectSetDouble(0, OBJ_FIBO_NAME, OBJPROP_LEVELVALUE, 9, Fibo_Level_9);

   // Set level colors
   color level_colors[10] = {VerticalLinesColor, FiboBaseColor, GoldenZoneColor, GoldenZoneColor,
                             GoldenZoneColor, FiboBaseColor, FiboBaseColor, FiboBaseColor,
                             ExtensionColor, ExtensionColor};

   for(int i = 0; i < 10; i++)
   {
      ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_LEVELCOLOR, i, level_colors[i]);
      ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
      ObjectSetInteger(0, OBJ_FIBO_NAME, OBJPROP_LEVELWIDTH, i, 1);
   }
}

//+------------------------------------------------------------------+
void UpdateGoldenZone(datetime start_time, datetime end_time,
                      double price_low, double price_high)
{
   if(ObjectFind(0, OBJ_RECT_NAME) < 0)
   {
      ObjectCreate(0, OBJ_RECT_NAME, OBJ_RECTANGLE, 0, start_time, price_low, end_time, price_high);
   }

   ObjectSetDouble(0, OBJ_RECT_NAME, OBJPROP_PRICE, 0, price_low);
   ObjectSetDouble(0, OBJ_RECT_NAME, OBJPROP_PRICE, 1, price_high);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_TIME, 0, start_time);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_TIME, 1, end_time);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_COLOR, GoldenZoneBgColor);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_BGCOLOR, ColorToARGB(GoldenZoneBgColor, GoldenZoneOpacity));
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_FILL, true);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_BACK, true);
   ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void UpdateGoldenZoneTime(datetime end_time)
{
   if(ObjectFind(0, OBJ_RECT_NAME) >= 0)
   {
      ObjectSetInteger(0, OBJ_RECT_NAME, OBJPROP_TIME, 1, end_time);
   }
}

//+------------------------------------------------------------------+
void CleanupObjects()
{
   ObjectDelete(0, OBJ_VLINE_HIGH);
   ObjectDelete(0, OBJ_VLINE_LOW);
   ObjectDelete(0, OBJ_TREND_NAME);
   ObjectDelete(0, OBJ_FIBO_NAME);
   ObjectDelete(0, OBJ_RECT_NAME);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanupObjects();
}

//+------------------------------------------------------------------+
// MQ4 style functions
//+------------------------------------------------------------------+
int iHighest(string symbol, int timeframe, int type=MODE_HIGH, int count=WHOLE_ARRAY, int start=0)
{
   if(start < 0) return(-1);
   if(count <= 0) return(-1);

   if(symbol == NULL || symbol == "") symbol = _Symbol;
   ENUM_TIMEFRAMES tf = ToTimeFrame(timeframe);

   double Arr[];
   ArraySetAsSeries(Arr, false);

   if(type == MODE_HIGH && CopyHigh(symbol, tf, start, count, Arr) > 0)
      return(ArrayMaximum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_LOW && CopyLow(symbol, tf, start, count, Arr) > 0)
      return(ArrayMaximum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_OPEN && CopyOpen(symbol, tf, start, count, Arr) > 0)
      return(ArrayMaximum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_CLOSE && CopyClose(symbol, tf, start, count, Arr) > 0)
      return(ArrayMaximum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_VOLUME || type == MODE_REAL_VOLUME)
   {
      long ArrLong[];
      ArraySetAsSeries(ArrLong, false);
      if(type == MODE_VOLUME && CopyTickVolume(symbol, tf, start, count, ArrLong) > 0)
         return(ArrayMaximum(ArrLong, 0, WHOLE_ARRAY) + start);
      else if(type == MODE_REAL_VOLUME && CopyRealVolume(symbol, tf, start, count, ArrLong) > 0)
         return(ArrayMaximum(ArrLong, 0, WHOLE_ARRAY) + start);
   }
   return(-1);
}

int iLowest(string symbol, int timeframe, int type=MODE_LOW, int count=WHOLE_ARRAY, int start=0)
{
   if(start < 0) return(-1);
   if(count <= 0) return(-1);

   if(symbol == NULL || symbol == "") symbol = _Symbol;
   ENUM_TIMEFRAMES tf = ToTimeFrame(timeframe);

   double Arr[];
   ArraySetAsSeries(Arr, false);

   if(type == MODE_LOW && CopyLow(symbol, tf, start, count, Arr) > 0)
      return(ArrayMinimum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_HIGH && CopyHigh(symbol, tf, start, count, Arr) > 0)
      return(ArrayMinimum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_OPEN && CopyOpen(symbol, tf, start, count, Arr) > 0)
      return(ArrayMinimum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_CLOSE && CopyClose(symbol, tf, start, count, Arr) > 0)
      return(ArrayMinimum(Arr, 0, WHOLE_ARRAY) + start);
   else if(type == MODE_VOLUME || type == MODE_REAL_VOLUME)
   {
      long ArrLong[];
      ArraySetAsSeries(ArrLong, false);
      if(type == MODE_VOLUME && CopyTickVolume(symbol, tf, start, count, ArrLong) > 0)
         return(ArrayMinimum(ArrLong, 0, WHOLE_ARRAY) + start);
      else if(type == MODE_REAL_VOLUME && CopyRealVolume(symbol, tf, start, count, ArrLong) > 0)
         return(ArrayMinimum(ArrLong, 0, WHOLE_ARRAY) + start);
   }
   return(-1);
}

double iHigh(string symbol, int timeframe, int shift)
{
   if(shift < 0) return(0);
   if(symbol == NULL || symbol == "") symbol = _Symbol;

   double Arr[];
   if(CopyHigh(symbol, ToTimeFrame(timeframe), shift, 1, Arr) > 0)
      return(Arr[0]);
   return(0);
}

double iLow(string symbol, int timeframe, int shift)
{
   if(shift < 0) return(0);
   if(symbol == NULL || symbol == "") symbol = _Symbol;

   double Arr[];
   if(CopyLow(symbol, ToTimeFrame(timeframe), shift, 1, Arr) > 0)
      return(Arr[0]);
   return(0);
}

datetime iTime(string symbol, int timeframe, int shift)
{
   if(shift < 0) return(0);
   if(symbol == NULL || symbol == "") symbol = _Symbol;

   datetime Arr[];
   if(CopyTime(symbol, ToTimeFrame(timeframe), shift, 1, Arr) > 0)
      return(Arr[0]);
   return(0);
}

double High(int bar=0) { return(iHigh(_Symbol, 0, bar)); }
double Low(int bar=0) { return(iLow(_Symbol, 0, bar)); }
datetime Time(int bar=0) { return(iTime(_Symbol, 0, bar)); }

ENUM_TIMEFRAMES ToTimeFrame(int timeframe)
{
   switch(timeframe)
   {
      case 0: return(PERIOD_CURRENT);
      case 1: return(PERIOD_M1);
      case 5: return(PERIOD_M5);
      case 15: return(PERIOD_M15);
      case 30: return(PERIOD_M30);
      case 60: return(PERIOD_H1);
      case 240: return(PERIOD_H4);
      case 1440: return(PERIOD_D1);
      case 10080: return(PERIOD_W1);
      case 43200: return(PERIOD_MN1);
      default: return(PERIOD_CURRENT);
   }
}

//+------------------------------------------------------------------+
// ColorToARGB is now a built-in MQL5 function
//+------------------------------------------------------------------+
