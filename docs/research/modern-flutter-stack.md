# The Flutter stack for the redesign

Task R1 of the interface overhaul. Written 2026-10-13 16:10 UTC against
`syrius-sol` on Flutter 3.47.2 (Dart 3.13.2, read from
`C:\dev\flutter\bin\cache\flutter.version.json`).

The earlier decision "no new package for motion or shaders" is reversed, so
every call in section 8 of `docs/flutter-dev-practices.md` is made again here,
on what pub.dev, the package sources and the SDK source say today.

How each fact was checked:

- Version, publish date, publisher, licence, platforms and dependencies come
  from the pub.dev API (`/api/packages/<name>`, `/publisher`, `/score`) and
  the package pages, read today. Dates are UTC.
- "Lines" is the count of Dart lines under `lib/` in the published archive
  (`/api/archives/<name>-<version>.tar.gz`), downloaded and counted today.
  Nothing from an archive was run.
- SDK statements are read from the installed SDK and from the 3.47.2 tag of
  `flutter/flutter`.
- Nothing here was built or run. No `pub get` was made with the pins below.
  What that leaves open is listed under "Not verified".

## 0. One fact under every call: Material left the SDK

Flutter froze `package:flutter/material.dart` at 3.44 and published the same
code as `material_ui` 1.0.0 (flutter.dev) with 3.47. The Flutter blog says the
in-framework library is "scheduled for formal deprecation in the upcoming Fall
stable release in November". New Material work lands in the package, which
releases about weekly (1.6.0 on 2026-10-06).

Packages are moving over, and a moved package cannot be dropped into an app
that has not moved:

| Package | Last version on `flutter/material.dart` | First on `material_ui` |
|---|---|---|
| `animations` | 2.2.0 (2026-04-23) | 3.0.0 (2026-08-19) |
| `shimmer` | 3.0.0 (2023-05-21) | 4.0.0 (2026-08-21) |
| `forui` | before 0.26.0 | 0.26.0 and later |

`animations` 3.0.0 reads `Theme.of(context).canvasColor` from `material_ui`.
In an app whose `MaterialApp` comes from the SDK that lookup finds no theme
and returns the default light one. `MaterialUiCompatibilityBridge` only works
the other way: a migrated app carrying unmigrated packages.

This app imports `package:flutter/material.dart` in 320 files. The migration
is one command (`dart fix --apply --code=migrate_design_widgets`), then
`flutter pub add material_ui`, then the bridge in `MaterialApp.builder` for
the dependencies that still import the SDK's Material (`window_manager`,
`lottie` and `expandable` do, read in their locked versions; the rest were
not checked). The documented limit: a dependency that takes or returns a
Material type in its API cannot be bridged.

**Recommendation: pin the versions that match the SDK's Material now, and
migrate to `material_ui` as one task of its own with every other agent
stopped, before the November release turns 320 imports into warnings.**

## 1. Motion

### What the SDK already gives (3.47.2, read in the source)

| Need | SDK |
|---|---|
| One value changing | `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSize`, `AnimatedCrossFade`, `TweenAnimationBuilder` |
| Swap one child for another | `AnimatedSwitcher` (the app's `RiseSwitcher` and `StateSwitcher` are built on it) |
| A loop | `RepeatingAnimationBuilder` (`widgets/repeating_animation_builder.dart`) |
| Rows arriving and leaving | `AnimatedList`, `SliverAnimatedList`, `AnimatedGrid` |
| A spring | `SpringDescription.withDurationAndBounce` with `AnimationController.animateWith(SpringSimulation(...))` |
| Route change | `FadeForwardsPageTransitionsBuilder`, `ZoomPageTransitionsBuilder`, `Hero` |
| Speed and easing | `Durations` and `Easing` (already the app's vocabulary) |

The SDK has no fade through, no shared axis and no container transform.
Those three are what a package is for.

### A trap for "motion always runs"

`AnimationController` shortens its duration to a twentieth when the platform
reports `disableAnimations`, unless it is built with
`animationBehavior: AnimationBehavior.preserve`
(`animation/animation_controller.dart`, lines 60 to 78 and 651). The implicit
widgets and `AnimatedSwitcher` build their controller without that argument
and offer no way to pass it.

Which platforms report it, from the 3.47.2 embedder sources:

- Windows: never. `FlutterWindowsEngine::SendAccessibilityFeatures` sends only
  high contrast. "Animation effects" off does not reach Flutter.
- Linux: yes, when the desktop's setting for animations is off
  (`fl_settings_get_enable_animations` in `fl_settings_handler.cc`, line 48).
- macOS: not read.

So on Linux the SDK itself breaks the owner's rule for every implicit
animation and for every package below. `ShellRail` already passes `preserve`
on its own controller. The one place that covers everything is the binding:
`SemanticsBinding.disableAnimations` is a getter that a
`WidgetsFlutterBinding` subclass can override to return false, and a
`MediaQuery` override in `MaterialApp.builder` covers code that reads
`MediaQuery.disableAnimations` instead. Read in the source, not tried.

### The calls

| Package | Verified today | Call |
|---|---|---|
| `animations` | flutter.dev, BSD-3-Clause, 2.2.0 2026-04-23 / 3.0.0 2026-08-19, depends on `flutter` only (3.0.0 adds `material_ui`), 2,604 lines in 7 files, no reduced-motion branch | **Take.** `SharedAxisTransition` for the 13 files that build a `Stepper`, `OpenContainer` for a card opening into its detail, `PageTransitionSwitcher` with `FadeThroughTransition` where a fade through is wanted. Nothing in the SDK does these. Pin 2.2.0 until the app is on `material_ui`, then 3.0.0, whose changelog is the import change and a higher SDK floor. |
| `flutter_animate` | gskinner.com, Flutter Favorite, BSD-3-Clause, 4.5.2 2024-11-25, depends on `flutter` and `flutter_shaders`, 3,883 lines in 43 files, built on the widgets layer with no Material import | **Take.** Chained one-shot effects, a staggered entrance for rows (`interval`), and `target:` to drive an effect from state without a controller. It replaces a hand-written controller per effect. It fails on freshness: no release for 23 months, 34 open issues and 14 open pull requests on GitHub. It is small and BSD, so it can be vendored if it is abandoned. Not on money figures, and not for page changes. |
| `rive` | rive.app, MIT, 0.14.11 2026-08-03, depends on `rive_native` 0.1.11 | **No.** `rive_native` is an FFI plugin and "by default, prebuilt native libraries are downloaded and used" at build time: a binary from outside the pub archive in a wallet's build. Fails the supply-chain test. The 12 Lottie call sites stay on `lottie`. |
| `motor` (springs) | whynotmake.it, MIT, 1.1.0 2025-12-02, depends on `equatable` and `meta`, 4,697 lines | **No.** Springs earn their keep on dragged, interruptible motion, which a desktop wallet has little of. The SDK spring covers a press or the rail in ten lines. |
| `flutter_physics`, `sprung`, `springster`, `spring` | 0.2.3 2026-09-12 (63 likes); 3.0.1 2022-07-27; 1.0.2 (needs `motor`); 2.0.2 2021-05-10 | **No.** Same reason, and three of the four are stale or thinly used. |
| `shimmer` | hunghd.dev, BSD-3-Clause, 4.0.0 2026-08-21, needs `material_ui`, 316 lines | **No.** 4.0.0 cannot be used before the migration, and the sweep is a gradient on the bar's own `Paint` (section 2, effect 3). |
| `skeletonizer` | codeness.ly, MIT, 3.0.0 2026-09-11, depends on `flutter` only, 3,632 lines | **No.** It skeletonises the real widget tree by standing in for the `PaintingContext`, and each site must be fed fake data (its README, "The need for fake data"). The app's `SkeletonRows` is in 17 files and needs neither. Add the sweep to `Skeleton` instead. |
| Animated numbers: `animated_flip_counter`, `animated_digit`, `number_flow`, `odometer` | 0.3.4 2024-04-02; 3.3.3 2026-05-27; 1.0.4 (62 downloads a month); 3.0.0 2022-03-15. None has a verified publisher. | **No.** Rolling digits on a balance is decoration on money, which the owner's rules forbid; `ValueFlash` (32 uses) is the sign that a value changed. All four fail on publisher. |
| List entrance: `flutter_staggered_animations`, `auto_animated`, `animated_list_plus` | 1.1.1 2022-08-23; 3.2.0 2023-06-30; 0.5.2 2023-08-21 | **No.** All stale. `flutter_animate` or `SliverAnimatedList` does it. |

**Recommendation: take `animations` 2.2.0 and `flutter_animate` 4.5.2, keep
the app's own `ValueFlash`, `StateSwitcher`, `RiseSwitcher` and `Skeleton`,
and make reduced motion a non-event once, in the binding.**

## 2. Shaders

### Where they run

Impeller is the default on Windows, Linux and macOS since 3.47 and the
opt-out will be removed. The Flutter blog says it runs on "Vulkan on Windows
and Linux". The 3.47.2 source says otherwise: the Windows embedder renders
"using OpenGL (via ANGLE)" (`flutter_windows_engine.cc`, line 54) and the
Linux embedder has an OpenGL manager and no Vulkan path (`fl_engine.cc`).
This repository met the same thing: `heatmap.frag` misdrew on Windows through
OpenGL ES until three undefined GLSL calls were fixed. Write every shader for
OpenGL ES and try it on Windows first.

Three things changed in the SDK that the practices doc does not yet reflect:

- Uniforms have names. `FragmentShader.getUniformFloat('u_time')`,
  `getUniformVec2`, `getUniformVec4` and `getImageSampler('u_image')` are in
  the installed `dart:ui`. Counting `setFloat` indices by hand, as
  `plasma_glow.dart` does, is no longer needed.
- `ImageFilter.shader(shader)` gives a fragment shader the pixels under a
  `BackdropFilter` or an `ImageFiltered`. Impeller only
  (`ImageFilter.isShaderFilterSupported`), which is every desktop target now.
- Since 3.47 a texture the engine renders is stored top down on OpenGL ES, so
  a shader that samples one needs no y flip. A shader copied from older code
  with an `IMPELLER_TARGET_OPENGLES` flip now draws upside down.

### The calls

| Package | Verified today | Call |
|---|---|---|
| `flutter_shaders` | flutter.dev, BSD-3-Clause, 0.1.5 2026-10-07, depends on `flutter` and `vector_math` (already locked at 2.4.3), 910 lines in 5 files. The source moved from a personal repository into `flutter/packages` in this release line. | **Take.** `ShaderBuilder` loads and caches the program by asset and replaces the loader each shader widget would repeat (`_PlasmaGlowAssets` plus the load in `initState`, about 40 lines). `AnimatedSampler` hands a shader its child as a texture. First-party, readable in an hour, and `flutter_animate` needs it anyway. |
| `mesh_gradient` | ben.fornefeld.dev, MIT, 1.3.8 2024-09-23, depends on `flutter_shaders`, 819 lines | **No.** Two years stale, and a mesh gradient is one `.frag` of moving blobs that this app would recolour anyway. |
| `mesh` | renan.gg, MPL-2.0, 0.5.0 2025-05-17, depends on `archive`, `binarize`, `cached_value`, `flutter_shaders` | **No.** Three more dependencies and a copyleft licence for one background. |
| `liquid_glass_renderer` | whynotmake.it, MIT, 0.2.0-dev.4 2025-11-13, platforms: Android, iOS, macOS | **No.** No Windows, no Linux, prerelease only. |
| `glassmorphism`, `glass_kit`, `flutter_glow` | 4.0.0 2026-09-26 (no verified publisher); 4.0.2 2025-09-30; 0.3.2 2024-08-16 | **No.** Blur and glow are `BackdropFilter` and `BoxShadow` in the SDK. Their archives were not read. |
| `shader_buffers` | marcobavagnoli.com, Apache-2.0, 1.1.4 2026-02-26, 418 downloads a month | **No.** Multi-pass buffers are more than these effects need. |
| `flutter_gpu` | the pub.dev entry is an unlisted 0.0.1 from 2023; the Flutter docs call the library experimental | **No.** Not for an application yet. |

### Five effects that suit mockup B

Each shader file is listed under `flutter: shaders:`, sits in a
`RepaintBoundary`, runs on one `Ticker`, and stops when its page is not shown
or the window loses focus (practices doc, section 7).

| # | Effect | Where | How |
|---|---|---|---|
| 1 | A slow field of green, blue and pink light under the card colour | Behind the Home hero | Own `.frag` (three or four drifting blobs, a dither term against banding), through `ShaderBuilder` into a `CustomPaint`. Low contrast: the balance in front of it does not move. It is the one plasma surface of the view. |
| 2 | One pass of light across the primary pill | Send, Collect, Stake: on hover and when the action completes | No shader file. A `LinearGradient` with a `GradientTransform` on a controller, painted as the button's own background, so no mask and no offscreen layer. `flutter_animate`'s `.shimmer()` is the one-line version; it goes through `ShaderMask`, which is acceptable for a one-shot on a 40 px pill and nowhere larger. |
| 3 | A sweep across the skeleton bars, in step across the page | Every loading list and card | Plain `dart:ui`: `Gradient.linear` on the bar's `Paint`, offset by one shared clock and the bar's global x. No package, no offscreen layer. Replaces the breathing fade in `Skeleton`. |
| 4 | Frosted backdrop | Behind the Go to palette, dialogs and menus | `BackdropFilter` with `ImageFilter.blur`, inside a `ClipRect`; `BackdropGroup` and `BackdropFilter.grouped` when several share one backdrop. Grain, if wanted, through `ImageFilter.shader`. |
| 5 | Flow inside the plasma meter | The hero's plasma line and the Plasma page, while plasma is being generated | Own small `.frag` (scrolling noise in QSR blue, speed from the generation state), through `ShaderBuilder`. Still when idle, like `PlasmaGlow`. |

A sixth, if a completed action should burst (RULES.md section 4 allows it on
the action, not on the number): `flutter_animate`'s `ShaderEffect` over the
button, once. It captures the child with `toImageSync` on every frame, so it
is for half a second, not for a loop.

Rule 3 of the owner's design rules says backgrounds are flat and the plasma
gradient fills one surface per view. Effects 1 and 2 both use plasma colours:
on Home the hero field should be the animated one and the Send pill should
keep a still gradient until hovered.

**Recommendation: take `flutter_shaders` 0.1.5, write the shaders by hand for
OpenGL ES, and use the SDK for blur and gradients.**

## 3. A widget set

### What the app has

`AppTokens` is read in 58 files, `Panel` is built in 49 and `PageGrid` lays
out 14 pages. `ShellRail` in `lib/widgets/main_app_container.dart` already
collapses the rail to icons. The motion widgets are in use: `StateSwitcher`
31 times, `ValueFlash` 32, `SkeletonRows` 18.

### What each set is

| Set | Verified today | Lines | Direct dependencies | Collapsible and compact parts | What stops it |
|---|---|---|---|---|---|
| `forui` | duobase.io, MIT, 0.27.5 2026-10-11, needs Flutter 3.47 | 116,064 in 474 files | 9: `material_ui`, `cupertino_ui`, `forui_lucide`, `sugar` (which brings `ffi` and `web`), `collection`, `intl`, `meta`, `vector_math`, `flutter_localizations` | Accordion, popover menu, context menu, resizable panes, a sidebar with nested groups that open and close, touch and desktop variants of every theme | The sidebar has no icon-only state (fixed 256 px in the 0.27.5 source). Needs the `material_ui` migration first. Its own `FThemeData` beside `AppTokens`. 39 lines of its source branch on reduced motion. Five releases in three weeks, pre-1.0. |
| `shadcn_ui` | mariuti.com, MIT, 0.57.1 2026-09-24 | 62,555 in 256 files | 14, among them `slang`, `slang_flutter`, `boxy`, `universal_image`, `flutter_svg`, `lucide_icons_flutter`, `flutter_animate` | Accordion, popover, context menu, menubar, resizable, table | No sidebar. Fourteen dependencies for a wallet. Its own theme. |
| `fluent_ui` | bdlukaa.dev, Flutter Favorite, BSD-3-Clause, 4.16.1 2026-08-03 | 95,582 in 126 files | 5: `intl`, `scroll_pos`, `recase`, `math_expressions`, `flutter_localizations` | `NavigationView` with a compact pane that shows only icons, `Expander`, `CommandBar` with overflow, `TreeView` | It is Windows 11's look, not mockup B's, on all three systems. Needs `FluentApp` and its own theme. The 4.16.1 archive ships a 173 MB `build/` folder, which says how it is packaged. |
| `macos_ui` | macosui.dev, MIT, 2.2.2 2025-10-19 | not counted | 5 | Sidebar, toolbar overflow | macOS only. |
| `shadcn_flutter` | sunaryathito.space, BSD-3-Clause, 0.0.55 2026-10-01 | not counted | 3 | Many | Still 0.0.x after 55 releases. |
| `yaru` | ubuntu.com, MPL-2.0, 11.0.0 2026-10-05 | not counted | 10 | Ubuntu's set | Linux only. |
| `naked_ui` | leoafarias.com, BSD-3-Clause, 1.1.0 2026-10-01, depends on `flutter` only | 13,468 | 0 | Unstyled accordion, disclosure, menu, popover, select, tabs, tooltip: behaviour only, styled by the app | The closest fit, but the SDK now has the same parts (below). 9 likes. |

None can be read in an afternoon; the three main ones are 60 to 116 thousand
lines.

### What the SDK now has in the widgets layer

Unstyled, in `packages/flutter/lib/src/widgets/` of the installed SDK, made
for building a design system that is not Material:

- `Expansible` and `ExpansibleController`: a header that opens a body in
  place. This is the disclosure for Settings groups (K2) and for a card's
  secondary rows (K3). It can also replace the `expandable` package, used in
  3 files.
- `RawMenuAnchor` and `MenuController`: the overflow menu for a card's lesser
  actions (K3). `MenuAnchor`, `MenuItemButton` and `SubmenuButton` are the
  Material-styled version, themable from `AppTokens`.
- `RawTooltip`, `RawAutocomplete`, `RawRadio` with `RadioGroup`,
  `OverlayPortal`, `TreeSliver`, `AnimatedSize`.

### Weighing it

A set would buy ready accordions, menus, popovers, selects and toasts with
keyboard handling done. It would cost a second theme system beside
`AppTokens` (the practices doc's first rule is one source for every value),
the screens already rebuilt and seen, and between 60 and 116 thousand lines
of third-party code in a program that holds keys. The owner's list is short:
a rail that collapses (built), disclosures, overflow menus, a compact
density. The SDK has an unstyled part for each. Taking single components from
`forui` or `shadcn_ui` does not help, because one import brings the whole
package and its dependencies.

Speed is not on a set's side either: all of these are ordinary widgets on the
same renderer. What makes this interface slow or fast is in section 5.

**Recommendation: stay on the app's own widgets. Build the disclosure and
the overflow menu once on `Expansible` and `RawMenuAnchor`, styled from
`AppTokens`, and add a compact density set to `AppTokens` (K4). Look at
`forui` again only after it reaches 1.0 and the app is on `material_ui`.**

## 4. Window chrome

Mockup B draws its own title strip: 32 px, the spaced title, three caption
buttons. So a custom title bar is part of the chosen look.

| Package | Verified today | Call |
|---|---|---|
| `window_manager` | leanflutter.dev, MIT, 0.5.2 2026-07-04, Windows, Linux, macOS; the app locks 0.5.1 | **Use what is there.** 0.5.2 has `setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: ...)`, `DragToMoveArea`, `DragToResizeArea`, `WindowCaptionButton` and `VirtualWindowFrame` (read in the archive). Draw the strip in Flutter from `AppTokens`. On macOS hide the title and keep the system's traffic lights. The repository's README already describes a different, newer API than the one on pub.dev, so a breaking release is coming: pin the exact version. |
| `flutter_acrylic` | no verified publisher, MIT, 1.1.4 2024-06-11, Windows, Linux, macOS | **No.** Mica and acrylic show through a transparent Flutter surface, and mockup B is opaque cards on an opaque ground: only the gaps would show it. Its README says acrylic on Windows 10 goes through an undocumented `user32.dll` call, Mica is Windows 11 only, and Linux depends on the compositor. Two years without a release, never tried on Impeller. Fails on publisher. |
| `bitsdojo_window` | bitsdojo.com, MIT, 0.1.6 2023-12-23, four federated packages | **No.** Nearly three years stale, and `window_manager` already does the same job. |

The SDK's own windowing (`RegularWindow`, `DialogWindow`, `PopupWindow` in
`widgets/_window.dart`) is what the 3.47 announcement calls "experimental
desktop windowing APIs". Not for this release.

**Recommendation: a custom title strip through `window_manager`, no new
package, no acrylic.**

## 5. State and structure

Counted in `lib/` today (737 files, 87,910 lines):

| Pattern | Count | What it costs on screen |
|---|---|---|
| `BlocBuilder` | 51, against 7 `BlocSelector` and 10 `buildWhen` | A builder round a card or page rebuilds all of it on every state the bloc emits, whether or not the part on screen changed. |
| `Widget _buildX()` and `_getX()` methods | 227 | A method's output cannot be `const` and has no element of its own, so it is rebuilt whenever its parent is, including on every tick of an animation the parent listens to. |
| `setState` | 283 | Each rebuilds every descendant of its `State`. Fine in a leaf, costly in a page. |
| Four ways to hold state | `flutter_bloc`, `stacked` (20 `ViewModelBuilder`), `provider` (19), `StreamBuilder` over `rxdart` (25) | `ViewModelBuilder` and `StreamBuilder` rebuild their whole builder with no selector. Four idioms also mean four ways for a rebuild to be wider than it looks. |
| Continuous painters | 12 `Lottie.asset`, 42 `SyriusLoadingWidget` | Each repaints every frame and takes its surroundings along unless it sits in a `RepaintBoundary`. |

What current guidance says:

- Flutter's performance page (updated 2026-09-29): "localize the `setState()`
  call to the part of the subtree whose UI actually needs to change", "to
  create reusable pieces of UIs, prefer using a `StatelessWidget` rather than
  a function", use `const` constructors "as much as possible", and inside
  `AnimatedBuilder` pass what does not depend on the animation as `child`.
- The bloc documentation: "DO use `BlocSelector` instead of `context.select`
  to explicitly scope rebuilds", and `context.watch` "at the root of the
  `build` method will result in the entire widget being rebuilt".
- Flutter's architecture recommendations: views stay "dumb", logic in a view
  model, immutable state. `flutter_bloc` already satisfies this. No new state
  package is needed.

What holds the interface back, in the order to fix it:

1. **No measurement.** No profile-mode run of this app exists (practices doc,
   section 6). Take one before R3, with DevTools' frame chart, so motion work
   is judged against a number. Text also changed in 3.47: Impeller draws
   desktop glyphs as signed distance fields with gamma correction, so check
   the 11 px ledger labels.
2. **Wide rebuilds under motion.** Motion makes an existing wide rebuild
   visible as a dropped frame. On each screen R3 touches: `BlocSelector` or
   `buildWhen` round the part that reads the state, and the `_buildX()`
   methods of that screen turned into private widget classes with `const`
   constructors.
3. **One idiom for reworked screens.** New and reworked screens use
   `flutter_bloc`. `stacked` and bare `StreamBuilder` stay where they are
   until their screen is reworked; no rewrite for its own sake.
4. **Tickers that never stop.** Put a `TickerMode` at the shell, off while
   the window is minimised or the wallet is locked (the shell is already a
   `WindowListener`). Every Lottie, shader and skeleton under it then stops
   without knowing why.
5. **The shell file.** `main_app_container.dart` is 1,546 lines in one
   `State` with `_buildBody`, `_buildRail` and others. It already narrows its
   rebuilds with `ValueListenableBuilder`, so this is about reading it, not
   about frames.

The practices doc's line that the shell calls `setState` for a notification
and rebuilds the app is out of date: the banner is a `ValueListenableBuilder`
now, and the page switch is a `RiseSwitcher` that builds only the page shown.

**Recommendation: no new state package. Measure in profile mode first, then
narrow rebuilds and replace `_buildX()` methods screen by screen as R3 passes
through, and stop every ticker from one `TickerMode` at the shell.**

## Packages to take

| Package | Publisher | Pin | Released | Licence | Windows / Linux / macOS | Replaces here | On Impeller |
|---|---|---|---|---|---|---|---|
| `animations` | flutter.dev | `2.2.0` now, `3.0.0` with the `material_ui` migration | 2026-04-23 (3.0.0: 2026-08-19) | BSD-3-Clause | yes / yes / yes | Hand-written stepper and detail transitions; nothing in the SDK does shared axis or container transform | Pure widgets: `FadeTransition`, `ScaleTransition`, `Material`. No shader, no platform code, no offscreen layer in its source. |
| `flutter_animate` | gskinner.com | `4.5.2` | 2024-11-25 | BSD-3-Clause | yes / yes / yes | A controller per one-shot effect; staggered row entrance | Widgets layer only. Three effects cost a layer: `shimmer` (`ShaderMask`), `blur` (`ImageFiltered`), `shader` (`AnimatedSampler`). Keep those short and small. |
| `flutter_shaders` | flutter.dev | `0.1.5` | 2026-10-07 | BSD-3-Clause | yes / yes / yes | The per-widget shader loader; gives a shader its child as a texture | `AnimatedSampler` captures the child with `toImageSync` each frame. From 3.47 the captured texture needs no y flip on OpenGL ES. |

Together they add three entries to `pubspec.lock` and nothing else:
`vector_math` is already locked. Pin with exact versions, not carets.

With the `material_ui` migration, later: `material_ui` (flutter.dev,
BSD-3-Clause, 1.6.0 on 2026-10-06, needs Flutter 3.47 and Dart 3.13, brings
`cupertino_ui` 1.1.2; its other dependencies are already locked at versions
that satisfy it) and `animations` 3.0.0. Take whichever `material_ui` is
current on the day, and pin it: it releases weekly.

Already in `pubspec.yaml` and used for the title strip: `window_manager`
(locked 0.5.1; 0.5.2 only moves `screen_retriever` for Swift Package Manager).

## Not verified

- Nothing was resolved, built or run. That the three pins resolve together on
  Flutter 3.47.2 is read from their `environment` and `dependencies` fields.
- No package was tried on Impeller on Windows. The Impeller column is read
  from each package's source.
- The binding override for reduced motion is read from the SDK source, not
  tried. The macOS embedder's handling of the flag was not read.
- The Flutter blog says Impeller runs on Vulkan on Windows and Linux; the
  3.47.2 embedder source says OpenGL through ANGLE on Windows and OpenGL on
  Linux. This document follows the source.
- GitHub did not show the date of `flutter_animate`'s last commit. Its
  staleness is judged from the pub.dev release date and the open counts.
- `forui`'s sidebar: the documentation page does not mention an icon-only
  state and the 0.27.5 source has none; its issue tracker was not searched.
- `flutter_acrylic`: a search of its issues for "impeller" returned nothing,
  which is absence of a report, not a pass.
- `macos_ui`, `shadcn_flutter` and `yaru` were judged from pub.dev metadata
  alone; their archives were not read.
- `bitsdojo_window` was judged from pub.dev metadata alone.

## Sources

Read on 2026-10-13.

1. pub.dev API, per package (`https://pub.dev/api/packages/<name>`, with
   `/publisher` and `/score`): animations, flutter_animate, flutter_shaders,
   rive, rive_native, shimmer, skeletonizer, motor, sprung, springster,
   flutter_physics, heroine, animated_flip_counter, animated_digit, odometer,
   number_flow, flutter_staggered_animations, auto_animated,
   animated_list_plus, mesh_gradient, mesh, liquid_glass_renderer, glass_kit,
   glassmorphism, flutter_glow, shader_buffers, flutter_gpu, lottie, forui,
   forui_lucide, sugar, shadcn_ui, shadcn_flutter, fluent_ui, macos_ui, yaru,
   naked_ui, mix, remix, material_ui, cupertino_ui, flutter_acrylic,
   window_manager, bitsdojo_window, screen_retriever, flutter_bloc, bloc
2. pub.dev archives, read without running
   (`https://pub.dev/api/archives/<name>-<version>.tar.gz`): animations 2.2.0
   and 3.0.0, flutter_shaders 0.1.5, flutter_animate 4.5.2, skeletonizer
   3.0.0, shimmer 4.0.0, motor 1.1.0, forui 0.27.5, shadcn_ui 0.57.1,
   fluent_ui 4.16.1, naked_ui 1.1.0, window_manager 0.5.2, flutter_acrylic
   1.1.4, mesh_gradient 1.3.8, rive 0.14.11, material_ui 1.6.0
3. https://pub.dev/packages/animations
4. https://pub.dev/packages/animations/changelog
5. https://pub.dev/packages/flutter_animate
6. https://pub.dev/packages/flutter_shaders
7. https://pub.dev/packages/rive
8. https://pub.dev/packages/skeletonizer
9. https://pub.dev/packages/shimmer
10. https://pub.dev/packages/material_ui
11. https://github.com/gskinner/flutter_animate
12. https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
13. https://flutter.dev/blog/decoupling-material-cupertino
14. https://flutter.dev/blog/whats-new-in-flutter-3-47
15. https://docs.flutter.dev/perf/impeller
16. https://docs.flutter.dev/ui/design/graphics/fragment-shaders
17. https://docs.flutter.dev/release/breaking-changes/opengles-render-to-texture-top-down
18. https://startdebugging.net/2026/10/migrate-a-flutter-windows-or-linux-desktop-app-to-impeller/
    (secondary; its claim about the backend was checked against source 19)
19. `flutter/flutter` at tag 3.47.2, through raw.githubusercontent.com:
    `engine/src/flutter/shell/platform/windows/flutter_windows_engine.cc`,
    `engine/src/flutter/shell/platform/linux/fl_settings_handler.cc`,
    `engine/src/flutter/shell/platform/linux/fl_engine.cc`,
    `engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine.mm`
20. The installed SDK, `C:\dev\flutter` (3.47.2):
    `packages/flutter/lib/src/animation/animation_controller.dart`,
    `semantics/binding.dart`, `widgets/expansible.dart`,
    `widgets/raw_menu_anchor.dart`, `widgets/raw_tooltip.dart`,
    `widgets/repeating_animation_builder.dart`, `widgets/basic.dart`,
    `widgets/_window.dart`, `widgets/implicit_animations.dart`,
    `physics/spring_simulation.dart`,
    `material/page_transitions_theme.dart`,
    `fix_data/fix_material/fix_material.yaml`, and
    `bin/cache/pkg/sky_engine/lib/ui/painting.dart`
21. https://forui.dev/docs/widgets/navigation/sidebar
22. https://forui.dev/docs/concepts/themes
23. https://github.com/leanflutter/window_manager/blob/main/README.md
24. https://github.com/alexmercerind/flutter_acrylic/issues?q=is%3Aissue+impeller
25. https://bloclibrary.dev/flutter-bloc-concepts/
26. https://docs.flutter.dev/perf/best-practices
27. https://docs.flutter.dev/app-architecture/recommendations
28. `C:\dev\zenon\webdesign-lab\RULES.md`, sections 1 to 5
