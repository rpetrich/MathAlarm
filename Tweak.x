#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBRemoteLocalNotificationAlert.h>
#import <CaptainHook/CaptainHook.h>
#import <notify.h>

%config(generator=internal)

static BOOL MAEnabled;
#ifdef PRO_VERSION
static NSInteger MADifficulty;
static NSInteger MAOperator;
static BOOL MAAllowSnooze;
#endif

static BOOL waitingForAnswer;
static NSUInteger answer;
static NSString *alertMessage;
static SBRemoteLocalNotificationAlert *activeAlert;

%hook SBRemoteLocalNotificationAlert

+ (id)presentWithLocalNotification:(id)localNotification application:(SBApplication *)application
{
	return waitingForAnswer ? nil : %orig;
}

+ (void)stopPlayingAlertSoundOrRingtone
{
	if (!waitingForAnswer)
		%orig;
}

static inline BOOL IsMobileTimerAlarm(SBRemoteLocalNotificationAlert *self)
{
//	return [objc_msgSend(self, @selector(alertItemNotificationSender)) isEqualToString:@"Clock"];
	return [[CHIvar(self, _app, SBApplication *) displayIdentifier] isEqualToString:@"com.apple.mobiletimer"];
}

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)actions
{
	if (IsMobileTimerAlarm(self) && MAEnabled) {
		if (!waitingForAnswer) {
			waitingForAnswer = YES;
			NSUInteger a = arc4random();
			NSUInteger b = arc4random();
#ifdef PRO_VERSION
			switch (MADifficulty) {
				case 0:
					a = (a % 10) + 3;
					b = (b % 10) + 3;
					break;
				case 1:
					a = (a % 25) + 4;
					b = (b % 10) + 3;
					break;
				case 2:
#endif
					a = (a % 90) + 11;
					b = (b % 10) + 3;
#ifdef PRO_VERSION
					break;
				case 3:
					a = a % 90 + 11;
					b = b % 90 + 11;
					break;
			}
#endif
			NSString *operatorString;
#ifdef PRO_VERSION
			switch (MAOperator) {
				case 0:
					operatorString = @"+";
					answer = a + b;
					break;
				case 1:
					operatorString = @"-";
					answer = a;
					a = a + b;
					break;
				case 2:
#endif
					operatorString = @"×";
					answer = a * b;
#ifdef PRO_VERSION
					break;
				case 3:
					operatorString = @"÷";
					answer = a;
					a = a * b;
					break;
				default:
					operatorString = nil;
					break;
			}
#endif
			[alertMessage release];
			alertMessage = [[NSString alloc] initWithFormat:@"%d %@ %d = ?", a, operatorString, b];
		}
		UIAlertView *alertView = [self alertSheet];
		alertView.title = @"Alarm";
		if ([[%c(SBAwayController) sharedAwayController] isLocked]) {
			alertView.message = @"Unlock to deactivate";
		} else {
			alertView.message = alertMessage;
			UITextField *textField = [alertView addTextFieldWithValue:nil label:@"Answer"];
			textField.keyboardAppearance = UIKeyboardAppearanceAlert;
			textField.keyboardType = UIKeyboardTypeNumberPad;
			alertView.cancelButtonIndex = [alertView addButtonWithTitle:@"Snooze"];
			[alertView addButtonWithTitle:@"Deactivate"];
			[alertView setNumberOfRows:1];
		}
		[activeAlert autorelease];
		activeAlert = [self retain];
	} else {
		%orig;
	}
}

static void ReactivateAlert()
{
	SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:@"com.apple.mobiletimer"];
	SBRemoteLocalNotificationAlert *newAlert = [[%c(SBRemoteLocalNotificationAlert) ?: %c(SBSystemLocalNotificationAlert) alloc] initWithApplication:app body:nil showActionButton:YES actionLabel:nil];
	if (newAlert) {
		newAlert.delegate = activeAlert.delegate;
		[(SBAlertItemsController *)[%c(SBAlertItemsController) sharedInstance] performSelector:@selector(activateAlertItem:) withObject:newAlert afterDelay:0.0];
	}
	[activeAlert release];
	activeAlert = newAlert;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (IsMobileTimerAlarm(self) && MAEnabled) {
		if ([alertView textFieldCount]) {
			UITextField *textField = [alertView textFieldAtIndex:0];
			[textField resignFirstResponder];
			waitingForAnswer = ![textField.text isEqualToString:[NSString stringWithFormat:@"%d", answer]];
#ifdef PRO_VERSION
			if (waitingForAnswer && (buttonIndex == 0) && MAAllowSnooze)
				waitingForAnswer = NO;
#endif
		} else {
			waitingForAnswer = YES;
		}
		if (waitingForAnswer)
			[(SBRemoteLocalNotificationAlert *)self dismiss:1];
		else
			%orig;
		if (waitingForAnswer)
			ReactivateAlert();
	} else {
		%orig;
	}
}

%new(v@:@)
- (void)didPresentAlertView:(UIAlertView *)alertView
{
	if ([alertView textFieldCount]) {
		UITextField *textField = [alertView textFieldAtIndex:0];
		[textField becomeFirstResponder];
	}
}

%end

%hook SBAwayController 

- (void)_sendLockStateChangedNotification
{
	if (waitingForAnswer && activeAlert) {
		waitingForAnswer = NO;
		[[activeAlert alertSheet] dismissAnimated:NO];
		[activeAlert dismiss:1];
		%orig;
		waitingForAnswer = YES;
		ReactivateAlert();
	} else {
		%orig;
	}
}

%end

@implementation NSObject (MathAlarm)

- (void)mathAlarmTestAlarm
{
	notify_post("com.rpetrich.mathalarm/testalarm");
}

#ifndef PRO_VERSION

- (void)mathAlarmUpgradeToPlus
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.rpetrich.mathalarmplus"]];
}

#endif

@end

static void SettingsCallback()
{
	NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.rpetrich.mathalarm.plist"];
	id temp;
	temp = [settings objectForKey:@"MAEnabled"];
	MAEnabled = temp ? [temp boolValue] : YES;
#ifdef PRO_VERSION
	temp = [settings objectForKey:@"MADifficulty"];
	MADifficulty = temp ? [temp integerValue] : 2;
	temp = [settings objectForKey:@"MAOperator"];
	MAOperator = temp ? [temp integerValue] : 2;
	MAAllowSnooze = [[settings objectForKey:@"MAAllowSnooze"] boolValue];
#endif
	[settings release];
}

%ctor
{
	CHAutoreleasePoolForScope();
	%init(SBRemoteLocalNotificationAlert = objc_getClass("SBRemoteLocalNotificationAlert") ?: objc_getClass("SBSystemLocalNotificationAlert"));
	CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(nc, NULL, (CFNotificationCallback)SettingsCallback, CFSTR("com.rpetrich.mathalarm/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(nc, NULL, (CFNotificationCallback)ReactivateAlert, CFSTR("com.rpetrich.mathalarm/testalarm"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	SettingsCallback();
}