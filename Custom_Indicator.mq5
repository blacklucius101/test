//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots   5

//--- Plot 1: Heiken Ashi candles
#property indicator_type1   DRAW_COLOR_BARS
#property indicator_color1  clrDodgerBlue, clrRed
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"

//--- Plot 2: Buy arrows
#property indicator_type2   DRAW_ARROW
#property indicator_color2  Aqua
#property indicator_width2  1
#property indicator_label2  "Low"

//--- Plot 3: Sell arrows
#property indicator_type3   DRAW_ARROW
#property indicator_color3  Magenta
#property indicator_width3  1
#property indicator_label3  "High"

//--- Plot 4: BullBorder Events
#property indicator_label5 "Bullish Event"
#property indicator_type5  DRAW_ARROW
#property indicator_color5 clrLime
#property indicator_width5 1

//--- Plot 5: BearBorder Events
#property indicator_label6 "Bearish Event"
#property indicator_type6  DRAW_ARROW
#property indicator_color6 clrYellow
#property indicator_width6 1

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

input int Period1      = 2;    // Depth
input int Deviation1   = 1;    // Deviation in points
input int Backstep1    = 1;    // Backstep
input int HighSymbol1  = 158;  // High senafor symbol
input int LowSymbol1   = 158;  // Low semafor symbol
input int BuySymbol   = 233;  // Buy arrow symbol
input int SellSymbol  = 234;  // Sell arrow symbol

//--- Heiken Ashi candle buffers (0-4)
double HAOpen[];
double HAHigh[];
double HALow[];
double HAClose[];
double HAColor[];

int ArrowShiftPixels = 10;

//--- Semafor buffers (5-6)
double LowBuffer1[];
double HighBuffer1[];

//--- Calculation buffers (7-8)
double LowMapBuffer[];
double HighMapBuffer[];

//--- Event buffers (9-10)
double         BufferBullishEvent[];
double         BufferBearishEvent[];

datetime targetDayStart = 0;
datetime targetDayEnd = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- indicator buffers mapping
   //--- use normal array indexing (oldest bar at index 0)
   
   //--- Heiken Ashi candle plot
   SetIndexBuffer(0, HAOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, HAHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, HALow,   INDICATOR_DATA);
   SetIndexBuffer(3, HAClose, INDICATOR_DATA);
   SetIndexBuffer(4, HAColor, INDICATOR_COLOR_INDEX);

   //--- Semafor plots
   SetIndexBuffer(5, LowBuffer1,  INDICATOR_DATA);
   SetIndexBuffer(6, HighBuffer1, INDICATOR_DATA);

   //--- Calculation buffers
   SetIndexBuffer(7, LowMapBuffer,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, HighMapBuffer, INDICATOR_CALCULATIONS);

   SetIndexBuffer(9, BufferBullishEvent, INDICATOR_DATA);
   SetIndexBuffer(10, BufferBearishEvent, INDICATOR_DATA);

   //--- Set arrow shifts
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, ArrowShiftPixels);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -ArrowShiftPixels);

   //--- Arrow symbols
   PlotIndexSetInteger(1, PLOT_ARROW, LowSymbol1);
   PlotIndexSetInteger(2, PLOT_ARROW, HighSymbol1);
   
   PlotIndexSetInteger(9, PLOT_ARROW, BuySymbol); // Bullish event 217,225,233,241
   PlotIndexSetInteger(10, PLOT_ARROW, SellSymbol); // Bearish event

   //--- Set series orientation AFTER binding
   ArraySetAsSeries(HAOpen, false);
   ArraySetAsSeries(HAHigh, false);
   ArraySetAsSeries(HALow, false);
   ArraySetAsSeries(HAClose, false);
   ArraySetAsSeries(HAColor, false);

   ArraySetAsSeries(LowBuffer1, false);
   ArraySetAsSeries(HighBuffer1, false);
   ArraySetAsSeries(LowMapBuffer, false);
   ArraySetAsSeries(HighMapBuffer, false);
   
   ArraySetAsSeries(BufferBullishEvent, false);
   ArraySetAsSeries(BufferBearishEvent, false);
   
   //--- set empty values
   

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Zigzags");
   
   //--- initialize state
   ResetLevelState();
   
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
   if(rates_total < Period1 + Backstep1 + 2) return 0;

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

   int start_idx;
   if(fullReset || prev_calculated == 0) {
      start_idx = 0;
      // Clear all buffers for the entire range
      ArrayInitialize(BufferBullishEvent, 0.0);
      ArrayInitialize(BufferBearishEvent, 0.0);
                  
      // Find the first bar of the day
      while(start_idx < rates_total && time[start_idx] < targetDayStart) {
         start_idx++;
      }
      state.firstBarOfDay = start_idx;

   } else {
      // Start from the last processed bar minus one to handle repaints
      start_idx = prev_calculated - 1;
      if(start_idx < 0) start_idx = 0;
      // Safety: make sure we don't start before the target day
      while(start_idx < rates_total && time[start_idx] < targetDayStart) {
         start_idx++;
      }
   }

   // Ensure firstBarOfDay is always valid
   if(state.firstBarOfDay < 0) {
      int fb = 0;
      while(fb < rates_total && time[fb] < targetDayStart) {
         fb++;
      }
      state.firstBarOfDay = fb;
   }

   // Process candles chronologically (up to rates_total - 1)
   // rates_total - 1 is the currently forming candle.
   for(int i = start_idx; i < rates_total; i++) {
      if(time[i] >= targetDayEnd) break;
      
      if(time[i] >= targetDayStart) {
         // custom code goes here
      }
      
   } // limits

   return(rates_total);
}
//+------------------------------------------------------------------+
