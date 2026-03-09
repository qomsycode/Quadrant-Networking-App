# Mobile App Store Roadmap: The Quadrant

This guide provides a separate, step-by-step walkthrough for deploying **The Quadrant** to the Google Play Store (Android) and the Apple App Store (iOS).

---

## 🚀 Parallel Deployment: Can you do both at once?

**Yes, you can (and should) run both processes simultaneously.** Since Flutter allows you to use the same code for both apps, you can manage the paperwork and testing tracks in parallel to save time.

### The Parallel Strategy:
1.  **Day 1 (Pay & Register):** Create both your Apple and Google accounts on the same day.
2.  **Week 2 (Internal Testing):** Upload your builds to both **TestFlight** (iOS) and the **Internal Track** (Android). You can test features on an iPhone and an Android phone at the same time.
3.  **The Overlap:** While you are waiting for the **14-day Google testing period** to finish, you can use that same time to submit your **iOS app for final review**.
4.  **Result:** Your iOS app might go live in Week 3, followed by your Android app in Week 5.

---

## 🤖 Part 1: Android Deployment (Google Play Store)

### Step 1: Account & Identity (Day 1)
1.  **Sign Up:** Create a [Google Play Console](https://play.google.com/console/signup) account.
2.  **Payment:** **$25 one-time fee** paid immediately.
3.  **Identity Verification:** Upload a government ID (Passport or Driver's License). Google will verify this within a few days.

### Step 2: Technical Prep & Internal Testing
1.  **App Signing:** Generate a `keystore` file in Flutter to digitally sign your release build.
2.  **Build:** Run `flutter build appbundle`.
3.  **Internal Testing Track:** Upload the `.aab` file to the "Internal Testing" track in the console. 
    *   **How to test:** You add your own email. You'll get a link to download the app from the Play Store immediately. It is **not** public yet.

### Step 3: The "20 Testers" Rule (Weeks 2-4)
**Exemption:** If your **Developer Console Account** was created **before November 13, 2023**, you are exempt from this requirement and can go straight to production.

> [!IMPORTANT]
> **Account vs. Developer Account:** Simply having a Gmail account since 2020 or using the Play Store to download apps does **not** count. You are only "exempt" if you went to the Play Console and paid the **$25 fee** before Nov 13, 2023. If you haven't paid that fee yet, you will be considered a "New Developer" and will need the 20 testers.

1.  **Closed Testing:** If your account was created *after* that date, you must invite **20 testers**.
2.  **14-Day Requirement:** These 20 people must be "opted-in" to the test for **14 days continuously**.
3.  **Onboarding:** You create a "Google Group" with their emails. They join the group, then they can download the app via the Play Store link you provide.

> [!CAUTION]
> **Using Someone Else's Account?**
> Technically, yes, someone with an old account can host your app. However, **they will legally own the app on the store.**
> *   **Payments:** Any AdSense revenue or in-app purchases will go to *their* linked bank account.
> *   **Brand:** The "Developer Name" shown to users will be theirs.
> *   **Control:** They can delete your app at any time, and you cannot easily move it to your own account later. It is generally better to own your own identity.

> [!CAUTION]
> **Can you use fake accounts?**
> It is **high-risk**. Google monitors for "suspicious" testing activity. If they see 20 accounts from the same IP address or accounts with no real activity, they may **reject your application for production** or even suspend your developer account for "circumventing policies." It is much safer to find 20 real friends/contacts.

### Testing Engagement (Quality vs. Camouflage)
Google does not just check *if* the app is installed; they check *how* it is used. "Camouflage" users who just download and never open the app will not help you pass.

To pass the review, your 20 testers should ideally:
*   **Open the app multiple times**: Not just once on Day 1. Testers should open it every few days throughout the 14-day period.
*   **Interact with features**: Since "The Quadrant" is a social app, they should create a profile, send a connection request, or post an insight.
*   **Report bugs/Feedback**: Google tracks if testers use the "provide feedback to developer" feature in the Play Store. This is a strong signal of "real" testing.
*   **Active Period**: If most testers uninstall the app before the 14 days are up, you will fail the requirement.

### Step 4: Production Submission (Week 5)
1.  **Promote to Production:** After 14 days of testing, you can click "Apply for Production."
2.  **Review Time:** The initial review typically takes **3 to 7 days**.
3.  **Rejections:** If rejected, you'll get an email with policy violations. Fix them, upload a new build, and feedback on fixes usually arrives in **< 24 hours**.

---

## 🍏 Part 2: iOS Deployment (Apple App Store)

### Step 1: Account & Identity (Day 1)
1.  **Device Requirement:** You **MUST** have a macOS device (MacBook/Mac mini) for the final build and submission.
2.  **Sign Up:** Create an [Apple Developer](https://developer.apple.com/programs/) account using the "Apple Developer" app.
3.  **Payment:** **$99/year recurring fee** paid immediately.
4.  **Verification:** Identity is verified through the app. If registering a business, you'll need a **D-U-N-S Number**.

### Step 2: Technical Prep & TestFlight
**Note:** Apple **does NOT** require a minimum number of testers like Google does.

1.  **Signing:** Set up "Certificates, Identifiers & Profiles" in the Apple Developer portal.
2.  **Build:** Run `flutter build ipa`.
3.  **Upload:** Use Xcode or "Transporter" to upload the build to App Store Connect.
4.  **TestFlight (Internal):** Add your email to the "Internal Testers" list. 
    *   **How to test:** Install the **TestFlight** app on your iPhone. Your app will appear there for download immediately.

### Step 3: External Testing (Optional)
If you want people outside your immediate team to test:
1.  **External Testers:** Add their emails to an "External Testing" group.
2.  **Beta Review:** Apple does a quick "Beta Review" (usually **< 24 hours**) before external people can download it.

### Step 4: Production Submission (Week 3)
1.  **Submit for Review:** Fill out the store listing (screenshots, description) and click "Submit for Review."
2.  **Review Time:** Very consistent, usually **24 to 48 hours**.
3.  **Rejections:** Handled in the "App Store Connect Resolution Center." You can chat directly with the reviewer. Fixes are often re-reviewed in **< 12 hours**.

### Apple vs. Google: Which is actually harder?
It sounds like Google is harder because of the "20 testers" rule, but the industry usually says Apple is harder. Here is why:

*   **Google (Harder to Start)**: The 20-tester rule is a "technical" hurdle. It’s annoying, but if you have the people, you pass. Google’s review process is more automated.
*   **Apple (Harder to Pass)**: Apple has **human reviewers** who will actually play with your app. They will reject you for "looking like a website," having a "boring UI," or if the app doesn't feel "iOS-native." They are much more opinionated about quality.

---

## 🛡️ Part 3: Shared Criteria for "The Quadrant"

To pass review on **both** stores, your app must include these networking-specific features:

1.  **User Safety (UGC Policy):** 
    *   **Report Button:** Must be present on every post or profile.
    *   **Block User:** Users must be able to block someone they don't want to see.
2.  **Account Management:**
    *   **Delete Account:** A button in Settings to permanently delete the account and all data (Required by Apple).
3.  **Reviewer Access:**
    *   You must provide a **Test Account** (username and password) in the "Reviewer Instructions" so they can log in and test the feed.
4.  **Privacy Policy (Live URL):**
    *   **What is a "Live URL"?** This is a public website link (e.g., `https://qomsycode.github.io/privacy.html`). You can use the GitHub Pages site we just set up to host this. It **must** be accessible to the public without a login.

---

## Quick Summary Roadmap
| Goal | Android | iOS |
| :--- | :--- | :--- |
| **Cost** | $25 (Once) | $99 (Yearly) |
| **Testing** | 20 people for 14 days | TestFlight (Instant) |
| **Review** | 3-7 Days | 24-48 Hours |
| **Hardware** | Any | Mac Required |
