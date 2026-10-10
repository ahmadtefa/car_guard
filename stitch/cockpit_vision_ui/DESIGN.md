---
name: Cockpit Vision UI
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#c3c6d7'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#8d90a0'
  outline-variant: '#434655'
  surface-tint: '#b4c5ff'
  primary: '#b4c5ff'
  on-primary: '#002a78'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#0053db'
  secondary: '#a2e7ff'
  on-secondary: '#003642'
  secondary-container: '#00d2fd'
  on-secondary-container: '#005669'
  tertiary: '#00e479'
  on-tertiary: '#003919'
  tertiary-container: '#007e40'
  on-tertiary-container: '#c1ffcc'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#b4ebff'
  secondary-fixed-dim: '#3cd7ff'
  on-secondary-fixed: '#001f27'
  on-secondary-fixed-variant: '#004e5f'
  tertiary-fixed: '#60ff99'
  tertiary-fixed-dim: '#00e479'
  on-tertiary-fixed: '#00210c'
  on-tertiary-fixed-variant: '#005228'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-hud:
    fontFamily: Space Mono
    fontSize: 56px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.02em
  display-hud-mobile:
    fontFamily: Space Mono
    fontSize: 38px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  metric-lg:
    fontFamily: Space Mono
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 32px
  metric-md:
    fontFamily: Space Mono
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
  body-lg:
    fontFamily: Chivo
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Chivo
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Space Mono
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.08em
  label-sm:
    fontFamily: Chivo
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style

This design system establishes a high-performance, critical-telemetry automotive interface designed for vehicle cockpit displays, Android Automotive OS consoles, and connected companion tablets. Built to bridge ESP8266 IoT sensor streams with immediate human comprehension, the aesthetic fuses precision industrial instrumentation with high-tech glassmorphism and luminous telemetry accents.

### Core Philosophy
- **Glanceability Under Cognitive Load:** Drivers and vehicle operators require microsecond visual parsing. Vital telemetry (voltages, temperatures, sensor links, and alarm triggers) takes strict precedence over decorative flourishes.
- **Safety-Critical Hierarchy:** Neon safety indicators operate on an absolute visual hierarchy. Critical alarms puncture through quiescent status readouts instantly.
- **Hardware-Connected Tactility:** Interfaces mirror the precision of mechanical automotive dials reimagined as illuminated digital avionics, using dark light-absorbent backdrops to prevent cabin glare during nighttime transit while retaining daylight legibility.

### Design Style: Modern Cockpit Glass & Illuminated Cybernetics
The UI avoids flat, lifeless enterprise styling in favor of deep-tinted surfaces layered with subtle micro-borders, low-diffusion ambient back-glows for active readings, translucent floating HUD toolbars, and pill-shaped quick-toggle actions. Bilingual typography balances Latin metrics and tabular numbers alongside Arabic script seamlessly across left-to-right and right-to-left mirror modes.

## Colors

The palette is tuned specifically for automotive safety, anti-fatigue low-lux cabin environments, and immediate glanceable alert recognition.

### Color Archetypes & Roles
- **Primary Blue (`#2563EB`):** Foundational automotive system interactions, focused states, primary action triggers, and primary hardware connectivity anchors.
- **Neon Cyan (`#00D4FF`):** Secondary instrument accent; live network telemetry streams, Wi-Fi/ESP8266 handshake status, active telemetry pings, and dynamic radar/radar-proximity vectors.
- **Neon Green (`#00FF88`):** Nominal telemetry indicators, battery voltage thresholds in safe operating zones, active relay latches, and nominal sensor health.
- **Neon Red (`#FF2244`):** Urgent safety triggers, critical engine/sensor heat thresholds, ESP8266 disconnection alarms, and intrusion perimeter alerts.
- **Neon Amber (`#FFAA00`):** Approaching temperature ceilings, low voltage warnings, degraded sensor signal strength.
- **Neon Magenta (`#FF00FF`):** Specialized auxiliary loops, perimeter proximity zones, and custom user-defined override triggers.

### Surfaces & Background Matrix
- **HUD Background (`#040406`):** Pure light-trap foundation used for projection heads-up displays and high-contrast ambient display cutouts.
- **Automotive Canvas (`#0F172A`):** Deep atmospheric slate base for the standard nocturnal cockpit view.
- **Card Surface (`#10151D`):** Subtle elevated chassis surface offering high contrast separation without screen backlight bleed.
- **Daylight Surface (`#F8FAFC`):** Daytime mode alternative providing anti-reflective contrast under intense ambient sunlight.

### Functional Status Tokens
- **Success (`#16A34A`):** Standard compliance confirmations and saved parameters.
- **Warning (`#F59E0B`):** System alerts requiring servicing or attention post-drive.
- **Danger (`#DC2626`):** Immediate hardware lockout or hazard indicators.

## Typography

Automotive readability demands zero typographic ambiguity between similar glyphs (e.g., `8`, `B`, `0`, `O`). 

### Font Choices
- **Headlines & Structural Titles (`Space Grotesk`):** Engineered geometric grotesque with pronounced apertures, ensuring distinct structural presence on sweeping automotive clusters.
- **Continuous Reading & System Feedback (`Chivo`):** High-efficiency neo-grotesque that remains crisp across varying display angles and anti-glare screen coatings.
- **Instrumentation & Telemetry Metrics (`Space Mono`):** Fixed-pitch tabular rendering guarantees that fluctuating numerical data (voltage ticks, temperature shifts, km/h reads) do not cause horizontal layout jitter.

### Multilingual & RTL Implementation
Arabic interface mirrors maintain the exact numerical hierarchy. In Arabic viewports, metrics remain formatted in western tabular numerals for standard OBD-II/ESP8266 compatibility, while contextual labels render in bold, open-counter Arabic type scaled +10% over Latin body tokens to preserve visual density.

## Layout & Spacing

The layout is built upon a 4px mechanical base unit (`4`, `8`, `12`, `16`, `24`, `32px`) translated to rem equivalents for proportional fluid rendering across varying cockpit display aspect ratios (16:9, 21:9 ultra-wide consoles, and portrait clusters).

### Grid Strategy
- **Center-Console Landscape & Widescreen (12 Columns):** Primary flight-deck view splits into a 3-column quick-telemetry telemetry rail, a 6-column main interactive gauge cluster, and a 3-column auxiliary status log.
- **Companion Portrait Mobile (4 Columns):** Telemetry flows in stacked priority modules with fixed minimum thumb-target heights (minimum 48px tactile tap targets).
- **HUD Mode (Zero Grid / Relative Anchors):** Peripheral edge pinning designed with a minimum 32px (`space-2xl`) safe zone from cockpit display bezels to prevent physical hardware occlusion.

### Gaps & Padding
Component padding strictly uses the defined scale:
- `space-xs` (4px): Micro-spacers between tabular units and measurement units (e.g., `13.8` and `V`).
- `space-sm` (8px): Internal chip padding, compact status badges.
- `space-md` (12px): Standard button vertical padding, metric tile separation.
- `space-lg` (16px): Standard internal card padding, cluster module gaps.
- `space-xl` (24px): Primary card separation, module section dividers.
- `space-2xl` (32px): Cockpit edge boundaries and outer canvas safe margins.

## Elevation & Depth

Visual hierarchy does not use simulated drop shadows, which wash out on low-nit night screens. Instead, depth is constructed via **chromatic luminescence, translucent layering, and surface tint tiers**.

### Surface Hierarchy
1. **Chassis Zero (`#040406` - HUD Base):** Absolute ground plane; unlit OLED black minimizing cockpit light spillage.
2. **Cockpit Deck (`#0F172A`):** Foundational viewport canvas.
3. **Telemetry Tiles (`#10151D` with 1px border `rgba(255, 255, 255, 0.06)`): Primary content enclosures.
4. **Active/Armed Cards:** Telemetry tiles elevated through low-intensity perimeter glow corresponding to status:
   - Nominal state: `0 0 20px rgba(0, 212, 255, 0.15)`
   - Safe/Armed state: `0 0 24px rgba(0, 255, 136, 0.20)`
   - Alert state: `0 0 32px rgba(255, 34, 68, 0.35)`
5. **Translucent Floating Controls:** Background tint of `rgba(16, 21, 29, 0.75)` backed by an `8px` to `16px` backdrop filter blur with high-contrast edge strokes `rgba(255, 255, 255, 0.15)`.

## Shapes

The design uses sculpted automotive geometry: robust corner radii for information surfaces, juxtaposed with smooth continuous pill capsules for interactive controls.

### Radius Assignments
- **Telemetry & Gauge Cards:** Standard 16px radius for compact dashboard tiles; expanded 24px to 28px radius for prominent cockpit cluster modules.
- **Floating Controls & Quick Switches:** Fully rounded pill capsules (`9999px` / `rounded-full`) to guarantee tactile affordance and clear differentiation from informational cards.
- **Data Badges & Micro Metrics:** 8px radius (`space-sm`) to preserve internal rectangular density for numbers.

## Components

### Buttons & Quick Switches
- **Pill Actuators:** Minimum 48px height for finger-swipe reliability while vehicle is stationary. Primary variant uses `#2563EB` fill with stark white typography. Secondary variant uses translucent dark fill `rgba(16, 21, 29, 0.8)` with `#00D4FF` 1px border.
- **Hardware Trigger Switches (Relay Toggles):** Heavy-duty pill toggles. When active, thumb handles transition from neutral slate to Neon Green (`#00FF88`) accompanied by a diffuse ambient glow.

### Telemetry Gauge Cards
- Composed on Card Surface (`#10151D`) with corner radii set between 16px and 28px.
- Top slot contains `label-caps` in muted slate (`#64748B`), right slot houses an animated ESP8266 heartbeat ping dot, center contains massive tabular `metric-lg` value, and bottom slot holds a micro progress bar or dynamic arc.

### Chips & Sensor Status Pills
- Compact status capsules displaying Wi-Fi RSSI, ESP8266 packet loss, and live IP connectivity.
- Background: `rgba(255, 255, 255, 0.04)`; border: 1px solid corresponding status color (Cyan for idle, Green for verified link, Red for drop).

### Translucent Floating Toolbars
- Docked at cluster bottom or cluster lateral edge.
- Glassmorphic treatment: `rgba(16, 21, 29, 0.8)` background, `backdrop-filter: blur(12px)`, containing pill action buttons with `space-sm` internal separation.

### Input Fields & Parameter Tuning
- Dark inset surfaces (`#040406`) with 12px border radius.
- Inactive border: `rgba(255, 255, 255, 0.1)`; active/editing border: `#00D4FF` with tabular numeric entry optimization.

### RTL / Arabic Cockpit Adaptation
- Toolbars, back buttons, and hierarchical progress tracks swap axes without displacing tabular sensor numbers.
- Gauge arcs mirror sweep angles (clockwise vs. counter-clockwise) while preserving standard engineering unit formats.