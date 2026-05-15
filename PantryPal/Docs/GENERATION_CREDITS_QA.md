# Generation credits — manual QA

Reference caps: **Free** = `TRIAL_MAX_INTERACTIONS` per rolling 7-day window from anchor (`AppConfig.trialMaxInteractions`). **Pro** = `PRO_MAX_INTERACTIONS` per RevenueCat subscription period (`AppConfig.proMaxInteractions`).

| Case | Steps | Expected |
|------|--------|----------|
| Fresh install (free) | Open app, check header | Coin + `N/N` with N = plist free cap |
| Free — pantry generate | Use “Generate recipes” until success | Count decreases by 1 after **successful** API only |
| Free — cookbook scan | Scan cookbook pages, success | −1 credit |
| Free — web scan | Import from URL, success | −1 credit |
| Free — out of credits | Tap generate / scan with 0 credits | Generation limit sheet (no “Resets in” / “Remind me”) |
| Free — header coin | Tap coin | Same sheet; CTA opens Pro paywall |
| Free — ingredient scan | Photo scan pantry | **No** credit use |
| Free — recipe image | Generate image on recipe | **No** credit use |
| Free — modify recipe | Open modify flow | Blocked; **upgrade** paywall (not trial copy) |
| Week rollover | Advance device date / wait 7 days from anchor | Free used count resets; header full again |
| Pro subscriber | Subscribe / restore | Header shows **Pro** + yellow crown; Customer Center on crown tap |
| Pro — cap | Exhaust `PRO_MAX_INTERACTIONS` | Sheet shows monthly wording; successful actions still blocked at VM until period rolls |
| Pro period change | RC entitlement `expirationDate` changes | `proUsed` resets (see `generation_period_reset` analytics) |
| Failed API | Trigger network/API error on generate | **No** `consumeGenerationCredit`; analytics `generation_credit_consumed` not fired |
| Home | Open Home | No trial banner, no subscription promo card |
| Onboarding | Complete onboarding | Copy mentions weekly free generations, not 7-day trial |

### Analytics (Firebase)

- `generation_credit_consumed` — after successful pantry/cookbook/web generation
- `generation_limit_sheet_shown` — sheet presented (header tap or blocked flow)
- `generation_period_reset` — tier `free` (week index) or `pro` (period key)
- `paywall_triggered` — `reason: modify_pro_required` when free user hits modify
