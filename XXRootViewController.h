#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Make sure XX matches your class prefix if different
@interface XXRootViewController : UIViewController <UITextFieldDelegate>


@property (class, nonatomic, readonly) UIColor *bgColor;
@property (class, nonatomic, readonly) UIColor *cardColor;
@property (class, nonatomic, readonly) UIColor *accentColor; // Electric Blue
@property (class, nonatomic, readonly) UIColor *secondaryAccentColor; // Muted Gray
@property (class, nonatomic, readonly) UIColor *fridaOrangeColor;
@property (class, nonatomic, readonly) UIColor *logTagGoodColor; // Green
@property (class, nonatomic, readonly) UIColor *logTagBadColor; // Red
@property (class, nonatomic, readonly) UIColor *logTagInfoColor; // Cyan
@property (nonatomic, strong) UIView *portCardView;
@property (nonatomic, strong) UIView *configCardView;
@property (nonatomic, strong) UIView *logCardView;
@property (nonatomic, strong) UILabel *currentPortHeaderLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *configHeaderLabel;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIButton *revertButton;
@property (nonatomic, strong) UIButton *revertInfoButton; // Hint only for now
@property (nonatomic, strong) UILabel *logHeaderLabel;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIButton *clearLogsButton;
@property (nonatomic, strong) UILabel *feedbackLabel;
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticGenerator;

@end

NS_ASSUME_NONNULL_END