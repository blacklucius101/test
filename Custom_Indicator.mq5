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
		// first bar initialization
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

   }

   return(rates_total);
}
