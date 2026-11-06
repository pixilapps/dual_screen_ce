# iPhone Duo pose matrix

What the iPhone Duo simulator (Xcode 27.2, iOS 27.2 runtime, Device Hub) reports to a plain `FlutterViewController` with no
UIKit bars, measured with the spike probe in plan step 1.0. All values are logical points in the Flutter view; rects are
`[left, top, width, height]`, insets `[left, top, right, bottom]`.

## Per pose

| Pose | Window | Safe area | `verticalBarEdge` → side | Bar region (system extent) | Occlusions (active) | Fold | Size classes |
|---|---|---|---|---|---|---|---|
| Open flat, landscape | 951 × 669 | `[0, 0, 84, 34]` | trailing → right | `[879, 124, 48, 511]` | status cluster `[867, 0, 84, 124]`; inner camera `[677.3, 21, 58, 37]` (inactive) | `[455.5, 0, 40, 669]` inactive, margins 20/20 | regular × regular |
| Closed, portrait | 466 × 678 | `[0, 0, 84, 34]` | trailing → right | `[394, 174, 48, 470]` | camera `[399.7, 29.3, 37, 37]`; cluster `[382, 0, 84, 174]` | none | compact × regular |
| Closed, landscape (camera bottom right) | 678 × 466 | `[0, 0, 84, 34]` | trailing → right | `[606, 2.3, 48, 381.7]` | camera `[611.7, 399.7, 37, 37]`; cluster `[594, 384, 84, 82]` | none | compact × compact |
| Closed, landscape (camera top left) | 678 × 466 | `[84, 0, 0, 34]` | leading → **left** | `[24, 82, 48, 350]` | camera `[29.3, 29.3, 37, 37]`; cluster `[0, 0, 84, 82]` | none | compact × compact |
| Open flat, portrait | 669 × 951 | `[0, 82, 0, 34]` | unspecified (horizontal bars) | none | cluster `[525, 0, 144, 82]`; inner camera `[21, 215.7, 37, 58]` (inactive) | `[0, 455.5, 669, 40]` inactive | regular × regular |
| Book (half open, landscape, 134°) | 951 × 669 | `[0, 0, 84, 34]` | trailing → right | `[879, 124, 48, 511]` | cluster `[867, 0, 84, 124]`; inner camera `[215.7, 611, 58, 37]` (inactive) | `[455.5, 0, 40, 669]` **active** | regular × regular |
| Laptop (half open, portrait, 134°) | 669 × 951 | `[0, 82, 0, 34]` | unspecified | none | cluster `[525, 0, 144, 82]` | `[0, 455.5, 669, 40]` **active** | regular × regular |
| Closed, portrait, **right-to-left** layout | 466 × 678 | `[0, 0, 84, 34]` | **leading** → right | `[394, 174, 48, 470]` | as left-to-right | none | compact × regular |

## With the vertical bar disabled (`preferredVerticalBarBehavior = .disabled`)

| Pose | Safe area | `verticalBarEdge` |
|---|---|---|
| Open flat, landscape | `[0, 82, 0, 34]` | unspecified |
| Closed, portrait | `[0, 82, 0, 34]` | unspecified |
| Closed, landscape (camera bottom right) | `[0, 0, 0, 82]` | unspecified |
| Closed, landscape (camera top left) | `[0, 82, 0, 34]` | unspecified |
| Book | `[0, 82, 0, 34]` | unspecified |

The runtime-installed override is honoured. The status bar returns to the horizontal axis on the camera's side, the side inset
disappears, and Flutter's `MediaQuery.padding` follows one or two frames later (UIKit animates the change).

## Native presentations, for comparison

| Pose | `UIAlertController` frame | Sheet (medium detent) frame | Sheet's own safe area |
|---|---|---|---|
| Open flat, landscape | `[273.7, 239.3, 320, 156.3]`: centred in the safe area | `[149, 276, 653, 385]`: centred on the full width | `[0, 0, 0, 34]` |
| Closed, portrait | `[31, 244, 320, 156]`: centred in the safe area | `[8, 280, 450, 390]`: full width, across the bar column | `[0, 0, 76, 34]` |
| Closed, landscape (camera bottom right) | `[137, 138, 320, 156]` | `[8, 8, 662, 458]`: full screen | `[0, 0, 76, 34]` |
| Closed, landscape (camera top left) | `[221, 138, 320, 156]` | `[8, 8, 662, 458]`: full screen | `[76, 0, 0, 34]` |
| Open flat, portrait | `[174.7, 421.3, 320, 156.3]`: centred in the safe area | `[8, 487.7, 653, 455.7]`: full width | `[0, 0, 0, 34]` |
| Book | `[67.7, 239.3, 320, 156.3]`: **centred in the leading half** | `[8, 276, 459.5, 385]`: **the leading half**, ending 8pt short of the crease | `[0, 0, 0, 34]` |
| Laptop | `[174.7, 628, 320, 156.3]`: **centred in the bottom half** | `[8, 487.7, 653, 455.7]`: the bottom half (its usual medium position) | `[0, 0, 0, 34]` |

## Findings

1. **The side inset is the bar column.** Without any UIKit bar, the view still gets an 84pt inset on the bar side whenever the
   system places a vertical bar, so Flutter's `MediaQuery.padding` already keeps content clear of it.
2. **The bar region sits inside that column.** The default extent is 48pt, inset 12pt from the content side and 24pt from the
   display edge, and it runs from below the status cluster (or above it, when the camera is at the bottom) down to the home
   indicator inset. `edgeInsetsForLayoutRegion:` and `layoutGuideForLayoutRegion:` agree.
3. **The status cluster is an occlusion region** (camera, status bar, Dynamic Island) at the camera end of the column; the bar
   region starts where it ends.
4. **The fold is reported while flat**, as an inactive 40pt division whose frame already includes 20pt margins on each side of
   the crease.
5. **`statusBarFrame` is not useful** with a vertical status bar (it reports a 2pt-high strip), so the package does not expose it.
6. **Sheets on the outer display span the column**: 8pt margins, with the sheet's content inset by the remaining 76pt, where the
   sheet's own vertical bar lives. On the inner display they are centred and keep horizontal bars.
7. **Corner adaptation** (`safeAreaLayoutRegionWithCornerAdaptation:`) only adds 16pt on the corner side of the opposite edge
   compared to the plain safe area, so the package does not expose it.
8. **The bar follows the camera.** On the outer display in landscape, it is on the right when the camera is at the bottom
   right, and on the left (`verticalBarEdge` = leading in a left-to-right layout) when the camera is at the top left.
9. **Portrait on the inner display has no vertical bar**, flat or folded like a laptop: the status bar is horizontal (82pt) and
   `verticalBarEdge` is unspecified.
10. **The fold becomes active when half open**, in both directions, with the same 40pt frame. Its direction follows the window:
    vertical in landscape (book), horizontal in portrait (laptop).
11. **Folded presentations go to one side of the fold:** alerts and sheets take the **leading half** of a book fold, and the
    **bottom half** of a laptop fold. Flutter's `DisplayFeatureSubScreen` default anchor (top leading) matches the book fold
    but picks the top half of a laptop fold, so a Flutter dialog or sheet needs an anchor at the bottom leading corner to
    match both.

12. **Right-to-left does not move the bar.** With the layout forced right-to-left (`-AppleTextDirection YES
    -NSForceRightToLeftWritingDirection YES`), the bar and its inset stay on the physical right and `verticalBarEdge` reports
    *leading*. `VerticalBar.side` is therefore resolved from the edge and the layout direction together, never from the edge alone.

Not recorded on the simulator: Split View. Apple's documentation and the group labs agree that each Split View window gets
the bar on its outer edge (the left window on the left); the package needs no special handling, since `verticalBarEdge` and the
bar region already describe the window the app is in.
