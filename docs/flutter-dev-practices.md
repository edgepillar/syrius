# Flutter practices for this app

What the Syrius desktop front end is built to, and where each rule comes from.
Written 2026-10-13 during the interface overhaul, from Flutter's own
documentation, the SDK source installed here (Flutter 3.47.2) and two curated
package lists. Add to it when a practice is adopted or dropped; a rule with no
source or no reason does not belong here.

Status column: **in use** means the code does it today, **adopt** means it is
decided and not yet done everywhere, **no** means considered and declined.

## 1. Theme and tokens

| Practice | Why | Status | Source |
|---|---|---|---|
| One source for every colour, size, radius and duration. Widgets read the theme or a named constant, never a literal. | A literal cannot follow light and dark, and a restyle becomes a search through the tree. | adopt. Colours are in `lib/utils/app_colors.dart`, type and radius in `lib/utils/app_theme.dart`, panel styles in `lib/rearchitecture/utils/widgets/page/page_widgets.dart`. Literals remain in older widgets. | [1] |
| Put values Material has no role for (the faint text tone, QSR ink, warning, gaps, radii) in a `ThemeExtension`, with `copyWith` and `lerp` implemented, read through `Theme.of(context).extension<T>()`. | A static constants class cannot differ between light and dark and cannot interpolate when the theme changes; `lerp` is what makes a theme switch animate. | adopt. Today these are `static const` on `AppColors`, which is why `faint` and `qsrInk` are the same in both themes. | [2] |
| Name colours by role (surface, on-surface, success, warning), not by look. | A role says why the colour is there, so a new theme can change it safely. | adopt | [1] |
| Style buttons through `WidgetStateProperty`, resolving hovered, focused, pressed and disabled. | One style then covers every state; setting a flat colour removes the hover and focus feedback Material gives for free. | in use: `primaryButtonStyle` in `app_theme.dart`. | [3] |
| If a default Material button style is changed, test keyboard focus and add the states back. | Flutter's docs note the built-in focus states are lost when `overlayColor` is made transparent. | adopt | [3] |

## 2. Type

| Practice | Why | Status | Source |
|---|---|---|---|
| Two faces: Space Grotesk for the interface, JetBrains Mono for amounts, addresses, hashes and heights. | Mono with tabular figures keeps columns aligned and stops a changing value from jittering. | in use (`kSansFontFamily`, `kMonoFontFamily`, `monoStyle()`). | owner's design rules |
| Ship static font files, one per weight, declared with their `weight` in `pubspec.yaml`. | A variable font needs `FontVariation` on every style to pick a weight; `fontWeight` alone is documented for static files. | in use: `assets/fonts/`, with the OFL texts. | [4] |
| `FontFeature.tabularFigures()` on every number. | Same reason as mono: digits of equal width. | in use, inside `monoStyle()`. | [4] |
| Nothing under 12 px. Body 13 to 14, panel titles 15, ledger labels 11 mono capitals with letter spacing. | The old 10 px labels were the hardest text in the app to read. The 11 px label is the one exception, and it is capitals. | in use | measured here |
| Balances drop trailing zeros. Nothing is rounded. | The owner's rule, 2026-10-13. | in use: `AmountText`. | owner |

## 3. Layout on a desktop window

| Practice | Why | Status | Source |
|---|---|---|---|
| Size from the space a widget is given (`LayoutBuilder`), or the window (`MediaQuery.sizeOf`), never from device type or orientation. | A desktop window is any size; the docs call out orientation and hardware checks as the wrong signal. | in use: `PageGrid`, the rail. | [5] |
| Do not let a form or a line of text stretch across the whole window. | Full-width fields read badly on a large screen. | adopt: forms sit in fixed-height rows with a share of the width; a max width on text is not yet set. | [5] |
| A page is rows of panels that fill the window; only when the window is shorter than the rows' least heights does the page scroll. | The old grid sized a card's height from the window's width, which clipped the Send button at 1200x600 and left empty space at 1500x950. | in use: `PageGrid` on Transfer, Pillars, Sentinels, Staking, Plasma, Tokens. | measured here |
| Lower `VisualDensity` for mouse users. Material components that support it resize and animate to it. | Touch-sized controls waste a desktop window. | adopt: not set yet; try `VisualDensity(horizontal: -1, vertical: -1)` and check every form. | [3] |
| Keep scroll position across rebuilds with `PageStorageKey` where a list is rebuilt. | Otherwise a long list jumps to the top. | adopt | [5] |

## 4. Input: mouse and keyboard

| Practice | Why | Status | Source |
|---|---|---|---|
| Anything clickable shows the click cursor and a hover state. | Without them a desktop user cannot tell a control from a label. | in use on the rail (`InkWell`); adopt elsewhere with `MouseRegion(cursor: SystemMouseCursors.click)`. | [3] |
| Custom controls use `FocusableActionDetector`, which gives focus, hover and shortcuts in one widget. | A `GestureDetector` alone is invisible to the keyboard. | adopt | [3] |
| Group a form with `FocusTraversalGroup` so Tab goes through its fields before its button. | Default reading order can leave a form mid-way. | adopt | [3] |
| Shortcuts for a part of the tree: `Shortcuts` + `Actions` + a focused child. App-wide ones: `HardwareKeyboard.instance.addHandler`, removed in `dispose`, and switched off while a text field has focus. | The global handler does not manage itself; the docs warn about it firing while the user types. | adopt: none yet. Planned: Ctrl K (go to), Ctrl L (lock), Ctrl 1 to 9 (pages). | [3] |
| Every icon-only button has a tooltip. | An icon alone has no name, for a person or for the test harness. | in use on the new shell and card headers; adopt elsewhere. | [3] |

## 5. Motion

Every animation runs, always. The owner's rule for every front end in this
tree is never to honour the operating system's reduced-motion setting
(`docs/design/RULES.md`, section 4), so nothing here reads
`MediaQuery.disableAnimations`. Motion is how the wallet shows that the chain
is live and that a value just changed.

| Practice | Why | Status | Source |
|---|---|---|---|
| Use the SDK's Material 3 tokens, not invented numbers: `Durations.short3` 150 ms, `short4` 200, `medium1` 250, `medium2` 300, `medium4` 400, `long2` 500; `Easing.standard` `Cubic(0.2, 0, 0, 1)`, `Easing.emphasizedDecelerate` `Cubic(0.05, 0.7, 0.1, 1)` for things entering, `Easing.emphasizedAccelerate` `Cubic(0.3, 0, 0.8, 0.15)` for things leaving. | One vocabulary of speed across the app; these are the values Material's own widgets use. | adopt. Read from `packages/flutter/lib/src/material/motion.dart` in the SDK. | [6] |
| Reach for an implicit animation first (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `TweenAnimationBuilder`). | Most motion is one value changing; these need no controller and cannot leak one. | in use: plasma meter, rail dimming. | [7] |
| Switching between unrelated destinations (the rail's pages) is a fade through, not a slide. Related steps (a stepper, onboarding) share an axis. A card opening into a detail is a container transform. | The transition says how two screens relate; a sideways slide between rail pages claims an order that is not there. | adopt. The rail's pages already fade and rise (`RiseSwitcher`). Steppers and a card opening into its detail take `package:animations` (flutter.dev): `SharedAxisTransition` and `OpenContainer`, pinned 2.2.0 until the app is on `material_ui` (section 8). | [8] |
| Inside `AnimatedBuilder`, build what does not depend on the animation once and pass it as `child`. | Otherwise the whole subtree rebuilds on every tick. | in use | [9] |
| Fade with `AnimatedOpacity` or `FadeTransition`, not a rebuilt `Opacity`. Avoid animating a clip. | `Opacity` and clips can force an offscreen layer per frame. | adopt | [9] |
| Wrap anything that animates continuously (Lottie, the plasma glow shader, the 3D pillar and sentinel) in a `RepaintBoundary`. | It gets its own layer, so its repaint does not repaint the page around it. | adopt: the shader widget has one; Lottie and 3D not yet. | [9] |
| A value that changes flashes once; a list row that arrives slides in. No decoration on money. | The owner's rules: motion reports a change, it does not dress a number. | adopt | owner's design rules |

## 6. Performance

| Practice | Why | Status | Source |
|---|---|---|---|
| Budget: 16 ms a frame at 60 Hz, aim for 8 ms build and 8 ms raster. Measure in profile mode, not debug. | Debug mode is several times slower and says nothing about a release build. | adopt: no profile run has been made of this app yet. | [9] |
| `const` constructors wherever possible; small `StatelessWidget`s rather than helper methods returning widgets. | A const widget is skipped on rebuild; a helper method is rebuilt with its parent every time. | adopt: the repo's convention is `_buildX()` methods (see `AGENTS.md`); new code prefers private widget classes. | [9] |
| Call `setState` on the smallest subtree that changes. | It rebuilds every descendant. The shell (`MainAppContainer`) calls it for a notification and rebuilds the whole app. | adopt | [9] |
| With bloc, narrow the rebuild: `BlocSelector`, or `buildWhen`, around the part that reads the state. | A `BlocBuilder` round a whole page rebuilds the page for any change. | adopt | [10] |
| Lists and tables are lazy (`ListView.builder`, the infinite-scroll table). No `Column` of hundreds of rows. | Only what is on screen is built. | in use | [9] |
| Avoid `saveLayer`: `ShaderMask`, `ColorFilter`, `Clip.antiAliasWithSaveLayer`, an `Opacity` over overlapping children. Round corners with `borderRadius`, not a clip. | Each allocates an offscreen buffer. | adopt: `Panel` clips with `Clip.antiAlias`, which does not save a layer. | [9] |
| No intrinsic-size passes in grids (`IntrinsicHeight` round rows of cards). | They lay out every cell twice. | in use: `PageGrid` uses fixed and flex sizes. | [9] |
| Build only the page that is shown. | Thirteen pages each start their own fetches. | adopt: `TabBarView` builds the current page and its neighbours. | measured here |
| Impeller is the default renderer on Windows, macOS and Linux since 3.47. It compiles shaders at build time, so there is no first-use stall. Opt out only to test: `flutter run --no-enable-impeller`. | The opt-out will be removed. A custom fragment shader must therefore work on Impeller. | in use (3.47.2). | [11] |
| Do not override `operator ==` on a widget. | It can make rebuilds quadratic. | in use | [9] |
| Nothing that computes is awaited on the UI isolate. Key work goes through `lib/utils/background_crypto.dart`; other work over a few milliseconds through `Isolate.run`, its closure built in a static function. | `async` does not move work: the SDK's Ed25519 is plain Dart with no gap in it, 0.7 s for a public key and 1.2 s for a signature, and every frame waited. An inline closure takes `this` with it and fails on the first unsendable field. | in use: `test/background_crypto` fails when a timer stalls through a call; `harness/h stalls` lists stalls in the running wallet. | measured here |

## 7. Fragment shaders

The plasma logo's glow is a fragment shader (`assets/shaders/heatmap.frag`).

| Practice | Why | Source |
|---|---|---|
| Declare shaders under `flutter: shaders:` in `pubspec.yaml`; load with `FragmentProgram.fromAsset`, once, and reuse the program. | Loading is asynchronous; a program per widget wastes it. | [12] |
| Write GLSL to Flutter's subset: `#include <flutter/runtime_effect.glsl>`, `FlutterFragCoord()`, loops with constant bounds, no dynamic array indexing. | The shader is compiled for several backends at build time. | [12] |
| Set uniforms in declaration order with `setFloat(index, …)`; a `vec2` takes two indices; samplers are set separately with `setImageSampler`. | There are no names at run time, only positions. | [12] |
| Drive time from one `Ticker`, stop it when the widget is not visible or not active, and put the painter in a `RepaintBoundary`. | A shader repaints every frame by design; it must not take the page with it. | [9] |

## 8. Packages

What the app already has that this work leans on: `window_manager`,
`tray_manager`, `desktop_drop`, `app_links`, `local_notifier`,
`launch_at_startup`, `lottie`, `fl_chart`, `flutter_bloc`.

The calls below were made again on 2026-10-13, after the owner reversed "no
new package for motion or shaders" and opened the whole front end. The
evidence for each, with versions, dates and line counts read that day, is in
`docs/research/modern-flutter-stack.md` [17]. They are task R1's calls; none
is in `pubspec.yaml` until the main thread logs it under Decisions.

Material left the SDK in 3.47: `package:flutter/material.dart` is frozen and
due to be deprecated in the November release, and the same code is now the
package `material_ui` [18][19]. A package that has moved (`animations` 3.0.0,
`shimmer` 4.0.0, `forui`) looks up a theme this app does not have until the
app moves too. So each pin below is the version that matches the Material the
app imports today.

Taken. Pin the exact version, no caret:

| Package | For | Call |
|---|---|---|
| `animations` (flutter.dev, BSD-3-Clause) | Fade through, shared axis, container transform | Take, `2.2.0` (2026-04-23). Steppers, and a card opening into its detail; the SDK has neither pattern. `3.0.0` with the `material_ui` migration: its only change is the import [8]. |
| `flutter_animate` (gskinner.com, BSD-3-Clause) | Chained one-shot effects, staggered entrance of rows, an effect driven by state | Take, `4.5.2` (2024-11-25). It replaces a hand-written controller per effect. No release in 23 months; it is 3,900 lines on the widgets layer and can be vendored if it is abandoned. Not on a money figure, not for page changes [20]. |
| `flutter_shaders` (flutter.dev, BSD-3-Clause) | `ShaderBuilder`, `AnimatedSampler` | Take, `0.1.5` (2026-10-07). 910 lines, now in `flutter/packages`. `ShaderBuilder` replaces the loader each shader widget repeats, and `flutter_animate` depends on it [21]. |
| `material_ui` (flutter.dev, BSD-3-Clause) | Material, now outside the SDK | Take with the migration, as one task of its own with nothing else in flight: `dart fix --apply --code=migrate_design_widgets` over 320 files, then `MaterialUiCompatibilityBridge` for dependencies that have not moved. `1.6.0` on 2026-10-06; it releases weekly, so pin the one current that day [18]. |
| `window_manager` (already here) | The title strip of mockup B | Use it: `setTitleBarStyle(TitleBarStyle.hidden)`, `DragToMoveArea`, the app's own caption buttons. On macOS keep the system's buttons. Its repository already documents a different API than 0.5.2 has, so pin [22]. |

Declined, and the two last rows left as they were:

| Package | For | Call |
|---|---|---|
| `shimmer`, `skeletonizer` | Loading placeholders | No. `shimmer` 4.0.0 needs `material_ui`; `skeletonizer` needs fake data at every site. The app's `Skeleton` gets a sweep painted with a `dart:ui` gradient. |
| `rive` | Interactive vector animation | No. Its `rive_native` downloads a prebuilt native library at build time. Lottie stays. |
| `motor`, `flutter_physics`, `sprung` | Springs | No. `SpringDescription.withDurationAndBounce` in the SDK is enough for a desktop wallet. |
| `animated_flip_counter`, `animated_digit`, `number_flow` | Rolling digits | No. Decoration on money, and none has a verified publisher. `ValueFlash` reports the change. |
| `flutter_staggered_animations`, `auto_animated` | List entrance | No. Stale since 2022 and 2023; `flutter_animate` or `SliverAnimatedList`. |
| `mesh_gradient`, `mesh` | Animated gradient background | No. One hand-written `.frag`; `mesh` adds three dependencies and MPL-2.0. |
| `liquid_glass_renderer`, `glassmorphism`, `glass_kit` | Glass | No. The first has no Windows or Linux build; the others offer blur, which is `BackdropFilter` in the SDK. |
| `flutter_acrylic` | Mica, acrylic window | No. Mockup B is opaque surfaces, so only the gaps would show it. No verified publisher, last release 2024-06-11, an undocumented `user32.dll` call on Windows 10. |
| `bitsdojo_window` | Custom title bar | No. Last release 2023-12-23; `window_manager` does it. |
| `forui`, `shadcn_ui`, `fluent_ui`, `macos_ui` | Whole widget sets | No. 60 to 116 thousand lines each and a second theme beside `AppTokens`, which 58 files read. `forui`'s sidebar has no icon-only state, `shadcn_ui` has no sidebar and 14 dependencies, `fluent_ui` is Windows 11's look, `macos_ui` is macOS only. Disclosures and overflow menus are built once on the SDK's unstyled `Expansible` and `RawMenuAnchor`. Look at `forui` again after its 1.0 and the `material_ui` migration. |
| `auto_updater` (Sparkle, WinSparkle) | In-app update | Candidate for wishlist item 4; needs signed releases first. |
| `hotkey_manager` | System-wide hotkeys | No. In-app shortcuts need no package. |

Two facts about the SDK that bear on these:

- `AnimationController` cuts its duration to a twentieth when the platform
  reports `disableAnimations`, unless built with
  `AnimationBehavior.preserve`; implicit widgets cannot pass it. Windows
  never reports it in 3.47.2, Linux does. To keep the rule of section 5 for
  the SDK's widgets and for every package above, override
  `disableAnimations` once in the binding (read in the source, not yet
  tried) [17].
- Impeller on Windows draws through OpenGL ES (ANGLE), whatever the release
  announcement says about Vulkan. Every shader is written for OpenGL ES and
  tried on Windows first [17][23].

A new dependency in a wallet is a supply-chain decision, not a styling one:
prefer the SDK, pin versions, read the code.

## Sources

1. The Flutter Kit, "Material 3 design tokens": https://theflutterk.it.com/blog/flutter-material3-design-tokens-guide (a blog; the pattern is the one the SDK's `ThemeExtension` documents)
2. Flutter API, `ThemeExtension`: https://api.flutter.dev/flutter/material/ThemeExtension-class.html
3. Flutter docs, "User input and accessibility": https://docs.flutter.dev/ui/adaptive-responsive/input
4. Flutter docs, "Typography": https://docs.flutter.dev/ui/design/text/typography
5. Flutter docs, "Best practices for adaptive design": https://docs.flutter.dev/ui/adaptive-responsive/best-practices
6. Flutter SDK 3.47.2, `packages/flutter/lib/src/material/motion.dart` (`Durations`, `Easing`)
7. Kodeco, "Implicit animations in Flutter": https://www.kodeco.com/18724197-implicit-animations-in-flutter-getting-started
8. pub.dev, `animations`: https://pub.dev/packages/animations
9. Flutter docs, "Performance best practices": https://docs.flutter.dev/perf/best-practices
10. Collected agent guides on bloc rebuild scope (secondary): https://www.skills.sh/hoangnguyen0403/agent-skills-standard/flutter-performance
11. Flutter docs, "Impeller rendering engine": https://docs.flutter.dev/perf/impeller
12. Flutter docs, "Writing and using fragment shaders": https://docs.flutter.dev/ui/design/graphics/fragment-shaders (not fetched in this session; the rules in section 7 are from the demo's working code and are to be checked against this page)
13. Solido, awesome-flutter: https://github.com/Solido/awesome-flutter
14. leanflutter, awesome-flutter-desktop: https://github.com/leanflutter/awesome-flutter-desktop
15. ksokolovskyi, paper_heatmap_logo (MIT): https://github.com/ksokolovskyi/paper_heatmap_logo, after Paper's heatmap shader: https://github.com/paper-design/shaders
16. flutterawesome.com, animation tag: https://flutterawesome.com/tag/animation/ (ideas taken: animated numbers, loading buttons, trim-path drawing, glass card; none adopted as packages)
17. This repository, "The Flutter stack for the redesign" (2026-10-13): `docs/research/modern-flutter-stack.md`, with its own list of 28 sources
18. Flutter docs, "Migrate to standalone material_ui and cupertino_ui packages": https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui; pub.dev, `material_ui`: https://pub.dev/packages/material_ui
19. Flutter blog, "What's new in Flutter 3.47": https://flutter.dev/blog/whats-new-in-flutter-3-47
20. pub.dev, `flutter_animate`: https://pub.dev/packages/flutter_animate; its repository: https://github.com/gskinner/flutter_animate
21. pub.dev, `flutter_shaders`: https://pub.dev/packages/flutter_shaders
22. leanflutter, window_manager README: https://github.com/leanflutter/window_manager/blob/main/README.md; the 0.5.2 archive from pub.dev for the released API
23. `flutter/flutter` at tag 3.47.2, `engine/src/flutter/shell/platform/windows/flutter_windows_engine.cc` and `engine/src/flutter/shell/platform/linux/fl_settings_handler.cc`
