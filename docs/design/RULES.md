# Design rules for this wallet

The owner's interface rules, copied into this repository on 2026-10-21 from the
rules every Zenon front end is held to, with the parts that only apply to web
pages (mobile breakpoints, CSS frameworks, CDNs) left out. Sections 4 and 5
are the owner's words; elsewhere the rule text is kept, and where it differs
from the original the difference is marked. Section 8 is the transfer shape,
first built for a bridge page, restated for the surfaces of this wallet. When a rule and the mockups in `mockups/redesign/` disagree, ask
the owner; until they answer, the mockups win for layout and these rules win
for motion and text.

## 1. Principle

- The data is the hero. Balances, amounts, addresses and hashes are
  first-class: mono type, tabular figures, dedicated components, never
  ordinary text.
- A user who has seen one surface can read the next without relearning what a
  colour or a column means.

## 2. Type

- Two roles only: one sans for interface, one mono for data. Here Space
  Grotesk and JetBrains Mono, unless the mockup's inlined fonts say otherwise
  (they are the source for this wallet).
- Every number uses tabular figures and every identifier is mono, so columns
  align and values do not jitter as they update.
- Ledger labels: mono, uppercase, 11 px, +0.06em tracking, for labels only,
  never values or prose.
- Sentence case for labels, headings and buttons. Uppercase only for the
  ledger-label texture.
- Fonts are bundled with the app, with their licences. Nothing is fetched at
  run time.

## 3. Colour and surface

- Semantic tokens only, never raw hex in a widget.
- Money is not coloured by default. Green and red belong to direction and
  status chips, not to the number.
- Green `#00D557` is brand and success, blue `#0061EB` is info and pending,
  pink `#F91690` is one reserved accent for new or featured and never an
  error.
- Errors are crimson, distinct from the brand accent.
- The signature gradient (plasma) fills only the primary or active surface,
  once per view. Do not spray it on chrome, and do not flatten primary buttons
  to a solid fill.
- One tight radius token (about 6 px). Pills go full. No arbitrary radii.
  (The transfer shape, section 8, sets this aside for its own cards.)
- Elevation is theme-aware: on dark, a deeper drop plus a lit top edge,
  because a plain shadow vanishes on near-black. Never hand-roll a shadow.
- Every token is defined for light and dark, and both are tested.
- Status never relies on colour alone: an icon plus a label.

## 4. Motion

The owner's rule, word for word. It binds.

**Never respect the OS reduced-motion setting.** Every animation runs, always,
whatever the OS reports. Don't branch on the platform's reduced-motion or
disable-animations flag (in Flutter, `MediaQuery.disableAnimations` and
`AccessibilityFeatures.disableAnimations`), don't add a toggle that defaults
to the OS setting, and when you find any of these in a file you're working
on, remove it and leave a comment saying why. Don't describe an animation as
honouring or depending on the setting either: it doesn't.

Windows reports reduced motion whenever "Animation effects" is off, and on the
machine these apps are built and checked on, nobody chose that setting. A
blanket rule that honoured it once cut every animation to zero, so a new block
never landed, and a loading state looked the same as a broken one. Motion is
how the wallet shows that the chain is live and that a value just changed, so
it runs whatever the OS reports.

There are no exceptions unless the owner names a specific effect and asks for
it in so many words.

Other motion rules:

- State changes: 150 ms `cubic-bezier(.4,0,.2,1)` on colour, background and
  shadow.
- No decorative animation on financial data. Amounts never roll or count.
- Overlays and sheets: a fast 150 to 240 ms translate, or instant.

## 5. Interface text

The owner's rule, word for word.

**Use as little text as you can.** This covers every word the interface
shows: headings, intros, notes, hints, warnings, empty states, button labels.

- One or two sentences introduce a page. A note under a table, form or step is
  one short line, or is left out.
- Do not explain what a heading, label or button already says, and do not say
  the same thing twice on a page.
- Plain English first. Technical terms (momentum, plasma, HTLC, spork) are
  fine where they are the right name; do not paraphrase them.
- No em dashes in interface text. Use a full stop, a comma or a colon.
- An empty state is "None yet". A warning is the fact and what to do about it.
- Background and rationale go in the docs, not on the screen.

A console once shipped with a paragraph under every heading and its owner
called the pages cluttered; the rewrite cut most intros to two sentences and
most notes to a line, and nothing a user needed was lost.

Other text rules:

- Exact numbers, always mono. **Balances show no trailing zeros at all**: the
  owner's later word, which overrides the original rule of dimming them.
  Truncate identifiers as `start…end` with the full value on hover.
- One word per state, app-wide.
- Status is factual, not alarmist.

## 6. Diagrams in docs

- Diagrams in Markdown, READMEs, docs and comments are always Mermaid. Never
  ASCII art, never an image of a diagram.
- Pick the type from what is shown: `sequenceDiagram` for parties exchanging
  messages over time (reach for it first), `flowchart` for dependencies,
  `stateDiagram-v2` for a thing in one state at a time, a table for fewer than
  about six measured points.
- One diagram makes one thing clear. A node label is a name, not a sentence.
  If it needs a legend, split it.
- Draw the failure path. Declare participants up front. No participant per
  function.
- Parsing is not rendering: render it and check there is no error box.

## 7. Working with the owner's art

- A redesign of existing art means augment: start from a faithful,
  higher-fidelity trace and add to it. Do not open with simplified variants or
  a critique.
- Trace marks from the source rather than redrawing by eye, and measure before
  scaling. The original Lottie files are kept as they are (see the mockup
  README).

## 8. The transfer shape

For a surface that is one action on money: in this wallet the Send / Receive /
Zap card, the send confirm dialog, and the Start and Join swap dialogs. It
keeps every rule above except two:

| Rule above | Here instead | Why |
|---|---|---|
| One tight radius, about 6 px | Three: cards 24 px, controls and rows 14 px, buttons and chips full | A single large card is the page; a tight radius reads as a table cell |
| Flat, still background | A field behind the card | The page has one form on it and nothing else to show the app is live. In this wallet the field is the hero shader, not a starfield |

Surface and colour:

- Cards are glass: the surface colour at 88% over the field, a 10 px backdrop
  blur, a 1 px line, a lit top edge plus a deep drop on dark and a plain soft
  shadow on light.
- Plasma fills the one main action and nothing else. That button is full
  width, 58 px tall, 17 px text.
- Colour is state: green done, blue waiting, amber needs you, crimson refused
  or down.

The form:

- One column, centred, at the width the mockup gives.
- The amount is mono at 30 px. The entered amount is an input with a Max pill;
  a computed amount is text, dim until there is one.
- Under each amount, one 20 px line of dim 14 px text: balance or recipient at
  the left, the dollar estimate, mono, at the right.
- When the card does several kinds of action, a segmented pill above the form
  picks one. The mode narrows everything to itself, and each mode comes back
  to what it last showed.
- The main button says what is missing, in the order the user meets it: enter
  an address, enter an amount, not enough, then the action. One button.
- Cost and steps sit one tap away under the button, in a collapsed Details
  list. Closed, the row shows the single most useful fact.
- Rare controls live in menus and sheets, not on the form.

Messages:

- A failure is a few plain words the user can act on, never a library's text:
  one line, 80 characters at most, first letter capital, through one mapper.
- Name the remedy: "Not enough plasma", "Network error. Try again." A
  contract's own error is shown as it is.
- A toast is the event in two or three words: "Sent", "Fused", "Collected".

Motion, always on (section 4):

- Two curves: `(.4,0,.2,1)` for colour and shadow at 180 ms, the spring
  `(.2,.8,.2,1)` for anything that moves.
- The segment has one thumb that slides between equal parts in 360 ms,
  `(.65,0,.35,1)`, while the labels change colour. It never jumps.
- Changing the mode does not rebuild the card. Only what changed is replaced,
  fading in place over 260 ms.
- A view rises 6 px in 320 ms. An opened list slides down 8 px in 240 ms. A
  chevron turns over in 220 ms. A changed value flashes once for 1.2 s.

## 9. Checklist for a screen

- [ ] Identifiers and amounts go through their widgets (`AmountText`, the
      address widget, `DollarText`)
- [ ] Every number in tabular figures, every identifier mono
- [ ] Tokens only, no colour literals
- [ ] The plasma fill appears once, on the main action
- [ ] Errors use the error colour; the accent stays an accent
- [ ] Status is icon plus label, named the same everywhere
- [ ] Correct in light and dark
- [ ] Text is minimal and plain, nothing said twice, no em dashes
- [ ] Nothing fetched at run time except the chain and the price feed
- [ ] No reduced-motion branch anywhere
- [ ] Every icon-only button has a tooltip
