- Refactor the logic in `Custom_Indicator` where applicable:
- On first_idx, for bootstrap purposes, HAHigh[first_idx] and HALow[first_idx] (or rather the bootstrap semafors initialized first_idx) will be used as provisional starting pivots.
- Actual pivots have the following defining features:
	1. the dome distance, ie. dome extreme to starting pivot, must be >2x the broker-reported spread, fetched once and reused (use raw price units for consistent comparisons). Note that the dome distance is defined at any candle bearing the dome extreme.
	2. the candidate pivot is anchored to the highest high semafor and the lowest low semafor. Note that:
	- low pivot anchor (ie. lowest low semafor) is only valid on a red HACandle
	- high pivot anchor (ie. highest high semafor) is only valid on a DodgerBlue HACandle

- From HAHigh[first_idx] we independently track lowest HAHigh price and index (dome extreme), and lowest low semafor (candidate low pivot anchor).
- From HALow[first_idx] we independently track highest HALow price and index (dome extreme), and highest high semafor (candidate high pivot anchor).
- I prefer a lightweight approach. Since processing is done step by step per closed candle, record a value and only update it if the next candidate value exceeds the recorded value.

- We'll use a first actual low pivot as an example.
- If HAHigh[first_idx] - lowest HAHigh > 2x spread, and lowest low semafor is on a red HACandle, plot a low pivot at the lowest low semafor anchor.
- These operations are done only when new values are updated thus avoiding unnecessary recalculations on non-extending values.
- If the dome distance threshold is met but lowest low semafor is on a dodger blue HACandle, the pivot is invalid and thus the pivot's visual plot is  removed.
- Notice here that for the candidate low pivot, lowest HAHigh (dome extreme) and lowest low semafor (candidate pivot anchor) might not necessarily fall within the same HACandle, and thus each can repaint lower independently.

- With that established, let's move the sequence forward: pivot0 at HAHigh[first_idx], pivot1 at low semafor[n].

- Note that pivot info is tracked as a duality (ie. both high and low trackers are populated), but only one actual pivot can exist at a bar index, maybe with the exception of first_idx but then again bootstrap pivots are not actual pivots.
- The relevant starting pivot forms the earliest boundary forward from which the next candidate pivot's anchor and dome extreme are tracked.
- When pivot1 forms, it becomes the latest pivot from which all tracking proceeds. However, since pivot1 can evolve lower it inherits static values from pivot0, eg. HAHigh[first_idx], which facilitate pivot1's repainting.

If low pivot1 is removed (due to HAColor mismatch), the dynamic values tracked by pivot1 are merged back into pivot0. This organicaly ensures we are working with the actual valid highest high semafor and lowest low semafor without doing a full sorting and color checking of the semafors in the entire range.
