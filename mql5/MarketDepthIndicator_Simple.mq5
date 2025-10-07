//+------------------------------------------------------------------+
//|                                  MarketDepthIndicator_Simple.mq5 |
//|                        Copyright 2025, WIRERIGG                   |
//|                   https://github.com/WIRERIGG                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, WIRERIGG"
#property link      "https://github.com/WIRERIGG"
#property version   "4.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot depth as lines
#property indicator_label1  "Bid Depth"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  3

#property indicator_label2  "Ask Depth"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  3

#property indicator_label3  "Imbalance %"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  2

//--- Indicator buffers
double BidDepthBuffer[];
double AskDepthBuffer[];
double ImbalanceBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit() {
   Print("========================================");
   Print("Market Depth Indicator (SIMPLE) - Initializing...");

   // Set indicator buffers
   SetIndexBuffer(0, BidDepthBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, AskDepthBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ImbalanceBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   ArraySetAsSeries(BidDepthBuffer, true);
   ArraySetAsSeries(AskDepthBuffer, true);
   ArraySetAsSeries(ImbalanceBuffer, true);

   Print("Mode: SYNTHETIC (calculated from volume/price)");
   Print("You should see 3 colored lines on the chart:");
   Print("- BLUE line: Bid depth (buyer volume)");
   Print("- RED line: Ask depth (seller volume)");
   Print("- YELLOW line: Volume imbalance percentage");
   Print("========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Comment("");
   Print("Market Depth Indicator (SIMPLE) - Deinitialized");
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

   // Set arrays as series
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(tick_volume, true);

   // Calculate from where we need to start
   int start = 0;
   if(prev_calculated > 1)
      start = prev_calculated - 1;

   // Calculate synthetic bid/ask depth for all bars
   for(int i = start; i < rates_total; i++) {
      // Get current bar data
      double current_volume = (double)tick_volume[i];
      bool bullish = close[i] > open[i];

      // Calculate body strength (0 to 1)
      double range = high[i] - low[i];
      double body_strength = 0.5;
      if(range > 0) {
         body_strength = MathAbs(close[i] - open[i]) / range;
      }

      // Distribute volume between bid and ask
      // Bullish: more bid (buyers), Bearish: more ask (sellers)
      double bid_ratio = bullish ? (0.5 + body_strength * 0.3) : (0.5 - body_strength * 0.3);
      double ask_ratio = 1.0 - bid_ratio;

      // Calculate buffer values
      BidDepthBuffer[i] = current_volume * bid_ratio;
      AskDepthBuffer[i] = current_volume * ask_ratio;

      // Imbalance percentage (ask/bid * 100)
      if(BidDepthBuffer[i] > 0)
         ImbalanceBuffer[i] = (AskDepthBuffer[i] / BidDepthBuffer[i]) * 100.0;
      else
         ImbalanceBuffer[i] = 100.0;
   }

   // Display current values
   string info = "=== Market Depth (SYNTHETIC) ===\n";
   StringAdd(info, StringFormat("Symbol: %s\n", _Symbol));
   StringAdd(info, StringFormat("Time: %s\n", TimeToString(TimeCurrent())));
   StringAdd(info, StringFormat("Close: %.5f\n", close[0]));
   StringAdd(info, StringFormat("Volume: %.0f\n", (double)tick_volume[0]));
   StringAdd(info, StringFormat("\nBid Depth: %.0f (Blue)\n", BidDepthBuffer[0]));
   StringAdd(info, StringFormat("Ask Depth: %.0f (Red)\n", AskDepthBuffer[0]));
   StringAdd(info, StringFormat("Imbalance: %.1f%% (Yellow)\n", ImbalanceBuffer[0]));

   string trend = (close[0] > open[0]) ? "Bullish" : "Bearish";
   StringAdd(info, StringFormat("\nCurrent Bar: %s\n", trend));
   StringAdd(info, "Mode: Calculated from volume");
   Comment(info);

   if(calc_count <= 3) {
      Print("Buffer values - Bid: ", BidDepthBuffer[0], ", Ask: ", AskDepthBuffer[0], ", Imbalance: ", ImbalanceBuffer[0]);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
