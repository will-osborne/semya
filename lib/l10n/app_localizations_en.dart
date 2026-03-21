// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Семья';

  @override
  String get languageSelectionTitle => 'Choose your language';

  @override
  String get languageSelectionSubtitle =>
      'You can change this later in Settings.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get continueButton => 'Continue';

  @override
  String get encryptedFamilyMessaging => 'Encrypted family messaging';

  @override
  String get enterEmailAndPassword => 'Enter your email and password';

  @override
  String get emailAuthDescription =>
      'Sign in with your Firebase email account.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get emailEmpty => 'Please enter your email address.';

  @override
  String get emailInvalid => 'Please enter a valid email address.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'At least 6 characters';

  @override
  String get passwordEmpty => 'Please enter your password.';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters.';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordEmpty => 'Please confirm your password.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get noAccountCreateOne => 'No account yet? Create one';

  @override
  String get noEmailVerificationRequired =>
      'Email verification is not required to sign in.';

  @override
  String get smsMigrationEntryAction =>
      'Already had an SMS account? Migrate it';

  @override
  String get smsMigrationTitle => 'Migrate SMS account';

  @override
  String get smsMigrationDescription =>
      'Sign in with your existing phone number once to keep your current account and data, then add email/password.';

  @override
  String get smsMigrationOtpDescription =>
      'Enter the SMS code for your existing account.';

  @override
  String get linkEmailPasswordTitle => 'Add email & password';

  @override
  String get linkEmailPasswordDescription =>
      'You\'re signed in with phone. Add email/password to keep this same account ID for future logins.';

  @override
  String get linkEmailPasswordAction => 'Link email & password';

  @override
  String get enterPhoneNumber => 'Enter your phone number';

  @override
  String get phoneVerificationDescription =>
      'We\'ll send a verification code to confirm your number.';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get phoneNumberHint => '+1 555 000 0000';

  @override
  String get phoneNumberEmpty => 'Please enter your phone number.';

  @override
  String get phoneNumberInvalid => 'Please enter a valid phone number.';

  @override
  String get sendCode => 'Send Code';

  @override
  String get standardRatesDisclaimer =>
      'Standard message and data rates may apply.';

  @override
  String get verifyNumber => 'Verify Number';

  @override
  String get enterSixDigitCode => 'Enter the 6-digit code';

  @override
  String get verificationCodeSent =>
      'We sent a verification code to your phone number.';

  @override
  String get verificationExpired =>
      'Verification session expired. Please go back and try again.';

  @override
  String get verify => 'Verify';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resendCode => 'Resend Code';

  @override
  String get setupProfile => 'Set up your profile';

  @override
  String get chooseDisplayName =>
      'Choose a display name visible to your family.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHint => 'e.g. Mama, Papa, Dasha…';

  @override
  String get displayNameEmpty => 'Please enter a display name.';

  @override
  String get displayNameTooShort => 'Name must be at least 2 characters.';

  @override
  String get changeInSettings => 'You can change this at any time in Settings.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get newChat => 'New Chat';

  @override
  String errorLoadingConversations(String error) {
    return 'Error loading conversations:\n$error';
  }

  @override
  String get newGroup => 'New Group';

  @override
  String get createGroupConversation => 'Create a group conversation';

  @override
  String get searchByPhoneNumber => 'Search by phone number';

  @override
  String get enterPhoneToFind => 'Enter a phone number to find family members.';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get noUsersFound => 'No users found.';

  @override
  String get unknown => 'Unknown';

  @override
  String get chat => 'Chat';

  @override
  String get group => 'Group';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get startConversationPrompt =>
      'Start a private or group conversation with your family members.';

  @override
  String get startConversation => 'Start a Conversation';

  @override
  String get loading => 'Loading...';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get account => 'Account';

  @override
  String get profile => 'Profile';

  @override
  String get displayNamePhoto => 'Display name, photo';

  @override
  String get preferences => 'Preferences';

  @override
  String get notifications => 'Notifications';

  @override
  String get alertsSoundsBadges => 'Alerts, sounds, badges';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySubtitle => 'Who can message you, read receipts';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'English, Русский';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessage =>
      'Are you sure you want to sign out? You will need your email and password to sign in again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get startupPermissionsMissing =>
      'Some permissions are still missing. Please enable them in iOS Settings.';

  @override
  String get openSettingsAction => 'Open Settings';

  @override
  String get microphonePermissionRequired =>
      'Microphone permission is required for voice notes.';

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String sendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get sayHello => 'Say hello!';

  @override
  String get sendingVoiceMessage => 'Sending voice message...';

  @override
  String get message => 'Message';

  @override
  String get recording => 'Recording...';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get create => 'Create';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameHint => 'e.g. Osborne Family';

  @override
  String get groupNameEmpty => 'Please enter a group name.';

  @override
  String get groupNameTooShort => 'Name must be at least 2 characters.';

  @override
  String membersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get searchForFamilyMembers =>
      'Search for family members by phone number.';

  @override
  String get noUsersFoundInstallApp =>
      'No users found. Make sure they have the app installed.';

  @override
  String failedToCreateGroup(String error) {
    return 'Failed to create group: $error';
  }

  @override
  String get addMembersToContinue => 'Add members to continue';

  @override
  String get createGroup => 'Create Group';

  @override
  String get call => 'Call';

  @override
  String get ringing => 'Ringing...';

  @override
  String get connecting => 'Connecting...';

  @override
  String get callEnded => 'Call ended';

  @override
  String get unmute => 'Unmute';

  @override
  String get mute => 'Mute';

  @override
  String get speaker => 'Speaker';

  @override
  String get end => 'End';

  @override
  String get video => 'Video';

  @override
  String get flipCamera => 'Flip';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get photo => 'Photo';

  @override
  String get videoMessage => 'Video';

  @override
  String get sendingMedia => 'Sending media...';

  @override
  String get photoFromGallery => 'Photo from Gallery';

  @override
  String get videoFromGallery => 'Video from Gallery';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get takeVideo => 'Take Video';

  @override
  String get compressingVideo => 'Compressing video...';

  @override
  String get loadingOlderMessages => 'Loading older messages...';
}
