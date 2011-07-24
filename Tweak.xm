#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBRemoteLocalNotificationAlert.h>
#import <CaptainHook/CaptainHook.h>
#import <notify.h>

static BOOL MAEnabled;
static NSInteger MADifficulty;
static NSInteger MAOperator;

static BOOL waitingForAnswer;
static BOOL lockScreen;
static NSUInteger answer;
static NSString *alertMessage;
static SBRemoteLocalNotificationAlert *activeAlert;

%hook SBRemoteLocalNotificationAlert

+ (void)stopPlayingAlertSoundOrRingtone
{
	if (!waitingForAnswer)
		%orig;
}

static inline BOOL IsMobileTimerAlarm(SBRemoteLocalNotificationAlert *self)
{
	return [[CHIvar(self, _app, SBApplication *) displayIdentifier] isEqualToString:@"com.apple.mobiletimer"];
}

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)actions
{
	if (IsMobileTimerAlarm(self)) {
		if (!waitingForAnswer) {
			waitingForAnswer = YES;
			NSUInteger a = arc4random();
			NSUInteger b = arc4random();
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
					a = (a % 90) + 11;
					b = (b % 10) + 3;
					break;
				case 3:
					a = a % 90 + 11;
					b = b % 90 + 11;
					break;
			}
			NSString *operatorString;
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
					operatorString = @"×";
					answer = a * b;
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
			[alertMessage release];
			alertMessage = [[NSString alloc] initWithFormat:@"%d %@ %d = ?", a, operatorString, b];
		}
		UIAlertView *alertView = [self alertSheet];
		alertView.title = @"Alarm";
		if (lockScreen) {
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
	SBRemoteLocalNotificationAlert *newAlert = [[%c(SBRemoteLocalNotificationAlert) alloc] initWithApplication:app body:nil showActionButton:YES actionLabel:nil];
	newAlert.delegate = activeAlert.delegate;
	[activeAlert release];
	activeAlert = newAlert;
	[(SBAlertItemsController *)[%c(SBAlertItemsController) sharedInstance] activateAlertItem:activeAlert];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (IsMobileTimerAlarm(self)) {
		UITextField *textField = [alertView textFieldAtIndex:0];
		[textField resignFirstResponder];
		waitingForAnswer = ![textField.text isEqualToString:[NSString stringWithFormat:@"%d", answer]];
		if (waitingForAnswer)
			[self dismiss:1];
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
	UITextField *textField = [alertView textFieldAtIndex:0];
	[textField becomeFirstResponder];
}

%end

%hook SBAwayController 

- (void)lock
{
	lockScreen = YES;
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

- (void)_finishedUnlockAttemptWithStatus:(BOOL)status
{
	lockScreen = NO;
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

@end

static void SettingsCallback()
{
	NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.rpetrich.mathalarm.plist"];
	id temp;
	temp = [settings objectForKey:@"MAEnabled"];
	MAEnabled = temp ? [temp boolValue] : YES;
	temp = [settings objectForKey:@"MADifficulty"];
	MADifficulty = temp ? [temp integerValue] : 2;
	temp = [settings objectForKey:@"MAOperator"];
	MAOperator = temp ? [temp integerValue] : 2;
	[settings release];
}

%ctor
{
	CHAutoreleasePoolForScope();
	CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(nc, NULL, (CFNotificationCallback)SettingsCallback, CFSTR("com.rpetrich.mathalarm/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(nc, NULL, (CFNotificationCallback)ReactivateAlert, CFSTR("com.rpetrich.mathalarm/testalarm"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	SettingsCallback();
}