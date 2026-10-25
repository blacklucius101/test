//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots   6

//--- Plot 1: Heiken Ashi bars
#property indicator_type1   DRAW_COLOR_BARS
#property indicator_color1  clrDodgerBlue, clrRed // 1.0, 0.0
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"

//--- Plot 2: Bullish Semafor Low arrow
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrAqua
#property indicator_label2  "Low"

//--- Plot 3: Bearish Semafor High arrow
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_label3  "High"

//--- Plot 4: Pivot Low arrow
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrAqua
#property indicator_label4  "Pivot Low"

//--- Plot 5: Pivot High arrow
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_label5  "Pivot High"

//--- Plot 6: Dotted Zigzag lines
#property indicator_type6   DRAW_COLOR_ZIGZAG
#property indicator_color6  clrAqua, clrMagenta
#property indicator_style6  STYLE_DOT
#property indicator_width6  1
#property indicator_label6  "Zigzag"

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

//--- Heiken Ashi candle buffers (0-4)
double HAOpen[];
double HAHigh[];
double HALow[];
double HAClose[];
double HAColor[];

//--- Semafor arrow buffers (5-6)
double LowBuffer[];
double HighBuffer[];

//--- Pivot arrow buffers (7-8)
double PivotLowBuffer[];
double PivotHighBuffer[];

//--- Zigzag buffers (9-11)
double ZZBuffer1[];
double ZZBuffer2[];
double ZZColorBuffer[];

double g_spread_price = 0.0;

datetime targetDayStart = 0;
datetime targetDayEnd = 0;

enum ENUM_PIVOT_TYPE {
   PIVOT_TYPE_NONE = 0,
   PIVOT_TYPE_LOW  = 1,
   PIVOT_TYPE_HIGH = 2
};

struct LowTracker {
   double start_high_price;
   double lowest_HAHigh;
   double lowest_HALow;
   int    lowest_HALow_idx;
};

struct HighTracker {
   double start_low_price;
   double highest_HALow;
   double highest_HAHigh;
   int    highest_HAHigh_idx;
};

struct PivotInfo { // HACandle tracker
   ENUM_PIVOT_TYPE type;
   int    bar_idx;
   double anchor_price;
   double dome_extreme;
   LowTracker  low_tr;
   HighTracker high_tr;
};

// Global state variables for pivot tracking
PivotInfo confirmed_pivots[];
int       confirmed_count = 0;
bool      low_cand_active = false;
bool      high_cand_active = false;

// Helper function to safely ensure confirmed_pivots array size
void EnsurePivotArrayCapacity(int required_size) {
   if(ArraySize(confirmed_pivots) < required_size) {
      ArrayResize(confirmed_pivots, required_size + 10);
   }
}

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

   //--- Semafor arrow plots
   SetIndexBuffer(5, LowBuffer,  INDICATOR_DATA);
   SetIndexBuffer(6, HighBuffer, INDICATOR_DATA);

   //--- Pivot arrow plots
   SetIndexBuffer(7, PivotLowBuffer,  INDICATOR_DATA);
   SetIndexBuffer(8, PivotHighBuffer, INDICATOR_DATA);

   //--- Zigzag plot
   SetIndexBuffer(9,  ZZBuffer1,     INDICATOR_DATA);
   SetIndexBuffer(10, ZZBuffer2,     INDICATOR_DATA);
   SetIndexBuffer(11, ZZColorBuffer, INDICATOR_COLOR_INDEX);

   //--- Set series orientation AFTER binding
   ArraySetAsSeries(HAOpen, false);
   ArraySetAsSeries(HAHigh, false);
   ArraySetAsSeries(HALow, false);
   ArraySetAsSeries(HAClose, false);
   ArraySetAsSeries(HAColor, false);
   ArraySetAsSeries(LowBuffer, false);
   ArraySetAsSeries(HighBuffer, false);
   ArraySetAsSeries(PivotLowBuffer, false);
   ArraySetAsSeries(PivotHighBuffer, false);
   ArraySetAsSeries(ZZBuffer1, false);
   ArraySetAsSeries(ZZBuffer2, false);
   ArraySetAsSeries(ZZColorBuffer, false);

   //--- Plot properties for Heiken Ashi
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   //--- Plot properties for Low Semafor (Plot index 1)
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(1, PLOT_ARROW, 158);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10); // Low arrows shift DOWN (below price)

   //--- Plot properties for High Semafor (Plot index 2)
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(2, PLOT_ARROW, 158);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -10);  // High arrows shift UP (above price)

   //--- Plot properties for Pivot Low (Plot index 3)
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 10);

   //--- Plot properties for Pivot High (Plot index 4)
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, -10);

   //--- Plot properties for Zigzag (Plot index 5)
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0.0);

   // Fetch broker-reported spread once
   g_spread_price = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Heiken Ashi ZZ Semafor");

   targetDayStart = 0;
   targetDayEnd = 0;
   
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

   int max_idx = rates_total - 2;
   if(max_idx < first_idx) return rates_total;

   int start;
   if(fullReset || prev_calculated == 0) {
      ArrayInitialize(HAOpen, 0.0);
      ArrayInitialize(HAHigh, 0.0);
      ArrayInitialize(HALow, 0.0);
      ArrayInitialize(HAClose, 0.0);
      ArrayInitialize(HAColor, 0.0);
      ArrayInitialize(LowBuffer, 0.0);
      ArrayInitialize(HighBuffer, 0.0);
      ArrayInitialize(PivotLowBuffer, 0.0);
      ArrayInitialize(PivotHighBuffer, 0.0);
      ArrayInitialize(ZZBuffer1, 0.0);
      ArrayInitialize(ZZBuffer2, 0.0);
      ArrayInitialize(ZZColorBuffer, 0.0);

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

      // Bootstrap Semafor at first_idx
      LowBuffer[first_idx] = HALow[first_idx];
      HighBuffer[first_idx] = HAHigh[first_idx];

      EnsurePivotArrayCapacity(10);

      // Initialize bootstrap pivot at first_idx
      confirmed_pivots[0].type = PIVOT_TYPE_NONE;
      confirmed_pivots[0].bar_idx = first_idx;
      confirmed_pivots[0].anchor_price = 0.0;
      confirmed_pivots[0].dome_extreme = 0.0;

      confirmed_pivots[0].low_tr.start_high_price = HAHigh[first_idx]; // static
      confirmed_pivots[0].low_tr.lowest_HAHigh = HAHigh[first_idx]; // dynamic
      confirmed_pivots[0].low_tr.lowest_HALow = HALow[first_idx]; // dynamic
      confirmed_pivots[0].low_tr.lowest_HALow_idx = first_idx; // dynamic

      confirmed_pivots[0].high_tr.start_low_price = HALow[first_idx]; // static
      confirmed_pivots[0].high_tr.highest_HALow = HALow[first_idx]; // dynamic
      confirmed_pivots[0].high_tr.highest_HAHigh = HAHigh[first_idx]; // dynamic
      confirmed_pivots[0].high_tr.highest_HAHigh_idx = first_idx; // dynamic

      confirmed_count = 0;
      low_cand_active = false;
      high_cand_active = false;

      start = first_idx + 1;
   } else {
      start = prev_calculated - 1;
      if(start < first_idx + 1) {
         start = first_idx + 1;
      }
   }

   // Main calculation loop
   for(int i = start; i <= max_idx && !IsStopped(); i++) {
      if(time[i] >= targetDayEnd) break;

      // Calculate Heiken Ashi candle
      HAOpen[i] = (HAOpen[i - 1] + HAClose[i - 1]) / 2.0;
      HAClose[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      HAHigh[i] = MathMax(high[i], MathMax(HAOpen[i], HAClose[i]));
      HALow[i] = MathMin(low[i], MathMin(HAOpen[i], HAClose[i]));
      HAColor[i] = (HAOpen[i] < HAClose[i]) ? 0.0 : 1.0;

      // Calculate Low Semafor (buy arrow)
      if(HALow[i] < HALow[i - 1]) {
         LowBuffer[i] = HALow[i];
         LowBuffer[i - 1] = 0.0;
      } else {
         LowBuffer[i] = 0.0;
      }

      // Calculate High Semafor (sell arrow)
      if(HAHigh[i] > HAHigh[i - 1]) {
         HighBuffer[i] = HAHigh[i];
         HighBuffer[i - 1] = 0.0;
      } else {
         HighBuffer[i] = 0.0;
      }

      //------------------------------------------------------------------
      // 1. UPDATE CANDIDATE LOW PIVOT TRACKING
      //------------------------------------------------------------------
      if(low_cand_active) {
         // Active Low Pivot candidate (pivot1) is plotted at confirmed_pivots[confirmed_count].
         // We continue tracking lower HAHigh and lower HALow from the parent pivot (confirmed_pivots[confirmed_count - 1]).
         int parent_idx = confirmed_count - 1;
         
         if(HAHigh[i] < confirmed_pivots[parent_idx].low_tr.lowest_HAHigh) {
            confirmed_pivots[parent_idx].low_tr.lowest_HAHigh = HAHigh[i];
         }
         
         if(HALow[i] < confirmed_pivots[parent_idx].low_tr.lowest_HALow) {
            confirmed_pivots[parent_idx].low_tr.lowest_HALow = HALow[i];
            confirmed_pivots[parent_idx].low_tr.lowest_HALow_idx = i;
            
            // Anchor repaints lower
            int old_bar = confirmed_pivots[confirmed_count].bar_idx;
            
            if(HAColor[i] == 1.0) { // Red candle -> valid low pivot repaints lower
               PivotLowBuffer[old_bar] = 0.0;
               PivotLowBuffer[i] = HALow[i];
               
               ZZBuffer1[old_bar] = 0.0;
               ZZBuffer2[old_bar] = 0.0;
               ZZColorBuffer[old_bar] = 0.0;

               ZZBuffer1[i] = HALow[i];
               ZZBuffer2[i] = HALow[i];
               ZZColorBuffer[i] = 1.0;
               
               confirmed_pivots[confirmed_count].bar_idx = i;
               confirmed_pivots[confirmed_count].anchor_price = HALow[i];
               confirmed_pivots[confirmed_count].dome_extreme = confirmed_pivots[parent_idx].low_tr.start_high_price - confirmed_pivots[parent_idx].low_tr.lowest_HAHigh;
               
               // Reset High Pivot tracker for this active Low Pivot starting from new anchor position i
               confirmed_pivots[confirmed_count].high_tr.start_low_price = HALow[i];
               confirmed_pivots[confirmed_count].high_tr.highest_HALow = HALow[i];
               confirmed_pivots[confirmed_count].high_tr.highest_HAHigh = HAHigh[i];
               confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx = i;
            }
            else if(HAColor[i] == 0.0) { // DodgerBlue candle -> invalid, remove plot and rollback state
               PivotLowBuffer[old_bar] = 0.0;
               ZZBuffer1[old_bar] = 0.0;
               ZZBuffer2[old_bar] = 0.0;
               ZZColorBuffer[old_bar] = 0.0;
               low_cand_active = false;
               
               // Merge tracked high values from removed pivot into parent pivot
               if(confirmed_pivots[confirmed_count].high_tr.highest_HALow > confirmed_pivots[parent_idx].high_tr.highest_HALow) {
                  confirmed_pivots[parent_idx].high_tr.highest_HALow = confirmed_pivots[confirmed_count].high_tr.highest_HALow;
               }
               if(confirmed_pivots[confirmed_count].high_tr.highest_HAHigh > confirmed_pivots[parent_idx].high_tr.highest_HAHigh) {
                  confirmed_pivots[parent_idx].high_tr.highest_HAHigh = confirmed_pivots[confirmed_count].high_tr.highest_HAHigh;
                  confirmed_pivots[parent_idx].high_tr.highest_HAHigh_idx = confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx;
               }
               
               confirmed_count--;
            }
         }
      }
      else if(confirmed_pivots[confirmed_count].type == PIVOT_TYPE_NONE || confirmed_pivots[confirmed_count].type == PIVOT_TYPE_HIGH) {
         // No active candidate low pivot. Update low tracker on current parent pivot.
         if(HAHigh[i] < confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh) {
            confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh = HAHigh[i];
         }
         if(HALow[i] < confirmed_pivots[confirmed_count].low_tr.lowest_HALow) {
            confirmed_pivots[confirmed_count].low_tr.lowest_HALow = HALow[i];
            confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx = i;
         }
         
         double dome_dist = confirmed_pivots[confirmed_count].low_tr.start_high_price - confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh;
         int cand_idx = confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx;
         
         if(dome_dist > 2.5 * g_spread_price && HAColor[cand_idx] == 1.0) {
            low_cand_active = true;
            high_cand_active = false;
            
            PivotLowBuffer[cand_idx] = HALow[cand_idx];
            ZZBuffer1[cand_idx] = HALow[cand_idx];
            ZZBuffer2[cand_idx] = HALow[cand_idx];
            ZZColorBuffer[cand_idx] = 1.0;
            
            confirmed_count++;
            EnsurePivotArrayCapacity(confirmed_count + 5);
            
            confirmed_pivots[confirmed_count].type = PIVOT_TYPE_LOW;
            confirmed_pivots[confirmed_count].bar_idx = cand_idx;
            confirmed_pivots[confirmed_count].anchor_price = HALow[cand_idx];
            confirmed_pivots[confirmed_count].dome_extreme = dome_dist;
            
            // Initialize High Pivot tracker from new Low Pivot
            confirmed_pivots[confirmed_count].high_tr.start_low_price = HALow[cand_idx];
            confirmed_pivots[confirmed_count].high_tr.highest_HALow = HALow[cand_idx];
            confirmed_pivots[confirmed_count].high_tr.highest_HAHigh = HAHigh[cand_idx];
            confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx = cand_idx;
            
            // Scan bars from cand_idx + 1 up to current bar i to aggregate high tracker data
            for(int k = cand_idx + 1; k <= i; k++) {
               if(HALow[k] > confirmed_pivots[confirmed_count].high_tr.highest_HALow) {
                  confirmed_pivots[confirmed_count].high_tr.highest_HALow = HALow[k];
               }
               if(HAHigh[k] > confirmed_pivots[confirmed_count].high_tr.highest_HAHigh) {
                  confirmed_pivots[confirmed_count].high_tr.highest_HAHigh = HAHigh[k];
                  confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx = k;
               }
            }
         }
      }

      //------------------------------------------------------------------
      // 2. UPDATE CANDIDATE HIGH PIVOT TRACKING
      //------------------------------------------------------------------
      if(high_cand_active) {
         // Active High Pivot candidate is plotted at confirmed_pivots[confirmed_count].
         // Track higher HALow and higher HAHigh from the parent pivot (confirmed_pivots[confirmed_count - 1]).
         int parent_idx = confirmed_count - 1;
         
         if(HALow[i] > confirmed_pivots[parent_idx].high_tr.highest_HALow) {
            confirmed_pivots[parent_idx].high_tr.highest_HALow = HALow[i];
         }
         
         if(HAHigh[i] > confirmed_pivots[parent_idx].high_tr.highest_HAHigh) {
            confirmed_pivots[parent_idx].high_tr.highest_HAHigh = HAHigh[i];
            confirmed_pivots[parent_idx].high_tr.highest_HAHigh_idx = i;
            
            // Anchor repaints higher
            int old_bar = confirmed_pivots[confirmed_count].bar_idx;
            
            if(HAColor[i] == 0.0) { // DodgerBlue candle -> valid high pivot repaints higher
               PivotHighBuffer[old_bar] = 0.0;
               PivotHighBuffer[i] = HAHigh[i];
               
               ZZBuffer1[old_bar] = 0.0;
               ZZBuffer2[old_bar] = 0.0;
               ZZColorBuffer[old_bar] = 0.0;

               ZZBuffer1[i] = HAHigh[i];
               ZZBuffer2[i] = HAHigh[i];
               ZZColorBuffer[i] = 0.0;
               
               confirmed_pivots[confirmed_count].bar_idx = i;
               confirmed_pivots[confirmed_count].anchor_price = HAHigh[i];
               confirmed_pivots[confirmed_count].dome_extreme = confirmed_pivots[parent_idx].high_tr.highest_HALow - confirmed_pivots[parent_idx].high_tr.start_low_price;
               
               // Reset Low Pivot tracker for this active High Pivot starting from new anchor position i
               confirmed_pivots[confirmed_count].low_tr.start_high_price = HAHigh[i];
               confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh = HAHigh[i];
               confirmed_pivots[confirmed_count].low_tr.lowest_HALow = HALow[i];
               confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx = i;
            }
            else if(HAColor[i] == 1.0) { // Red candle -> invalid, remove plot and rollback state
               PivotHighBuffer[old_bar] = 0.0;
               ZZBuffer1[old_bar] = 0.0;
               ZZBuffer2[old_bar] = 0.0;
               ZZColorBuffer[old_bar] = 0.0;
               high_cand_active = false;
               
               // Merge tracked low values from removed pivot into parent pivot
               if(confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh < confirmed_pivots[parent_idx].low_tr.lowest_HAHigh) {
                  confirmed_pivots[parent_idx].low_tr.lowest_HAHigh = confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh;
               }
               if(confirmed_pivots[confirmed_count].low_tr.lowest_HALow < confirmed_pivots[parent_idx].low_tr.lowest_HALow) {
                  confirmed_pivots[parent_idx].low_tr.lowest_HALow = confirmed_pivots[confirmed_count].low_tr.lowest_HALow;
                  confirmed_pivots[parent_idx].low_tr.lowest_HALow_idx = confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx;
               }
               
               confirmed_count--;
            }
         }
      }
      else if(confirmed_pivots[confirmed_count].type == PIVOT_TYPE_NONE || confirmed_pivots[confirmed_count].type == PIVOT_TYPE_LOW) {
         // No active candidate high pivot. Update high tracker on current parent pivot.
         if(HALow[i] > confirmed_pivots[confirmed_count].high_tr.highest_HALow) {
            confirmed_pivots[confirmed_count].high_tr.highest_HALow = HALow[i];
         }
         if(HAHigh[i] > confirmed_pivots[confirmed_count].high_tr.highest_HAHigh) {
            confirmed_pivots[confirmed_count].high_tr.highest_HAHigh = HAHigh[i];
            confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx = i;
         }
         
         double dome_dist = confirmed_pivots[confirmed_count].high_tr.highest_HALow - confirmed_pivots[confirmed_count].high_tr.start_low_price;
         int cand_idx = confirmed_pivots[confirmed_count].high_tr.highest_HAHigh_idx;
         
         if(dome_dist > 2.5 * g_spread_price && HAColor[cand_idx] == 0.0) {
            high_cand_active = true;
            low_cand_active = false;
            
            PivotHighBuffer[cand_idx] = HAHigh[cand_idx];
            ZZBuffer1[cand_idx] = HAHigh[cand_idx];
            ZZBuffer2[cand_idx] = HAHigh[cand_idx];
            ZZColorBuffer[cand_idx] = 0.0;
            
            confirmed_count++;
            EnsurePivotArrayCapacity(confirmed_count + 5);
            
            confirmed_pivots[confirmed_count].type = PIVOT_TYPE_HIGH;
            confirmed_pivots[confirmed_count].bar_idx = cand_idx;
            confirmed_pivots[confirmed_count].anchor_price = HAHigh[cand_idx];
            confirmed_pivots[confirmed_count].dome_extreme = dome_dist;
            
            // Initialize Low Pivot tracker from new High Pivot
            confirmed_pivots[confirmed_count].low_tr.start_high_price = HAHigh[cand_idx];
            confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh = HAHigh[cand_idx];
            confirmed_pivots[confirmed_count].low_tr.lowest_HALow = HALow[cand_idx];
            confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx = cand_idx;
            
            // Scan bars from cand_idx + 1 up to current bar i to aggregate low tracker data
            for(int k = cand_idx + 1; k <= i; k++) {
               if(HAHigh[k] < confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh) {
                  confirmed_pivots[confirmed_count].low_tr.lowest_HAHigh = HAHigh[k];
               }
               if(HALow[k] < confirmed_pivots[confirmed_count].low_tr.lowest_HALow) {
                  confirmed_pivots[confirmed_count].low_tr.lowest_HALow = HALow[k];
                  confirmed_pivots[confirmed_count].low_tr.lowest_HALow_idx = k;
               }
            }
         }
      }

      
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
