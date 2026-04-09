# Mouseplate

Mouseplate is a Flutter app that helps guests estimate whether a Disney-style dining plan is “worth it” for their specific trip, while also providing a simple way to plan meals and log dining usage during the vacation.

This repo currently runs **without any backend** (all data is stored locally on-device). If/when you want Firebase or Supabase, use the **Firebase** / **Supabase** panel in Dreamflow to set it up.

---

## Tech stack

- **Flutter (Material 3)** + **Dart**
- **Navigation:** `go_router` (use `context.go / context.push / context.pop`)
- **State management:** `provider` + `ChangeNotifier` (`AppController`)
- **Persistence (Phase 1):** `shared_preferences` via `LocalStorageService` (local-first, on-device)
- **Platforms:** Android / iOS / Web (Dreamflow runs with CanvasKit)

---

## Architecture (Phase 1: local-first)

The app is intentionally structured so Phase 1 stays simple (no backend), while Phase 2+ can swap persistence/auth without rewriting UI.

- **UI layer**: `lib/pages/*` and `lib/widgets/*`
  - Pages own layout and user interactions.
  - Reusable UI pieces live under `widgets/`.
- **Controller layer**: `lib/controllers/app_controller.dart`
  - Single source of truth for the current trip, usage log, premium flag, and derived totals.
  - Exposes commands (save trip, log usage, consume planned meal, etc.) and notifies listeners.
- **Domain models**: `lib/models/*`
  - `Trip`, `PlannedMeal`, `UsageEntry`, `AppUser`
  - JSON serialization (`toJson/fromJson`) + immutable updates (`copyWith`).
- **Services (data access)**: `lib/services/local_storage_service.dart`
  - Reads/writes models to local storage.
  - This is the main seam for future Firebase/Supabase integration.
- **Routing**: `lib/nav.dart` + `go_router`
  - Centralized route table (avoid `Navigator.push`).

## Current feature list (Phase 1)

### Trip setup
- **Pre-onboarding choice screen**: choose how to set up a trip
  - Manual setup (Free)
  - AI Concierge (Premium) — visible but paywalled / placeholder for Phase 2
- **5-step Trip Onboarder** (manual wizard) modeled after the referenced calculator’s step structure:
  1. Describe your vacation plans (party + dates + AP/DVC)
  2. Customize dining experience (habits/preferences)
  3. Restaurants / meals per day planning
  4. Cost & plan comparison inputs
  5. Review & confirm summary

### Planning + tracking
- **Dashboard**: quick snapshot of trip and estimated value (depending on entered data)
- **Food logger**: create and manage planned meals and record usage entries
- **Credit / usage tracking**: track how many meals/snacks are planned vs used
- **Tips page** and **Settings** (basic)

### Data & architecture
- Local-first persistence via a local storage service
- Models for Trip, PlannedMeal, UsageEntry, and AppUser

---

## Example complete user flow (family of 4)

Below is an end-to-end flow that a typical family might take.

### Scenario
- Party: **2 adults + 2 kids**
- Dates: **Apr 4 → Apr 10** (6 nights / 7 days)
- Staying on-site: Yes
- Annual Passholder: No
- DVC: No
- Goal: figure out whether a dining plan makes sense, then build a meal plan and log what they actually used.

### Flow
1. **Welcome** → tap **“Set up a trip”**
2. **Trip Setup Method** (`/setup`)
   - Choose **Manual setup (Free)**
   - (AI Concierge is visible but locked behind Premium)
3. **Trip Onboarder** (`/setup/manual`)
   - **Step 1: Vacation plans**
     - Enter party (2 adults, 2 kids)
     - Select dates (Apr 4–10)
     - Confirm AP/DVC = off
   - **Step 2: Dining preferences**
     - Choose preferences like snacks/day, beverage assumptions, dessert, refillable mug, etc.
   - **Step 3: Plan meals**
     - Pick how many breakfasts/lunches/dinners they expect across the trip
     - Add any “must-do” meals (character breakfast, signature dinner, etc.) as planned meals
   - **Step 4: Costs & comparisons**
     - Enter/confirm plan pricing assumptions (as provided by you)
     - Add any discounts that apply (none in this scenario)
   - **Step 5: Review & confirm**
     - Review the summary
     - Confirm to create the trip and initialize the meal logger plan
4. **Dashboard** (`/dashboard`)
   - See a high-level “worth it” snapshot and trip overview
5. **Log meals during the trip** (`/log`)
   - Each day, open the logger and mark meals as used (or add ad-hoc meals)
   - The app updates usage totals as they go
6. **Post-trip**
   - Review what was planned vs what was actually used
   - Adjust assumptions for next trip (repeat-customer workflow)

---

## TODO (living checklist)

### Phase 1 (manual-first, no AI)
- [ ] Finalize the exact input fields/rules to match the target calculator behavior
- [ ] Add importable data format for **restaurant names** and **price estimates** (JSON)
- [ ] Implement robust “worth it” calculation using the manually provided price dataset
- [ ] Improve “Review & confirm” summary to show all assumptions clearly
- [ ] Add validation + better empty states (no trip, no planned meals, etc.)

### Phase 2 (Premium: AI Concierge)
- [ ] Add Premium “concierge” chat to collect trip details from natural language
- [ ] AI asks follow-up questions until required fields are complete
- [ ] AI generates a draft onboarding summary + initial planned meal list
- [ ] User can edit the summary before saving (human-in-the-loop)

### Nice-to-haves
- [ ] Multiple trips support + switching between trips
- [ ] Better reporting (per-day spend, per-person breakdown, planned vs actual graphs)
- [ ] Export/share trip summary (PDF / link)

---

## Compliance / data note
This app should **not claim to scrape** proprietary pricing data. Menu prices change frequently and should be provided by the app owner (you) via a maintained dataset.
