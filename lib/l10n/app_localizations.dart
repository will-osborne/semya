import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Семья'**
  String get appName;

  /// No description provided for @languageSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageSelectionTitle;

  /// No description provided for @languageSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get languageSelectionSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @encryptedFamilyMessaging.
  ///
  /// In en, this message translates to:
  /// **'Encrypted family messaging'**
  String get encryptedFamilyMessaging;

  /// No description provided for @enterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password'**
  String get enterEmailAndPassword;

  /// No description provided for @emailAuthDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Firebase email account.'**
  String get emailAuthDescription;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @emailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get emailEmpty;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordHint;

  /// No description provided for @passwordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get passwordEmpty;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get confirmPasswordEmpty;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @noAccountCreateOne.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get noAccountCreateOne;

  /// No description provided for @noEmailVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Email verification is not required to sign in.'**
  String get noEmailVerificationRequired;

  /// No description provided for @smsMigrationEntryAction.
  ///
  /// In en, this message translates to:
  /// **'Already had an SMS account? Migrate it'**
  String get smsMigrationEntryAction;

  /// No description provided for @smsMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Migrate SMS account'**
  String get smsMigrationTitle;

  /// No description provided for @smsMigrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your existing phone number once to keep your current account and data, then add email/password.'**
  String get smsMigrationDescription;

  /// No description provided for @smsMigrationOtpDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code for your existing account.'**
  String get smsMigrationOtpDescription;

  /// No description provided for @linkEmailPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add email & password'**
  String get linkEmailPasswordTitle;

  /// No description provided for @linkEmailPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in with phone. Add email/password to keep this same account ID for future logins.'**
  String get linkEmailPasswordDescription;

  /// No description provided for @linkEmailPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Link email & password'**
  String get linkEmailPasswordAction;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneNumber;

  /// No description provided for @phoneVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to confirm your number.'**
  String get phoneVerificationDescription;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'+1 555 000 0000'**
  String get phoneNumberHint;

  /// No description provided for @phoneNumberEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get phoneNumberEmpty;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number.'**
  String get phoneNumberInvalid;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @standardRatesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Standard message and data rates may apply.'**
  String get standardRatesDisclaimer;

  /// No description provided for @verifyNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify Number'**
  String get verifyNumber;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get enterSixDigitCode;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to your phone number.'**
  String get verificationCodeSent;

  /// No description provided for @verificationExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification session expired. Please go back and try again.'**
  String get verificationExpired;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resendCodeIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @setupProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setupProfile;

  /// No description provided for @chooseDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Choose a display name visible to your family.'**
  String get chooseDisplayName;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mama, Papa, Dasha…'**
  String get displayNameHint;

  /// No description provided for @displayNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name.'**
  String get displayNameEmpty;

  /// No description provided for @displayNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters.'**
  String get displayNameTooShort;

  /// No description provided for @changeInSettings.
  ///
  /// In en, this message translates to:
  /// **'You can change this at any time in Settings.'**
  String get changeInSettings;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @errorLoadingConversations.
  ///
  /// In en, this message translates to:
  /// **'Error loading conversations:\n{error}'**
  String errorLoadingConversations(String error);

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @createGroupConversation.
  ///
  /// In en, this message translates to:
  /// **'Create a group conversation'**
  String get createGroupConversation;

  /// No description provided for @searchByPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Search by phone number'**
  String get searchByPhoneNumber;

  /// No description provided for @searchByEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by email address'**
  String get searchByEmail;

  /// No description provided for @enterPhoneToFind.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number to find family members.'**
  String get enterPhoneToFind;

  /// No description provided for @enterEmailToFind.
  ///
  /// In en, this message translates to:
  /// **'Enter an email address to find family members.'**
  String get enterEmailToFind;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get noUsersFound;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @startConversationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start a private or group conversation with your family members.'**
  String get startConversationPrompt;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a Conversation'**
  String get startConversation;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @displayNamePhoto.
  ///
  /// In en, this message translates to:
  /// **'Display name, photo'**
  String get displayNamePhoto;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @alertsSoundsBadges.
  ///
  /// In en, this message translates to:
  /// **'Alerts, sounds, badges'**
  String get alertsSoundsBadges;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who can message you, read receipts'**
  String get privacySubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'English, Русский'**
  String get languageSubtitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? You will need your email and password to sign in again.'**
  String get signOutConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @startupPermissionsMissing.
  ///
  /// In en, this message translates to:
  /// **'Some permissions are still missing. Please enable them in iOS Settings.'**
  String get startupPermissionsMissing;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettingsAction;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice notes.'**
  String get microphonePermissionRequired;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorGeneric(String error);

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String sendFailed(String error);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello!'**
  String get sayHello;

  /// No description provided for @sendingVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending voice message...'**
  String get sendingVoiceMessage;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Osborne Family'**
  String get groupNameHint;

  /// No description provided for @groupNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name.'**
  String get groupNameEmpty;

  /// No description provided for @groupNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters.'**
  String get groupNameTooShort;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String membersCount(int count);

  /// No description provided for @searchForFamilyMembers.
  ///
  /// In en, this message translates to:
  /// **'Search for family members by email address.'**
  String get searchForFamilyMembers;

  /// No description provided for @noUsersFoundInstallApp.
  ///
  /// In en, this message translates to:
  /// **'No users found. Make sure they have the app installed.'**
  String get noUsersFoundInstallApp;

  /// No description provided for @failedToCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group: {error}'**
  String failedToCreateGroup(String error);

  /// No description provided for @addMembersToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add members to continue'**
  String get addMembersToContinue;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @ringing.
  ///
  /// In en, this message translates to:
  /// **'Ringing...'**
  String get ringing;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @flipCamera.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flipCamera;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @videoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// No description provided for @sendingMedia.
  ///
  /// In en, this message translates to:
  /// **'Sending media...'**
  String get sendingMedia;

  /// No description provided for @photoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo from Gallery'**
  String get photoFromGallery;

  /// No description provided for @videoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Video from Gallery'**
  String get videoFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @takeVideo.
  ///
  /// In en, this message translates to:
  /// **'Take Video'**
  String get takeVideo;

  /// No description provided for @compressingVideo.
  ///
  /// In en, this message translates to:
  /// **'Compressing video...'**
  String get compressingVideo;

  /// No description provided for @loadingOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading older messages...'**
  String get loadingOlderMessages;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
