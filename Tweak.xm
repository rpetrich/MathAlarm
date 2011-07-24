#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBRemoteLocalNotificationAlert.h>
#import <CaptainHook/CaptainHook.h>

static BOOL waitingForAnswer;
static BOOL lockScreen;
static NSInteger answer;
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
			NSInteger a = arc4random() % 90 + 11;
			NSInteger b = arc4random() % 10 + 3;
			answer = a * b;
			[alertMessage release];
			alertMessage = [[NSString alloc] initWithFormat:@"%d × %d = ?", a, b];
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

static inline void ReactivateAlert()
{
	SBRemoteLocalNotificationAlert *newAlert = [[[activeAlert class] alloc] initWithApplication:CHIvar(activeAlert, _app, SBApplication *) body:nil showActionButton:YES actionLabel:nil];
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
