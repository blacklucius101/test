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

//--- Plot 2: Bullish Semafor Low arrow
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrAqua
#property indicator_label2  "Low"

//--- Plot 3: Bearish Semafor High arrow
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_label3  "High"

//--- Plot 4: Bullish Pivot Low arrow
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrAqua
#property indicator_label4  "Pivot Low"

//--- Plot 5: Bearish Pivot High arrow
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_label5  "Pivot High"

#define OBJ_PREFIX "CustomHAZZ_"

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

datetime targetDayStart = 0;
datetime targetDayEnd = 0;

//+------------------------------------------------------------------+
//| Helper function to delete indicator chart objects               |
//+------------------------------------------------------------------+
void ObjectsDeleteByPrefix(const string prefix)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteByPrefix(OBJ_PREFIX);
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

   //--- Plot properties for Heiken Ashi
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   //--- Plot properties for Low Semafor (Plot index 1)
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(1, PLOT_ARROW, 158);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10);

   //--- Plot properties for High Semafor (Plot index 2)
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(2, PLOT_ARROW, 158);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -10);

   //--- Plot properties for Low Pivot (Plot index 3)
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 10);

   //--- Plot properties for High Pivot (Plot index 4)
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, -10);

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Heiken Ashi ZZ Semafor");

   targetDayStart = 0;
   targetDayEnd = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Structure for Pivot Nodes                                        |
//+------------------------------------------------------------------+
struct SPivot {
   int      type;           // +1 = High Pivot, -1 = Low Pivot
   int      bar_idx;        // bar index in rates
   double   price;          // HAHigh for High Pivot, HALow for Low Pivot
   datetime time;           // time[bar_idx]
   int      extreme_idx;    // index of dome extreme bar
   double   extreme_price;  // price of dome extreme
   double   midpoint_price; // midpoint price of dome distance
};

//+------------------------------------------------------------------+
//| Helper function to draw trend line objects                       |
//+------------------------------------------------------------------+
void DrawTrendLine(const string name, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
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

   if(dayStart != targetDayStart) {
      targetDayStart = dayStart;
      targetDayEnd = dayEnd;
   }

   int first_idx = 0;
   while(first_idx < rates_total && time[first_idx] < targetDayStart) {
      first_idx++;
   }

   if(first_idx >= rates_total) return rates_total;

   int max_idx = rates_total - 2;
   if(max_idx < first_idx) return rates_total;

   // Re-initialize buffers for target day processing
   ArrayInitialize(HAOpen, 0.0);
   ArrayInitialize(HAHigh, 0.0);
   ArrayInitialize(HALow, 0.0);
   ArrayInitialize(HAClose, 0.0);
   ArrayInitialize(HAColor, 0.0);
   ArrayInitialize(LowBuffer, 0.0);
   ArrayInitialize(HighBuffer, 0.0);
   ArrayInitialize(PivotLowBuffer, 0.0);
   ArrayInitialize(PivotHighBuffer, 0.0);

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

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point == 0.0) point = _Point;
   long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double double_spread = 2.0 * current_spread * point;

   SPivot pivots[100];
   int num_pivots = 0;
   int periodSec = PeriodSeconds();

   // Main calculation loop: sequential per-candle processing
   for(int i = first_idx + 1; i <= max_idx && !IsStopped(); i++) {
      if(time[i] >= targetDayEnd) break;

      // (1) Calculate Heiken Ashi candle & Semafors for bar i
      HAOpen[i] = (HAOpen[i - 1] + HAClose[i - 1]) / 2.0;
      HAClose[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      HAHigh[i] = MathMax(high[i], MathMax(HAOpen[i], HAClose[i]));
      HALow[i] = MathMin(low[i], MathMin(HAOpen[i], HAClose[i]));
      HAColor[i] = (HAOpen[i] < HAClose[i]) ? 0.0 : 1.0;

      if(HALow[i] < HALow[i - 1]) {
         LowBuffer[i] = HALow[i];
         LowBuffer[i - 1] = 0.0;
      } else {
         LowBuffer[i] = 0.0;
      }

      if(HAHigh[i] > HAHigh[i - 1]) {
         HighBuffer[i] = HAHigh[i];
         HighBuffer[i - 1] = 0.0;
      } else {
         HighBuffer[i] = 0.0;
      }

      // (2) Process Pivots & Trendlines up to bar i
      if(num_pivots == 0) {
         // Bootstrap phase
         int L_cand = first_idx;
         for(int k = first_idx; k <= i; k++) {
            if(HALow[k] <= HALow[L_cand]) L_cand = k;
         }

         int min_HAHigh_idx = first_idx;
         for(int k = first_idx; k <= i; k++) {
            if(HAHigh[k] <= HAHigh[min_HAHigh_idx]) min_HAHigh_idx = k;
         }
         double min_HAHigh = HAHigh[min_HAHigh_idx];
         double dome_L = HAHigh[first_idx] - min_HAHigh;

         if(dome_L > double_spread && HAColor[L_cand] == 1.0) {
            pivots[0].type = -1;
            pivots[0].bar_idx = L_cand;
            pivots[0].price = HALow[L_cand];
            pivots[0].time = time[L_cand];
            pivots[0].extreme_idx = min_HAHigh_idx;
            pivots[0].extreme_price = min_HAHigh;
            pivots[0].midpoint_price = (HAHigh[first_idx] + min_HAHigh) / 2.0;
            num_pivots = 1;
         } else {
            int H_cand = first_idx;
            for(int k = first_idx; k <= i; k++) {
               if(HAHigh[k] >= HAHigh[H_cand]) H_cand = k;
            }

            int max_HALow_idx = first_idx;
            for(int k = first_idx; k <= i; k++) {
               if(HALow[k] >= HALow[max_HALow_idx]) max_HALow_idx = k;
            }
            double max_HALow = HALow[max_HALow_idx];
            double dome_H = max_HALow - HALow[first_idx];

            if(dome_H > double_spread && HAColor[H_cand] == 0.0) {
               pivots[0].type = 1;
               pivots[0].bar_idx = H_cand;
               pivots[0].price = HAHigh[H_cand];
               pivots[0].time = time[H_cand];
               pivots[0].extreme_idx = max_HALow_idx;
               pivots[0].extreme_price = max_HALow;
               pivots[0].midpoint_price = (HALow[first_idx] + max_HALow) / 2.0;
               num_pivots = 1;
            }
         }
      } else {
         int last_type = pivots[num_pivots - 1].type;

         if(last_type == -1) { // Last active pivot is Low Pivot
            int prev_H_idx = (num_pivots >= 2) ? pivots[num_pivots - 2].bar_idx : first_idx;
            double prev_H_price = (num_pivots >= 2) ? pivots[num_pivots - 2].price : HAHigh[first_idx];

            int L_cand = prev_H_idx;
            for(int k = prev_H_idx; k <= i; k++) {
               if(HALow[k] <= HALow[L_cand]) L_cand = k;
            }

            int min_HAHigh_idx = prev_H_idx;
            for(int k = prev_H_idx; k <= i; k++) {
               if(HAHigh[k] <= HAHigh[min_HAHigh_idx]) min_HAHigh_idx = k;
            }
            double min_HAHigh = HAHigh[min_HAHigh_idx];
            double dome = prev_H_price - min_HAHigh;

            if(dome > double_spread && HAColor[L_cand] == 1.0) {
               pivots[num_pivots - 1].bar_idx = L_cand;
               pivots[num_pivots - 1].price = HALow[L_cand];
               pivots[num_pivots - 1].time = time[L_cand];
               pivots[num_pivots - 1].extreme_idx = min_HAHigh_idx;
               pivots[num_pivots - 1].extreme_price = min_HAHigh;
               pivots[num_pivots - 1].midpoint_price = (prev_H_price + min_HAHigh) / 2.0;
            } else if(HAColor[L_cand] == 0.0) {
               num_pivots--;
            }

            if(num_pivots > 0 && pivots[num_pivots - 1].type == -1) {
               int L_idx = pivots[num_pivots - 1].bar_idx;
               double L_price = pivots[num_pivots - 1].price;

               int H_cand = L_idx;
               for(int k = L_idx; k <= i; k++) {
                  if(HAHigh[k] >= HAHigh[H_cand]) H_cand = k;
               }

               int max_HALow_idx = L_idx;
               for(int k = L_idx; k <= i; k++) {
                  if(HALow[k] >= HALow[max_HALow_idx]) max_HALow_idx = k;
               }
               double max_HALow = HALow[max_HALow_idx];
               double dome_opp = max_HALow - L_price;

               if(dome_opp > double_spread && HAColor[H_cand] == 0.0 && num_pivots < 100) {
                  pivots[num_pivots].type = 1;
                  pivots[num_pivots].bar_idx = H_cand;
                  pivots[num_pivots].price = HAHigh[H_cand];
                  pivots[num_pivots].time = time[H_cand];
                  pivots[num_pivots].extreme_idx = max_HALow_idx;
                  pivots[num_pivots].extreme_price = max_HALow;
                  pivots[num_pivots].midpoint_price = (L_price + max_HALow) / 2.0;
                  num_pivots++;
               }
            }
         } else if(last_type == 1) { // Last active pivot is High Pivot
            int prev_L_idx = (num_pivots >= 2) ? pivots[num_pivots - 2].bar_idx : first_idx;
            double prev_L_price = (num_pivots >= 2) ? pivots[num_pivots - 2].price : HALow[first_idx];

            int H_cand = prev_L_idx;
            for(int k = prev_L_idx; k <= i; k++) {
               if(HAHigh[k] >= HAHigh[H_cand]) H_cand = k;
            }

            int max_HALow_idx = prev_L_idx;
            for(int k = prev_L_idx; k <= i; k++) {
               if(HALow[k] >= HALow[max_HALow_idx]) max_HALow_idx = k;
            }
            double max_HALow = HALow[max_HALow_idx];
            double dome = max_HALow - prev_L_price;

            if(dome > double_spread && HAColor[H_cand] == 0.0) {
               pivots[num_pivots - 1].bar_idx = H_cand;
               pivots[num_pivots - 1].price = HAHigh[H_cand];
               pivots[num_pivots - 1].time = time[H_cand];
               pivots[num_pivots - 1].extreme_idx = max_HALow_idx;
               pivots[num_pivots - 1].extreme_price = max_HALow;
               pivots[num_pivots - 1].midpoint_price = (prev_L_price + max_HALow) / 2.0;
            } else if(HAColor[H_cand] == 1.0) {
               num_pivots--;
            }

            if(num_pivots > 0 && pivots[num_pivots - 1].type == 1) {
               int H_idx = pivots[num_pivots - 1].bar_idx;
               double H_price = pivots[num_pivots - 1].price;

               int L_cand = H_idx;
               for(int k = H_idx; k <= i; k++) {
                  if(HALow[k] <= HALow[L_cand]) L_cand = k;
               }

               int min_HAHigh_idx = H_idx;
               for(int k = H_idx; k <= i; k++) {
                  if(HAHigh[k] <= HAHigh[min_HAHigh_idx]) min_HAHigh_idx = k;
               }
               double min_HAHigh = HAHigh[min_HAHigh_idx];
               double dome_opp = H_price - min_HAHigh;

               if(dome_opp > double_spread && HAColor[L_cand] == 1.0 && num_pivots < 100) {
                  pivots[num_pivots].type = -1;
                  pivots[num_pivots].bar_idx = L_cand;
                  pivots[num_pivots].price = HALow[L_cand];
                  pivots[num_pivots].time = time[L_cand];
                  pivots[num_pivots].extreme_idx = min_HAHigh_idx;
                  pivots[num_pivots].extreme_price = min_HAHigh;
                  pivots[num_pivots].midpoint_price = (H_price + min_HAHigh) / 2.0;
                  num_pivots++;
               }
            }
         }
      }

      // (3) Render Pivot Plot Arrows & Connecting Lines up to bar i
      for(int b = first_idx; b <= i; b++) {
         PivotLowBuffer[b] = 0.0;
         PivotHighBuffer[b] = 0.0;
      }

      ObjectsDeleteByPrefix(OBJ_PREFIX);

      for(int k = 0; k < num_pivots; k++) {
         if(pivots[k].type == -1) {
            PivotLowBuffer[pivots[k].bar_idx] = pivots[k].price;
         } else if(pivots[k].type == 1) {
            PivotHighBuffer[pivots[k].bar_idx] = pivots[k].price;
         }

         datetime prev_t;
         double prev_p;
         if(k == 0) {
            prev_t = time[first_idx];
            prev_p = (pivots[0].type == -1) ? HAHigh[first_idx] : HALow[first_idx];
         } else {
            prev_t = pivots[k - 1].time;
            prev_p = pivots[k - 1].price;
         }

         datetime t1 = prev_t;
         double p1 = prev_p;
         datetime t2 = pivots[k].time;
         double p2 = pivots[k].price;
         color line_color = (p2 >= p1) ? clrAqua : clrMagenta;
         string line_name = OBJ_PREFIX + "Line_" + IntegerToString(k);
         DrawTrendLine(line_name, t1, p1, t2, p2, line_color, STYLE_DOT, 1);

         string mid_name = OBJ_PREFIX + "Mid_" + IntegerToString(k);
         datetime mt1 = time[pivots[k].extreme_idx];
         datetime mt2 = mt1 + 10 * periodSec;
         double mp = pivots[k].midpoint_price;
         DrawTrendLine(mid_name, mt1, mp, mt2, mp, clrOrange, STYLE_DOT, 1);
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
