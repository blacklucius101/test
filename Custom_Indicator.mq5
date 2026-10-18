//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   5

//--- Plot 1: Heiken Ashi bars
#property indicator_type1   DRAW_COLOR_BARS
#property indicator_color1  clrDodgerBlue, clrRed
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"

//--- Plot 2: Lesser Low semafors
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrAqua
#property indicator_label2  "Lesser Low"

//--- Plot 3: Lesser High semafors
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_label3  "Lesser High"

//--- Plot 4: Greater Low semafors
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrAqua
#property indicator_width4  2
#property indicator_label4  "Greater Low"

//--- Plot 5: Greater High semafors
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_width5  2
#property indicator_label5  "Greater High"

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

//--- Heiken Ashi candle buffers (0-4)
double HAOpen[];
double HAHigh[];
double HALow[];
double HAClose[];
double HAColor[];

//--- Semafor buffers (5-8)
double LesserLow[];
double LesserHigh[];
double GreaterLow[];
double GreaterHigh[];

datetime targetDayStart = 0;
datetime targetDayEnd = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- Heiken Ashi candle plot
   SetIndexBuffer(0, HAOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, HAHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, HALow,   INDICATOR_DATA);
   SetIndexBuffer(3, HAClose, INDICATOR_DATA);
   SetIndexBuffer(4, HAColor, INDICATOR_COLOR_INDEX);

   //--- Semafor plots
   SetIndexBuffer(5, LesserLow,   INDICATOR_DATA);
   SetIndexBuffer(6, LesserHigh,  INDICATOR_DATA);
   SetIndexBuffer(7, GreaterLow,  INDICATOR_DATA);
   SetIndexBuffer(8, GreaterHigh, INDICATOR_DATA);

   //--- Set series orientation AFTER binding
   ArraySetAsSeries(HAOpen,      false);
   ArraySetAsSeries(HAHigh,      false);
   ArraySetAsSeries(HALow,       false);
   ArraySetAsSeries(HAClose,     false);
   ArraySetAsSeries(HAColor,     false);
   ArraySetAsSeries(LesserLow,   false);
   ArraySetAsSeries(LesserHigh,  false);
   ArraySetAsSeries(GreaterLow,  false);
   ArraySetAsSeries(GreaterHigh, false);

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Heiken Ashi Semafor");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);

   int LesserLowSymbol   = 158;
   int LesserHighSymbol  = 158;
   int GreaterLowSymbol  = 159;
   int GreaterHighSymbol = 159;
   int ArrowShiftPixels  = 10;

   //--- Set arrow symbols and shifts
   PlotIndexSetInteger(1, PLOT_ARROW, LesserLowSymbol);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -ArrowShiftPixels);

   PlotIndexSetInteger(2, PLOT_ARROW, LesserHighSymbol);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, ArrowShiftPixels);

   PlotIndexSetInteger(3, PLOT_ARROW, GreaterLowSymbol);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -ArrowShiftPixels);

   PlotIndexSetInteger(4, PLOT_ARROW, GreaterHighSymbol);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, ArrowShiftPixels);

   targetDayStart = 0;
   targetDayEnd = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "CustomHA_");
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
   // We require at least 3 bars (so at least 2 closed bars: bar 0 and bar rates_total-2)
   if(rates_total < 3) return 0;

   // Ignore the live, incomplete candle at rates_total - 1
   int last_closed_bar = rates_total - 2;

   // Determine target day boundaries using the last closed bar if InpHistoricalDate is 0
   datetime refTime = (InpHistoricalDate == 0) ? time[last_closed_bar] : InpHistoricalDate;
   
   MqlDateTime dt;
   TimeToStruct(refTime, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   datetime dayEnd = dayStart + 86400;

   targetDayStart = dayStart;
   targetDayEnd = dayEnd;

   // Find target day range within available closed bars
   int first_idx = 0;
   while(first_idx <= last_closed_bar && time[first_idx] < targetDayStart) {
      first_idx++;
   }

   if(first_idx > last_closed_bar) return rates_total;

   int last_idx = first_idx;
   while(last_idx <= last_closed_bar && time[last_idx] < targetDayEnd) {
      last_idx++;
   }
   last_idx--; // Adjust to last valid bar inside target day

   if(last_idx < first_idx) return rates_total;

   // Clear all indicator buffers
   ArrayInitialize(HAOpen,      0.0);
   ArrayInitialize(HAHigh,      0.0);
   ArrayInitialize(HALow,       0.0);
   ArrayInitialize(HAClose,     0.0);
   ArrayInitialize(HAColor,     0.0);
   ArrayInitialize(LesserLow,   0.0);
   ArrayInitialize(LesserHigh,  0.0);
   ArrayInitialize(GreaterLow,  0.0);
   ArrayInitialize(GreaterHigh, 0.0);

   // --- Step 1: Compute Heiken Ashi candles for the target day
   if(first_idx > 0) {
      HAOpen[first_idx] = (open[first_idx - 1] + close[first_idx - 1]) / 2.0;
   } else {
      HAOpen[first_idx] = (open[0] + close[0]) / 2.0;
   }
   HAClose[first_idx] = (open[first_idx] + high[first_idx] + low[first_idx] + close[first_idx]) / 4.0;
   HAHigh[first_idx]  = MathMax(high[first_idx], MathMax(HAOpen[first_idx], HAClose[first_idx]));
   HALow[first_idx]   = MathMin(low[first_idx], MathMin(HAOpen[first_idx], HAClose[first_idx]));
   HAColor[first_idx] = (HAOpen[first_idx] < HAClose[first_idx]) ? 0.0 : 1.0;

   for(int i = first_idx + 1; i <= last_idx && !IsStopped(); i++) {
      HAOpen[i]  = (HAOpen[i - 1] + HAClose[i - 1]) / 2.0;
      HAClose[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      HAHigh[i]  = MathMax(high[i], MathMax(HAOpen[i], HAClose[i]));
      HALow[i]   = MathMin(low[i], MathMin(HAOpen[i], HAClose[i]));
      HAColor[i] = (HAOpen[i] < HAClose[i]) ? 0.0 : 1.0;
   }

   // --- Step 2: Compute Lesser Semafors (Fractal anchoring & repainting)
   struct SemaforNode {
      int bar;
      bool is_high;
      double price;
      double dome_mid_price;
      bool is_greater;
   };

   SemaforNode semafors[];
   ArrayResize(semafors, 0);

   // Bootstrap initial semafors at first_idx
   SemaforNode init_low;
   init_low.bar = first_idx;
   init_low.is_high = false;
   init_low.price = HALow[first_idx];
   init_low.dome_mid_price = 0.0;
   init_low.is_greater = false;

   SemaforNode init_high;
   init_high.bar = first_idx;
   init_high.is_high = true;
   init_high.price = HAHigh[first_idx];
   init_high.dome_mid_price = 0.0;
   init_high.is_greater = false;

   ArrayResize(semafors, 2);
   semafors[0] = init_low;
   semafors[1] = init_high;

   for(int i = first_idx + 1; i <= last_idx && !IsStopped(); i++) {
      int sz = ArraySize(semafors);
      if(sz < 1) break;

      int last_node_idx = sz - 1;
      SemaforNode last_node = semafors[last_node_idx];

      if(last_node.is_high) {
         if(HAHigh[i] >= last_node.price) {
            semafors[last_node_idx].bar = i;
            semafors[last_node_idx].price = HAHigh[i];
         }
         else if(HALow[i] < semafors[last_node_idx - 1].price || HALow[i] < HALow[i - 1]) {
            SemaforNode new_low;
            new_low.bar = i;
            new_low.is_high = false;
            new_low.price = HALow[i];
            new_low.dome_mid_price = 0.0;
            new_low.is_greater = false;

            ArrayResize(semafors, sz + 1);
            semafors[sz] = new_low;
         }
      }
      else {
         if(HALow[i] <= last_node.price) {
            semafors[last_node_idx].bar = i;
            semafors[last_node_idx].price = HALow[i];
         }
         else if(HAHigh[i] > semafors[last_node_idx - 1].price || HAHigh[i] > HAHigh[i - 1]) {
            SemaforNode new_high;
            new_high.bar = i;
            new_high.is_high = true;
            new_high.price = HAHigh[i];
            new_high.dome_mid_price = 0.0;
            new_high.is_greater = false;

            ArrayResize(semafors, sz + 1);
            semafors[sz] = new_high;
         }
      }
   }

   // Populate Lesser Semafors indicator buffers
   int num_nodes = ArraySize(semafors);
   for(int s = 0; s < num_nodes; s++) {
      int b = semafors[s].bar;
      if(semafors[s].is_high) {
         LesserHigh[b] = semafors[s].price;
      } else {
         LesserLow[b] = semafors[s].price;
      }
   }

   // --- Step 3: Evaluate Greater Semafors (Dome distance >= 2x spread AND matching HA Color)
   double spread_val = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread_val <= 0.0) {
      spread_val = _Point * 10.0;
   }

   SemaforNode greater_semafors[];
   ArrayResize(greater_semafors, 0);

   for(int s = 0; s < num_nodes; s++) {
      int b = semafors[s].bar;

      // HA Color matching: Dodger Blue (0.0) for High, Red (1.0) for Low
      bool color_ok = semafors[s].is_high ? (HAColor[b] == 0.0) : (HAColor[b] == 1.0);
      if(!color_ok) continue;

      bool dome_ok = false;
      double dome_mid = 0.0;

      if(s > 0) {
         int prev_b = semafors[s - 1].bar;
         if(semafors[s].is_high) {
            // Low-to-High pair: find lowest low between prev_b and b (inclusive)
            double lowest_low = HALow[prev_b];
            for(int k = prev_b; k <= b; k++) {
               if(HALow[k] < lowest_low) lowest_low = HALow[k];
            }
            double dome_dist = HAHigh[b] - lowest_low;
            if(dome_dist >= 2.0 * spread_val) {
               dome_ok = true;
               dome_mid = HAHigh[b] - (dome_dist / 2.0);
            }
         } else {
            // High-to-Low pair: find highest high between prev_b and b (inclusive)
            double highest_high = HAHigh[prev_b];
            for(int k = prev_b; k <= b; k++) {
               if(HAHigh[k] > highest_high) highest_high = HAHigh[k];
            }
            double dome_dist = highest_high - HALow[b];
            if(dome_dist >= 2.0 * spread_val) {
               dome_ok = true;
               dome_mid = HALow[b] + (dome_dist / 2.0);
            }
         }
      } else {
         // First semafor node at first_idx
         double dome_dist = HAHigh[b] - HALow[b];
         if(dome_dist >= 2.0 * spread_val) {
            dome_ok = true;
            dome_mid = (HAHigh[b] + HALow[b]) / 2.0;
         }
      }

      if(!dome_ok) continue;

      // Candidate qualifies for Greater Semafor.
      // Enforce strict High/Low alternation with repainting logic.
      SemaforNode cand = semafors[s];
      cand.is_greater = true;
      cand.dome_mid_price = dome_mid;

      int g_sz = ArraySize(greater_semafors);
      if(g_sz == 0) {
         ArrayResize(greater_semafors, 1);
         greater_semafors[0] = cand;
      } else {
         SemaforNode last_g = greater_semafors[g_sz - 1];
         if(last_g.is_high == cand.is_high) {
            // Same type: check if repainting is required
            if(cand.is_high) {
               if(cand.price > last_g.price) {
                  greater_semafors[g_sz - 1] = cand; // Repaint to higher High
               }
            } else {
               if(cand.price < last_g.price) {
                  greater_semafors[g_sz - 1] = cand; // Repaint to lower Low
               }
            }
         } else {
            // Opposite type: append new Greater Semafor
            ArrayResize(greater_semafors, g_sz + 1);
            greater_semafors[g_sz] = cand;
         }
      }
   }

   // Populate Greater Semafors indicator buffers
   int num_greater = ArraySize(greater_semafors);
   for(int g = 0; g < num_greater; g++) {
      int b = greater_semafors[g].bar;
      if(greater_semafors[g].is_high) {
         GreaterHigh[b] = greater_semafors[g].price;
      } else {
         GreaterLow[b] = greater_semafors[g].price;
      }
   }

   // --- Step 4: Clear previously created graphic objects
   ObjectsDeleteAll(0, "CustomHA_");

   // --- Step 5: Draw ZigZag trendlines and Dome Halfway horizontal lines
   int obj_counter = 0;

   for(int g = 0; g < num_greater; g++) {
      int cur_bar = greater_semafors[g].bar;
      datetime cur_time = time[cur_bar];
      double cur_price = greater_semafors[g].price;

      // 1. Draw ZigZag line connecting to previous greater semafor
      if(g > 0) {
         int prev_bar = greater_semafors[g - 1].bar;
         datetime prev_time = time[prev_bar];
         double prev_price = greater_semafors[g - 1].price;

         string line_name = "CustomHA_ZZ_" + IntegerToString(obj_counter++);
         if(ObjectCreate(0, line_name, OBJ_TREND, 0, prev_time, prev_price, cur_time, cur_price)) {
            ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
            color line_color = (cur_price >= prev_price) ? clrDodgerBlue : clrRed;
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         }

         // 2. Draw 20-bar short horizontal line at dome midpoint centered at ZigZag intersection
         double mid_p = greater_semafors[g].dome_mid_price;
         if(mid_p > 0.0 && prev_price != cur_price) {
            // Find bar index B_mid where ZigZag segment intersects mid_p
            double ratio = (mid_p - prev_price) / (cur_price - prev_price);
            if(ratio < 0.0) ratio = 0.0;
            if(ratio > 1.0) ratio = 1.0;

            int mid_bar = (int)MathRound(prev_bar + ratio * (cur_bar - prev_bar));
            int half_span = 10;
            int start_bar = MathMax(0, mid_bar - half_span);
            int end_bar   = MathMin(rates_total - 1, mid_bar + half_span);

            datetime start_time = time[start_bar];
            datetime end_time   = time[end_bar];

            string mid_name = "CustomHA_Mid_" + IntegerToString(obj_counter++);
            if(ObjectCreate(0, mid_name, OBJ_TREND, 0, start_time, mid_p, end_time, mid_p)) {
               ObjectSetInteger(0, mid_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, mid_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, mid_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, mid_name, OBJPROP_COLOR, clrOrange);
            }
         }
      } else {
         // First greater semafor (no previous greater semafor for ZigZag segment)
         double mid_p = greater_semafors[g].dome_mid_price;
         if(mid_p > 0.0) {
            int half_span = 10;
            int start_bar = MathMax(0, cur_bar - half_span);
            int end_bar   = MathMin(rates_total - 1, cur_bar + half_span);

            datetime start_time = time[start_bar];
            datetime end_time   = time[end_bar];

            string mid_name = "CustomHA_Mid_" + IntegerToString(obj_counter++);
            if(ObjectCreate(0, mid_name, OBJ_TREND, 0, start_time, mid_p, end_time, mid_p)) {
               ObjectSetInteger(0, mid_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, mid_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, mid_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, mid_name, OBJPROP_COLOR, clrOrange);
            }
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
