TODO
- Before release: set `AppPreferences.debugDefaultUpsellValue` to `false` (or remove the dev-only upsell override) so celebration/paywall only show once.
- Before release: set `AppPreferences.debugDefaultOnboardingValue` to `false` (or remove the dev-only onboarding override) so onboarding only shows once.
- Implement StoreKit purchase flow for “Get offer” in discount paywall (close paywall on success, update entitlement, add restore purchases and receipt validation).
- Wire Pro paywall plan selection CTA to StoreKit purchase (yearly/monthly/lifetime) and persist subscription state.
