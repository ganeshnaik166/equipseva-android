# A2 role confirmation previews

These PNGs draw the actual Compose role picker through Robolectric's native
Canvas. They contain synthetic UI state, not a device, real account or production
session. The render source is `RoleSelectScreenUiTest`.

- `en-360-selected.png`: hospital selected, 360dp width.
- `en-360-error-*.png`: failed save and retry, 360dp width.
- `hi-320-2x-*.png` and `te-320-2x-*.png`: Hindi/Telugu at 320dp and 2x text,
  showing the top, hospital choice and complete scroll end/exit action.

Long screens are captured at several scroll positions. Partial cards at viewport
edges are not the full layout. Tests separately check text layout, target bounds,
non-overlap, complete exit visibility after scrolling, and the exit callback.
TalkBack, native device rendering and human language/usability review remain open.
