import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_pa.dart';

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
    Locale('hi'),
    Locale('pa'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'ReliefNet'**
  String get app_title;

  /// No description provided for @emergency_hotlines.
  ///
  /// In en, this message translates to:
  /// **'Emergency Hotlines'**
  String get emergency_hotlines;

  /// No description provided for @police.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get police;

  /// No description provided for @ambulance.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get ambulance;

  /// No description provided for @fire_brigade.
  ///
  /// In en, this message translates to:
  /// **'Fire Brigade'**
  String get fire_brigade;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @new_reports.
  ///
  /// In en, this message translates to:
  /// **'New Reports'**
  String get new_reports;

  /// No description provided for @task_assigned.
  ///
  /// In en, this message translates to:
  /// **'Task Assigned'**
  String get task_assigned;

  /// No description provided for @task_completed.
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get task_completed;

  /// No description provided for @urgent_only.
  ///
  /// In en, this message translates to:
  /// **'Urgent Only'**
  String get urgent_only;

  /// No description provided for @language_region.
  ///
  /// In en, this message translates to:
  /// **'Language & Region'**
  String get language_region;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @privacy_data.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get privacy_data;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @clear_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clear_cache;

  /// No description provided for @delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account;

  /// No description provided for @help_feedback.
  ///
  /// In en, this message translates to:
  /// **'Help & Feedback'**
  String get help_feedback;

  /// No description provided for @send_feedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get send_feedback;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @app_version.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get app_version;

  /// No description provided for @built_for_gsc.
  ///
  /// In en, this message translates to:
  /// **'Built for Google Solution Challenge'**
  String get built_for_gsc;

  /// No description provided for @select_language.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get select_language;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @active_volunteer.
  ///
  /// In en, this message translates to:
  /// **'You\'re an active volunteer.'**
  String get active_volunteer;

  /// No description provided for @how_can_we_help.
  ///
  /// In en, this message translates to:
  /// **'How can we help you today?'**
  String get how_can_we_help;

  /// No description provided for @report_issue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get report_issue;

  /// No description provided for @need_help_desc.
  ///
  /// In en, this message translates to:
  /// **'Need help? Let us know immediately.'**
  String get need_help_desc;

  /// No description provided for @quick_emergency_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick Emergency Actions'**
  String get quick_emergency_actions;

  /// No description provided for @hospitals.
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get hospitals;

  /// No description provided for @sos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sos;

  /// No description provided for @safety_preparedness.
  ///
  /// In en, this message translates to:
  /// **'Safety & Preparedness'**
  String get safety_preparedness;

  /// No description provided for @community_impact.
  ///
  /// In en, this message translates to:
  /// **'Community Impact'**
  String get community_impact;

  /// No description provided for @active_reports.
  ///
  /// In en, this message translates to:
  /// **'Active Reports'**
  String get active_reports;

  /// No description provided for @pending_tasks.
  ///
  /// In en, this message translates to:
  /// **'Pending Tasks'**
  String get pending_tasks;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @volunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get volunteer;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @apply_as_volunteer.
  ///
  /// In en, this message translates to:
  /// **'Apply as Volunteer'**
  String get apply_as_volunteer;

  /// No description provided for @my_tasks.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Dashboard'**
  String get my_tasks;

  /// No description provided for @application_status.
  ///
  /// In en, this message translates to:
  /// **'Application status'**
  String get application_status;

  /// No description provided for @logout_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logout_confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @make_a_difference.
  ///
  /// In en, this message translates to:
  /// **'Make a Difference'**
  String get make_a_difference;

  /// No description provided for @join_volunteer_desc.
  ///
  /// In en, this message translates to:
  /// **'Join our team of volunteers today!'**
  String get join_volunteer_desc;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// No description provided for @volunteers.
  ///
  /// In en, this message translates to:
  /// **'Volunteers'**
  String get volunteers;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @no_active_reports.
  ///
  /// In en, this message translates to:
  /// **'No active reports. You\'re all caught up!'**
  String get no_active_reports;

  /// No description provided for @no_pending_tasks.
  ///
  /// In en, this message translates to:
  /// **'No pending tasks. Great work!'**
  String get no_pending_tasks;

  /// No description provided for @fill_details_desc.
  ///
  /// In en, this message translates to:
  /// **'Fill in the details below and we\'ll dispatch help quickly.'**
  String get fill_details_desc;

  /// No description provided for @issue_type.
  ///
  /// In en, this message translates to:
  /// **'Issue Type'**
  String get issue_type;

  /// No description provided for @select_issue_type.
  ///
  /// In en, this message translates to:
  /// **'Select issue type'**
  String get select_issue_type;

  /// No description provided for @urgency_level.
  ///
  /// In en, this message translates to:
  /// **'Urgency Level'**
  String get urgency_level;

  /// No description provided for @select_urgency.
  ///
  /// In en, this message translates to:
  /// **'Select urgency'**
  String get select_urgency;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @fetch_location_hint.
  ///
  /// In en, this message translates to:
  /// **'Tap to fetch your location'**
  String get fetch_location_hint;

  /// No description provided for @photos_videos.
  ///
  /// In en, this message translates to:
  /// **'Photos / Videos'**
  String get photos_videos;

  /// No description provided for @add_media.
  ///
  /// In en, this message translates to:
  /// **'Add Photo / Video'**
  String get add_media;

  /// No description provided for @add_more_media.
  ///
  /// In en, this message translates to:
  /// **'Add More'**
  String get add_more_media;

  /// No description provided for @describe_situation_hint.
  ///
  /// In en, this message translates to:
  /// **'Describe the situation in detail...'**
  String get describe_situation_hint;

  /// No description provided for @ai_analysis_preview.
  ///
  /// In en, this message translates to:
  /// **'Get AI Analysis Preview'**
  String get ai_analysis_preview;

  /// No description provided for @refresh_ai_analysis.
  ///
  /// In en, this message translates to:
  /// **'Refresh AI Analysis'**
  String get refresh_ai_analysis;

  /// No description provided for @ai_analyzing.
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing your report...'**
  String get ai_analyzing;

  /// No description provided for @submit_report.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submit_report;

  /// No description provided for @report_submitted.
  ///
  /// In en, this message translates to:
  /// **'Report Submitted!'**
  String get report_submitted;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @copy_id.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get copy_id;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @medical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get medical;

  /// No description provided for @shelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get shelter;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcome_back;

  /// No description provided for @sign_in_desc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue helping your community'**
  String get sign_in_desc;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get sign_in;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @continue_with_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continue_with_google;

  /// No description provided for @dont_have_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dont_have_account;

  /// No description provided for @sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get sign_up;

  /// No description provided for @already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get already_have_account;

  /// No description provided for @create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get create_account;

  /// No description provided for @join_reliefnet_desc.
  ///
  /// In en, this message translates to:
  /// **'Join ReliefNet and make an impact'**
  String get join_reliefnet_desc;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get full_name;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone_number;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirm_password;

  /// No description provided for @re_enter_password.
  ///
  /// In en, this message translates to:
  /// **'Re-enter password'**
  String get re_enter_password;

  /// No description provided for @live_reports.
  ///
  /// In en, this message translates to:
  /// **'Live Reports'**
  String get live_reports;

  /// No description provided for @active_reports_count.
  ///
  /// In en, this message translates to:
  /// **'{count} active reports'**
  String active_reports_count(Object count);

  /// No description provided for @ai_situation_summary.
  ///
  /// In en, this message translates to:
  /// **'AI Situation Summary'**
  String get ai_situation_summary;

  /// No description provided for @analyzing_crisis_data.
  ///
  /// In en, this message translates to:
  /// **'Analyzing current crisis data...'**
  String get analyzing_crisis_data;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @no_reports_found.
  ///
  /// In en, this message translates to:
  /// **'No reports found'**
  String get no_reports_found;

  /// No description provided for @accept_task.
  ///
  /// In en, this message translates to:
  /// **'Accept Task'**
  String get accept_task;

  /// No description provided for @task_accepted_success.
  ///
  /// In en, this message translates to:
  /// **'Task accepted successfully!'**
  String get task_accepted_success;

  /// No description provided for @only_verified_volunteers.
  ///
  /// In en, this message translates to:
  /// **'Only verified NGO volunteers can accept tasks.'**
  String get only_verified_volunteers;

  /// No description provided for @task_completed_desc.
  ///
  /// In en, this message translates to:
  /// **'This task has been completed.'**
  String get task_completed_desc;

  /// No description provided for @go_to_my_tasks.
  ///
  /// In en, this message translates to:
  /// **'Go to My Tasks → Submit Proof'**
  String get go_to_my_tasks;

  /// No description provided for @submit_completion_proof.
  ///
  /// In en, this message translates to:
  /// **'Submit Completion Proof'**
  String get submit_completion_proof;

  /// No description provided for @attach_photo_proof.
  ///
  /// In en, this message translates to:
  /// **'Please attach a photo as proof'**
  String get attach_photo_proof;

  /// No description provided for @add_note.
  ///
  /// In en, this message translates to:
  /// **'Please add a note'**
  String get add_note;

  /// No description provided for @tap_to_attach_photo.
  ///
  /// In en, this message translates to:
  /// **'Tap to attach photo'**
  String get tap_to_attach_photo;

  /// No description provided for @add_note_hint.
  ///
  /// In en, this message translates to:
  /// **'Add a note about what was done...'**
  String get add_note_hint;

  /// No description provided for @proof_submitted.
  ///
  /// In en, this message translates to:
  /// **'Proof submitted! Task marked as completed.'**
  String get proof_submitted;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @ai_analysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get ai_analysis;

  /// No description provided for @open_in_google_maps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get open_in_google_maps;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @no_active_tasks.
  ///
  /// In en, this message translates to:
  /// **'No active tasks right now.'**
  String get no_active_tasks;

  /// No description provided for @no_completed_tasks.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks yet.'**
  String get no_completed_tasks;

  /// No description provided for @no_rejected_tasks.
  ///
  /// In en, this message translates to:
  /// **'No rejected tasks.'**
  String get no_rejected_tasks;

  /// No description provided for @task_id.
  ///
  /// In en, this message translates to:
  /// **'TASK ID'**
  String get task_id;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

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

  /// No description provided for @en_route.
  ///
  /// In en, this message translates to:
  /// **'En Route'**
  String get en_route;

  /// No description provided for @on_site.
  ///
  /// In en, this message translates to:
  /// **'On Site'**
  String get on_site;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @please_login.
  ///
  /// In en, this message translates to:
  /// **'Please login'**
  String get please_login;
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
      <String>['en', 'hi', 'pa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'pa':
      return AppLocalizationsPa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
