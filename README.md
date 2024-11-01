# bar-widgets

A collection of BAR widgets I made for anyone to use.

- [idle_notfiier.lua](https://gitlab.com/Nehroz/bar-widgets/-/blob/main/idle_notifier.lua) Audio queue and ping on idle cons appearing. alt+a move camera to latest idle and selects it until it's no longer idling; This will keep selecting idles in the same order as they appeared.
  - `select_latest_idle_unit`: Move the camera to the latest idle and selects
    it; This will keep selecting idles in the same order as they appeared.
  - `select_latest_idle_factory`: Selects the next idle factory/lab, requires   the factory option to be enabled.
  - `dismiss_idles`: Flushes lists, removing all idles.
- [nearest_con.lua](https://gitlab.com/Nehroz/bar-widgets/-/blob/main/nearest_con.lua) Selects nearest constructor on map, near mouse. T1 alt+q or T2 alt+w or alt+e to select all con's on map.
  - `select_nearest_t1_constructor`
  - `select_nearest_t2_constructor`
  - `select_all_constructors`
- [nano_check.lua](https://gitlab.com/Nehroz/bar-widgets/-/blob/main/nano_check.lua) A script that ensures construction turrets only try to complete orders on things within there range. Automatically deques orders when given if there outside of range. Construction turrets no longer will wait for the other orders outside of there range to be done.
