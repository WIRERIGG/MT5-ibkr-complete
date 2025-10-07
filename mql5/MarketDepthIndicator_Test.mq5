//+------------------------------------------------------------------+
//|                                   MarketDepthIndicator_Test.mq5  |
//|                        Copyright 2025, WIRERIGG                   |
//|                   https://github.com/WIRERIGG                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, WIRERIGG"
#property link      "https://github.com/WIRERIGG"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot test lines
#property indicator_label1  "Test Line 1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  3

#property indicator_label2  "Test Line 2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  3

#property indicator_label3  "Test Line 3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  2

//--- Indicator buffers
double TestBuffer1[];
double TestBuffer2[];
double TestBuffer3[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit() {
   Print("========================================");
   Print("TEST INDICATOR - Initializing...");

   // Set indicator buffers
   SetIndexBuffer(0, TestBuffer1, INDICATOR_DATA);
   SetIndexBuffer(1, TestBuffer2, INDICATOR_DATA);
   SetIndexBuffer(2, TestBuffer3, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   ArraySetAsSeries(TestBuffer1, true);
   ArraySetAsSeries(TestBuffer2, true);
   ArraySetAsSeries(TestBuffer3, true);

   Print("Buffers configured successfully");
   Print("You should see 3 colored lines on the chart:");
   Print("- BLUE line at Close price");
   Print("- RED line at Close + 10 pips");
   Print("- YELLOW line at Close - 10 pips");
   Print("========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Comment("");
   Print("TEST INDICATOR - Deinitialized");
}

//+------------------------------------------------------------------+
//| OnCalculate - Main calculation function                          |
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

   static int calc_count = 0;
   calc_count++;

   if(calc_count <= 3) {
      Print("OnCalculate #", calc_count, " - rates_total: ", rates_total, ", prev_calculated: ", prev_calculated);
   }

   ArraySetAsSeries(close, true);

   // Calculate from where we need to start
   int start = 0;
   if(prev_calculated > 1)
      start = prev_calculated - 1;

   // Calculate test values for all bars
   for(int i = start; i < rates_total; i++) {
      TestBuffer1[i] = close[i];                    // Blue: Close price
      TestBuffer2[i] = close[i] + 10 * _Point;      // Red: Close + 10 pips
      TestBuffer3[i] = close[i] - 10 * _Point;      // Yellow: Close - 10 pips
   }

   // Display info on current bar
   string info = "TEST INDICATOR\n";
   StringAdd(info, StringFormat("Time: %s\n", TimeToString(TimeCurrent())));
   StringAdd(info, StringFormat("Close: %.5f\n", close[0]));
   StringAdd(info, StringFormat("Blue: %.5f\n", TestBuffer1[0]));
   StringAdd(info, StringFormat("Red: %.5f\n", TestBuffer2[0]));
   StringAdd(info, StringFormat("Yellow: %.5f\n", TestBuffer3[0]));
   StringAdd(info, StringFormat("\nBars: %d | Calculated: %d", rates_total, prev_calculated));
   Comment(info);

   if(calc_count <= 3) {
      Print("Buffer values - Blue: ", TestBuffer1[0], ", Red: ", TestBuffer2[0], ", Yellow: ", TestBuffer3[0]);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
