# clickup DESIGN.md

> Auto-generated design system — reverse-engineered via static analysis by skillui.
> Frameworks: None detected
> Colors: 20 · Fonts: 3 · Components: 6
> Icon library: not detected · State: not detected
> Primary theme: light · Dark mode toggle: no · Motion: expressive

## Visual Reference

**Match this design exactly** — study colors, fonts, spacing, and component shapes before writing any UI code.

![clickup Homepage](screenshots/homepage.png)

---

## 1. Visual Theme & Atmosphere

This is a **light-themed** interface with a neutral, approachable feel. The light background emphasizes content clarity. Typography pairs **Inter** for display/headings with **Plus Jakarta Sans** for body text, creating clear visual hierarchy through type contrast. Spacing follows a **4px base grid** (compact density), with scale: 2, 4, 6, 8, 10, 12, 14, 16px. Motion is expressive — spring physics, layout animations, and staggered reveals are part of the visual language.

---

## 2. Color Palette & Roles

| Token | Hex | Role | Use |
|---|---|---|---|
| color-ui-glass-main | `#ffffff` | background | Page background, darkest surface |
| color-gray-light-2 | `#f1f3fb` | surface | Card and panel backgrounds |
| color-ui-border-buttons | `#030303` | text-primary | Headings and body text |
| bottom-navigation-item-text-color | `#646464` | text-muted | Captions, placeholders, secondary info |
| Hero-Text-Secondary | `#5d5d85` | text-muted | Captions, placeholders, secondary info |
| color-ui-glass-main | `#1d1e20` | border | Dividers, card borders, outlines |
| danger | `#fd9a46` | danger | Error states, destructive actions |
| shimmer-color1 | `#0091ff` | info | Informational highlights |
| bottom-navigation-mobile-border-color | `#e8e8e8` | unknown | Palette color |
| bottom-navigation-chevron-color | `#838383` | unknown | Palette color |
| bottom-navigation-shell-background | `#111111` | unknown | Palette color |
| Core-Text-Disabled | `#bbbbbb` | unknown | Palette color |
| Core-Accents-Purple | `#6647f0` | unknown | Palette color |
| color-primary-purple | `#7612fa` | unknown | Palette color |
| Carousel-Control-Background-Hover | `#e2e8ff` | unknown | Palette color |
| color-slate-900 | `#292d34` | unknown | Palette color |
| Core-Button-Secondary-Hover | `#d9d9d9` | unknown | Palette color |
| unknown | `#fa24ce` | unknown | Palette color |
| unknown | `#fc6d7b` | unknown | Palette color |
| color-ui-border-default | `#737373` | unknown | Palette color |

### CSS Variable Tokens

```css
--color-button-other-background: 0,0,0,.15;
--color-gradient-cyan-accent-light-1: var(--color-white),.1;
--color-ui-border-default: rgba(96,96,163,.3);
--color-ui-border-hover: rgba(96,96,163,.5);
--color-ui-border-buttons: rgba(0,0,0,.18);
--color-ui-border-default: rgba(115,115,115,.3);
--color-ui-border-hover: rgba(115,115,115,.5);
--color-ui-border-buttons: rgba(255,255,255,.18);
--max-card-width: 545px;
--accent-inline-property: 40px;
--table-border-radius: 10px;
--table-border-radius: 14px;
--accent-inline-property: 40px;
--bottom-navigation-shell-background: rgb(var(--color-white));
--bottom-navigation-shell-background: #111;
--bottom-navigation-link-hover-background: rgba(0,0,0,.04);
--bottom-navigation-mobile-border-color: rgb(232,232,232);
--bottom-navigation-subsection-border-color: rgb(232,232,232);
--bottom-navigation-link-hover-background: rgba(255,255,255,.04);
--bottom-navigation-mobile-border-color: rgba(255,255,255,.12);
```


---

## 3. Typography Rules

**Font Stack:**
- **Plus Jakarta Sans** — Heading 1, Heading 2, Heading 3
- **Inter** — Body, Caption
- **Sometype Mono** — Code

**Font Sources:**

```css
@font-face {
  font-family: "Inter";
  src: url("https://clickup.com/assets/fonts/Inter.woff2") format("woff2");
  font-weight: 100;
}
@font-face {
  font-family: "Plus Jakarta Sans";
  src: url("https://clickup.com/assets/fonts/PlusJakartaSans-VariableFont_wght.woff2") format("woff2");
  font-weight: 200;
}
@font-face {
  font-family: "Shantell Sans";
  src: url("https://clickup.com/assets/fonts/ShantellSans-VariableFont.woff2") format("woff2");
  font-weight: 300;
}
@font-face {
  font-family: "Sometype Mono";
  src: url("https://clickup.com/assets/fonts/SometypeMono-VariableFont.woff2") format("woff2");
  font-weight: 400;
}
```

| Role | Font | Size | Weight |
|---|---|---|---|
| Heading 1 | Plus Jakarta Sans | 236px | 700 |
| Heading 2 | Plus Jakarta Sans | 166px | 700 |
| Heading 3 | Plus Jakarta Sans | 5.75rem | 700 |
| Body | Inter | 14px | 400 |
| Caption | Inter | 16px | 400 |
| Code | Sometype Mono | 14px | 400 |

**Typographic Rules:**
- Limit to 3 font families max per screen
- Use **Plus Jakarta Sans** for body/UI text, **Inter** for display/headings
- Maintain consistent hierarchy: no more than 3-4 font sizes per screen
- Headings use bold (600-700), body uses regular (400)
- Line height: 1.5 for body text, 1.2 for headings
- Use color and opacity for secondary hierarchy, not additional font sizes


---

## 4. Component Stylings

### Layout (1)

**Footer** — `html`

### Navigation (1)

**Navigation** — `html`

### Data Input (1)

**Button** — `html`
- Animation: 

### Media (3)

**Image** — `html`

**Icon** — `html`

**Map/Canvas** — `html`



---

## 5. Layout Principles

- **Base spacing unit:** 4px
- **Spacing scale:** 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24
- **Border radius:** .125rem, .188rem, .25rem, .375rem, .5rem, 1px, 2px, 3px, 4px, 5px, 6px, 7px, 7.7px, 8px, 9px, 10px, 11px, 12px, 13px, 14px, 15px, 16px, 18px, 20px, 24px, 25px, 27.72px, 28px, 30px, 32px, 40px, 48px, 50px, 54px, 60px, 64.605px, 70px, 88px, 90.324px, 100px, 200px, unset, 100%, 124.516px, 170px, 724px, 999px, inherit
- **Max content width:** 1200px

**Spacing as Meaning:**
| Spacing | Use |
|---|---|
| 4-8px | Tight: related items within a group |
| 12-16px | Medium: between groups |
| 24-32px | Wide: between sections |
| 48px+ | Vast: major section breaks |


---

## 6. Depth & Elevation

### Flat — subtle depth hints

- `0 0#0000,0 1px 2px #0000000d`
- `inset 0 0 0 1px #00000026`
- `inset 0 0 0 1px #dacfff`

### Raised — cards, buttons, interactive elements

- `0 3px 3px -1.5px #122ba50d`
- `0 2px 8px #0000001a`
- `0 1px 4px #00000014`

### Floating — dropdowns, popovers, modals

- `0 1px 1px -.5px #122ba50a,0 3px 3px -1.5px #122ba50a,0 6px 6px -3px #122ba50a,0 12px 12px -6px #122ba50a`
- `0 4px 12px #0000001a`
- `0 4px 10px #0d15300d`

### Overlay — full-screen overlays, top-level dialogs

- `0 1px 1px -.5px #122ba50a,0 3px 3px -1.5px #122ba50a,0 6px 6px -3px #122ba50a,0 12px 12px -6px #122ba50a,0 24px 24px -12px #122ba50a`
- `0 1px 1px -.5px #122ba50f,0 3px 3px -1.5px #122ba50f,0 6px 6px -3px #122ba50f,0 12px 12px -6px #122ba50f,0 24px 24px -12px #122ba50f,0 48px 48px -24px #122ba50f`
- `0 .41px .41px -.205px #122ba50a,0 1.231px 1.231px -.616px #122ba50a,0 2.462px 2.462px -1.231px #122ba50a`

### Z-Index Scale

`0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 20, 21, 22, 50, 89, 99, 100, 1001, 1999, 9997, 9998, 9999, 10000, 10020, 50000, 99999, 2147483647, 3000000000, 3000000001, 3000000002, 3000000003`



---

## 7. Animation & Motion

This project uses **expressive motion**. Animations are an integral part of the experience.

### CSS Animations

- `@keyframes _progressBarHeight_1kq03_1`
- `@keyframes _slideDown_1kq03_1`
- `@keyframes _slideUp_1kq03_1`
- `@keyframes _slideDown_jxed5_1`
- `@keyframes _slideUp_jxed5_1`
- `@keyframes _banner_10pd0_1`
- `@keyframes _moveLogos_1ojqd_1`
- `@keyframes _slide-translate_1s4xh_1`

### Animated Components

- **Button**: 

### Motion Guidelines

- Duration: 150-300ms for micro-interactions, 300-500ms for page transitions
- Easing: `ease-out` for enters, `ease-in` for exits
- Always respect `prefers-reduced-motion`


---

## 8. Do's and Don'ts

### Do's

- Use `#ffffff` as the primary page background
- Pair **Plus Jakarta Sans** (body) with **Inter** (display) — these are the only allowed fonts
- Follow the **4px** spacing grid for all margins, padding, and gaps
- Use the defined shadow tokens for elevation — see Section 6
- Use border-radius from the scale: .125rem, .188rem, .25rem, .375rem, .5rem
- Reuse existing components from Section 4 before creating new ones

### Don'ts

- Don't introduce colors outside this palette — extend the design tokens first
- Don't introduce additional font families beyond Plus Jakarta Sans and Inter and Sometype Mono
- Don't use arbitrary spacing values — stick to multiples of 4px
- Don't create custom box-shadow values outside the system tokens
- Don't use arbitrary border-radius values — pick from the defined scale
- Don't duplicate component patterns — check Section 4 first
- Don't use backdrop-blur or blur effects

### Anti-Patterns (detected from codebase)

- No blur or backdrop-blur effects
- No zebra striping on tables/lists


---

## 9. Responsive Behavior

| Name | Value | Source |
|---|---|---|
| xs | 25rem | css |
| sm | 31.25rem | css |
| sm | 37.5rem | css |
| md | 48rem | css |
| lg | 51.3125rem | css |
| lg | 56.25rem | css |
| lg | 62.5rem | css |
| xl | 68.75rem | css |
| xl | 70rem | css |
| xl | 72.5rem | css |
| xl | 75rem | css |
| 2xl | 87.5rem | css |
| 2xl | 106.25rem | css |
| xs | 300px | css |
| xs | 395px | css |
| xs | 400px | css |
| xs | 480px | css |
| sm | 500px | css |
| sm | 520px | css |
| sm | 560px | css |
| sm | 600px | css |
| sm | 640px | css |
| md | 650px | css |
| md | 670px | css |
| md | 678px | css |
| md | 700px | css |
| md | 760px | css |
| md | 768px | css |
| lg | 820px | css |
| lg | 860px | css |
| lg | 900px | css |
| lg | 901px | css |
| lg | 968px | css |
| lg | 980px | css |
| lg | 981px | css |
| lg | 991px | css |
| lg | 1000px | css |
| lg | 1024px | css |
| xl | 1025px | css |
| xl | 1080px | css |
| xl | 1081px | css |
| xl | 1100px | css |
| xl | 1119px | css |
| xl | 1160px | css |
| xl | 1180px | css |
| xl | 1200px | css |
| xl | 1250px | css |
| 2xl | 1400px | css |
| 2xl | 1440px | css |

**Approach:** Use `@media (min-width: ...)` queries matching the breakpoints above.


---

## 10. Agent Prompt Guide

Use these as starting points when building new UI:

### Build a Card

```
Background: #f1f3fb
Border: 1px solid #1d1e20
Radius: 24px
Padding: 16px
Font: Plus Jakarta Sans
Use shadow tokens from Section 6.
```

### Build a Button

```
Primary: bg var(--accent), text white
Ghost: bg transparent, border #1d1e20
Padding: 8px 16px
Radius: 24px
Hover: opacity 0.9 or lighter shade
Focus: ring with var(--accent)
```

### Build a Page Layout

```
Background: #ffffff
Max-width: 1200px, centered
Grid: 4px base
Responsive: mobile-first, breakpoints from Section 9
```

### Build a Stats Card

```
Surface: #f1f3fb
Label: #646464 (muted, 12px, uppercase)
Value: #030303 (primary, 24-32px, bold)
Status: use success/warning/danger from Section 2
```

### Build a Form

```
Input bg: #ffffff
Input border: 1px solid #1d1e20
Focus: border-color var(--accent)
Label: #646464 12px
Spacing: 16px between fields
Radius: 24px
```

### General Component

```
1. Read DESIGN.md Sections 2-6 for tokens
2. Colors: only from palette
3. Font: Plus Jakarta Sans, type scale from Section 3
4. Spacing: 4px grid
5. Components: match patterns from Section 4
6. Elevation: shadow tokens
```
