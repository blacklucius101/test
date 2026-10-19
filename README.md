Revise the existing OnCalculate() function according to the requirements below. Preserve existing behavior unless a change is explicitly required.

1. Process Closed Candles Sequentially — Simulate Real-Time Execution
The current implementation processes all candles in batches: it calculates all Heiken Ashi candles, then identifies all Lesser Semafors, then evaluates all Greater Semafors, and finally draws the chart objects.

Replace this batch-processing approach with sequential, candle-by-candle processing.

Process historical candles in chronological order, from the earliest relevant closed candle to the latest closed candle.
For each candle, execute the indicator's logical steps in the same order they would occur in real time when that candle closes.
Calculate the candle's Heiken Ashi values first.
Update the Lesser Semafor state using the current candle and previously established state.
Evaluate Greater Semafor qualification using the information available at that point.
Update indicator buffers and chart drawings as appropriate before advancing to the next closed candle.
Exclude the currently forming candle from all calculations and decisions.
Historical simulation requirement: When processing historical data, replay candles sequentially as though each candle were closing in real time. The result for each historical candle must depend only on information available up to that candle's close.

Ensure that live execution and historical replay produce consistent results, subject to the existing repainting rules.

Use appropriate state management and prev_calculated handling to avoid unnecessarily replaying the entire history on every tick. Reprocess earlier candles only when required to initialize state, handle history changes, or correctly reproduce the existing repainting behavior.

2. Correct the Greater Semafor Dome-Distance Calculation
The existing dome-distance calculation is suspected to be incorrect.

Implement the following intended formulas:

High → Low pair

- Use the HAHigh of the starting High semafor as the upper reference.
- Find the lowest HAHigh between the two semafor bars, inclusive.
- Calculate dome distance as:
`dome_dist = HAHigh[starting_high_bar] - lowest_HAHigh_between_the_two_bars`

Low → High pair

- Use the HALow of the starting Low semafor as the lower reference.
- Find the highest HALow between the two semafor bars, inclusive.
- Calculate dome distance as:
`dome_dist = highest_HALow_between_the_two_bars - HALow[starting_low_bar]`

Preserve the qualification threshold:

`dome_dist >= 2.0 * spread_val`

Ensure the dome midpoint is calculated consistently with the corrected dome-distance formula and the appropriate reference price.
