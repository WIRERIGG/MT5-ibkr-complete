//+------------------------------------------------------------------+
//|                                   MarketDepthIndicator_Fixed.mq5  |
//|                        Copyright 2025, WIRERIGG                   |
//|                   https://github.com/WIRERIGG                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, WIRERIGG"
#property link      "https://github.com/WIRERIGG"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot bid/ask depth as lines
#property indicator_label1  "Bid Depth"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Ask Depth"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "Imbalance"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  1

#include <Canvas\Canvas.mqh>

//--- Input parameters
input group "=== Display Settings ==="
input int    MaxDepthLevels        = 10;          // Maximum depth levels to display
input bool   ShowOnChart           = true;        // Show depth on chart
input bool   ShowHistogram         = true;        // Show histogram
input color  BidColor              = clrBlue;     // Bid price color
input color  AskColor              = clrRed;      // Ask price color
input color  HighVolumeBidColor    = clrDarkBlue; // High-volume bid color
input color  HighVolumeAskColor    = clrDarkRed;  // High-volume ask color

input group "=== Update & Logging ==="
input int    UpdateInterval        = 1000;        // Update interval (ms)
input bool   LogToFile             = false;       // Log data to CSV
input bool   EnableAlerts          = false;       // Enable alerts

input group "=== Volume Imbalance ==="
input double ImbalanceUpperThreshold = 1.5;       // Upper threshold for imbalance ratio
input double ImbalanceLowerThreshold = 0.67;      // Lower threshold for imbalance ratio
input double ImbalanceThresholdPercent = 150.0;   // Volume imbalance threshold (%)

input group "=== Cluster Detection ==="
input double ClusterWindow         = 0.0050;      // Price window for clusters (50 pips)
input double ClusterStdDevThreshold = 1.0;        // Std dev threshold for clusters

input group "=== Velocity & Spikes ==="
input int    VelocityHistorySize   = 30;          // Velocity history size (30-100)
input double VelocitySmoothingFactor = 0.2;       // Smoothing factor (0-1)
input double VelocityThreshold     = 5000.0;      // Velocity threshold (lots/sec)
input double VelocityAlertHysteresisRatio = 0.8;  // Hysteresis ratio
input double LiquidationSpikeMultiplier = 3.0;    // Spike detection multiplier

input group "=== Depth & Range ==="
input int    ATRPeriod             = 14;          // ATR period for dynamic range
input double DepthRange            = 0.0010;      // Range for depth score (10 pips)
input double IcebergVolumeTolerance = 0.05;       // Iceberg tolerance (5%)

input group "=== ML Prediction ==="
input double MLRangeMultiplier     = 2.0;         // Multiplier for ML price range
input double MLBuyVolumeWeight     = 0.4;         // Weight for buy volume
input double MLSellVolumeWeight    = -0.4;        // Weight for sell volume
input double MLSpreadWeight        = 1000.0;      // Weight for spread
input double MLVelocityWeight      = 0.1;         // Weight for velocity
input double MLDepthWeight         = 0.2;         // Weight for depth ratio
input double MLNeutralThreshold    = 0.1;         // Neutral threshold

//--- Indicator buffers
double BidDepthBuffer[];
double AskDepthBuffer[];
double ImbalanceBuffer[];

//--- Global variables
CCanvas canvas;
string  log_file_name;
int     depth_file_handle = INVALID_HANDLE;
int     atr_handle = INVALID_HANDLE;
ulong   last_update_ms = 0;
datetime last_update_time = 0;

struct VolumeSnapshot {
   long volume;
   ulong timestamp;
};

VolumeSnapshot volume_history[];
double prev_buy_volumes[];
double prev_sell_volumes[];
int history_index = 0;
ulong last_velocity_alert_ms = 0;
ulong last_calculated_ms = 0;
static double filtered_velocity = 0;
static bool velocity_alert_active = false;
bool market_depth_available = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit() {
   // Validate inputs
   if(MaxDepthLevels <= 0) {
      Print("Error: MaxDepthLevels must be positive");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(VelocityHistorySize < 2 || VelocityHistorySize > 100) {
      Print("Error: VelocityHistorySize must be 2-100");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(VelocitySmoothingFactor < 0 || VelocitySmoothingFactor > 1) {
      Print("Error: VelocitySmoothingFactor must be 0-1");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Verify symbol exists
   if(!SymbolSelect(_Symbol, true)) {
      Print("Symbol ", _Symbol, " not available");
      return(INIT_FAILED);
   }

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

   // Subscribe to market depth
   Print("Subscribing to market depth for ", _Symbol, "...");
   if(!MarketBookAdd(_Symbol)) {
      Print("ERROR: Failed to subscribe to market depth for ", _Symbol);
      Print("Market depth may not be available for this symbol");
      Print("This indicator requires Level II / Market Depth data");
      market_depth_available = false;
      return(INIT_FAILED);
   }
   market_depth_available = true;
   Print("SUCCESS: Subscribed to market depth for ", _Symbol);

   // Create ATR handle
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(atr_handle == INVALID_HANDLE) {
      Print("Failed to create ATR handle");
      MarketBookRelease(_Symbol);
      return(INIT_FAILED);
   }

   // Initialize canvas
   if(ShowHistogram) {
      if(!canvas.CreateBitmapLabel("MarketDepthHistogram", 10, 10, 300, 200, COLOR_FORMAT_ARGB_NORMALIZE)) {
         Print("Failed to create canvas, continuing without histogram");
      }
   }

   // Initialize log file
   if(LogToFile) {
      log_file_name = _Symbol + "_MarketDepth_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
      depth_file_handle = FileOpen(log_file_name, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
      if(depth_file_handle == INVALID_HANDLE) {
         Print("Failed to open log file, continuing without logging");
      } else {
         FileWrite(depth_file_handle, "Timestamp", "Price", "Type", "Volume", "ImbalancePercent");
      }
   }

   // Initialize arrays
   ArrayResize(volume_history, VelocityHistorySize);
   for(int i = 0; i < VelocityHistorySize; i++) {
      volume_history[i].volume = 0;
      volume_history[i].timestamp = 0;
   }
   ArrayResize(prev_buy_volumes, MaxDepthLevels);
   ArrayInitialize(prev_buy_volumes, 0);
   ArrayResize(prev_sell_volumes, MaxDepthLevels);
   ArrayInitialize(prev_sell_volumes, 0);

   Print("========================================");
   Print("Market Depth Indicator SUCCESSFULLY initialized for ", _Symbol);
   Print("Waiting for market depth events...");
   Print("If nothing appears, check:");
   Print("1. Symbol has market depth data (Level II)");
   Print("2. Check 'View > Market Depth' in MT5");
   Print("3. Check Experts log for OnBookEvent messages");
   Print("========================================");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(market_depth_available)
      MarketBookRelease(_Symbol);
   Comment("");
   if(ShowHistogram)
      canvas.Destroy();
   if(depth_file_handle != INVALID_HANDLE)
      FileClose(depth_file_handle);
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   Print("Market Depth Indicator deinitialized");
}

//+------------------------------------------------------------------+
//| Calculate dynamic range based on ATR                             |
//+------------------------------------------------------------------+
double GetDynamicRange() {
   double atr_array[1];
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_array) <= 0) {
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      return tick_size * 10; // Fallback
   }
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return MathMax(atr_array[0] * 0.5, tick_size * 10);
}

//+------------------------------------------------------------------+
//| Get market book with retry logic                                 |
//+------------------------------------------------------------------+
bool GetMarketBookWithRetry(MqlBookInfo &book[]) {
   int retries = 3;
   int delay = 50;

   while(retries > 0) {
      if(MarketBookGet(_Symbol, book) && ArraySize(book) > 0)
         return true;

      retries--;
      if(retries > 0)
         Sleep(delay);
      delay *= 2; // Exponential backoff
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate order flow velocity                                    |
//+------------------------------------------------------------------+
double CalculateOrderFlowVelocity() {
   if(history_index < 2) return 0.0;

   int newest = (history_index - 1) % VelocityHistorySize;
   int oldest = (history_index - 2) % VelocityHistorySize;

   ulong time_diff = volume_history[newest].timestamp - volume_history[oldest].timestamp;
   if(time_diff == 0) return 0.0;

   long volume_diff = volume_history[newest].volume - volume_history[oldest].volume;
   double velocity = (double)volume_diff / (time_diff / 1000.0);

   // Apply exponential smoothing
   filtered_velocity = VelocitySmoothingFactor * velocity +
                      (1 - VelocitySmoothingFactor) * filtered_velocity;

   return filtered_velocity;
}

//+------------------------------------------------------------------+
//| Sort order book by price                                         |
//+------------------------------------------------------------------+
void SortBookByPrice(MqlBookInfo &orders[]) {
   int size = ArraySize(orders);
   for(int i = 0; i < size - 1; i++) {
      for(int j = i + 1; j < size; j++) {
         if(orders[i].price > orders[j].price) {
            MqlBookInfo temp = orders[i];
            orders[i] = orders[j];
            orders[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate statistics (average and std dev)                        |
//+------------------------------------------------------------------+
void CalculateStats(const double &volumes[], double &average, double &std_dev) {
   int size = ArraySize(volumes);
   if(size < 2) {
      average = 0;
      std_dev = 0;
      return;
   }

   double sum = 0;
   for(int i = 0; i < size; i++)
      sum += volumes[i];
   average = sum / size;

   double sum_sq = 0;
   for(int i = 0; i < size; i++)
      sum_sq += MathPow(volumes[i] - average, 2);
   std_dev = MathSqrt(sum_sq / (size - 1));
}

//+------------------------------------------------------------------+
//| Detect clusters in order book                                    |
//+------------------------------------------------------------------+
string DetectClusters(MqlBookInfo &orders[], double window, double threshold) {
   string clusters = "";
   int size = ArraySize(orders);
   if(size == 0) return clusters;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   window = MathMax(window, tick_size * 5);

   // Calculate average volume
   double avg_volume = 0;
   for(int i = 0; i < size; i++)
      avg_volume += (double)orders[i].volume;
   avg_volume /= size;

   for(int i = 0; i < size; i++) {
      double center_price = orders[i].price;
      double volumes[];
      int count = 0;

      // Collect volumes within window
      for(int j = 0; j < size; j++) {
         if(MathAbs(orders[j].price - center_price) <= window) {
            ArrayResize(volumes, count + 1);
            volumes[count++] = (double)orders[j].volume;
         }
      }

      if(count >= 2) {
         double average, std_dev;
         CalculateStats(volumes, average, std_dev);

         if((double)orders[i].volume > average + threshold * std_dev / 2.0) {
            clusters += StringFormat("%.5f, ", orders[i].price);
         }
      } else if((double)orders[i].volume > avg_volume * 2.0) {
         clusters += StringFormat("%.5f, ", orders[i].price);
      }
   }

   if(StringLen(clusters) > 2)
      clusters = StringSubstr(clusters, 0, StringLen(clusters) - 2);

   return clusters;
}

//+------------------------------------------------------------------+
//| Market book event handler                                        |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol) {
   static int event_count = 0;
   event_count++;

   if(event_count <= 5)
      Print("OnBookEvent called #", event_count, " for symbol: ", symbol);

   if(symbol != _Symbol || !market_depth_available) {
      if(event_count <= 5)
         Print("Ignoring event (wrong symbol or depth unavailable)");
      return;
   }

   // Control update frequency
   ulong current_ms = GetTickCount();
   if(current_ms - last_update_ms < (ulong)UpdateInterval)
      return;

   if(event_count <= 5)
      Print("Processing market depth update...");

   MqlBookInfo book[];
   if(!GetMarketBookWithRetry(book)) {
      Print("Failed to get market depth data");
      return;
   }

   if(ArraySize(book) == 0) {
      Print("Empty order book");
      return;
   }

   if(event_count <= 5)
      Print("Order book size: ", ArraySize(book), " orders");

   // Rotate log file if date changed
   if(LogToFile && depth_file_handle != INVALID_HANDLE) {
      string current_date = TimeToString(TimeCurrent(), TIME_DATE);
      string expected_filename = _Symbol + "_MarketDepth_" + current_date + ".csv";
      if(log_file_name != expected_filename) {
         FileClose(depth_file_handle);
         log_file_name = expected_filename;
         depth_file_handle = FileOpen(log_file_name, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
         if(depth_file_handle != INVALID_HANDLE)
            FileWrite(depth_file_handle, "Timestamp", "Price", "Type", "Volume", "ImbalancePercent");
      }
   }

   // Separate buy and sell orders
   MqlBookInfo buy_orders[], sell_orders[];
   int buy_count = 0, sell_count = 0;

   for(int i = 0; i < ArraySize(book); i++) {
      if(book[i].type == BOOK_TYPE_BUY)
         buy_count++;
      else if(book[i].type == BOOK_TYPE_SELL)
         sell_count++;
   }

   ArrayResize(buy_orders, buy_count);
   ArrayResize(sell_orders, sell_count);

   int buy_idx = 0, sell_idx = 0;
   for(int i = 0; i < ArraySize(book); i++) {
      if(book[i].type == BOOK_TYPE_BUY)
         buy_orders[buy_idx++] = book[i];
      else if(book[i].type == BOOK_TYPE_SELL)
         sell_orders[sell_idx++] = book[i];
   }

   if(buy_count == 0 && sell_count == 0) {
      Print("No orders in book");
      return;
   }

   // Sort orders
   SortBookByPrice(buy_orders);
   SortBookByPrice(sell_orders);

   // Detect clusters
   string buy_clusters = DetectClusters(buy_orders, ClusterWindow, ClusterStdDevThreshold);
   string sell_clusters = DetectClusters(sell_orders, ClusterWindow, ClusterStdDevThreshold);

   if(StringLen(buy_clusters) > 0 && EnableAlerts)
      Alert("Buy Clusters: ", buy_clusters);
   if(StringLen(sell_clusters) > 0 && EnableAlerts)
      Alert("Sell Clusters: ", sell_clusters);

   // Calculate volumes
   long current_buy_volume = 0;
   for(int i = 0; i < buy_count; i++)
      current_buy_volume += buy_orders[i].volume;

   long current_sell_volume = 0;
   for(int i = 0; i < sell_count; i++)
      current_sell_volume += sell_orders[i].volume;

   long current_total_volume = current_buy_volume + current_sell_volume;

   // Update volume history
   volume_history[history_index % VelocityHistorySize].volume = current_total_volume;
   volume_history[history_index % VelocityHistorySize].timestamp = current_ms;
   history_index++;

   // Calculate velocity
   double velocity = 0;
   if(current_ms - last_calculated_ms >= 500) {
      velocity = CalculateOrderFlowVelocity();

      // Velocity alerts with hysteresis
      if(MathAbs(velocity) > VelocityThreshold) {
         if(!velocity_alert_active && EnableAlerts) {
            Alert("High Order Flow Velocity: ", DoubleToString(velocity, 2), " lots/sec");
            velocity_alert_active = true;
         }
      } else if(velocity_alert_active && MathAbs(velocity) < VelocityThreshold * VelocityAlertHysteresisRatio) {
         velocity_alert_active = false;
      }

      last_calculated_ms = current_ms;
   }

   // Detect liquidation spikes
   string spike_text = "";
   if(history_index >= VelocityHistorySize) {
      long sum = 0;
      for(int i = 0; i < VelocityHistorySize; i++)
         sum += volume_history[i].volume;
      double avg_volume = (double)sum / VelocityHistorySize;

      if(current_total_volume > avg_volume * LiquidationSpikeMultiplier)
         spike_text = "Liquidation Spike Detected!";
   }

   // Calculate best bid/ask and midpoint
   double best_bid = (buy_count > 0) ? buy_orders[buy_count - 1].price : 0;
   double best_ask = (sell_count > 0) ? sell_orders[0].price : 0;
   double midpoint = (best_bid + best_ask) / 2;
   double spread = (best_ask > 0 && best_bid > 0) ? best_ask - best_bid : 0;

   // Volume imbalance prediction
   double imbalance_range = GetDynamicRange();
   double buy_volume_in_range = 0;
   for(int i = 0; i < buy_count; i++) {
      if(buy_orders[i].price >= midpoint - imbalance_range)
         buy_volume_in_range += (double)buy_orders[i].volume;
   }

   double sell_volume_in_range = 0;
   for(int i = 0; i < sell_count; i++) {
      if(sell_orders[i].price <= midpoint + imbalance_range)
         sell_volume_in_range += (double)sell_orders[i].volume;
   }

   double ratio = (sell_volume_in_range > 0) ? buy_volume_in_range / sell_volume_in_range : 0;
   string prediction = (ratio > ImbalanceUpperThreshold) ? "Up" :
                      (ratio < ImbalanceLowerThreshold) ? "Down" : "Neutral";

   // Depth score
   double bid_depth = 0, ask_depth = 0;
   for(int i = 0; i < buy_count; i++) {
      if(buy_orders[i].price >= best_bid - DepthRange)
         bid_depth += (double)buy_orders[i].volume;
   }
   for(int i = 0; i < sell_count; i++) {
      if(sell_orders[i].price <= best_ask + DepthRange)
         ask_depth += (double)sell_orders[i].volume;
   }

   // Iceberg detection
   string iceberg_text = "";
   double avg_book_volume = 0;
   for(int i = 0; i < ArraySize(book); i++)
      avg_book_volume += (double)book[i].volume;
   avg_book_volume /= MathMax(1, ArraySize(book));

   for(int i = 0; i < buy_count && i < MaxDepthLevels; i++) {
      double curr_vol = (double)buy_orders[i].volume;
      double prev_vol = prev_buy_volumes[i];

      if(curr_vol > avg_book_volume * 2 && prev_vol > 0 &&
         MathAbs(curr_vol - prev_vol) / curr_vol <= IcebergVolumeTolerance) {
         iceberg_text += StringFormat("Buy Iceberg @ %.5f\n", buy_orders[i].price);
      }
      prev_buy_volumes[i] = curr_vol;
   }

   for(int i = 0; i < sell_count && i < MaxDepthLevels; i++) {
      double curr_vol = (double)sell_orders[i].volume;
      double prev_vol = prev_sell_volumes[i];

      if(curr_vol > avg_book_volume * 2 && prev_vol > 0 &&
         MathAbs(curr_vol - prev_vol) / curr_vol <= IcebergVolumeTolerance) {
         iceberg_text += StringFormat("Sell Iceberg @ %.5f\n", sell_orders[i].price);
      }
      prev_sell_volumes[i] = curr_vol;
   }

   // ML prediction
   double ml_range = imbalance_range * MLRangeMultiplier;
   double ml_buy_volume = 0;
   for(int i = 0; i < buy_count; i++) {
      if(buy_orders[i].price >= midpoint - ml_range)
         ml_buy_volume += (double)buy_orders[i].volume;
   }

   double ml_sell_volume = 0;
   for(int i = 0; i < sell_count; i++) {
      if(sell_orders[i].price <= midpoint + ml_range)
         ml_sell_volume += (double)sell_orders[i].volume;
   }

   double total_ml_volume = ml_buy_volume + ml_sell_volume;
   double norm_buy_volume = (total_ml_volume > 0) ? ml_buy_volume / total_ml_volume : 0;
   double norm_sell_volume = (total_ml_volume > 0) ? ml_sell_volume / total_ml_volume : 0;
   double total_depth = bid_depth + ask_depth;
   double norm_depth_ratio = (total_depth > 0) ? (bid_depth - ask_depth) / total_depth : 0;

   double prediction_score = (norm_buy_volume * MLBuyVolumeWeight +
                             norm_sell_volume * MLSellVolumeWeight +
                             spread * MLSpreadWeight +
                             velocity * MLVelocityWeight +
                             norm_depth_ratio * MLDepthWeight);

   string ml_prediction = (MathAbs(prediction_score) < MLNeutralThreshold) ? "Neutral" :
                         (prediction_score > 0) ? "Up" : "Down";

   // Calculate imbalance percentage
   double imbalance_percent = (current_buy_volume > 0) ?
                             (double)current_sell_volume / current_buy_volume * 100.0 : 0.0;
   string imbalance_text = (imbalance_percent > ImbalanceThresholdPercent) ? "Strong Sell Pressure" :
                          (imbalance_percent < 100.0 / (ImbalanceThresholdPercent / 100.0)) ? "Strong Buy Pressure" :
                          "Balanced";

   // Build display text
   string output = "";
   output = StringFormat("=== Market Depth: %s ===\n", _Symbol);
   StringAdd(output, StringFormat("Time: %s\n", TimeToString(TimeCurrent())));
   StringAdd(output, StringFormat("Spread: %.5f\n", spread));
   StringAdd(output, StringFormat("Imbalance: %.1f%% (%s)\n\n", imbalance_percent, imbalance_text));
   StringAdd(output, "=== Top Asks ===\n");

   for(int i = 0; i < MathMin(5, sell_count); i++)
      StringAdd(output, StringFormat("%.5f | %I64d\n", sell_orders[i].price, sell_orders[i].volume));

   StringAdd(output, "\n=== Top Bids ===\n");
   for(int i = MathMin(5, buy_count) - 1; i >= 0; i--)
      StringAdd(output, StringFormat("%.5f | %I64d\n", buy_orders[i].price, buy_orders[i].volume));

   StringAdd(output, "\n=== Analysis ===\n");
   StringAdd(output, StringFormat("Velocity: %.2f lots/sec\n", velocity));
   StringAdd(output, StringFormat("Bid Depth: %.0f | Ask Depth: %.0f\n", bid_depth, ask_depth));
   StringAdd(output, StringFormat("Prediction (Imbalance): %s\n", prediction));
   StringAdd(output, StringFormat("Prediction (ML): %s (Score: %.3f)\n", ml_prediction, prediction_score));

   if(StringLen(buy_clusters) > 0)
      StringAdd(output, "Buy Clusters: " + buy_clusters + "\n");
   if(StringLen(sell_clusters) > 0)
      StringAdd(output, "Sell Clusters: " + sell_clusters + "\n");
   if(StringLen(spike_text) > 0)
      StringAdd(output, spike_text + "\n");
   if(StringLen(iceberg_text) > 0)
      StringAdd(output, iceberg_text);

   // Update indicator buffers (current bar)
   BidDepthBuffer[0] = bid_depth;
   AskDepthBuffer[0] = ask_depth;
   ImbalanceBuffer[0] = imbalance_percent;

   if(event_count <= 5) {
      Print("Updated buffers: BidDepth=", bid_depth, " AskDepth=", ask_depth, " Imbalance=", imbalance_percent);
   }

   // Display on chart
   if(ShowOnChart)
      Comment(output);

   // Update histogram
   if(ShowHistogram) {
      canvas.Erase(ColorToARGB(clrBlack, 255));
      int height = canvas.Height();
      int width = canvas.Width();
      int total_bars = MathMin(10, buy_count + sell_count);
      if(total_bars == 0) {
         canvas.Update(true);
         last_update_ms = current_ms;
         return;
      }

      int bar_width = width / total_bars;
      long max_vol = 1;

      for(int i = 0; i < MathMin(5, sell_count); i++)
         max_vol = MathMax(max_vol, sell_orders[i].volume);
      for(int i = 0; i < MathMin(5, buy_count); i++)
         max_vol = MathMax(max_vol, buy_orders[i].volume);

      int x = 0;
      for(int i = MathMin(5, sell_count) - 1; i >= 0; i--) {
         int bar_height = (int)((double)sell_orders[i].volume / max_vol * (height - 20));
         canvas.FillRectangle(x, height - bar_height, x + bar_width - 2, height,
                            ColorToARGB(AskColor, 200));
         x += bar_width;
      }
      for(int i = 0; i < MathMin(5, buy_count); i++) {
         int bar_height = (int)((double)buy_orders[i].volume / max_vol * (height - 20));
         canvas.FillRectangle(x, height - bar_height, x + bar_width - 2, height,
                            ColorToARGB(BidColor, 200));
         x += bar_width;
      }
      canvas.Update(true);
   }

   // Log to file
   if(LogToFile && depth_file_handle != INVALID_HANDLE) {
      for(int i = 0; i < ArraySize(book); i++) {
         FileWrite(depth_file_handle,
                  TimeToString(TimeCurrent()),
                  DoubleToString(book[i].price, 5),
                  (book[i].type == BOOK_TYPE_SELL) ? "Ask" : "Bid",
                  book[i].volume,
                  DoubleToString(imbalance_percent, 2));
      }
   }

   last_update_ms = current_ms;
}

//+------------------------------------------------------------------+
//| OnCalculate - Required for custom indicators                     |
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
   static bool first_call = true;

   if(first_call) {
      Print("OnCalculate called - rates_total: ", rates_total);
      Print("Indicator buffers are ready for market depth updates");
      first_call = false;
   }

   // Initialize new bars with previous values
   if(prev_calculated == 0) {
      ArrayInitialize(BidDepthBuffer, 0);
      ArrayInitialize(AskDepthBuffer, 0);
      ArrayInitialize(ImbalanceBuffer, 0);
   } else {
      // Copy forward last known values to new bars
      for(int i = prev_calculated; i < rates_total; i++) {
         if(prev_calculated > 0) {
            BidDepthBuffer[i] = BidDepthBuffer[prev_calculated - 1];
            AskDepthBuffer[i] = AskDepthBuffer[prev_calculated - 1];
            ImbalanceBuffer[i] = ImbalanceBuffer[prev_calculated - 1];
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
