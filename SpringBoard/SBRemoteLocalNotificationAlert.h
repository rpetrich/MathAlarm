#import <SpringBoard/SBAlertItem.h>

@protocol SBRemoteLocalNotificationAlertDelegate;
@interface SBRemoteLocalNotificationAlert : SBAlertItem {
@private
	id<SBRemoteLocalNotificationAlertDelegate> _delegate;
	SBApplication *_app;
	NSString *_body;
	NSString *_actionLabel;
	NSString *_customLockLabel;
	NSString *_alertLaunchImage;
	BOOL _showActionButton;
	BOOL _hideTitle;
	BOOL _allowSnooze;
	NSTimer *_ringtoneAutoMuteTimer;
	unsigned _launchButtonIndex;
	unsigned _snoozeButtonIndex;
	id _context;
}
@property(assign, nonatomic) id<SBRemoteLocalNotificationAlertDelegate> delegate;
@property(assign, nonatomic) BOOL hideTitle;
@property(assign, nonatomic) BOOL allowSnooze;
@property(retain, nonatomic) NSString *customLockLabel;
@property(retain, nonatomic) NSString *alertLaunchImage;
@property(retain, nonatomic) id context;
- (id)initWithApplication:(SBApplication *)application body:(NSString *)body showActionButton:(BOOL)button actionLabel:(NSString *)label;
- (Class)alertSheetClass;
- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)actions;
- (void)dismiss:(int)reason;
@end

