# Source map for the selected-theme redesign

Baseline: `1dc9188e212ab217393e055b4c238b18c72521ae`. Source associations only; not a runtime reachability or full-code audit.

**98 screen declarations**: 91 registered-screen associations, 5 root/activity surfaces, 2 legacy/unmounted. **92 route registrations** include one legacy redirect. Shared role variants and modal surfaces add design states, not extra declarations.

Every row is **planned / not implemented / not integrated / native verification not run** for the selected theme. The JSON carries separate status fields and full source SHA-256 values. Registered does not mean exposed by a current role menu or authorized for every account.

Link each page to its dedicated design row and the common [state contract](../UI_THEME_PAGE_PLAN_2026-09-12.md#4-contract-for-every-page-and-overlay). Hospital Home plus the engineer Home variant, shared job detail, DSR and financial sheets must be checked in both relevant roles.

| Page and exact source definition | Navigation association / disposition | Design and batch |
| --- | --- | --- |
| [DevModeBlockingScreen](../../app/src/main/kotlin/com/equipseva/app/core/security/DevModeBlockingScreen.kt#L54) | root/activity entry (MainActivity.kt:83) | [UI-02](../UI_THEME_PAGE_PLAN_2026-09-12.md) |
| [AboutScreen](../../app/src/main/kotlin/com/equipseva/app/features/about/AboutScreen.kt#L52) | `ABOUT` (MainNavGraph.kt:713) | [UI-08](account-pages.md) |
| [ActiveWorkScreen](../../app/src/main/kotlin/com/equipseva/app/features/activework/ActiveWorkScreen.kt#L44) | `ACTIVE_WORK` (MainNavGraph.kt:823) | [UI-06](engineer-pages.md) |
| [AmcDetailScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt#L335) | `AMC_CONTRACT_DETAIL` (MainNavGraph.kt:577) | [UI-09](hospital-pages.md) |
| [CreateAmcWizardScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/CreateAmcWizardScreen.kt#L605) | `CREATE_AMC` (MainNavGraph.kt:596) | [UI-09](hospital-pages.md) |
| [HospitalAmcTierPerksScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/HospitalAmcTierPerksScreen.kt#L90) | `AMC_TIER_PERKS` (MainNavGraph.kt:515) | [UI-09](hospital-pages.md) |
| [HospitalAssetHistoryScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/HospitalAssetHistoryScreen.kt#L125) | `HOSPITAL_ASSET_HISTORY` (MainNavGraph.kt:563) | [UI-09](hospital-pages.md) |
| [HospitalFleetHealthScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/HospitalFleetHealthScreen.kt#L114) | `HOSPITAL_FLEET_HEALTH` (MainNavGraph.kt:555) | [UI-09](hospital-pages.md) |
| [HospitalPmCalendarScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/HospitalPmCalendarScreen.kt#L132) | `HOSPITAL_PM_CALENDAR` (MainNavGraph.kt:520) | [UI-09](hospital-pages.md) |
| [HospitalPortalScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/HospitalPortalScreen.kt#L169) | `HOSPITAL_PORTAL` (MainNavGraph.kt:545) | [UI-09](hospital-pages.md) |
| [MaintenanceContractsScreen](../../app/src/main/kotlin/com/equipseva/app/features/amc/MaintenanceContractsScreen.kt#L204) | `AMC_CONTRACTS_LIST` (MainNavGraph.kt:495) | [UI-09](hospital-pages.md) |
| [ForgotPasswordScreen](../../app/src/main/kotlin/com/equipseva/app/features/auth/ForgotPasswordScreen.kt#L53) | `AUTH_FORGOT_PASSWORD` (AuthNavGraph.kt:57) | [UI-03](account-pages.md) |
| [RoleSelectScreen](../../app/src/main/kotlin/com/equipseva/app/features/auth/RoleSelectScreen.kt#L79) | root/activity entry (AppNavGraph.kt:64) | [UI-03](account-pages.md) |
| [SignInScreen](../../app/src/main/kotlin/com/equipseva/app/features/auth/SignInScreen.kt#L55) | `AUTH_SIGN_IN` (AuthNavGraph.kt:34) | [UI-03](account-pages.md) |
| [SignUpScreen](../../app/src/main/kotlin/com/equipseva/app/features/auth/SignUpScreen.kt#L61) | `AUTH_SIGN_UP` (AuthNavGraph.kt:42) | [UI-03](account-pages.md) |
| [WelcomeScreen](../../app/src/main/kotlin/com/equipseva/app/features/auth/WelcomeScreen.kt#L54) | `AUTH_WELCOME` (AuthNavGraph.kt:28) | [UI-03](account-pages.md) |
| [ChatScreen](../../app/src/main/kotlin/com/equipseva/app/features/chat/ChatScreen.kt#L101) | `CHAT_DETAIL` (MainNavGraph.kt:743) | [UI-08](account-pages.md) |
| [ConversationsScreen](../../app/src/main/kotlin/com/equipseva/app/features/chat/ConversationsScreen.kt#L60) | `CONVERSATIONS` (MainNavGraph.kt:736) | [UI-08](account-pages.md) |
| [EarningsScreen](../../app/src/main/kotlin/com/equipseva/app/features/earnings/EarningsScreen.kt#L67) | `EARNINGS` (MainNavGraph.kt:802) | [UI-07](engineer-pages.md) |
| [EngineerActiveEscrowsScreen](../../app/src/main/kotlin/com/equipseva/app/features/earnings/EngineerActiveEscrowsScreen.kt#L100) | `ENGINEER_ACTIVE_ESCROWS` (MainNavGraph.kt:817) | [UI-07](engineer-pages.md) |
| [EngineerAmcVisitsScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerAmcVisitsScreen.kt#L103) | `ENGINEER_AMC_VISITS` (MainNavGraph.kt:436) | [UI-09](engineer-pages.md) |
| [EngineerDemandSignalsScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerDemandSignalsScreen.kt#L141) | `ENGINEER_DEMAND_SIGNALS` (MainNavGraph.kt:426) | [UI-06](engineer-pages.md) |
| [EngineerEarningsProjectionScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerEarningsProjectionScreen.kt#L91) | `ENGINEER_EARNINGS_PROJECTION` (MainNavGraph.kt:431) | [UI-06](engineer-pages.md) |
| [EngineerGraduationScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerGraduationScreen.kt#L108) | `ENGINEER_GRADUATION` (MainNavGraph.kt:416) | [UI-06](engineer-pages.md) |
| [EngineerJobsHubScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerJobsHubScreen.kt#L143) | `ENGINEER_JOBS_HUB` (MainNavGraph.kt:397) | [UI-06](engineer-pages.md) |
| [EngineerLocationScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerLocationScreen.kt#L39) | `ENGINEER_LOCATION` (MainNavGraph.kt:460) | [UI-06](engineer-pages.md) |
| [EngineerMyDisputesScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerMyDisputesScreen.kt#L104) | `ENGINEER_MY_DISPUTES` (MainNavGraph.kt:452) | [UI-06](engineer-pages.md) |
| [EngineerSupervisionScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerSupervisionScreen.kt#L232) | `ENGINEER_SUPERVISION` (MainNavGraph.kt:421) | [UI-06](engineer-pages.md) |
| [EngineerProfileScreen](../../app/src/main/kotlin/com/equipseva/app/features/engineerprofile/EngineerProfileScreen.kt#L75) | `ENGINEER_PROFILE` (MainNavGraph.kt:920) | [UI-06](engineer-pages.md) |
| [FounderAmcEscalationDetailScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderAmcEscalationDetailScreen.kt#L145) | `FOUNDER_AMC_ESCALATION_DETAIL` (MainNavGraph.kt:1004) | [UI-10](founder-pages.md) |
| [FounderAmcExpiringScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderAmcExpiringScreen.kt#L93) | `FOUNDER_AMC_EXPIRING` (MainNavGraph.kt:1114) | [UI-10](founder-pages.md) |
| [FounderBuyerKycQueueScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderBuyerKycQueueScreen.kt#L170) | `FOUNDER_BUYER_KYC` (MainNavGraph.kt:1108) | [UI-10](founder-pages.md) |
| [FounderCashFlagHistoryScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderCashFlagHistoryScreen.kt#L104) | `FOUNDER_CASH_FLAG_HISTORY` (MainNavGraph.kt:1024) | [UI-10](founder-pages.md) |
| [FounderCategoriesScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderCategoriesScreen.kt#L230) | `FOUNDER_CATEGORIES` (MainNavGraph.kt:1103) | [UI-10](founder-pages.md) |
| [FounderDashboardScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderDashboardScreen.kt#L168) | `FOUNDER_DASHBOARD` (MainNavGraph.kt:931) | [UI-10](founder-pages.md) |
| [FounderEngineerMapScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderEngineerMapScreen.kt#L103) | `FOUNDER_ENGINEER_MAP` (MainNavGraph.kt:1041) | [UI-10](founder-pages.md) |
| [FounderEngineerPayoutsScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderEngineerPayoutsScreen.kt#L361) | `FOUNDER_ENGINEER_PAYOUTS` (MainNavGraph.kt:965) | [UI-10](founder-pages.md) |
| [FounderEscrowDisputeDetailScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderEscrowDisputeDetailScreen.kt#L114) | `FOUNDER_ESCROW_DISPUTE_DETAIL` (MainNavGraph.kt:984) | [UI-10](founder-pages.md) |
| [FounderInactiveEngineersScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderInactiveEngineersScreen.kt#L91) | `FOUNDER_INACTIVE_ENGINEERS` (MainNavGraph.kt:1123) | [UI-10](founder-pages.md) |
| [FounderIntegrityScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderIntegrityScreen.kt#L109) | `FOUNDER_INTEGRITY` (MainNavGraph.kt:1084) | [UI-10](founder-pages.md) |
| [FounderKycQueueScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderKycQueueScreen.kt#L163) | `FOUNDER_KYC_QUEUE` (MainNavGraph.kt:1046) | [UI-10](founder-pages.md) |
| [FounderKycReviewScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderKycReviewScreen.kt#L169) | `FOUNDER_KYC_REVIEW` (MainNavGraph.kt:1054) | [UI-10](founder-pages.md) |
| [FounderEscrowDisputesScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderOpsQueueScreens.kt#L143) | `FOUNDER_ESCROW_DISPUTES` (MainNavGraph.kt:957) | [UI-10](founder-pages.md) |
| [FounderAmcEscalationsScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderOpsQueueScreens.kt#L315) | `FOUNDER_AMC_ESCALATIONS` (MainNavGraph.kt:996) | [UI-10](founder-pages.md) |
| [FounderCashSuspendedScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderOpsQueueScreens.kt#L478) | `FOUNDER_CASH_SUSPENDED` (MainNavGraph.kt:1016) | [UI-10](founder-pages.md) |
| [FounderPartsOutliersScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderOpsQueueScreens.kt#L615) | `FOUNDER_PARTS_OUTLIERS` (MainNavGraph.kt:1036) | [UI-10](founder-pages.md) |
| [FounderPausedAmcScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderPausedAmcScreen.kt#L94) | `FOUNDER_AMC_PAUSED` (MainNavGraph.kt:1132) | [UI-10](founder-pages.md) |
| [FounderPaymentsScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderPaymentsScreen.kt#L110) | `FOUNDER_PAYMENTS` (MainNavGraph.kt:1076) | [UI-10](founder-pages.md) |
| [FounderReportsQueueScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderReportsQueueScreen.kt#L129) | `FOUNDER_REPORTS_QUEUE` (MainNavGraph.kt:1066) | [UI-10](founder-pages.md) |
| [FounderResolvedDisputesScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderResolvedDisputesScreen.kt#L101) | `FOUNDER_RESOLVED_DISPUTES` (MainNavGraph.kt:971) | [UI-10](founder-pages.md) |
| [FounderSpotAuditsScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderSpotAuditsScreen.kt#L98) | `FOUNDER_SPOT_AUDITS` (MainNavGraph.kt:979) | [UI-10](founder-pages.md) |
| [FounderUsersScreen](../../app/src/main/kotlin/com/equipseva/app/features/founder/FounderUsersScreen.kt#L187) | `FOUNDER_USERS` (MainNavGraph.kt:1071) | [UI-10](founder-pages.md) |
| [HomeHubScreen](../../app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt#L101) | `HOME` (MainNavGraph.kt:316) | [UI-04](hospital-pages.md) |
| [HospitalActiveJobsScreen](../../app/src/main/kotlin/com/equipseva/app/features/hospital/HospitalActiveJobsScreen.kt#L68) | `REPAIR` (MainNavGraph.kt:347), `HOSPITAL_ACTIVE_JOBS` (MainNavGraph.kt:913) | [UI-04](hospital-pages.md) |
| [HospitalMyDisputesScreen](../../app/src/main/kotlin/com/equipseva/app/features/hospital/HospitalMyDisputesScreen.kt#L104) | `HOSPITAL_MY_DISPUTES` (MainNavGraph.kt:444) | [UI-04](hospital-pages.md) |
| [RequestSentScreen](../../app/src/main/kotlin/com/equipseva/app/features/hospital/RequestSentScreen.kt#L60) | `REQUEST_SENT` (MainNavGraph.kt:880) | [UI-04](hospital-pages.md) |
| [RequestServiceScreen](../../app/src/main/kotlin/com/equipseva/app/features/hospital/RequestServiceScreen.kt#L96) | `REQUEST_SERVICE` (MainNavGraph.kt:838) | [UI-04](hospital-pages.md) |
| [KycScreen](../../app/src/main/kotlin/com/equipseva/app/features/kyc/KycScreen.kt#L107) | `KYC` (MainNavGraph.kt:696) | [UI-03](account-pages.md) |
| [KycSubmittedScreen](../../app/src/main/kotlin/com/equipseva/app/features/kyc/KycSubmittedScreen.kt#L49) | `KYC_SUBMITTED` (MainNavGraph.kt:708) | [UI-03](account-pages.md) |
| [HospitalTierPreviewScreen](../../app/src/main/kotlin/com/equipseva/app/features/mybids/HospitalTierPreviewScreen.kt#L97) | `HOSPITAL_TIER_PREVIEW` (MainNavGraph.kt:777) | [UI-07](engineer-pages.md) |
| [JobProfitabilityScreen](../../app/src/main/kotlin/com/equipseva/app/features/mybids/JobProfitabilityScreen.kt#L123) | `JOB_PROFITABILITY` (MainNavGraph.kt:767) | [UI-07](engineer-pages.md) |
| [MyBidsScreen](../../app/src/main/kotlin/com/equipseva/app/features/mybids/MyBidsScreen.kt#L62) | `MY_BIDS` (MainNavGraph.kt:754) | [UI-06](engineer-pages.md) |
| [NotificationSettingsScreen](../../app/src/main/kotlin/com/equipseva/app/features/notifications/NotificationSettingsScreen.kt#L69) | `NOTIFICATION_SETTINGS` (MainNavGraph.kt:691) | [UI-08](account-pages.md) |
| [NotificationsScreen](../../app/src/main/kotlin/com/equipseva/app/features/notifications/NotificationsScreen.kt#L79) | `NOTIFICATIONS` (MainNavGraph.kt:673) | [UI-08](account-pages.md) |
| [EngineerOnboardingScreen](../../app/src/main/kotlin/com/equipseva/app/features/onboarding/EngineerOnboardingScreen.kt#L158) | `ENGINEER_ONBOARDING` (MainNavGraph.kt:870) | [UI-03](account-pages.md) |
| [EngineerPayoutOnboardingScreen](../../app/src/main/kotlin/com/equipseva/app/features/onboarding/EngineerPayoutOnboardingScreen.kt#L384) | root/activity entry (AppNavGraph.kt:107) | [UI-03](account-pages.md) |
| [HospitalOnboardingScreen](../../app/src/main/kotlin/com/equipseva/app/features/onboarding/HospitalOnboardingScreen.kt#L154) | `HOSPITAL_ONBOARDING` (MainNavGraph.kt:858) | [UI-03](account-pages.md) |
| [HospitalPhoneOnboardingScreen](../../app/src/main/kotlin/com/equipseva/app/features/onboarding/HospitalPhoneOnboardingScreen.kt#L56) | legacy/unmounted | [UI-03](account-pages.md) |
| [TourScreen](../../app/src/main/kotlin/com/equipseva/app/features/onboarding/TourScreen.kt#L96) | `TOUR` (MainNavGraph.kt:302) | [UI-03](account-pages.md) |
| [EngineerPayoutMethodScreen](../../app/src/main/kotlin/com/equipseva/app/features/payouts/EngineerPayoutMethodScreen.kt#L61) | `ENGINEER_PAYOUT_METHOD` (MainNavGraph.kt:1150) | [UI-07](engineer-pages.md) |
| [AddPhoneScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/AddPhoneScreen.kt#L118) | `ADD_PHONE` (MainNavGraph.kt:718) | [UI-08](account-pages.md) |
| [CommissionTierScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/CommissionTierScreen.kt#L84) | `COMMISSION_TIER` (MainNavGraph.kt:525) | [UI-08](account-pages.md) |
| [DpdpGrievanceScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/DpdpGrievanceScreen.kt#L126) | `DPDP_GRIEVANCE` (MainNavGraph.kt:535) | [UI-08](account-pages.md) |
| [EngineerReferralScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/EngineerReferralScreen.kt#L159) | `ENGINEER_REFERRALS` (MainNavGraph.kt:540) | [UI-08](account-pages.md) |
| [AddressBookScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/AddressBookScreen.kt#L128) | `PROFILE_ADDRESSES` (MainNavGraph.kt:1156) | [UI-08](account-pages.md) |
| [AddressFormScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/AddressFormScreen.kt#L227) | `PROFILE_ADDRESS_FORM` (MainNavGraph.kt:1163) | [UI-08](account-pages.md) |
| [BankDetailsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L306) | `PROFILE_BANK_DETAILS` (MainNavGraph.kt:1144) | [UI-08](account-pages.md); UI-07 routing prerequisite |
| [HospitalAddressesScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L331) | legacy/unmounted | [UI-08](account-pages.md) |
| [HospitalSettingsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L360) | `PROFILE_HOSPITAL_SETTINGS` (MainNavGraph.kt:1177) | [UI-08](account-pages.md) |
| [StorefrontSettingsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L383) | `PROFILE_STOREFRONT` (MainNavGraph.kt:1183) | [UI-08](account-pages.md) |
| [GstSettingsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L400) | `PROFILE_GST` (MainNavGraph.kt:1189) | [UI-08](account-pages.md) |
| [BrandPortfolioScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L416) | `PROFILE_BRAND_PORTFOLIO` (MainNavGraph.kt:1195) | [UI-08](account-pages.md) |
| [TaxDetailsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L432) | `PROFILE_TAX_DETAILS` (MainNavGraph.kt:1201) | [UI-08](account-pages.md) |
| [VehicleDetailsScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L448) | `PROFILE_VEHICLE_DETAILS` (MainNavGraph.kt:1207) | [UI-08](account-pages.md) |
| [LicenceScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L465) | `PROFILE_LICENCE` (MainNavGraph.kt:1213) | [UI-08](account-pages.md) |
| [ServiceAreasScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt#L481) | `PROFILE_SERVICE_AREAS` (MainNavGraph.kt:1219) | [UI-08](account-pages.md) |
| [KycRenewalScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/KycRenewalScreen.kt#L107) | `KYC_RENEWAL` (MainNavGraph.kt:550) | [UI-08](account-pages.md) |
| [ProfileCompletenessScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/ProfileCompletenessScreen.kt#L88) | `PROFILE_COMPLETENESS` (MainNavGraph.kt:530) | [UI-08](account-pages.md) |
| [ProfileScreen](../../app/src/main/kotlin/com/equipseva/app/features/profile/ProfileScreen.kt#L112) | `PROFILE` (MainNavGraph.kt:621) | [UI-08](account-pages.md) |
| [EngineerDirectoryScreen](../../app/src/main/kotlin/com/equipseva/app/features/repair/directory/EngineerDirectoryScreen.kt#L277) | `ENGINEER_DIRECTORY` (MainNavGraph.kt:466) | [UI-04](hospital-pages.md) |
| [EngineerPublicProfileScreen](../../app/src/main/kotlin/com/equipseva/app/features/repair/directory/EngineerPublicProfileScreen.kt#L547) | `ENGINEER_PUBLIC_PROFILE` (MainNavGraph.kt:474) | [UI-04](hospital-pages.md) |
| [DsrScreen](../../app/src/main/kotlin/com/equipseva/app/features/repair/DsrScreen.kt#L170) | `DSR_REPORT` (MainNavGraph.kt:789) | [UI-05](engineer-pages.md) |
| [RepairJobDetailScreen](../../app/src/main/kotlin/com/equipseva/app/features/repair/RepairJobDetailScreen.kt#L142) | `REPAIR_DETAIL` (MainNavGraph.kt:372) | [UI-05](engineer-pages.md) |
| [RepairJobsScreen](../../app/src/main/kotlin/com/equipseva/app/features/repair/RepairJobsScreen.kt#L100) | `REPAIR` (MainNavGraph.kt:347) | [UI-06](engineer-pages.md) |
| [ChangeEmailScreen](../../app/src/main/kotlin/com/equipseva/app/features/security/ChangeEmailScreen.kt#L46) | `CHANGE_EMAIL` (MainNavGraph.kt:730) | [UI-08](account-pages.md) |
| [ChangePasswordScreen](../../app/src/main/kotlin/com/equipseva/app/features/security/ChangePasswordScreen.kt#L55) | `CHANGE_PASSWORD` (MainNavGraph.kt:724) | [UI-08](account-pages.md) |
| [SessionRecoveryScreen](../../app/src/main/kotlin/com/equipseva/app/navigation/AppNavGraph.kt#L131) | root/activity entry (AppNavGraph.kt:73) | [UI-03](account-pages.md) |
| [SessionResolvingScreen](../../app/src/main/kotlin/com/equipseva/app/navigation/AppNavGraph.kt#L157) | root/activity entry (AppNavGraph.kt:81) | [UI-03](account-pages.md) |

## Additional surfaces and retained behavior

- `AUTH_GRAPH` is a graph container, not a screen. `HOSPITAL_PHONE_ONBOARDING` in AuthNavGraph:66 is a redirect to Sign in; the older HospitalPhoneOnboardingScreen remains unmounted. Do not reactivate it as a shortcut around the current root gate.
- HospitalAddressesScreen in ProfileForms is superseded by the real AddressBook/AddressForm flow. Retain it without adding a new navigation entry.
- Several marketplace/logistics profile forms still have graph registrations but no active two-role menu entry. Their current UserSettings writes are real. Restyle the shared form safely; do not remove them or reintroduce retired roles as a visual task.
- Native splash, security blocking, top/bottom bars, banners, empty/loading/error, menus, bottom sheets, dialogs, map overlays and all external-provider launch/return states are part of the parent page/component plan.
- Theme and language preference controls are proposed new surfaces, listed separately from the existing declaration count. Their persistence and account boundaries need explicit tests before acceptance.
- See each page-plan appendix for nested surfaces, precise route defects and state gaps. New routes/functions discovered later expand this inventory rather than being silently omitted.
