---
name: modern-ui-universal
description: >
  Use this skill whenever the user asks to design, build, redesign, or improve any user interface — screen, page, dashboard, form, app, website, or component — in ANY framework or platform (Flutter, React, Vue, Angular, plain HTML/CSS, iOS/SwiftUI, Android/Jetpack Compose, desktop apps, etc.). Also trigger when the user describes a layout as "empty", "boring", "outdated", "cramped", "siksik", "sira ang UI", or asks to make something "modern", "maganda", "professional", or compares it to a reference app (good or bad example, e.g. Shopee, Lazada, banking apps, competitor products). This skill is framework-agnostic — it detects whatever platform/framework the user is working in from context (mentioned files, prior messages, stated tech stack) and translates the design principles into that framework's native idioms and components. Apply by default for any UI-generation task unless the user explicitly asks for a bare/minimal/wireframe layout.
---

# Modern UI (Universal)

A framework-agnostic design skill for producing UIs that are **modern, fully-utilized, and professional** — regardless of what platform or tech stack is being used. The same core principles apply whether the output is Flutter widgets, React components, plain HTML/CSS, SwiftUI, Jetpack Compose, or anything else.

This skill solves the two most common bad extremes:
1. **Too empty** — big blank areas, wasted whitespace, feels unfinished or lazy.
2. **Too cramped** — elements stacked directly on top of each other with no grouping, no breathing room, flat unstyled inputs, weak hierarchy. (Classic example: outdated e-commerce account/profile pages like Shopee's — fields stacked raw with no card grouping, only one action button, inconsistent icon sizes.)

The target is the middle ground: **dense with content and function, generous with structured spacing.**

## Step 0: Detect the platform/framework

Before applying anything, determine what the user is building in — check file extensions, prior messages, stated stack, or ask if genuinely ambiguous. This determines which native idioms to use in Step 5. Do not default to web/HTML if the context suggests otherwise (e.g. `.dart` files → Flutter, `.swift` → SwiftUI, mentions of "widget"/"StatefulWidget" → Flutter, mentions of "component"/"JSX" → React).

## Core Principles (platform-agnostic — apply regardless of framework)

### 1. Group, don't stack
Never place raw fields, list items, or content blocks directly one after another with no container. Group related content into **cards/sections** with:
- A section label/header
- Internal padding (16–24px / dp equivalent, minimum)
- Visual differentiation from the page background (elevation, border, or tonal fill)
- Consistent gap **between** groups (24–32px) vs. gap **within** a group (16–20px)

### 2. Use one spacing scale — never arbitrary gaps
Pick a single scale and use it everywhere: `4, 8, 12, 16, 24, 32, 48, 64`. No eyeballed/random gaps anywhere in the layout. This single rule prevents most "randomly cramped in some spots, randomly empty in others" problems.

### 3. Fill space with function, not decoration
"Every space is used" means purposeful content, not filler:
- Empty rail/sidebar space → shortcuts, stats, recent activity, status
- Empty page bottom → related actions, secondary info, footer/nav
- Empty card corners → badges, counts, timestamps, icons
- If a region genuinely has nothing useful, **shrink that region** — don't pad it with blank space or stuff it with irrelevant decoration.

### 4. Typography hierarchy (mandatory)
Minimum 3 clear levels on any screen:
- Title/section heading — bold, larger
- Label/subheading — medium weight, muted color, smaller
- Body/value/input text — regular weight
Never let a label and its value render at the same weight/size — that kills scannability.

### 5. Every interactive element needs states
Buttons, inputs, list items, nav items: define default, hover/focus, active/pressed, and disabled states — regardless of whether the platform has a literal "hover" (touch platforms still need pressed/active feedback). Flat, static-looking inputs with no focus indication read as dated. Use rounded corners and a clear focus indicator (border/ring/elevation change).

### 6. Button hierarchy — always more than one lonely action
Any form or settings-type screen should include, as appropriate:
- Primary action (filled, brand color) — e.g. Save, Submit, Continue
- Secondary action (outlined/ghost) — e.g. Cancel, Reset
- Tertiary/inline actions (text links or icon buttons) — e.g. Edit, Change, Remove
- Destructive action if relevant — e.g. Delete, styled distinctly (red/outline)
Never ship a screen with a single isolated primary button and nothing else, unless the flow genuinely has no other action.

### 7. Icon consistency
Pick ONE icon family appropriate to the platform (Material Symbols/Cupertino/Lucide/Font Awesome/SF Symbols) and ONE consistent size per context (e.g. nav icons vs. inline icons). Never mix icon families or let sizes vary arbitrarily.

### 8. Color system
- One brand/accent color for primary actions, active states, links.
- Neutral grayscale for text/background/borders — avoid pure black (#000); prefer dark gray (#1A1A1A–#212121).
- Status colors (success/warning/error) reserved strictly for status — never for decoration.
- At least 2 distinct neutral tones: page background ≠ card/surface background ≠ input background.

### 9. Responsive density
On larger viewports, use extra space for a genuinely useful secondary column/panel (stats, preview, related info) rather than just widening margins. On smaller viewports, stack to a single column but preserve the spacing scale and grouping — never compress spacing purely because the screen is smaller.

## Step 5: Translate principles into the detected framework's native idioms

Apply Step 0's detected platform here — use the platform's real component system, not generic markup with inline styles:

| Platform | Use |
|---|---|
| Flutter | Material 3 (`ColorScheme.fromSeed`, `ThemeData`, `TextTheme`), real widgets (`Card`, `FilledButton`, `OutlinedButton`, `NavigationBar`), centralize spacing/radius/colors in a theme/tokens class |
| React / Next.js | Tailwind CSS or shadcn/ui components, design tokens via `tailwind.config` or CSS variables, semantic component structure |
| Plain HTML/CSS | Semantic HTML, CSS custom properties (`:root { --space-md: 16px }`) for the spacing scale and color system |
| SwiftUI | Native `.padding()`, `.cornerRadius()`, HIG-compliant components, `Color` assets for the palette |
| Jetpack Compose | Material 3 for Compose, `MaterialTheme`, `Modifier.padding()` using a defined spacing object |
| Vue / Angular | Same as React idioms — component-based structure, scoped design tokens |

If the framework isn't listed, infer the closest native idiom set and apply the same principles.

## Workflow when this skill triggers

1. **Detect platform/framework** (Step 0).
2. **Identify screen type** (form, dashboard, list, profile, landing page, etc.).
3. **Map every region of the screen to a function** before building. If a region has no function, cut it — don't leave it blank, don't fill it with filler.
4. **Build using real, native components** for the detected framework (not raw unstyled containers).
5. **Apply the spacing scale and typography hierarchy consistently**, centralized in a theme/tokens layer whenever the framework supports one.
6. **Add the full button/state set** (Principle 6) — don't ship a screen with only one button if the flow logically needs more.
7. **Self-check before presenting**: Does any area look dead/empty? Does any area look squeezed/stacked with no grouping or padding? Fix both before showing the result.

## Reference anti-pattern

Outdated e-commerce account/profile pages (e.g. Shopee's "My Profile" web page) are the canonical *bad* example: fields stacked raw with no card grouping, flat unstyled inputs with no focus state, only one action button, inconsistent icon sizing, weak label/value hierarchy. If the user references this kind of layout as a bad example, explicitly avoid all issues listed in Principles 1–7 above, regardless of the target framework.
