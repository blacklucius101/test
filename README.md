- Here I shall introduce a new concept, namely: pivots.
- On first_idx, for bootstrap purposes, HAHigh[first_idx] and HALow[first_idx] will be used as provisional starting pivots.
- Actual pivots have the following defining features:
	1. the dome distance, ie. dome extreme to starting pivot, must be >2x the broker-reported spread, fetched once and reused (use raw price units for consistent comparisons).
	2. the candidate pivot is anchored to the highest HAHigh and the lowest HALow
	3. low pivot anchor is only valid on a red HACandle
	4. high pivot anchor is only valid on a DodgerBlue HACandle

- From HAHigh[first_idx] we independently track lowest HAHigh (dome extreme) and lowest HALow (candidate pivot anchor).
- From HALow[first_idx] we independently track highest HALow (dome extreme) and highest HAHigh (candidate pivot anchor).
- I prefer a lightweight approach. Since processing is done step by step per closed candle, record a value and only update it if the next candle's value exceeds the recorded value.

- We'll use a low first actual pivot as an example.
- If HAHigh[first_idx] - lowest HAHigh > 2x spread, and lowest HALow is on a red HACandle, plot a low pivot at the lowest HALow.
- These operations are done only when new values are updated thus avoiding unnecessary recalculations on non-extending values.
- If the dome distance threshold is met but lowest HALow is on a dodger blue HACandle, the pivot is invalid and thus its visual plot is  removed.
- Notice here that for the candidate low pivot, lowest HAHigh (dome extreme) and lowest HALow (candidate pivot anchor) might not necessarily fall within the same HACandle, and thus each can repaint lower independently.

- With that established, let's move the sequence forward: pivot0 at HAHigh[first_idx], pivot1 at HALow[n].

- Note that tracked values are recorded per pivot.
- See for example that initially from pivot0 HALow[first_idx] we track highest HALow and highest HAHigh for a potential high pivot (we tracked for both high and low pivots at first_idx, but let's focus on high pivot to highlight the contrast).
- When a new low pivot forms at pivot1 HALow[n] we now track a new set of highest HALow and highest HAHigh from this pivot.
- The relevant starting pivot forms the earliest boundary forward from which the next candidate pivot's anchor and dome extreme are tracked.
- The lowest HAHigh and lowest HALow, for pivot1's lower repainting or removal, are still tracked from pivot0 since pivots always alternate.

- If low pivot1 is removed (due to HAColor mismatch), the values tracked by pivot1 are compared to the values last recorded by pivot0 and the greater values recorded instead. This organicaly ensures we are working with the actual highest HALow and highest HAHigh without doing a full sorting of the entire range.
- The initial bootstrap at first_idx is the only bar index that has double pivot tracking. By design, actual pivots only ever track the next pivot candidate.

- Pivot arrow symbol = 159. Inherit color, styling and arrow shift pixels from semafors.
