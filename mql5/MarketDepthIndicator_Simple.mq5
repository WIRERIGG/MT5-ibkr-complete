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

      // Calculate volume distribution
      double bid_volume = current_volume * bid_ratio;
      double ask_volume = current_volume * ask_ratio;

      // SCALE TO PRICE CHART - plot around current price
      // Use volume as offset from close price (in pips)
      double pip_value = _Point * 10;
      BidDepthBuffer[i] = close[i] - (ask_volume * pip_value * 0.1);  // Below price (sellers push down)
      AskDepthBuffer[i] = close[i] + (bid_volume * pip_value * 0.1);  // Above price (buyers push up)
      ImbalanceBuffer[i] = close[i];  // At price level (reference line)
   }

   // Display current values
   string info = "=== Market Depth (SYNTHETIC) ===\n";
   StringAdd(info, StringFormat("Symbol: %s\n", _Symbol));
   StringAdd(info, StringFormat("Time: %s\n", TimeToString(TimeCurrent())));
   StringAdd(info, StringFormat("Close: %.5f\n", close[0]));
   StringAdd(info, StringFormat("Volume: %.0f\n", (double)tick_volume[0]));
   StringAdd(info, StringFormat("\nRed Line (Ask): %.5f\n", AskDepthBuffer[0]));
   StringAdd(info, StringFormat("Yellow Line (Mid): %.5f\n", ImbalanceBuffer[0]));
   StringAdd(info, StringFormat("Blue Line (Bid): %.5f\n", BidDepthBuffer[0]));

   string trend = (close[0] > open[0]) ? "Bullish" : "Bearish";
   StringAdd(info, StringFormat("\nBar: %s\n", trend));
   StringAdd(info, "Lines show price pressure from volume");
   Comment(info);

   if(calc_count <= 3) {
      Print("Lines visible - Ask: ", AskDepthBuffer[0], ", Mid: ", ImbalanceBuffer[0], ", Bid: ", BidDepthBuffer[0]);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
