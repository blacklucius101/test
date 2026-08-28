//+------------------------------------------------------------------+
//|                                             Custom_Indicator.mq5 |
//|                                  Copyright 2024, Software Agency |
//|                                       Optimized for BTCUSD M1    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.21"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   10

#property indicator_label1 "Upper Line"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrGreen
#property indicator_width1 2

#property indicator_label2 "Lower Line"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_width2 2

#property indicator_label3 "Resistance Line"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrGreen
#property indicator_width3 1

#property indicator_label4 "Support Line"
#property indicator_type4 DRAW_LINE
#property indicator_color4 clrRed
#property indicator_width4 1

//--- plot Level 1 High
#property indicator_label5  "Level 1 High"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_width5  1
//--- plot Level 1 Low
#property indicator_label6  "Level 1 Low"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrAqua
#property indicator_width6  1
//--- plot Level 2 High
#property indicator_label7 "Level 2 High"
#property indicator_type7  DRAW_ARROW
#property indicator_color7 clrMagenta
#property indicator_width7 1
//--- plot Level 2 Low
#property indicator_label8 "Level 2 Low"
#property indicator_type8  DRAW_ARROW
#property indicator_color8 clrAqua
#property indicator_width8 1

//--- plot BullBorder Events
#property indicator_label9 "Bullish Event"
#property indicator_type9  DRAW_ARROW
#property indicator_color9 clrLime
#property indicator_width9 1
//--- plot BearBorder Events
#property indicator_label10 "Bearish Event"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrYellow
#property indicator_width10 1

//--- input parameters
input datetime InpHistoricalDate = 0;   // Historical Date (YYYY.MM.DD) - 0 for Current Day

//--- indicator buffers
double         BufferUp[];
double         BufferDown[];
double         BufferResistance[];
double         BufferSupport[];

double         BufferL1H[];
double         BufferL1L[];
double         BufferL2H[];
double         BufferL2L[];
double         BufferBullishEvent[];
double         BufferBearishEvent[];

//--- Level Settings (Hardcoded as per requirements)
const int L1_PERIOD = 3;
const int L1_BACKSTEP = 3;
const int L1_ARROW = 159;

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

enum EBorderLevel {
   INT_NULL,
   INT_30,
   INT_40,
   INT_50,
   INT_60,
   INT_70
};

struct BorderState { // Tracks internal border
   EBorderLevel crossState;
   EInteractionType pushState;
   double retLevel;
   int bufferCrossCount;
   int bufferDelayCount;
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

LevelState stateL1;
LevelState stateL2;

BorderState resState;
BorderState supState;

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
   SetIndexBuffer(2, BufferResistance, INDICATOR_DATA);
   ArraySetAsSeries(BufferResistance, false);
   SetIndexBuffer(3, BufferSupport, INDICATOR_DATA);
   ArraySetAsSeries(BufferSupport, false);
   
   SetIndexBuffer(4, BufferL1H, INDICATOR_DATA);
   ArraySetAsSeries(BufferL1H, false);
   SetIndexBuffer(5, BufferL1L, INDICATOR_DATA);
   ArraySetAsSeries(BufferL1L, false);
   SetIndexBuffer(6, BufferL2H, INDICATOR_DATA);
   ArraySetAsSeries(BufferL2H, false);
   SetIndexBuffer(7, BufferL2L, INDICATOR_DATA);
   ArraySetAsSeries(BufferL2L, false);
   SetIndexBuffer(8, BufferBullishEvent, INDICATOR_DATA);
   ArraySetAsSeries(BufferBullishEvent, false);
   SetIndexBuffer(9, BufferBearishEvent, INDICATOR_DATA);
   ArraySetAsSeries(BufferBearishEvent, false);

   //--- set arrow codes for Level 1 and Level 2
   PlotIndexSetInteger(4, PLOT_ARROW, L1_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, L1_ARROW);
   PlotIndexSetInteger(6, PLOT_ARROW, L2_ARROW);
   PlotIndexSetInteger(7, PLOT_ARROW, L2_ARROW);
   PlotIndexSetInteger(8, PLOT_ARROW, 233); // Bullish event 217,225,233,241
   PlotIndexSetInteger(9, PLOT_ARROW, 234); // Bearish event

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

   //--- initialize state
   ResetLevelState(stateL1);
   ResetLevelState(stateL2);
   
   ResetBorderState(resState);
   ResetBorderState(supState);
   
   targetDayStart = 0;
   targetDayEnd = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "L2_");
   ObjectsDeleteAll(0, "L1_");
}

//+------------------------------------------------------------------+
//| Reset the state for a specific level                             |
//+------------------------------------------------------------------+
void ResetBorderState(BorderState &bs) {
   bs.crossState = INT_NULL;
   bs.pushState = INT_NONE;
   bs.retLevel = 0;
   bs.bufferCrossCount = 0;
   bs.bufferDelayCount = 0;
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
   string prefix = isHigh ? "H_" : "L_";

   string lineName = levelPrefix + "_ZZ_Line_" + prefix + IntegerToString(id);
   string textName = levelPrefix + "_ZZ_Text_" + prefix + IntegerToString(id);

   ObjectDelete(0, lineName);
   ObjectDelete(0, textName);
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

   string prefix = isHigh ? "H_" : "L_";
   
   string lineName = levelPrefix + "_ZZ_Line_" + prefix + IntegerToString(end_v.id);
   string textName = levelPrefix + "_ZZ_Text_" + prefix + IntegerToString(end_v.id);

   UpdateTrendLine(lineName, start_v.time, start_v.price, end_v.time, end_v.price, lineClr, textStr);
   UpdateTextLabel(textName, midTime, midPrice, textStr);
}

//+------------------------------------------------------------------+
//| Draw vertical transition lines                                   |
//+------------------------------------------------------------------+
void DrawLockLine(int barIndex, datetime t, color clr, string prefix, ENUM_LINE_STYLE style) {
   string name = prefix + "_" + IntegerToString(barIndex);
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_VLINE, 0, t, 0);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Process level1 semafors for a specific candle index           |
//+------------------------------------------------------------------+
void ProcessLevelL1(int idx, int period, int backstep, int firstBar, const double &pOpen[], const double &pHigh[], const double &pLow[], const double &pClose[], const datetime &pTime[], LevelState &state, double &bufH[], double &bufL[]) {
   // Bootstrap: first candle of the day becomes both high and low anchors
   if(idx == firstBar)
   {
      int window_start = firstBar - period + 1;
      
      int hh_idx = ArrayMaximum(pHigh, window_start, period);
      int ll_idx = ArrayMinimum(pLow,  window_start, period);
      
      state.highCounter++;
      state.highAnchors[1].barIndex = idx;
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
      

      if(bufH[idx] > 0) BufferResistance[idx] = pHigh[hh_idx];
      else if(BufferResistance[idx - 1] > 0) BufferResistance[idx] = BufferResistance[idx - 1];
   
      if(bufL[idx] > 0) BufferSupport[idx] = pLow[ll_idx];
      else if(BufferSupport[idx - 1] > 0) BufferSupport[idx] = BufferSupport[idx - 1];
      
      return;
   }
   
   // Warm-up phase: allow only anchor evolution
   if(idx - firstBar < period - 1)
   {
      // High evolves
      if(pHigh[idx] > state.highAnchors[1].price)
      {
          bufH[state.highAnchors[1].barIndex] = 0;

          state.highAnchors[1].barIndex = idx;
          state.highAnchors[1].price    = pHigh[idx];
          state.highAnchors[1].time     = pTime[idx];

          bufH[idx] = pHigh[idx];
          state.bullishLock = true;
          
          DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L1"); // HH
      }

      // Low evolves
      if(pLow[idx] < state.lowAnchors[1].price)
      {
          bufL[state.lowAnchors[1].barIndex] = 0;

          state.lowAnchors[1].barIndex = idx;
          state.lowAnchors[1].price    = pLow[idx];
          state.lowAnchors[1].time     = pTime[idx];

          bufL[idx] = pLow[idx];
          state.bearishLock = true;
          
          DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L1"); // LL
      }
       
      if(bufH[idx] > 0) BufferResistance[idx] = pHigh[idx];
      else if(BufferResistance[idx - 1] > 0) BufferResistance[idx] = BufferResistance[idx - 1];
   
      if(bufL[idx] > 0) BufferSupport[idx] = pLow[idx];
      else if(BufferSupport[idx - 1] > 0) BufferSupport[idx] = BufferSupport[idx - 1];

       return;
   }
   
   // Check if enough candles exist since the start of the day to satisfy Period requirement
   if(idx - firstBar < period - 1) return;
   
   double brkPercentage = 0.72;
   double retPercentage = 0.72;

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
      if(dist <= backstep && !(state.highAnchors[1].barIndex < state.lowAnchors[1].barIndex)) {
         // Repaint: remove old visual and relocate to current extreme
         bufH[state.highAnchors[1].barIndex] = 0;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         bufH[idx] = pHigh[idx];
         repainted = true;
         
         DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L1"); // HH
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bullishLock) {
            state.bullishLock = true;
            state.bearishLock = false;
            state.highAnchors[0] = state.highAnchors[1];
         } else if(state.bullishLock /*&& (pHigh[idx] > state.highAnchors[1].price)*/) DeleteConnector(state.highAnchors[1].id, true, "L1");
         state.highCounter++;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         state.highAnchors[1].id = state.highCounter;
         bufH[idx] = pHigh[idx];
         
         DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L1"); // HH
      }
      
      // trend set
      if(state.highAnchors[0].price > 0) {
         double prevLegHigh = state.highAnchors[0].price - state.lowAnchors[1].price;
         double currLegHigh = state.highAnchors[1].price - state.lowAnchors[1].price;
         resState.retLevel = state.highAnchors[1].price - NormalizeDouble(currLegHigh * retPercentage, 2);
         
         if(state.highAnchors[1].price/* > state.highAnchors[0].price*/) {
            if(NormalizeDouble(currLegHigh / prevLegHigh, 2) > brkPercentage) {
               if(pClose[idx] >= (state.lowAnchors[1].price + NormalizeDouble(prevLegHigh * brkPercentage, 2))) {
               //if(pClose[idx] >= state.highAnchors[0].price) {
                  if(resState.pushState == INT_NONE) DrawLockLine(idx, pTime[idx], clrLime, "L1_Bullish_Lock", STYLE_DOT);
                  resState.pushState = INT_HIGH;
                  supState.pushState = INT_NONE;
                  resState.crossState = INT_NULL;
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
      if(dist <= backstep && !(state.lowAnchors[1].barIndex < state.highAnchors[1].barIndex)) {
         // Repaint: remove old visual and relocate to current extreme
         bufL[state.lowAnchors[1].barIndex] = 0;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         bufL[idx] = pLow[idx];
         repainted = true;
         
         DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L1"); // LL
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bearishLock) {
            state.bearishLock = true;
            state.bullishLock = false;
            state.lowAnchors[0] = state.lowAnchors[1];
         } else if(state.bearishLock /*&& (pLow[idx] < state.lowAnchors[1].price)*/) DeleteConnector(state.lowAnchors[1].id, false, "L1");
         state.lowCounter++;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         state.lowAnchors[1].id = state.lowCounter;
         bufL[idx] = pLow[idx];
         
         DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L1"); // LL
      }
      
      // trend set
      if(state.lowAnchors[0].price > 0) {
         double prevLegLow = state.highAnchors[1].price - state.lowAnchors[0].price;
         double currLegLow = state.highAnchors[1].price - state.lowAnchors[1].price;
         supState.retLevel = state.lowAnchors[1].price + NormalizeDouble(currLegLow * retPercentage, 2);
         
         if(state.lowAnchors[1].price/* < state.lowAnchors[0].price*/) {
            if(NormalizeDouble(currLegLow / prevLegLow, 2) > brkPercentage) {
               if(pClose[idx] <= (state.highAnchors[1].price - NormalizeDouble(prevLegLow * brkPercentage, 2))) {
               //f(pClose[idx] <= state.lowAnchors[0].price) {
                  if(supState.pushState == INT_NONE) DrawLockLine(idx, pTime[idx], clrRed, "L1_Bearish_Lock", STYLE_DOT);
                  supState.pushState = INT_LOW;
                  resState.pushState = INT_NONE;
                  supState.crossState = INT_NULL;
               }
            }
         }
      }
   }
   
   // external envelopes
   if(bufH[idx] > 0) BufferResistance[idx] = pHigh[idx];
   else if(BufferResistance[idx - 1] > 0) BufferResistance[idx] = BufferResistance[idx - 1];
   
   if(bufL[idx] > 0) BufferSupport[idx] = pLow[idx];
   else if(BufferSupport[idx - 1] > 0) BufferSupport[idx] = BufferSupport[idx - 1];
}

//+------------------------------------------------------------------+
//| Process level2 semafors for a specific candle index           |
//+------------------------------------------------------------------+
void ProcessLevelL2(int idx, int period, int backstep, int firstBar, const double &pOpen[], const double &pHigh[], const double &pLow[], const double &pClose[], const datetime &pTime[], LevelState &state, double &bufH[], double &bufL[]) {
   // Bootstrap: first candle of the day becomes both high and low anchors
   if(idx == firstBar)
   {
      int window_start = firstBar - period + 1;
      
      int hh_idx = ArrayMaximum(pHigh, window_start, period);
      int ll_idx = ArrayMinimum(pLow,  window_start, period);
      
      state.highCounter++;
      state.highAnchors[1].barIndex = idx;
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
          bufH[state.highAnchors[1].barIndex] = 0;

          state.highAnchors[1].barIndex = idx;
          state.highAnchors[1].price    = pHigh[idx];
          state.highAnchors[1].time     = pTime[idx];

          bufH[idx] = pHigh[idx];
          state.bullishLock = true;
          
          DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
      }

      // Low evolves
      if(pLow[idx] < state.lowAnchors[1].price)
      {
          bufL[state.lowAnchors[1].barIndex] = 0;

          state.lowAnchors[1].barIndex = idx;
          state.lowAnchors[1].price    = pLow[idx];
          state.lowAnchors[1].time     = pTime[idx];

          bufL[idx] = pLow[idx];
          state.bearishLock = true;
          
          DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
      }
       
      if(bufH[idx] > 0) BufferUp[idx] = pHigh[idx];
      else if(BufferUp[idx - 1] > 0) BufferUp[idx] = BufferUp[idx - 1];
   
      if(bufL[idx] > 0) BufferDown[idx] = pLow[idx];
      else if(BufferDown[idx - 1] > 0) BufferDown[idx] = BufferDown[idx - 1];

      return;
   }
   
   // Check if enough candles exist since the start of the day to satisfy Period requirement
   if(idx - firstBar < period - 1) return;
   
   double brkPercentage = 0.72;
   double retPercentage = 0.72;

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
      if(dist <= backstep && !(state.highAnchors[1].barIndex < state.lowAnchors[1].barIndex)) {
         // Repaint: remove old visual and relocate to current extreme
         bufH[state.highAnchors[1].barIndex] = 0;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         bufH[idx] = pHigh[idx];
         repainted = true;
         
         DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bullishLock) {
            state.bullishLock = true;
            state.bearishLock = false;
            state.highAnchors[0] = state.highAnchors[1];
         } else if(state.bullishLock /*&& (pHigh[idx] > state.highAnchors[1].price)*/) DeleteConnector(state.highAnchors[1].id, true, "L2");
         state.highCounter++;
         state.highAnchors[1].barIndex = idx;
         state.highAnchors[1].price = pHigh[idx];
         state.highAnchors[1].time = pTime[idx];
         state.highAnchors[1].id = state.highCounter;
         bufH[idx] = pHigh[idx];
         
         DrawZigzagLines(state.lowAnchors[1], state.highAnchors[1], true, "L2"); // HH
      }
      
      // trend set
      if(state.highAnchors[0].price > 0) {
         double prevLegHigh = state.highAnchors[0].price - state.lowAnchors[1].price;
         double currLegHigh = state.highAnchors[1].price - state.lowAnchors[1].price;
         resState.retLevel = state.highAnchors[1].price - NormalizeDouble(currLegHigh * retPercentage, 2);
         
         if(state.highAnchors[1].price/* > state.highAnchors[0].price*/) {
            if(NormalizeDouble(currLegHigh / prevLegHigh, 2) > brkPercentage) {
               if(pClose[idx] >= (state.lowAnchors[1].price + NormalizeDouble(prevLegHigh * brkPercentage, 2))) {
               //if(pClose[idx] >= state.highAnchors[0].price) {
                  if(resState.pushState == INT_NONE) DrawLockLine(idx, pTime[idx], clrLime, "L2_Bullish_Lock", STYLE_SOLID);
                  resState.pushState = INT_HIGH;
                  supState.pushState = INT_NONE;
                  resState.crossState = INT_NULL;
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
      if(dist <= backstep && !(state.lowAnchors[1].barIndex < state.highAnchors[1].barIndex)) {
         // Repaint: remove old visual and relocate to current extreme
         bufL[state.lowAnchors[1].barIndex] = 0;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         bufL[idx] = pLow[idx];
         repainted = true;
         
         DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
      }
      
      if(!repainted) {
         // New anchor: push previous to secondary position and finalize current
         if(!state.bearishLock) {
            state.bearishLock = true;
            state.bullishLock = false;
            state.lowAnchors[0] = state.lowAnchors[1];
         } else if(state.bearishLock /*&& (pLow[idx] < state.lowAnchors[1].price)*/) DeleteConnector(state.lowAnchors[1].id, false, "L2");
         state.lowCounter++;
         state.lowAnchors[1].barIndex = idx;
         state.lowAnchors[1].price = pLow[idx];
         state.lowAnchors[1].time = pTime[idx];
         state.lowAnchors[1].id = state.lowCounter;
         bufL[idx] = pLow[idx];
         
         DrawZigzagLines(state.highAnchors[1], state.lowAnchors[1], false, "L2"); // LL
      }
      
      // trend set
      if(state.lowAnchors[0].price > 0) {
         double prevLegLow = state.highAnchors[1].price - state.lowAnchors[0].price;
         double currLegLow = state.highAnchors[1].price - state.lowAnchors[1].price;
         supState.retLevel = state.lowAnchors[1].price + NormalizeDouble(currLegLow * retPercentage, 2);
         
         if(state.lowAnchors[1].price/* < state.lowAnchors[0].price*/) {
            if(NormalizeDouble(currLegLow / prevLegLow, 2) > brkPercentage) {
               if(pClose[idx] <= (state.highAnchors[1].price - NormalizeDouble(prevLegLow * brkPercentage, 2))) {
               //f(pClose[idx] <= state.lowAnchors[0].price) {
                  if(supState.pushState == INT_NONE) DrawLockLine(idx, pTime[idx], clrRed, "L2_Bearish_Lock", STYLE_SOLID);
                  supState.pushState = INT_LOW;
                  resState.pushState = INT_NONE;
                  supState.crossState = INT_NULL;
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
   if(rates_total < MathMax(L1_PERIOD, L2_PERIOD)) return 0;

   // Always ensure the currently forming candle is empty (closed candles only)
   BufferUp[rates_total - 1] = EMPTY_VALUE;
   BufferDown[rates_total - 1] = EMPTY_VALUE;
   BufferResistance[rates_total - 1] = EMPTY_VALUE;
   BufferSupport[rates_total - 1] = EMPTY_VALUE;
   BufferL1H[rates_total - 1] = 0.0;
   BufferL1L[rates_total - 1] = 0.0;
   BufferL2H[rates_total - 1] = 0.0;
   BufferL2L[rates_total - 1] = 0.0;
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
      ArrayInitialize(BufferResistance, EMPTY_VALUE);
      ArrayInitialize(BufferSupport, EMPTY_VALUE);
      ArrayInitialize(BufferL1H, 0.0);
      ArrayInitialize(BufferL1L, 0.0);
      ArrayInitialize(BufferL2H, 0.0);
      ArrayInitialize(BufferL2L, 0.0);
      ArrayInitialize(BufferBullishEvent, 0.0);
      ArrayInitialize(BufferBearishEvent, 0.0);
      
      ObjectsDeleteAll(0, "L2_");
      ObjectsDeleteAll(0, "L1_");
      
      ResetLevelState(stateL1);
      ResetLevelState(stateL2);
      
      ResetBorderState(resState);
      ResetBorderState(supState);
      
      // Find the first bar of the day
      while(start_idx < rates_total && time[start_idx] < targetDayStart) {
         start_idx++;
      }
      stateL1.firstBarOfDay = start_idx;
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
   if(stateL1.firstBarOfDay < 0) {
      int fb = 0;
      while(fb < rates_total && time[fb] < targetDayStart) {
         fb++;
      }
      stateL1.firstBarOfDay = fb;
      stateL2.firstBarOfDay = fb;
   }

   // Process only closed candles chronologically (up to rates_total - 2)
   // rates_total - 1 is the currently forming candle.
   for(int i = start_idx; i < rates_total - 1; i++) {
      if(time[i] >= targetDayEnd) break;
      
      if(time[i] >= targetDayStart) {
         ProcessLevelL1(i, L1_PERIOD, L1_BACKSTEP, stateL1.firstBarOfDay, open, high, low, close, time, stateL1, BufferL1H, BufferL1L);
         ProcessLevelL2(i, L2_PERIOD, L2_BACKSTEP, stateL2.firstBarOfDay, open, high, low, close, time, stateL2, BufferL2H, BufferL2L);
         
         // cross

      }
      
   } // limits

   return(rates_total);
}
//+------------------------------------------------------------------+



