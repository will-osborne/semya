// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Семья';

  @override
  String get languageSelectionTitle => 'Выберите язык';

  @override
  String get languageSelectionSubtitle =>
      'Вы можете изменить это позже в Настройках.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get encryptedFamilyMessaging => 'Зашифрованный семейный мессенджер';

  @override
  String get enterEmailAndPassword => 'Введите email и пароль';

  @override
  String get emailAuthDescription =>
      'Войдите с помощью email-аккаунта Firebase.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get emailEmpty => 'Пожалуйста, введите email.';

  @override
  String get emailInvalid => 'Пожалуйста, введите корректный email.';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordHint => 'Минимум 6 символов';

  @override
  String get passwordEmpty => 'Пожалуйста, введите пароль.';

  @override
  String get passwordTooShort => 'Пароль должен содержать не менее 6 символов.';

  @override
  String get confirmPasswordLabel => 'Подтвердите пароль';

  @override
  String get confirmPasswordEmpty => 'Пожалуйста, подтвердите пароль.';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают.';

  @override
  String get signIn => 'Войти';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get alreadyHaveAccountSignIn => 'Уже есть аккаунт? Войти';

  @override
  String get noAccountCreateOne => 'Нет аккаунта? Создать';

  @override
  String get noEmailVerificationRequired =>
      'Подтверждение email для входа не требуется.';

  @override
  String get smsMigrationEntryAction => 'Уже был SMS-аккаунт? Перенести';

  @override
  String get smsMigrationTitle => 'Перенос SMS-аккаунта';

  @override
  String get smsMigrationDescription =>
      'Войдите один раз по существующему номеру телефона, чтобы сохранить текущий аккаунт и данные, затем добавьте email/пароль.';

  @override
  String get smsMigrationOtpDescription =>
      'Введите SMS-код для вашего существующего аккаунта.';

  @override
  String get linkEmailPasswordTitle => 'Добавить email и пароль';

  @override
  String get linkEmailPasswordDescription =>
      'Вы вошли по телефону. Добавьте email/пароль, чтобы сохранить этот же ID аккаунта для следующих входов.';

  @override
  String get linkEmailPasswordAction => 'Привязать email и пароль';

  @override
  String get enterPhoneNumber => 'Введите номер телефона';

  @override
  String get phoneVerificationDescription =>
      'Мы отправим код подтверждения на ваш номер.';

  @override
  String get phoneNumberLabel => 'Номер телефона';

  @override
  String get phoneNumberHint => '+7 999 000 0000';

  @override
  String get phoneNumberEmpty => 'Пожалуйста, введите номер телефона.';

  @override
  String get phoneNumberInvalid =>
      'Пожалуйста, введите корректный номер телефона.';

  @override
  String get sendCode => 'Отправить код';

  @override
  String get standardRatesDisclaimer =>
      'Могут применяться стандартные тарифы на сообщения и данные.';

  @override
  String get verifyNumber => 'Подтверждение номера';

  @override
  String get enterSixDigitCode => 'Введите 6-значный код';

  @override
  String get verificationCodeSent =>
      'Мы отправили код подтверждения на ваш номер телефона.';

  @override
  String get verificationExpired =>
      'Сессия подтверждения истекла. Пожалуйста, вернитесь и попробуйте снова.';

  @override
  String get verify => 'Подтвердить';

  @override
  String resendCodeIn(int seconds) {
    return 'Отправить код повторно через $seconds сек.';
  }

  @override
  String get resendCode => 'Отправить код повторно';

  @override
  String get setupProfile => 'Настройте профиль';

  @override
  String get chooseDisplayName => 'Выберите имя, видимое вашей семье.';

  @override
  String get displayNameLabel => 'Отображаемое имя';

  @override
  String get displayNameHint => 'напр. Мама, Папа, Даша…';

  @override
  String get displayNameEmpty => 'Пожалуйста, введите отображаемое имя.';

  @override
  String get displayNameTooShort => 'Имя должно содержать не менее 2 символов.';

  @override
  String get changeInSettings =>
      'Вы можете изменить это в любое время в Настройках.';

  @override
  String get getStarted => 'Начать';

  @override
  String get search => 'Поиск';

  @override
  String get settings => 'Настройки';

  @override
  String get newChat => 'Новый чат';

  @override
  String errorLoadingConversations(String error) {
    return 'Ошибка загрузки бесед:\n$error';
  }

  @override
  String get newGroup => 'Новая группа';

  @override
  String get createGroupConversation => 'Создать групповой чат';

  @override
  String get searchByPhoneNumber => 'Поиск по номеру телефона';

  @override
  String get enterPhoneToFind =>
      'Введите номер телефона, чтобы найти членов семьи.';

  @override
  String searchFailed(String error) {
    return 'Ошибка поиска: $error';
  }

  @override
  String get noUsersFound => 'Пользователи не найдены.';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get chat => 'Чат';

  @override
  String get group => 'Группа';

  @override
  String get noConversationsYet => 'Бесед пока нет';

  @override
  String get startConversationPrompt =>
      'Начните личную или групповую беседу с членами вашей семьи.';

  @override
  String get startConversation => 'Начать беседу';

  @override
  String get loading => 'Загрузка...';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get account => 'Аккаунт';

  @override
  String get profile => 'Профиль';

  @override
  String get displayNamePhoto => 'Имя, фото';

  @override
  String get preferences => 'Настройки';

  @override
  String get notifications => 'Уведомления';

  @override
  String get alertsSoundsBadges => 'Оповещения, звуки, значки';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get privacySubtitle => 'Кто может писать вам, отчёты о прочтении';

  @override
  String get language => 'Язык';

  @override
  String get languageSubtitle => 'English, Русский';

  @override
  String get signOut => 'Выйти';

  @override
  String get signOutConfirmTitle => 'Выйти';

  @override
  String get signOutConfirmMessage =>
      'Вы уверены, что хотите выйти? Для повторного входа понадобится email и пароль.';

  @override
  String get cancel => 'Отмена';

  @override
  String get startupPermissionsMissing =>
      'Некоторые разрешения всё ещё не выданы. Включите их в настройках iOS.';

  @override
  String get openSettingsAction => 'Открыть настройки';

  @override
  String get microphonePermissionRequired =>
      'Для голосовых заметок необходимо разрешение на использование микрофона.';

  @override
  String errorGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String sendFailed(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get sayHello => 'Скажите привет!';

  @override
  String get sendingVoiceMessage => 'Отправка голосового сообщения...';

  @override
  String get message => 'Сообщение';

  @override
  String get recording => 'Запись...';

  @override
  String get voiceMessage => 'Голосовое сообщение';

  @override
  String get create => 'Создать';

  @override
  String get groupNameLabel => 'Название группы';

  @override
  String get groupNameHint => 'напр. Семья Осборн';

  @override
  String get groupNameEmpty => 'Пожалуйста, введите название группы.';

  @override
  String get groupNameTooShort =>
      'Название должно содержать не менее 2 символов.';

  @override
  String membersCount(int count) {
    return 'Участники ($count)';
  }

  @override
  String get searchForFamilyMembers =>
      'Найдите членов семьи по номеру телефона.';

  @override
  String get noUsersFoundInstallApp =>
      'Пользователи не найдены. Убедитесь, что у них установлено приложение.';

  @override
  String failedToCreateGroup(String error) {
    return 'Не удалось создать группу: $error';
  }

  @override
  String get addMembersToContinue => 'Добавьте участников для продолжения';

  @override
  String get createGroup => 'Создать группу';

  @override
  String get call => 'Звонок';

  @override
  String get ringing => 'Вызов...';

  @override
  String get connecting => 'Подключение...';

  @override
  String get callEnded => 'Звонок завершён';

  @override
  String get unmute => 'Вкл. микрофон';

  @override
  String get mute => 'Выкл. микрофон';

  @override
  String get speaker => 'Динамик';

  @override
  String get end => 'Завершить';

  @override
  String get video => 'Видео';

  @override
  String get flipCamera => 'Камера';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String get photo => 'Фото';

  @override
  String get videoMessage => 'Видео';

  @override
  String get sendingMedia => 'Отправка медиа...';

  @override
  String get photoFromGallery => 'Фото из галереи';

  @override
  String get videoFromGallery => 'Видео из галереи';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get takeVideo => 'Снять видео';

  @override
  String get compressingVideo => 'Сжатие видео...';

  @override
  String get loadingOlderMessages => 'Загрузка старых сообщений...';
}
