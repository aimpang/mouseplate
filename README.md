# Mouseplate — Disney Dining Plan Calculator & Trip Logger

Mouseplate is a Flutter app that helps Disney World guests determine whether a dining plan is "worth it" for their trip, then plan and log meals during their vacation. It compares the cost of dining plans (Quick-Service, Standard) against estimated out-of-pocket spending, and tracks credit usage in real time.

**Status:** Phase 1 complete with full local-first persistence. No backend required.

---

## Features

### 🎯 Trip Planning

- **6-step onboarding wizard** to gather trip details:
  1. Vacation dates, party size (adults/children), and discounts (AP/DVC)
  2. Per-person dining profiles (eating style, snacks, dessert preferences, alcohol)
  3. Parks you're visiting (filters signature dining options)
  4. Signature Dining meal selection (2-credit restaurants)
  5. Dining plan vs. cash-out-of-pocket recommendation
  6. Review & confirm summary

- **Dining plan options:**
  - **Quick-Service Plan:** 2 QS meals + 1 snack per person per day
  - **Disney Dining Plan (Standard):** 1 QS + 1 Table-Service + 1 snack per person per day
  - **Pay Cash (no plan):** Log meals without credit constraints

- **Signature Dining tracking:** Pre-select restaurants and dates; they appear in the logging interface

### 📊 Dashboard

- **Real-time credit summary:** See total, used, and remaining credits per category (QS / TS / Snacks)
- **Worth It? analysis:** Compare plan cost vs. estimated out-of-pocket value
- **Per-person breakdown:** See dining style and preferences for each party member
- **Day-by-day pacing:** Get tips on meal consumption rate relative to trip length

### 📝 Meal Logging

- **Planned meals:** Marked meals appear as a card on the Log page; tap "Eat" to move them to history
- **Quick-log buttons:** Fast entry for QS, Table-Service, or Snacks
- **Restaurant picker:** Autofill meal estimates when you log from the restaurant catalog
- **Cash mode:** In "pay cash" mode, log meals freely (no credit limits)
- **Optional details:** Record restaurant name, estimated value, and custom notes

### 🧾 PDF Export

- Generate and share a full trip summary including:
  - Trip snapshot (dates, party, plan type, discounts)
  - Party member profiles (name, eating style, snacks/day, dessert & alcohol preferences)
  - Credit totals (QS / TS / Snacks with used/remaining)
  - "Worth It?" breakdown (plan cost vs. cash value vs. savings)
  - Planned meals (by date and slot)
  - Full usage history (timestamps, values, notes)

---

## Architecture

### Tech Stack

- **Framework:** Flutter + Dart (Material 3 design)
- **Navigation:** `go_router` (centralized routing)
- **State Management:** Provider + `ChangeNotifier` (AppController)
- **Storage:** `shared_preferences` via LocalStorageService (local-first)
- **Platforms:** Android / iOS / Web
- **PDF Export:** `pdf` + `printing` packages

### Codebase Structure

```
lib/
├── pages/              # Full-screen UI (onboarding, dashboard, log, settings)
├── widgets/            # Reusable components (app shell, restaurant picker)
├── controllers/        # AppController (single source of truth)
├── models/             # Trip, UsageEntry, PlannedMeal, PartyMember
├── services/           # LocalStorageService (data persistence)
├── data/               # WdwRestaurantCatalog (hardcoded restaurant data)
├── theme.dart          # Material 3 colors + typography
└── nav.dart            # GoRouter configuration
```

### Key Models

- **Trip:** Immutable; stores party size, dates, dining plan choice, party members, planned meals, assumptions
- **PartyMember:** Individual guest profile (name, eating style, snacks/day, dessert & alcohol preferences)
- **PlannedMeal:** Scheduled restaurant visit (date, type, credits, estimated value)
- **UsageEntry:** Logged meal (type, timestamp, restaurant/note, value, credits)

### Single Source of Truth

`AppController` in `lib/controllers/app_controller.dart` owns:
- Current trip
- Usage log
- Computed totals (used/remaining credits, worth-it analysis)
- Premium flag & onboarding status

All UI listens via `Provider.watch<AppController>()`.

---

## Complete User Flow Example

### Scenario
**Family of 2 adults + 2 kids visiting Apr 4–10 (6 nights)**
- No AP/DVC discounts
- Moderate eaters
- Interested in signature dining
- Want to know: is the Standard plan worth it?

### Step-by-Step

1. **Launch app** → Welcome page
   - No existing trip data
   - Tap **"Set up a trip"**

2. **Trip Setup Method** (`/setup`)
   - Choose **"Manual setup (Free)"**
   - (AI Concierge option is visible but locked)

3. **Step 1: Vacation Plans** (`/setup/manual` step 0)
   - Adults: `2`
   - Children: `2`
   - Check-in: `Apr 4`
   - Check-out: `Apr 10` (calculates 6 nights)
   - Discounts: Off
   - Tap **Continue**

4. **Step 2: Meet Your Party** (step 1)
   - App auto-creates 2 adult + 2 child profiles
   - Edit each person:
     - Adult 1: "Mom" → Park Explorer (1.0x) → 1 snack/day, dessert at TS, enjoys alcohol
     - Adult 2: "Dad" → Park Explorer (1.0x) → 1 snack/day, no dessert, no alcohol
     - Child 1: "Emma" → Little Nibbler (0.8x) → 0 snacks/day
     - Child 2: "Liam" → Park Explorer (1.0x) → 1 snack/day, dessert at TS
   - Tap **Continue**

5. **Step 3: Parks You're Visiting** (step 2)
   - All 4 parks pre-selected
   - Deselect one if desired
   - Tap **Continue**

6. **Step 4: Signature Dining** (step 3)
   - App shows signature restaurants by park
   - Select 2–3 meals (e.g., "Be Our Guest" for Mom & Dad on day 2, "Chef Mickey's" breakfast day 3)
   - Tap **Continue**

7. **Step 5: Choose Your Dining Option** (step 4)
   - App calculates:
     - **Out of Pocket:** ~$425 (meals + snacks for 6 nights)
     - **Quick-Service Plan:** $1,291.68 (2 adults × $60.47 × 6 nights + 2 kids × $47.17 × 6 nights)
     - **Standard Plan:** $2,105.76 (2 adults × $98.59 × 6 nights + 2 kids × $76.89 × 6 nights)
   - Recommendation: **Out of Pocket** (cheapest)
   - But family wants signature dining → choose **Standard Plan** anyway (for access to Be Our Guest)
   - Tap **Continue**

8. **Step 6: Review & Confirm** (step 5)
   - See snapshot: 2 adults, 2 kids, Apr 4–10, Standard Plan
   - Party members listed with eating styles
   - Signature dining choices shown
   - Tap **Save Trip**

9. **Dashboard** (`/app/dashboard`)
   - Credit summary shows:
     - **QS:** 24 total (2 adults × 1 × 6 nights, 2 kids × 1 × 6 nights)
     - **TS:** 24 total (2 adults × 1 × 6 nights, 2 kids × 1 × 6 nights)
     - **Snacks:** 24 total (4 people × 1 × 6 nights)
   - "Worth It?" card: Plan costs $2,105.76, estimated cash value is ~$425. **Net cost: $1,680.76 but includes signature dining access.**
   - Tip: "You have 24 TS credits — don't miss those table-service meals!"

10. **First day — Log page** (`/app/logs`)
    - **Planned meals card** shows:
      - Dinner: "Be Our Guest" (TS) — tap **Eat**
    - Credits update: **TS: 23 remaining**
    - Quick-log buttons for ad-hoc meals
    - History shows the BEG entry

11. **Throughout trip**
    - Log QS meals, snacks, and TS meals as they happen
    - Dashboard updates in real time
    - When TS credits run low, app warns: "You're low on TS credits!"

12. **Post-trip**
    - Export PDF to compare plan value vs. actual spending
    - Adjust assumptions for next trip (e.g., "kids eat less" → try QS plan next time)

---

## Installation & Running

### Prerequisites
- Flutter 3.6+
- Dart 3.6+

### Setup
```bash
cd mouseplate
flutter pub get
flutter run
```

### Running on Web (Dreamflow / CanvasKit)
```bash
flutter run -d web
```

---

## Recent Fixes & Improvements (Session Summary)

### Bug Fixes
1. **Snack price mismatch** — Onboarder used $7/snack vs Trip model's $9/snack → Fixed to $9 everywhere
2. **Child signature dining pricing** — Used `60 × 0.6 = $36` vs Trip's `$28` → Fixed to use consistent child TS value
3. **Planned meal credit loss** — Signature dining created TS planned meals on QS plans (no TS credits) → Now only create when plan includes TS
4. **Onboarding reset on edit** — Jumping back from review and continuing lost all customizations → Fixed by preserving drafts when jumping back
5. **Unused variables & imports** — Cleaned up linter warnings

### Features Completed
- **Per-person party profiles** in onboarding (name, eating style, snacks/day, dessert & alcohol)
- **Signature Dining cost estimation** (2-credit restaurants)
- **Cash mode** dashboard variant (no credit counters, shows dining budget instead)
- **PDF export** with full trip summary, party breakdown, and usage history
- **Step consolidation** — Removed redundant "Explore other options" step (6 steps now, was 7)

---

## Roadmap (Phase 2+)

- [ ] **Premium AI Concierge:** Natural language trip setup via chat
- [ ] **Multiple trips:** Save and switch between different trip plans
- [ ] **Advanced analytics:** Per-day spend, per-person breakdown, planned vs. actual charts
- [ ] **Dining preference templates:** Save and reuse party profiles
- [ ] **Restaurant sync:** Auto-update restaurant catalog and pricing
- [ ] **Cloud sync:** (Optional) Backup trips to Firebase/Supabase

---

## Notes

- **No backend required (Phase 1):** All data is stored locally on device
- **Restaurant data:** Hardcoded in `lib/data/wdw_restaurant_catalog.dart` — update manually or via JSON import
- **Pricing data:** Defaults are 2026 Disney Dining Plan prices; customizable per trip on the dashboard
- **Export format:** PDF uses `pdf` package with Material 3 styling
- **Offline-first:** Works completely without network access

---

## License & Disclaimer

This app is **not affiliated with The Walt Disney Company.** It's a fan-made planning tool. Always verify current prices and policies on the official Disney World website.
