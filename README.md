Refactor `Custom_Indicator.mq5` to incorporate the high/low semafor functionality from `Single_Level_ZZ_Semafor.mq5`.

Optimize the implementation to use hard-coded values: Period 2 and Backstep 1.

Maintain per-day processing. Process sequentially: calculate Heiken Ashi, identify and plot high/low on the Heiken Ashi candle, and proceed to the next candle. Repeat for all closed candles up to `rates_total - 2`, with real-time processing performed upon the close of the `rates_total - 1` candle.
