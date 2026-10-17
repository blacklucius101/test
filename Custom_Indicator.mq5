//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Heiken Ashi bars
#property indicator_type1   DRAW_COLOR_BARS
#property indicator_color1  clrDodgerBlue, clrRed
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

//--- Heiken Ashi candle buffers (0-4)
double HAOpen[];
double HAHigh[];
double HALow[];
double HAClose[];
double HAColor[];

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

   //--- Set series orientation AFTER binding
   ArraySetAsSeries(HAOpen, false);
   ArraySetAsSeries(HAHigh, false);
   ArraySetAsSeries(HALow, false);
   ArraySetAsSeries(HAClose, false);
   ArraySetAsSeries(HAColor, false);

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Heiken Ashi");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

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

   return(rates_total);
}
//+------------------------------------------------------------------+

/* Custom functionality
-----------------------
//--- Plot 2: High semafors
#property indicator_type2   DRAW_ARROW
#property indicator_color2  Aqua
#property indicator_width2  1
#property indicator_label2  "Low"

//--- Plot 3: Low semafors
#property indicator_type3   DRAW_ARROW
#property indicator_color3  Magenta
#property indicator_width3  1
#property indicator_label3  "High"

//--- Notables
Period      = 2;
Backstep    = 1;

int HighSemafor1 = 158;  // High semafor symbol
int LowSemafor1  = 158;  // Low semafor symbol
int ArrowShiftPixels = 10;

//--- Set arrow shifts
PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, ArrowShiftPixels);
PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -ArrowShiftPixels);

//--- OnCalculate
1. If current index is first bar of the target day, bootstrap by anchoring semafors to HAHigh and HALow of that first bar.
   
2. For subsequent candles, repaint semafors higher or lower depending on whether previous anchor was exceeded.
   - Draw a line (color dictated by slope) connecting high and low semafors, in zigzag fashion.
   - A semafor is valid for zigzag connection (greater semafor) if it is anchored to a corresponding HAColor bar, ie.:
      - High semafor valid if anchored to dodger blue bar.
      - Low semafor valid if anchored to red bar.

3. Additionally, a greater semafor occurs when the "dome" distance is at least 2x the instrument spread.
   - "Dome" distance is defined as follows:
      - For a high-low semafor pair (in chronological order, ie. high bar index before low bar index), the low becomes a greater semafor if the distance from the low semafor anchor to the highest low between the two bars (inclusive) is at least 2x the symbol's spread.
      - For a low-high semafor pair (in chronological order, ie. low bar index before high bar index), the high becomes a greater semafor if the distance from the high semafor anchor to the lowest high between the two bars (inclusive) is at least 2x the symbol's spread.

Secondary feature: A short horizontal line (no ray extensions), preferably anchored to the zigzag connecting line, ought to mark out the halfway point of the "dome" distance.
*/
