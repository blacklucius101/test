Refactor `Custom_Indicator.mq5` to incorporate the specified high/low pivot functionality, ensuring optimized, lightweight, and efficient performance.

Maintain per-day processing. Process sequentially: calculate Heiken Ashi, identify and plot high/low semafors on the Heiken Ashi candle, and proceed to the next candle. Repeat for all closed candles up to `rates_total - 2`, with real-time processing performed upon the close of the `rates_total - 1` candle (all this is presumably already implemented).

At `first_idx`, the initial semafors are anchored to HAHigh (node0) and HALow (node1).

Node1 repaints lower such that the distance between node0 and node1 exceeds twice the spread, and the anchor candle is HAColor red; pivot0 is registered here. Node1 anchor repaints lower, changes to HAColor dodger blue, and pivot0 is removed. Node2, a high semafor anchored to HAHigh, has its distance checked against pivot0. If the distance exceeds twice the spread and the anchor candle is HAColor dodger blue, pivot1 is registered. Draw a style-dot connecting line between pivot anchors, with color determined by slope. If pivot1 is deregistered, pivot0 may repaint lower or be deregistered. Pivot0 and pivot1 must alternate types. Following pivot1, the system should scan for a low semafor satisfying pivot conditions to register pivot2, or a high exceeding pivot1 to repaint or deregister pivot1 if the HAColor does not match. Note: pivot0 may be a high or low semafor.

Dome distance is defined as follows:

* **High pivot → low semafor:** The low semafor becomes a low pivot if the distance from the high pivot's HAHigh anchor to the lowest HAHigh between the high pivot and the low semafor (inclusive) is greater than twice the symbol's spread.

* **Low pivot → high semafor:** The high semafor becomes a high pivot if the distance from the low pivot's HALow anchor to the highest HALow between the low pivot and the high semafor (inclusive) is greater than twice the symbol's spread.

As no pivots exist at `first_idx`, we bootstrap the process by arbitrarily assigning the `first_idx` HAHigh and HALow as starting pivot anchors:

* **Starting high pivot → low semafor**
* **Starting low pivot → high semafor**

By design, a double pivot is unlikely to survive the bootstrap. Only one pivot0 will be formed, from which actual pivoting can commence.

Note that pivots may repaint lower or higher; therefore, focus is directed toward semafors that exceed the previously recorded semafor.

Secondary feature: A short, orange, dotted horizontal line, anchored to the pivot connecting line and spanning 10 bars to the right, marks the midpoint of the dome distance.
