//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//|                                  Copyright 2024, Software Agency |
//|                                       Optimized for BTCUSD M1    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

#property indicator_label1 "Upper Line"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrGreen
#property indicator_width1 2

#property indicator_label2 "Lower Line"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_width2 2

//--- plot Semafor High
#property indicator_label3 "Level 2 High"
#property indicator_type3  DRAW_ARROW
#property indicator_color3 clrMagenta
#property indicator_width3 1
//--- plot Semafor Low
#property indicator_label4 "Level 2 Low"
#property indicator_type4  DRAW_ARROW
#property indicator_color4 clrAqua
#property indicator_width4 1

//--- plot BullBorder Events
#property indicator_label5 "Bullish Event"
#property indicator_type5  DRAW_ARROW
#property indicator_color5 clrLime
#property indicator_width5 1
//--- plot BearBorder Events
#property indicator_label6 "Bearish Event"
#property indicator_type6  DRAW_ARROW
#property indicator_color6 clrYellow
#property indicator_width6 1

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

//--- Indicator inputs
input int    InpKPeriod = 100;
input double InpLevel1  = 100.0;
input double InpLevel2  = 75.0;
input double InpLevel3  = 50.0;
input double InpLevel4  = 25.0;
input double InpLevel5  = 0.0;

//--- indicator buffers
double         BufferUp[];
double         BufferDown[];

double         BufferH[];
double         BufferL[];
double         BufferBullishEvent[];
double         BufferBearishEvent[];

double upper[2];
double resistance[2];
double mid[2];
double support[2];
double lower[2];

int stoch_bands_handle = INVALID_HANDLE;

//--- Level Settings (Hardcoded as per requirements)
const int L2_PERIOD = 13;
const int L2_BACKSTEP = 5;
const int L2_ARROW = 108;

//--- Anchor structure for state retention
struct SemaforAnchor {
   int      barIndex;
   double   price;
   datetime time;
   int      id;
};

enum EInteractionType {
   INT_NONE,
   INT_HIGH,
   INT_LOW
};

enum ECrossType {
   INT_NULL,
   INT_RES,
   INT_MID,
   INT_SUP
};

struct BorderState { // Tracks internal border
   ECrossType       crossState;
   EInteractionType pushState;
   int              bufferCrossCount;
};

struct LevelState { // Tracks level 2 high/low (level 1 is a minor consequence)
   SemaforAnchor highAnchors[2]; // Two most recent HIGH anchors
   SemaforAnchor lowAnchors[2]; // Two most recent LOW anchors
   int           firstBarOfDay;
   int           highCounter;
   int           lowCounter;
   bool          bullishLock;
   bool          bearishLock;
};

LevelState stateL2;

BorderState resStateL2;
BorderState supStateL2;

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
   SetIndexBuffer(0, BufferUp, INDICATOR_DATA);
   ArraySetAsSeries(BufferUp, false);
   SetIndexBuffer(1, BufferDown, INDICATOR_DATA);
   ArraySetAsSeries(BufferDown, false);
   
   SetIndexBuffer(2, BufferH, INDICATOR_DATA);
   ArraySetAsSeries(BufferH, false);
   SetIndexBuffer(3, BufferL, INDICATOR_DATA);
   ArraySetAsSeries(BufferL, false);
   SetIndexBuffer(4, BufferBullishEvent, INDICATOR_DATA);
   ArraySetAsSeries(BufferBullishEvent, false);
   SetIndexBuffer(5, BufferBearishEvent, INDICATOR_DATA);
   ArraySetAsSeries(BufferBearishEvent, false);

   //--- set arrow codes for Level 1 and Level 2
   PlotIndexSetInteger(2, PLOT_ARROW, L2_ARROW);
   PlotIndexSetInteger(3, PLOT_ARROW, L2_ARROW);
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Bullish event 217,225,233,241
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Bearish event

   //--- set empty values
   for(int i=0; i<4; i++) {
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   }
   for(int i=4; i<10; i++) {
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, 0.0);
   }

   //--- name for DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, "Custom Indicator (BTCUSD M1 Optimized)");

   //--- symbol/period check (informational)
   if(Symbol() != "BTCUSD" || _Period != PERIOD_M1) {
      Print("Note: This indicator is optimized for BTCUSD M1.");
   }

   stoch_bands_handle = iCustom(
      _Symbol,
      PERIOD_CURRENT,
      "Custom\\Stochastic bands",
      InpKPeriod,
      InpLevel1,
      InpLevel2,
      InpLevel3,
      InpLevel4,
      InpLevel5
   );
   
   //--- initialize state
   ResetLevelState(stateL2);
   
   ResetBorderState(resStateL2);
   ResetBorderState(supStateL2);
   
   targetDayStart = 0;
   targetDayEnd = 0;
   
   //--- Check whether the handle was created
   if(stoch_bands_handle == INVALID_HANDLE)
   {
      PrintFormat(
         "Failed to create Stochastic bands handle. Error: %d",
         GetLastError()
      );

      return INIT_FAILED;
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "L2_");
   ObjectsDeleteAll(0, "H2_");
   
   if(stoch_bands_handle != INVALID_HANDLE)
   {
      IndicatorRelease(stoch_bands_handle);
      stoch_bands_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Reset the state for a specific level                             |
//+------------------------------------------------------------------+
void ResetBorderState(BorderState &bs) {
   bs.crossState = false;
   bs.pushState = INT_NONE;
   bs.bufferCrossCount = 0;
}

//+------------------------------------------------------------------+
//| Helper functions for candle classification                      |
//+------------------------------------------------------------------+
bool IsBullishCandle(const double &o[], const double &c[], int idx) {
//bool IsBullishCandle(int idx) {
   return c[idx] > o[idx];
}

bool IsBearishCandle(const double &o[], const double &c[], int idx) {
//bool IsBearishCandle(int idx) {
   return c[idx] < o[idx];
}

void ResetLevelState(LevelState &state) {
   for(int i=0; i<2; i++) {
      state.highAnchors[i].barIndex = -1;
      state.highAnchors[i].price = 0;
      state.highAnchors[i].time = 0;
      state.highAnchors[i].id = 0;
      state.lowAnchors[i].barIndex = -1;
      state.lowAnchors[i].price = 0;
      state.lowAnchors[i].time = 0;
      state.lowAnchors[i].id = 0;
   }
   state.firstBarOfDay = -1;
   state.highCounter = 0;
   state.lowCounter = 0;
   state.bullishLock = false;
   state.bearishLock = false;
}

void DeleteConnector(int id, bool isHigh, string levelPrefix) {
   string prefix = "HL"; // isHigh ? "H_" : "L_";

   string lineName = levelPrefix + "_ZZ_Line_" + prefix + IntegerToString(id);
   string textName = levelPrefix + "_ZZ_Text_" + prefix + IntegerToString(id);

   ObjectDelete(0, lineName);
   ObjectDelete(0, textName);
}

void GetBands()
{
   const int count = 2;

   // CopyBuffer() places the oldest copied item at the beginning of physical memory
   int upper_count = CopyBuffer(
      stoch_bands_handle,
      0,
      1,
      count,
      upper
   );

   int resistance_count = CopyBuffer(
      stoch_bands_handle,
      1,
      1,
      count,
      resistance
   );

   int mid_count = CopyBuffer(
      stoch_bands_handle,
      2,
      1,
      count,
      mid
   );

   int support_count = CopyBuffer(
      stoch_bands_handle,
      3,
      1,
      count,
      support
   );

   int lower_count = CopyBuffer(
      stoch_bands_handle,
      4,
      1,
      count,
      lower
   );

   if(upper_count != count ||
      resistance_count != count ||
      mid_count != count ||
      support_count != count ||
      lower_count != count)
   {
      PrintFormat(
         "Not enough band data. Error: %d",
         GetLastError()
      );

      return;
   }
}

//+------------------------------------------------------------------+
//| Update a trend line object on the chart                          |
//+------------------------------------------------------------------+
void UpdateTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, string text) {
   if(ObjectFind(0, name) < 0) {
      if(ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2)) {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
      }
   } else {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
   }
}

//+------------------------------------------------------------------+
//| Update a text label object on the chart                          |
//+------------------------------------------------------------------+
void UpdateTextLabel(string name, datetime t, double p, string text) {
   if(ObjectFind(0, name) < 0) {
      if(ObjectCreate(0, name, OBJ_TEXT, 0, t, p)) {
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS");
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
      }
   } else {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
   }
}

//+------------------------------------------------------------------+
//| Draw and update the Level 2 zigzag lines and labels              |
//+------------------------------------------------------------------+
void DrawZigzagLines(const SemaforAnchor &start_v, const SemaforAnchor &end_v, bool isHigh, string levelPrefix) {
   // Styling: High-to-Low = Red, Low-to-High = Dodger Blue
   color lineClr = isHigh ? clrDodgerBlue : clrRed;

   // Price difference in points with +/- sign
   double diff = end_v.price - start_v.price;
   int points = (int)MathRound(diff / _Point);
   string textStr = StringFormat("%+d", points);

   // Midpoint calculations
   datetime midTime = (datetime)(start_v.time + (end_v.time - start_v.time) / 2);
   double midPrice = start_v.price + (end_v.price - start_v.price) / 2.0;

   string prefix = "HL"; // isHigh ? "H_" : "L_";
   
   string lineName = levelPrefix + "_ZZ_Line_" + prefix + IntegerToString(start_v.id);
   string textName = levelPrefix + "_ZZ_Text_" + prefix + IntegerToString(start_v.id);

   UpdateTrendLine(lineName, start_v.time, start_v.price, end_v.time, end_v.price, lineClr, textStr);
   //UpdateTextLabel(textName, midTime, midPrice, textStr);
}

//+------------------------------------------------------------------+
//| Draw vertical transition lines                                   |
//+------------------------------------------------------------------+
void DrawLockLine(int barIndex, datetime t, color clr, string prefix, ENUM_LINE_STYLE style) {
   string name = prefix + "_" + IntegerToString(barIndex);
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_VLINE, 0, t, 0);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Process level2 semafors for a specific candle index              |
//+------------------------------------------------------------------+
void ProcessLevelL2(int idx, int period, int backstep, int firstBar, const double &pOpen[], const double &pHigh[], const double &pLow[], const double &pClose[], const datetime &pTime[], LevelState &state, BorderState &resState, BorderState &supState, double &bufH[], double &bufL[]) {
   // Bootstrap: first candle of the day becomes both high and low anchors
   if(idx == firstBar)
   {
      int window_start = firstBar - period + 1;
      
      int hh_idx = ArrayMaximum(pHigh, window_start, period);
      int ll_idx = ArrayMinimum(pLow,  window_start, period);
      
      state.highCounter++;
      state.highAnchors[i].barIndex = idx;
      state.highAnchors[1].price    = pHigh[hh_idx];
      state.highAnchors[1].time     = pTime[idx];
      state.highAnchors[1].id       = state.highCounter;
      bufH[idx] = pHigh[hh_idx];

      state.lowCounter++;
      state.lowAnchors[1].barIndex = idx;
      state.lowAnchors[1].price    = pLow[ll_idx];
      state.lowAnchors[1].time     = pTime[idx];
      state.lowAnchors[1].id       = state.lowCounter;
      bufL[idx] = pLow[ll_idx];
      

      if(bufH[idx] > 0) BufferUp[idx] = pHigh[hh_idx];
      else if(BufferUp[idx - 1] > 0) BufferUp[idx] = BufferUp[idx - 1];
   
      if(bufL[idx] > 0) BufferDown[idx] = pLow[ll_idx];
      else if(BufferDown[idx - 1] > 0) BufferDown[idx] = BufferDown[idx - 1];
      
      return;
   }
   
   // Warm-up phase: allow only anchor evolution
   if(idx - firstBar < period - 1)
   {
      // High evolves
      if(pHigh[idx] > state.highAnchors[1].price)
      {
          // If this is the first move beyond the bootstrap high,
         // preserve the bootstrap anchor in [0].
         if(state.highAnchors[0].price <= 0)
         {
            state.highAnchors[0] = state.highAnchors[1];

            if(resState.pushState == INT_NONE)
            {
               DrawLockLine(idx, pTime[idx], clrLime, "L2_Bullish_Lock", STYLE_SOLID);
               resState.pushState = INT_HIGH;
               ResetBorderState(supState);
               resState.crossState = false;
               resState.bufferCrossCount = 0;
            }
         }
          
          bufH[state.highAnchors[1].barIndex] = 0;

          state.highAnchors[1].barIndex = idx;
          state.highAnchors[1].price    = pHigh[idx];
          state.highAnchors[1].time     = pTime[idx];

          bufH[idx] = pHigh[idx];
          state.bullishLock = true;
          
          //DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
          if(state.highAnchors[0].price > 0) {
            if(state.highAnchors[1].price > state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], true, "H2"); // HH
            else if(state.highAnchors[1].price < state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], false, "H2"); // LH
         }
      }

      // Low evolves
      if(pLow[idx] < state.lowAnchors[1].price)
      {
          // Preserve the original bootstrap low in [0].
         if(state.lowAnchors[0].price <= 0)
         {
            state.lowAnchors[0] = state.lowAnchors[1];
            
            if(supState.pushState == INT_NONE)
            {
               DrawLockLine(idx, pTime[idx], clrRed, "L2_Bearish_Lock", STYLE_SOLID);
               supState.pushState = INT_LOW;
               ResetBorderState(resState);
               supState.crossState = false;
               supState.bufferCrossCount = 0;
            }
         }
          
          bufL[state.lowAnchors[1].barIndex] = 0;

          state.lowAnchors[1].barIndex = idx;
          state.lowAnchors[1].price    = pLow[idx];
          state.lowAnchors[1].time     = pTime[idx];

          bufL[idx] = pLow[idx];
          state.bearishLock = true;
          
          //DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
          if(state.lowAnchors[0].price > 0) {
            if(state.lowAnchors[1].price < state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], false, "L2"); // LL
            else if(state.lowAnchors[1].price > state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], true, "L2"); // HL
         }
      }
       
      if(bufH[idx] > 0) BufferUp[idx] = pHigh[idx];
      else if(BufferUp[idx - 1] > 0) BufferUp[idx] = BufferUp[idx - 1];
   
      if(bufL[idx] > 0) BufferDown[idx] = pLow[idx];
      else if(BufferDown[idx - 1] > 0) BufferDown[idx] = BufferDown[idx - 1];

      return;
   }
   
   double brkPercentage = 1;

   // --- High Semafor ---
   bool isHighSemafor = true;
   for(int j = idx - 1; j > idx - period; j--) {
      // Equal high does not qualify as higher high
      if(pHigh[idx] < pHigh[j]) {
         isHighSemafor = false;
         break;
      }
   }

   if(isHighSemafor) {
      bool repainted = false;
      // Check if we can repaint the most recent active anchor within Backstep range
      int dist = idx - state.highAnchors[1].barIndex;
      if(dist <= backstep) {
         // Repaint: remove old visual and relocate to current extreme
         bufH[state.highAnchors[1].barIndex] = 0;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         bufH[idx] = pHigh[idx];
         repainted = true;
         
         //DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
         if(state.highAnchors[0].price > 0) {
            if(state.highAnchors[1].price > state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], true, "H2"); // HH
            else if(state.highAnchors[1].price < state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], false, "H2"); // LH
         }
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bullishLock) {
            state.bullishLock = true;
            state.bearishLock = false;
            state.highAnchors[0] = state.highAnchors[1];
         } else if(state.bullishLock) DeleteConnector(state.highAnchors[0].id, true, "H2");
         state.highCounter++;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         state.highAnchors[1].id = state.highCounter;
         bufH[idx] = pHigh[idx];
         
         //DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
         if(state.highAnchors[0].price > 0) {
            if(state.highAnchors[1].price > state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], true, "H2"); // HH
            else if(state.highAnchors[1].price < state.highAnchors[0].price) DrawZigzagLines(state.highAnchors[0], state.highAnchors[1], false, "H2"); // LH
         }
      }
      
      // trend set
      if(state.highAnchors[0].price > 0) {
         double prevLegHigh = state.highAnchors[0].price - state.lowAnchors[1].price;
         double currLegHigh = state.highAnchors[1].price - state.lowAnchors[1].price;
         
         if(NormalizeDouble(currLegHigh / prevLegHigh, 2) > brkPercentage) {
            if(pHigh[idx] >= (state.lowAnchors[1].price + NormalizeDouble(prevLegHigh * brkPercentage, 2))) {
               if(resState.pushState == INT_NONE) {
                  DrawLockLine(idx, pTime[idx], clrLime, "L2_Bullish_Lock", STYLE_SOLID);
                  resState.pushState = INT_HIGH;
                  ResetBorderState(supState);
                  resState.crossState = false;
                  resState.bufferCrossCount = 0;
               }
            }
         }
      }
   }

   // --- Low Semafor ---
   bool isLowSemafor = true;
   for(int j = idx - 1; j > idx - period; j--) {
      // Equal low does not qualify as lower low
      if(pLow[idx] > pLow[j]) {
         isLowSemafor = false;
         break;
      }
   }

   if(isLowSemafor) {
      bool repainted = false;
      // Check if we can repaint the most recent active anchor within Backstep range
      int dist = idx - state.lowAnchors[1].barIndex;
      if(dist <= backstep) {
         // Repaint: remove old visual and relocate to current extreme
         bufL[state.lowAnchors[1].barIndex] = 0;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         bufL[idx] = pLow[idx];
         repainted = true;
         
         //DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
         if(state.lowAnchors[0].price > 0) {
            if(state.lowAnchors[1].price < state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], false, "L2"); // LL
            else if(state.lowAnchors[1].price > state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], true, "L2"); // HL
         }
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bearishLock) {
            state.bearishLock = true;
            state.bullishLock = false;
            state.lowAnchors[0] = state.lowAnchors[1];
         } else if(state.bearishLock) DeleteConnector(state.lowAnchors[0].id, false, "L2");
         state.lowCounter++;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         state.lowAnchors[1].id = state.lowCounter;
         bufL[idx] = pLow[idx];
         
         //DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
         if(state.lowAnchors[0].price > 0) {
            if(state.lowAnchors[1].price < state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], false, "L2"); // LL
            else if(state.lowAnchors[1].price > state.lowAnchors[0].price) DrawZigzagLines(state.lowAnchors[0], state.lowAnchors[1], true, "L2"); // HL
         }
      }
      
      // trend set
      if(state.lowAnchors[0].price > 0) {
         double prevLegLow = state.highAnchors[1].price - state.lowAnchors[0].price;
         double currLegLow = state.highAnchors[1].price - state.lowAnchors[1].price;
         
         if(NormalizeDouble(currLegLow / prevLegLow, 2) > brkPercentage) {
            if(pLow[idx] <= (state.highAnchors[1].price - NormalizeDouble(prevLegLow * brkPercentage, 2))) {
               if(supState.pushState == INT_NONE) {
                  DrawLockLine(idx, pTime[idx], clrRed, "L2_Bearish_Lock", STYLE_SOLID);
                  supState.pushState = INT_LOW;
                  ResetBorderState(resState);
                  supState.crossState = false;
                  supState.bufferCrossCount = 0;
               }
            }
         }
      }
   }
   
   // external envelopes
   if(bufH[idx] > 0) BufferUp[idx] = pHigh[idx];
   else if(BufferUp[idx - 1] > 0) BufferUp[idx] = BufferUp[idx - 1];
   
   if(bufL[idx] > 0) BufferDown[idx] = pLow[idx];
   else if(BufferDown[idx - 1] > 0) BufferDown[idx] = BufferDown[idx - 1];
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
   if(rates_total < L2_PERIOD) return 0;

   // Always ensure the currently forming candle is empty (closed candles only)
   BufferUp[rates_total - 1] = EMPTY_VALUE;
   BufferDown[rates_total - 1] = EMPTY_VALUE;
   BufferH[rates_total - 1] = 0.0;
   BufferL[rates_total - 1] = 0.0;
   BufferBullishEvent[rates_total - 1] = 0.0;
   BufferBearishEvent[rates_total - 1] = 0.0;

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
      ArrayInitialize(BufferUp, EMPTY_VALUE);
      ArrayInitialize(BufferDown, EMPTY_VALUE);
      ArrayInitialize(BufferH, 0.0);
      ArrayInitialize(BufferL, 0.0);
      ArrayInitialize(BufferBullishEvent, 0.0);
      ArrayInitialize(BufferBearishEvent, 0.0);
      
      ObjectsDeleteAll(0, "L2_");
      
      ResetLevelState(stateL2);
      
      ResetBorderState(resStateL2);
      ResetBorderState(supStateL2);
      
      // Find the first bar of the day
      while(start_idx < rates_total && time[start_idx] < targetDayStart) {
         start_idx++;
      }
      stateL2.firstBarOfDay = start_idx;

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
   if(stateL2.firstBarOfDay < 0) {
      int fb = 0;
      while(fb < rates_total && time[fb] < targetDayStart) {
         fb++;
      }
      stateL2.firstBarOfDay = fb;
   }

   // Process only closed candles chronologically (up to rates_total - 2)
   // rates_total - 1 is the currently forming candle.
   for(int i = start_idx; i < rates_total - 1; i++) {
      if(time[i] >= targetDayEnd) break;
      
      if(time[i] >= targetDayStart) {
         ProcessLevelL2(i, L2_PERIOD, L2_BACKSTEP, stateL2.firstBarOfDay, open, high, low, close, time, stateL2, resStateL2, supStateL2, BufferH, BufferL);
      }
      
      GetBands();
      
      // bullish
		if(resStateL2.pushState == INT_HIGH)
		{
			// countercross
			if(resStateL2.crossState == INT_RES)
			{
				if(open[i] < resistance[i] && close[i] > resistance[i]) // bullish cc
				{
					if(IsBearishCandle(open, close, i-1) && high[i-1] > resistance[i-1] && close[i-1] < resistance[i-1] && close[i] > open[i-1] && resStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBullishEvent[i] = low[i];
					}
					else resStateL2.bufferCrossCount++;
				}
				
				if(resStateL2.bufferCrossCount > 0)
				{
					if(high[i] >= upper[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						resStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			if(resStateL2.crossState == INT_MID)
			{
				if(open[i] < mid[1] && close[i] > mid[1]) // bullish cc
				{
					if(high[i-1] > mid[i-1] && close[i-1] < mid[i-1] && resStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBullishEvent[i] = low[i];
					}
					else resStateL2.bufferCrossCount++;
				}
				
				if(resStateL2.bufferCrossCount > 0)
				{
					if(high[i] >= resistance[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						resStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			if(resStateL2.crossState == INT_SUP)
			{
				if(IsBullishCandle(open, close, i) && open[i] < support[i]) // bullish cc
				{
					if(IsBearishCandle(open, close, i-1) && close[i] > open[i-1] && resStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBullishEvent[i] = low[i];
					}
					else if(close[i] > support[i]) resStateL2.bufferCrossCount++;
				}
				
				if(resStateL2.bufferCrossCount > 0)
				{
					if(high[i] >= mid[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						resStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			// crossState
			if(resStateL2.crossState != INT_RES)
			{
				if((open[i] < resistance[i] && close[i] > resistance[i]) || (open[i] > resistance[i] && close[i] < resistance[i])) resStateL2.crossState = INT_RES;
			}
			else if(resStateL2.crossState != INT_MID)
			{
				if((open[i] < mid[i] && close[i] > mid[i]) || (open[i] > mid[i] && close[i] < mid[i])) resStateL2.crossState = INT_MID;
			}
			else if(resStateL2.crossState != INT_SUP)
			{
				if((open[i] < support[i] && close[i] > support[i]) || (open[i] > support[i] && close[i] < support[i])) resStateL2.crossState = INT_SUP;
			}
		}

		// bearish
		if(supStateL2.pushState == INT_LOW)
		{
			// countercross
			if(supStateL2.crossState == INT_SUP)
			{
				if(open[i] > support[i] && close[i] < support[i]) // bearish cc
				{
					if(IsBullishCandle(open, close, i-1) && low[i-1] < support[i-1] && close[i-1] > support[i-1] && close[i] < open[i-1] && supStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBearishEvent[i] = high[i];
					}
					else supStateL2.bufferCrossCount++;
				}
				
				if(supStateL2.bufferCrossCount > 0)
				{
					if(low[i] >= lower[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						supStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			if(supStateL2.crossState == INT_MID)
			{
				if(open[i] > mid[i] && close[i] < mid[i]) // bullish cc
				{
					if(low[i-1] < mid[i-1] && close[i-1] > mid[i-1] && supStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBearishEvent[i] = high[i];
					}
					else supStateL2.bufferCrossCount++;
				}
				
				if(supStateL2.bufferCrossCount > 0)
				{
					if(low[i] <= support[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						supStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			if(supStateL2.crossState == INT_RES)
			{
				if(IsBearishCandle(open, close, i) && open[i] > resistance[i]) // bullish cc
				{
					if(IsBullishCandle(open, close, i-1) && close[i] < open[i-1] && supStateL2.bufferCrossCount == 0) // bullish c/swipe
					{
						BufferBearishEvent[i] = high[i];
					}
					else if(close[i] < resistance[i]) supStateL2.bufferCrossCount++;
				}
				
				if(supStateL2.bufferCrossCount > 0)
				{
					if(low[i] <= mid[i] || high[i] >= BufferUp[i] || low[i] <= BufferDown[i])
					{
						supStateL2.bufferCrossCount = 0;
					}
				}
			}
			
			// crossState
			if(supStateL2.crossState != INT_RES)
			{
				if((open[i] < resistance[i] && close[i] > resistance[i]) || (open[i] > resistance[i] && close[i] < resistance[i])) supStateL2.crossState = INT_RES;
			}
			else if(supStateL2.crossState != INT_MID)
			{
				if((open[i] < mid[i] && close[i] > mid[i]) || (open[i] > mid[i] && close[i] < mid[i])) supStateL2.crossState = INT_MID;
			}
			else if(supStateL2.crossState != INT_SUP)
			{
				if((open[i] < support[i] && close[i] > support[i]) || (open[i] > support[i] && close[i] < support[i])) supStateL2.crossState = INT_SUP;
			}
		}
      
   } // limits

   return(rates_total);
}
//+------------------------------------------------------------------+



