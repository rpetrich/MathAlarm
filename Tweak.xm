#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

%hook SBRemoteLocalNotificationAlert

static BOOL waitingForAnswer;
static BOOL lockScreen;
static NSInteger answer;

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
		waitingForAnswer = YES;
		UIAlertView *alertView = [self alertSheet];
		alertView.title = @"Alarm";
		NSInteger a = arc4random() % 90 + 11;
		NSInteger b = arc4random() % 10 + 3;
		alertView.message = [NSString stringWithFormat:@"%d × %d = ?", a, b];
		answer = a * b;
		UITextField *textField = [alertView addTextFieldWithValue:nil label:@"Answer"];
		textField.keyboardAppearance = UIKeyboardAppearanceAlert;
		textField.keyboardType = UIKeyboardTypeNumberPad;
		alertView.cancelButtonIndex = [alertView addButtonWithTitle:@"Snooze"];
		[alertView addButtonWithTitle:@"Deactivate"];
		[alertView setNumberOfRows:1];
                if(lockScreen) {
        	      window1 = [[UIWindow alloc] init];
    	              window1.frame = CGRectMake(0.0, 0.0, 0.0, 0.0);
    		      window1.windowLevel = UIWindowLevelAlert;
    		      [window1 makeKeyAndVisible];
		}
	} else {
		%orig;
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (IsMobileTimerAlarm(self)) {
		UITextField *textField = [alertView textFieldAtIndex:0];
		waitingForAnswer = ![textField.text isEqualToString:[NSString stringWithFormat:@"%d", answer]];
		if (waitingForAnswer)
			return;
	}

	if(lockScreen) {
		[window1 resignKeyWindow];
		[window1 release];
	}
	%orig;
}

%new(v@:@i)
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (IsMobileTimerAlarm(self) && waitingForAnswer)
		[alertView performSelector:@selector(show) withObject:nil afterDelay:0.0];
}

%new(v@:@)
- (void)didPresentAlertView:(UIAlertView *)alertView
{
	UITextField *textField = [alertView textFieldAtIndex:0];
	[textField becomeFirstResponder];
}

- (void)willDeactivateForReason:(NSInteger)reason
{
	if (!IsMobileTimerAlarm(self) || !waitingForAnswer)
		%orig;
}

- (void)dismiss:(NSInteger)reason
{
	if (!IsMobileTimerAlarm(self) || !waitingForAnswer)
		%orig;
}

%end

%hook SBAwayController 
- (void) lock {
	lockScreen = YES;
        %orig;
}

- (void)_finishedUnlockAttemptWithStatus:(BOOL)status
{
	lockScreen = NO;
        %orig;
}
%end