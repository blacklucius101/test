//+------------------------------------------------------------------+
//|                                      Stochastic bands.mq5         |
//|                             Copyright 2025                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property description "Stochastic Bands"

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Resistance Band
#property indicator_label2  "Res Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Mid Band
#property indicator_label3  "Mid Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 4: Support Band
#property indicator_label4  "Sup Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5: Lower Band
#property indicator_label5  "Lower Band"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Input parameters
input int    InpKPeriod = 100;       // Stochastic lookback period
input double InpLevel1  = 100.0;   // Upper level
input double InpLevel2  = 75.0;    // Resistance level
input double InpLevel3  = 50.0;    // Mid level
input double InpLevel4  = 25.0;    // Support level
input double InpLevel5  = 0.0;     // Lower level

//--- Indicator buffers
double ExtUpperBuffer[];
double ExtResBuffer[];
double ExtMidBuffer[];
double ExtSupBuffer[];
double ExtLowerBuffer[];

//--- Effective K period
int ExtKPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Validate K period
   ExtKPeriod = InpKPeriod;

   if(ExtKPeriod < 1)
     {
      ExtKPeriod = 5;

      PrintFormat(
         "Invalid InpKPeriod = %d. Using %d instead.",
         InpKPeriod,
         ExtKPeriod
      );
     }

   //--- Map indicator buffers
   SetIndexBuffer(0, ExtUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtResBuffer,   INDICATOR_DATA);
   SetIndexBuffer(2, ExtMidBuffer,   INDICATOR_DATA);
   SetIndexBuffer(3, ExtSupBuffer,   INDICATOR_DATA);
   SetIndexBuffer(4, ExtLowerBuffer, INDICATOR_DATA);

   //--- Make buffers series arrays
   ArraySetAsSeries(ExtUpperBuffer, false);
   ArraySetAsSeries(ExtResBuffer,   false);
   ArraySetAsSeries(ExtMidBuffer,   false);
   ArraySetAsSeries(ExtSupBuffer,   false);
   ArraySetAsSeries(ExtLowerBuffer, false);

   //--- Indicator precision
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   //--- Indicator short name
   string short_name = StringFormat(
      "StochBands(%d)",
      ExtKPeriod
   );

   IndicatorSetString(
      INDICATOR_SHORTNAME,
      short_name
   );

   //--- Plot labels
   PlotIndexSetString(
      0,
      PLOT_LABEL,
      StringFormat("Upper Band (%.1f)", InpLevel1)
   );

   PlotIndexSetString(
      1,
      PLOT_LABEL,
      StringFormat("Res Band (%.1f)", InpLevel2)
   );

   PlotIndexSetString(
      2,
      PLOT_LABEL,
      StringFormat("Mid Band (%.1f)", InpLevel3)
   );

   PlotIndexSetString(
      3,
      PLOT_LABEL,
      StringFormat("Sup Band (%.1f)", InpLevel4)
   );

   PlotIndexSetString(
      4,
      PLOT_LABEL,
      StringFormat("Lower Band (%.1f)", InpLevel5)
   );

   //--- Don't draw until enough bars exist
   for(int plot = 0; plot < 5; plot++)
     {
      PlotIndexSetInteger(
         plot,
         PLOT_DRAW_BEGIN,
         ExtKPeriod - 1
      );

      PlotIndexSetDouble(
         plot,
         PLOT_EMPTY_VALUE,
         EMPTY_VALUE
      );
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
  {
   //--- Need enough bars for the lookback period
   if(rates_total < ExtKPeriod)
      return(0);

   //--- Determine starting bar
   int start;

   if(prev_calculated <= 0)
     {
      //--- First calculation
      start = ExtKPeriod - 1;

      //--- Clear bars before the first valid calculation
      for(int i = 0; i < start; i++)
        {
         ExtUpperBuffer[i] = EMPTY_VALUE;
         ExtResBuffer[i]   = EMPTY_VALUE;
         ExtMidBuffer[i]   = EMPTY_VALUE;
         ExtSupBuffer[i]   = EMPTY_VALUE;
         ExtLowerBuffer[i] = EMPTY_VALUE;
        }
     }
   else
     {
      //--- Recalculate the last completed bar as well
      start = prev_calculated - 1;

      if(start < ExtKPeriod - 1)
         start = ExtKPeriod - 1;
     }

   //--- Calculate bands
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      //--- Find lowest low and highest high
      //--- over the K-period lookback
      double range_low  = low[i];
      double range_high = high[i];

      for(int k = i - ExtKPeriod + 1; k <= i; k++)
        {
         if(low[k] < range_low)
            range_low = low[k];

         if(high[k] > range_high)
            range_high = high[k];
        }

      //--- Price range
      double price_range = range_high - range_low;

      //--- Protect against zero-range bars
      if(price_range <= 0.0)
        {
         ExtUpperBuffer[i] = range_low;
         ExtResBuffer[i]   = range_low;
         ExtMidBuffer[i]   = range_low;
         ExtSupBuffer[i]   = range_low;
         ExtLowerBuffer[i] = range_low;

         continue;
        }

      //--- Map stochastic levels to price
      ExtUpperBuffer[i] =
         range_low + (InpLevel1 / 100.0) * price_range;

      ExtResBuffer[i] =
         range_low + (InpLevel2 / 100.0) * price_range;

      ExtMidBuffer[i] =
         range_low + (InpLevel3 / 100.0) * price_range;

      ExtSupBuffer[i] =
         range_low + (InpLevel4 / 100.0) * price_range;

      ExtLowerBuffer[i] =
         range_low + (InpLevel5 / 100.0) * price_range;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
