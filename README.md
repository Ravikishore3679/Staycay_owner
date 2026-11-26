# heavenrock_registry

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Account profile

Tap the profile avatar at the top of the app to view or edit your guest-house
name and address, your name, phone, email and profile photo. The guest-house name
and address appear on Home and booking receipts. These fields are optional; an
existing address is retained until edited or cleared. When the name is blank, an existing
guest-house name or the default header is used. Contact details do not
change your sign-in credentials. Photos must be no larger than 500 KB after
selection. Your account profile is separate from existing guest-house details,
which remain available for the Home header and booking receipts. New accounts
use the default guest-house header and no longer require guest-house setup. New users
can save their account profile before Home or skip it and edit it later.
Deploy the updated `firestore.rules` before using account profile storage.

## Website

Under **Manage > Website**, add or edit the website address for the signed-in
account. The saved address can be opened, copied or shared. New accounts have
no website until one is added; clear the address and save to remove it. Addresses
without a scheme use HTTPS. The address is stored in
`users/{uid}/settings/website`. Deploy the updated `firestore.rules` before
releasing this feature.

## Booking balance payments

Tap an empty date on the Home calendar to open a new booking with that date
selected as check-in. Check-out defaults to the next day and can be changed.
The same default applies when choosing check-in from the Add screen. Tapping
an occupied date continues to show its stays on Home.
Bookings support between 1 and 99 guests.

From Home, open a booking and choose **Record payment** to record a full or
partial payment. The original advance and subsequent balance payments are
shown separately. Payments can be recorded before or after the check-in date;
the balance is due on that date. Choose **Reprint receipt** to open the system
print dialog with the latest booking details, payments, cancellation status and
any recorded refund. Monthly P&L attributes collected payments to
the booking's check-in month, not the month in which a payment was recorded.
From the check-in date onward, bookings with an unpaid balance are highlighted
in red on Home and listed under **Payments due**, including past stays. Partial
payments remain due until the full balance is recorded; cancelled bookings are
excluded.

Deploy the updated `firestore.rules` before releasing this app version so
Firestore accepts the new payment, cancellation, and refund fields.

## Booking changes and cancellations

Open a booking on Home to modify or cancel it. Cancelled bookings remain
available under **Cancelled bookings** in their check-in month and no longer
occupy the calendar. Payments remain recorded when cancelling. After returning
the money to the guest, use **Record full refund** to record the full amount;
the app does not transfer money. Monthly P&L keeps unrefunded payments as
revenue and subtracts a recorded refund in the booking's check-in month.

The monthly P&L PDF includes separate lists of active and cancelled bookings,
their payments and refunds, and all expenses dated in the selected month.
Bookings are listed by check-in month, including when a cancellation or refund
was recorded in a different month.

## Android Google Sign-In setup

Android requires native OAuth configuration in addition to Firebase web auth.

1. In Firebase Console, open your Android app (`com.example.heavenrock_registry`) and add SHA-1 and SHA-256 fingerprints for your debug/release keystores.
2. In Firebase Authentication, enable Google as a sign-in provider.
3. Download a fresh `google-services.json` and replace `android/app/google-services.json`.
4. Verify the new `google-services.json` includes non-empty `oauth_client` entries and `services.appinvite_service.other_platform_oauth_client` with a `client_type: 3` Web Client ID.
5. Run the app with the Web Client ID passed to Flutter:

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com
```

Without the Web Client ID and OAuth clients in `google-services.json`, Google Sign-In on Android cannot securely exchange tokens with Firebase Auth.

## Firebase login providers

The login screen supports these Firebase Authentication entry points:

1. Google sign-in
2. Email/password sign-in and account creation

Before testing the screen, enable the providers you need in Firebase Console under Authentication > Sign-in method:

1. Turn on `Google`.
2. Turn on `Email/Password`.
Firebase Email/Password sign-in must be enabled before creating an account.
//flutter run -d 00008110-001545200C05801E --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com
//flutter run -d 9F832C20-6CB5-42D4-80F9-3555F259E7C2 --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com

dart run bin/deploy.dart