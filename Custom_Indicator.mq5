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
   if(rates_total < 2) return 0;

   // Determine target day boundaries
   datetime lastBarTime = time[rates_total - 1];
   datetime refTime = (InpHistoricalDate == 0) ? lastBarTime : InpHistoricalDate;
   
   MqlDateTime dt;
   TimeToStruct(refTime, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   datetime dayEnd = dayStart + 86400;

   bool fullReset = false;
   if(dayStart != targetDayStart) {
      targetDayStart = dayStart;
      targetDayEnd = dayEnd;
      fullReset = true;
   }

   int first_idx = 0;
   while(first_idx < rates_total && time[first_idx] < targetDayStart) {
      first_idx++;
   }

   if(first_idx >= rates_total) return rates_total;

   int start;
   if(fullReset || prev_calculated == 0) {
      ArrayInitialize(HAOpen, 0.0);
      ArrayInitialize(HAHigh, 0.0);
      ArrayInitialize(HALow, 0.0);
      ArrayInitialize(HAClose, 0.0);
      ArrayInitialize(HAColor, 0.0);

      // First bar calculation (bootstrapping using previous bar if available)
      if(first_idx > 0) {
         HAOpen[first_idx] = (open[first_idx - 1] + close[first_idx - 1]) / 2.0;
      } else {
         HAOpen[first_idx] = (open[0] + close[0]) / 2.0;
      }
      HAClose[first_idx] = (open[first_idx] + high[first_idx] + low[first_idx] + close[first_idx]) / 4.0;
      HAHigh[first_idx] = MathMax(high[first_idx], MathMax(HAOpen[first_idx], HAClose[first_idx]));
      HALow[first_idx] = MathMin(low[first_idx], MathMin(HAOpen[first_idx], HAClose[first_idx]));
      HAColor[first_idx] = (HAOpen[first_idx] < HAClose[first_idx]) ? 0.0 : 1.0;

      start = first_idx + 1;
   } else {
      start = prev_calculated - 1;
      if(start < first_idx) {
         start = first_idx;
      }

      if(start == first_idx) {
         if(first_idx > 0) {
            HAOpen[first_idx] = (open[first_idx - 1] + close[first_idx - 1]) / 2.0;
         } else {
            HAOpen[first_idx] = (open[0] + close[0]) / 2.0;
         }
         HAClose[first_idx] = (open[first_idx] + high[first_idx] + low[first_idx] + close[first_idx]) / 4.0;
         HAHigh[first_idx] = MathMax(high[first_idx], MathMax(HAOpen[first_idx], HAClose[first_idx]));
         HALow[first_idx] = MathMin(low[first_idx], MathMin(HAOpen[first_idx], HAClose[first_idx]));
         HAColor[first_idx] = (HAOpen[first_idx] < HAClose[first_idx]) ? 0.0 : 1.0;

         start = first_idx + 1;
      }
   }

   // Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++) {
      if(time[i] >= targetDayEnd) break;

      HAOpen[i] = (HAOpen[i - 1] + HAClose[i - 1]) / 2.0;
      HAClose[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      HAHigh[i] = MathMax(high[i], MathMax(HAOpen[i], HAClose[i]));
      HALow[i] = MathMin(low[i], MathMin(HAOpen[i], HAClose[i]));
      HAColor[i] = (HAOpen[i] < HAClose[i]) ? 0.0 : 1.0;
   }

   // --- Clear semafor buffers for target day range (*probably unnecessary at this point in the processing loop)
   for(int i = first_idx; i < rates_total; i++) {
      LesserLow[i]   = 0.0;
      LesserHigh[i]  = 0.0;
      GreaterLow[i]  = 0.0;
      GreaterHigh[i] = 0.0;
   }

   // --- Semafor structure for target day tracking
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

   // Process target day bars for semafors
   for(int i = first_idx + 1; i < rates_total && !IsStopped(); i++) {
      if(time[i] >= targetDayEnd) break;

      int sz = ArraySize(semafors);
      if(sz < 1) break;

      int last_idx = sz - 1;
      SemaforNode last_node = semafors[last_idx];

      if(last_node.is_high) {
         if(HAHigh[i] >= last_node.price) {
            semafors[last_idx].bar = i;
            semafors[last_idx].price = HAHigh[i];
         }
         else if(HALow[i] < semafors[last_idx - 1].price || HALow[i] < HALow[i - 1]) {
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
            semafors[last_idx].bar = i;
            semafors[last_idx].price = HALow[i];
         }
         else if(HAHigh[i] > semafors[last_idx - 1].price || HAHigh[i] > HAHigh[i - 1]) {
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

   // Populate lesser semafors into indicator buffers
   int num_nodes = ArraySize(semafors);
   for(int s = 0; s < num_nodes; s++) {
      int b = semafors[s].bar;
      if(semafors[s].is_high) {
         LesserHigh[b] = semafors[s].price;
      } else {
         LesserLow[b] = semafors[s].price;
      }
   }

   // Evaluate Greater Semafors (Dome distance >= 2x spread AND HA Color rule)
   double spread_val = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread_val <= 0.0) {
      spread_val = _Point * 10.0;
   }

   for(int s = 0; s < num_nodes; s++) {
      int b = semafors[s].bar;
      bool color_ok = false;

      if(semafors[s].is_high) {
         color_ok = (HAColor[b] == 0.0); // Dodger Blue (bullish HA)
      } else {
         color_ok = (HAColor[b] == 1.0); // Red (bearish HA)
      }

      bool dome_ok = false;
      double dome_mid = 0.0;

      if(s > 0) {
         int prev_b = semafors[s - 1].bar;
         if(semafors[s].is_high) {
            // Low-to-High pair: find lowest high between prev_b and b (inclusive)
            double lowest_high = HAHigh[prev_b];
            for(int k = prev_b; k <= b; k++) {
               if(HAHigh[k] < lowest_high) lowest_high = HAHigh[k];
            }
            double dome_dist = HAHigh[b] - lowest_high;
            if(dome_dist >= 2.0 * spread_val) {
               dome_ok = true;
               dome_mid = HAHigh[b] - (dome_dist / 2.0);
            }
         } else {
            // High-to-Low pair: find highest low between prev_b and b (inclusive)
            double highest_low = HALow[prev_b];
            for(int k = prev_b; k <= b; k++) {
               if(HALow[k] > highest_low) highest_low = HALow[k];
            }
            double dome_dist = highest_low - HALow[b];
            if(dome_dist >= 2.0 * spread_val) {
               dome_ok = true;
               dome_mid = HALow[b] + (dome_dist / 2.0);
            }
         }
      } else {
         // First semafor at first_idx
         double dome_dist = HAHigh[b] - HALow[b];
         if(dome_dist >= 2.0 * spread_val) {
            dome_ok = true;
            dome_mid = (HAHigh[b] + HALow[b]) / 2.0;
         }
      }

      if(color_ok && dome_ok) {
         semafors[s].is_greater = true;
         semafors[s].dome_mid_price = dome_mid;

         if(semafors[s].is_high) {
            GreaterHigh[b] = HAHigh[b];
         } else {
            GreaterLow[b] = HALow[b];
         }
      }
   }

   // --- Clear previously created graphic objects
   ObjectsDeleteAll(0, "CustomHA_");

   // --- Draw ZigZag lines and Dome Halfway horizontal lines for Greater Semafors
   int prev_greater_idx = -1;
   int obj_counter = 0;

   for(int s = 0; s < num_nodes; s++) {
      if(!semafors[s].is_greater) continue;

      int cur_bar = semafors[s].bar;
      datetime cur_time = time[cur_bar];
      double cur_price = semafors[s].price;

      // 1. Draw ZigZag line connecting to previous greater semafor
      if(prev_greater_idx >= 0) {
         int prev_bar = semafors[prev_greater_idx].bar;
         datetime prev_time = time[prev_bar];
         double prev_price = semafors[prev_greater_idx].price;

         string line_name = "CustomHA_ZZ_" + IntegerToString(obj_counter++);
         if(ObjectCreate(0, line_name, OBJ_TREND, 0, prev_time, prev_price, cur_time, cur_price)) {
            ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
            color line_color = (cur_price >= prev_price) ? clrDodgerBlue : clrRed;
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         }
      }

      // 2. Draw short horizontal line (span = 20 bars) at the halfway point of the dome distance
      if(semafors[s].dome_mid_price > 0.0) {
         int half_span = 10;
         int start_bar = MathMax(first_idx, cur_bar - half_span);
         int end_bar   = MathMin(rates_total - 1, cur_bar + half_span);

         datetime start_time = time[start_bar];
         datetime end_time   = time[end_bar];
         double mid_p        = semafors[s].dome_mid_price;

         string mid_name = "CustomHA_Mid_" + IntegerToString(obj_counter++);
         if(ObjectCreate(0, mid_name, OBJ_TREND, 0, start_time, mid_p, end_time, mid_p)) {
            ObjectSetInteger(0, mid_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, mid_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, mid_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, mid_name, OBJPROP_COLOR, clrOrange);
         }
      }

      prev_greater_idx = s;
   }

   return(rates_total);
}
//+------------------------------------------------------------------+

/* Custom functionality
-----------------------
//--- High semafors
#property indicator_type   DRAW_ARROW
#property indicator_color  Aqua
#property indicator_width  1

//--- Low semafors
#property indicator_type   DRAW_ARROW
#property indicator_color  Magenta
#property indicator_width  1

//--- Notables (Lesser semafor parameters)
Period      = 2;
Backstep    = 1;

int lesser_semafor_symbol = 158;
int greater_semafor_symbol  = 159;
int ArrowShiftPixels = 10; // for visual acuity of semafors

//--- Set arrow shifts
PlotIndexSetInteger(high_semafor_plots, PLOT_ARROW_SHIFT, ArrowShiftPixels); // shifted up
PlotIndexSetInteger(low_semafor_plots, PLOT_ARROW_SHIFT, -ArrowShiftPixels); // shifted down

//--- OnCalculate
- Restructure to only execute on closed candles. Process sequentially, that probably involves using a single main loop.
- If current index is first bar of the target day, bootstrap lesser semafors by anchoring semafors to HAHigh and HALow of that first bar.
- For subsequent candles, repaint lesser semafors higher or lower depending on whether previous anchor was exceeded (see lesser semafor period and backstep parameters above).
- Greater semafors occur when the "dome" distance is at least 2x the instrument spread and the semafor is anchored to a corresponding HAColor bar, ie.:
   - High semafor on dodger blue bar.
   - Low semafor on to red bar.
- "Dome" distance is defined as follows (assume non-series, ie. oldest-latest, high[4]-low[7], low[7]-high[11]):
   - For a high-low semafor pair, the low is a "greater semafor" if the distance from its HALow anchor to the highest low between the two bars (inclusive) is at least twice the symbol's spread.
   - For a low-high semafor pair, the high is a "greater semafor" if the distance from its HAHigh anchor to the lowest high between the two bars (inclusive) is at least twice the symbol's spread.
- Draw a straight line (color dictated by slope) connecting high and low greater semafors, in zigzag fashion but using objects, not buffers.
- Unlike lesser semafors, greater semafors must alternate such that no two high greater semafors occur consecutively without an intervening low greater semafor.
- For this reason, it is expected for greater semafors to repaint onto higher/lower positions if an intermission is missed, or remain unchanged if the new position does not exceed the previous one.
- Secondary feature: A short horizontal line (no ray extensions), preferably anchored to the zigzag connecting line, ought to mark out the halfway point of the "dome" distance.
*/
