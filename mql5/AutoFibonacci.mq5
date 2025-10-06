//+------------------------------------------------------------------+
//|                                              AutoFibonacci.mq5   |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Auto Fibonacci Indicator"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- input parameters
input int      SwingPeriod = 10;        // Period for swing high/low detection
input color    FibColor = clrBlue;      // Fibonacci lines color
input int      FibWidth = 1;            // Fibonacci lines width
input ENUM_LINE_STYLE FibStyle = STYLE_SOLID; // Fibonacci lines style

//--- Fibonacci levels
double fib_levels[] = {0.0, 0.236, 0.382, 0.500, 0.618, 0.786, 1.000};
string fib_names[] = {"0.0%", "23.6%", "38.2%", "50.0%", "61.8%", "78.6%", "100.0%"};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   //--- Find swing high and low
   int swing_high_idx = -1;
   int swing_low_idx = -1;
   double swing_high = -DBL_MAX;
   double swing_low = DBL_MAX;

   // Look back through recent bars
   int lookback = MathMin(100, rates_total - 1);

   for(int i = 1; i < lookback; i++)
   {
      bool is_swing_high = true;
      bool is_swing_low = true;

      // Check if current bar is a swing high
      for(int j = 1; j <= SwingPeriod && (i-j) >= 0 && (i+j) < rates_total; j++)
      {
         if(high[i] <= high[i-j] || high[i] <= high[i+j])
         {
            is_swing_high = false;
            break;
         }
      }

      // Check if current bar is a swing low
      for(int j = 1; j <= SwingPeriod && (i-j) >= 0 && (i+j) < rates_total; j++)
      {
         if(low[i] >= low[i-j] || low[i] >= low[i+j])
         {
            is_swing_low = false;
            break;
         }
      }

      if(is_swing_high && high[i] > swing_high)
      {
         swing_high = high[i];
         swing_high_idx = i;
      }

      if(is_swing_low && low[i] < swing_low)
      {
         swing_low = low[i];
         swing_low_idx = i;
      }
   }

   //--- Draw Fibonacci levels if swing points found
   if(swing_high_idx >= 0 && swing_low_idx >= 0)
   {
      DeleteFibObjects();
      DrawFibonacci(time[swing_high_idx], swing_high, time[swing_low_idx], swing_low);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw Fibonacci retracement levels                                |
//+------------------------------------------------------------------+
void DrawFibonacci(datetime time_high, double price_high, datetime time_low, double price_low)
{
   double range = price_high - price_low;

   for(int i = 0; i < ArraySize(fib_levels); i++)
   {
      string obj_name = "AutoFib_" + fib_names[i];
      double price = price_low + (range * fib_levels[i]);

      ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, FibColor);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, FibWidth);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, FibStyle);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, fib_names[i]);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete all Fibonacci objects                                     |
//+------------------------------------------------------------------+
void DeleteFibObjects()
{
   for(int i = 0; i < ArraySize(fib_names); i++)
   {
      string obj_name = "AutoFib_" + fib_names[i];
      ObjectDelete(0, obj_name);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteFibObjects();
}
//+------------------------------------------------------------------+
