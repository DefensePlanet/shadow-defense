# Shadow Defense — Soft Launch Plan (#200)

## Overview
Staged geographic rollout to validate retention, monetization, and stability before global launch. Each phase gates on KPIs — if targets are missed, fix and re-test before advancing.

---

## Phase 1: Canada + Australia (2 Weeks)
**Goal:** Validate core loop retention and technical stability

### Markets
- **Canada** — English-speaking, iOS/Android split similar to US, moderate competition
- **Australia** — English-speaking, high ARPU market, timezone diversity for server load testing

### KPIs (Gate to Phase 2)
| Metric | Target | Red Flag |
|--------|--------|----------|
| D1 Retention | > 40% | < 30% |
| D7 Retention | > 20% | < 12% |
| Crash Rate | < 1% | > 2% |
| Tutorial Completion | > 80% | < 60% |
| Avg Session Length | > 6 min | < 3 min |
| ANR Rate (Android) | < 0.5% | > 1% |

### Focus Areas
- Crash/ANR monitoring (Firebase Crashlytics)
- Tutorial funnel drop-off analysis
- Act 1 completion rate (target: > 60% of players who finish tutorial)
- Device/OS compatibility matrix (minimum: iPhone 8+, Android 8.0+)
- Network error rates and retry success

### Actions if KPIs Missed
- D1 < 30%: Redesign tutorial, add skip option, review first 3 levels for frustration points
- Crash > 2%: Hotfix cycle, delay Phase 2 until < 1%
- Tutorial < 60%: A/B test simplified tutorial vs current

---

## Phase 2: UK + Germany (2 Weeks)
**Goal:** Validate monetization and localization readiness

### Markets
- **UK** — Largest European English market, strong mobile gaming spend
- **Germany** — Largest European market by population, tests German localization

### KPIs (Gate to Global)
| Metric | Target | Red Flag |
|--------|--------|----------|
| ARPU (Day 7) | > $0.50 | < $0.20 |
| Avg Session Length | > 8 min | < 5 min |
| IAP Conversion | > 3% | < 1% |
| Ad Revenue per DAU | > $0.05 | < $0.02 |
| D14 Retention | > 12% | < 7% |
| Localization Bugs | < 5 reported | > 20 reported |

### Focus Areas
- Rewarded ad opt-in rate and frequency tuning
- IAP price point testing (starter pack, gem bundles)
- German text overflow/truncation issues
- GDPR consent flow completion rate
- Age gate (COPPA) flow on first launch
- Server response times from EU

### Actions if KPIs Missed
- ARPU < $0.20: Revise IAP pricing, add value bundles, test ad frequency
- Session < 5 min: Analyze where players quit, add engagement hooks (daily rewards, streaks)
- Localization > 20 bugs: Delay global, fix all UI overflow, re-test RTL readiness

---

## Phase 3: Global Launch
**Goal:** Full worldwide release with marketing support

### Timeline
- **Soft launch start:** Target July 2026
- **Phase 1 complete:** +2 weeks (mid-July)
- **Phase 2 complete:** +2 weeks (early August)
- **Global launch:** Mid-August 2026 (if all gates pass)

### Launch Markets
- All App Store / Google Play territories
- Priority localization: English, German, French, Spanish, Portuguese, Japanese, Korean
- Secondary (post-launch): Chinese (Simplified), Russian, Italian

### Marketing Plan
- **ASO Optimization:** Keywords, screenshots, preview video optimized per locale
- **Launch Trailer:** 30-second cinematic + 60-second gameplay trailer
- **Press Kit:** Presskit.html with assets, fact sheet, developer story
- **Influencer Outreach:** 20 mobile gaming YouTubers/TikTokers (micro to mid-tier)
- **Social Media:** Launch day countdown, character reveal series, community contests
- **App Store Feature Request:** Submit 6 weeks before launch with creative assets

### Day-1 Live Ops
- Welcome event: double XP for first 48 hours
- Daily login calendar: 14-day rewards including exclusive "Launch Day" Robin Hood skin
- Community milestone: "1 million enemies defeated globally" unlocks reward for all players

---

## Rollback Plan

### Phase 1 Rollback Triggers
- Crash rate > 5% sustained for 24 hours
- Data loss reports from > 0.1% of players
- Critical exploit discovered (gold/gem duplication)

### Phase 2 Rollback Triggers
- Revenue per install negative ROI with projected ad spend
- Regulatory issue (GDPR violation, age gate failure)
- Widespread negative reviews (< 3.0 stars average)

### Rollback Procedure
1. Disable new installs via App Store/Google Play (unpublish from expansion markets)
2. Push remote config: `maintenance_mode = true` with player-facing message
3. Hotfix within 48 hours or revert to last stable build
4. Post-mortem within 1 week, revised timeline within 2 weeks
5. Re-launch expansion market after fix verified in original markets

### Emergency Contacts
- App Store Connect: [configured in Fastlane]
- Google Play Console: [configured in Fastlane]
- Firebase: Real-time crash dashboard + Slack alerts
- On-call: Primary (John) + Secondary (automated monitoring)

---

## Infrastructure Checklist
- [ ] Firebase Crashlytics configured (iOS + Android)
- [ ] Firebase Analytics events for all funnel steps
- [ ] Remote config server with default values loaded
- [ ] AdMob mediation configured (IronSource fallback)
- [ ] GDPR consent SDK integrated (Google UMP)
- [ ] Age gate flow tested on fresh install
- [ ] Save system backup/restore tested across app updates
- [ ] Anti-cheat checksum system active
- [ ] Deep link URL scheme registered (shadowdefense://)
- [ ] App Store / Google Play listings drafted per market
