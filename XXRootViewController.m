#import "XXRootViewController.h" 
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <QuartzCore/QuartzCore.h> 

extern char **environ;

@implementation XXRootViewController

// MARK: - Color Definitions
+ (UIColor *)bgColor { return [UIColor colorWithRed:10.0/255.0 green:10.0/255.0 blue:10.0/255.0 alpha:1.0];} // #0a0a0a
+ (UIColor *)cardColor { return [UIColor colorWithRed:24.0/255.0 green:24.0/255.0 blue:24.0/255.0 alpha:1.0];} // Slightly lighter dark grey #181818
+ (UIColor *)accentColor { return [UIColor colorWithRed:0.0/255.0 green:191.0/255.0 blue:255.0/255.0 alpha:1.0];} // #00bfff Electric Blue
+ (UIColor *)secondaryAccentColor { return [UIColor colorWithRed:68.0/255.0 green:68.0/255.0 blue:68.0/255.0 alpha:1.0];} // #444 Muted Gray
+ (UIColor *)fridaOrangeColor { return [UIColor colorWithRed:240.0/255.0 green:95.0/255.0 blue:64.0/255.0 alpha:1.0];} // #F05F40 Approx Frida Orange
+ (UIColor *)logTagGoodColor { return [UIColor colorWithRed:57.0/255.0 green:255.0/255.0 blue:20.0/255.0 alpha:1.0];} // #39ff14 Neon Green
+ (UIColor *)logTagBadColor { return [UIColor colorWithRed:255.0/255.0 green:77.0/255.0 blue:77.0/255.0 alpha:1.0];} // #ff4d4d Neon Red
+ (UIColor *)logTagInfoColor { return [UIColor colorWithRed:0.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0];} // #00ffff Cyan


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [XXRootViewController bgColor];
    [self setupNavBarTitle];
    [self setupHaptics];
    [self setupUIElements];
    [self setupViewsAndLayout];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
    [self logMessage:@"[~] App Loaded. Fetching status..."];
    [self fetchCurrentPortStatus];
    UIImage *githubIcon = [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"];
    UIBarButtonItem *githubButton = [[UIBarButtonItem alloc] initWithImage:githubIcon
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(githubButtonTapped:)];
    githubButton.tintColor = [XXRootViewController secondaryAccentColor];
    self.navigationItem.rightBarButtonItem = githubButton;
}

// MARK: - Setup Helpers

- (void)setupNavBarTitle {
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] init];
    UIFont *titleFont = [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy];
    [titleString appendAttributedString:[[NSAttributedString alloc] initWithString:@"Frida" attributes:@{
        NSFontAttributeName: titleFont,
        NSForegroundColorAttributeName: [XXRootViewController fridaOrangeColor]
    }]];
    [titleString appendAttributedString:[[NSAttributedString alloc] initWithString:@" Ctrl" attributes:@{
        NSFontAttributeName: titleFont,
        NSForegroundColorAttributeName: [UIColor whiteColor]
    }]];
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.attributedText = titleString;
    [titleLabel sizeToFit];
    self.navigationItem.titleView = titleLabel;
}

- (void)setupHaptics {
    self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self.hapticGenerator prepare];
}

- (void)triggerHapticFeedback {
    [self.hapticGenerator impactOccurred];
    [self.hapticGenerator prepare];
}

- (void)setupUIElements {
    CGFloat cardCornerRadius = 12.0f;

    // --- Card Views ---
    self.portCardView = [self createCardViewWithRadius:cardCornerRadius];
    self.configCardView = [self createCardViewWithRadius:cardCornerRadius];
    self.logCardView = [self createCardViewWithRadius:cardCornerRadius];

    // --- Section 1 Elements ---
    self.currentPortHeaderLabel = [self createHeaderLabelWithText:@"Current Port"];
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Loading...";
    self.statusLabel.textAlignment = NSTextAlignmentLeft;
    self.statusLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self updateStatusLabel:@"Loading..."];


    // --- Section 2/3 Elements ---
    self.configHeaderLabel = [self createHeaderLabelWithText:@"Port Configuration"];

    self.portTextField = [[UITextField alloc] init];
    self.portTextField.placeholder = @"Enter Port...";
    self.portTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.portTextField.borderStyle = UITextBorderStyleNone;
    self.portTextField.layer.cornerRadius = 8.0f;
    self.portTextField.backgroundColor = [XXRootViewController bgColor];
    self.portTextField.textColor = [UIColor whiteColor];
    self.portTextField.textAlignment = NSTextAlignmentCenter;
    self.portTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.portTextField.delegate = self;
    self.portTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter Port..." attributes:@{NSForegroundColorAttributeName: [XXRootViewController secondaryAccentColor]}];
    UIImageView *tfIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left.arrow.right.circle.fill"]];
    tfIconView.tintColor = [XXRootViewController secondaryAccentColor];
    tfIconView.contentMode = UIViewContentModeScaleAspectFit;
    UIView *leftPaddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 35, 20)];
    tfIconView.frame = CGRectMake(10, 0, 20, 20);
    [leftPaddingView addSubview:tfIconView];
    self.portTextField.leftView = leftPaddingView;
    self.portTextField.leftViewMode = UITextFieldViewModeAlways;


    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyButton setTitle:@"Set Custom Port" forState:UIControlStateNormal];
    self.applyButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.applyButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];// Black text on blue bg
    self.applyButton.backgroundColor = [XXRootViewController accentColor];// Electric Blue bg
    self.applyButton.layer.cornerRadius = 8.0f;
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.applyButton addTarget:self action:@selector(applyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];


    self.revertButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.revertButton setTitle:@"Use Default Port" forState:UIControlStateNormal];
    self.revertButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [self.revertButton setTitleColor:[XXRootViewController accentColor] forState:UIControlStateNormal];
    self.revertButton.backgroundColor = [UIColor clearColor];
    self.revertButton.layer.cornerRadius = 8.0f;
    self.revertButton.layer.borderColor = [XXRootViewController accentColor].CGColor;
    self.revertButton.layer.borderWidth = 1.5f;
    self.revertButton.contentEdgeInsets = UIEdgeInsetsMake(8, 15, 8, 15);// (top, left, bottom, right)
    self.revertButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.revertButton addTarget:self action:@selector(revertButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    self.revertInfoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.revertInfoButton setImage:[UIImage systemImageNamed:@"info.circle"] forState:UIControlStateNormal];
    self.revertInfoButton.tintColor = [XXRootViewController secondaryAccentColor];
    self.revertInfoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.revertInfoButton addTarget:self action:@selector(revertInfoButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // --- Section 4 Elements ---
    self.logHeaderLabel = [self createHeaderLabelWithText:@"Logs"];
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.logTextView.textColor = [UIColor whiteColor];
    self.logTextView.backgroundColor = [XXRootViewController bgColor];
    self.logTextView.layer.cornerRadius = 8.0f;
    self.logTextView.editable = NO;
    self.logTextView.selectable = YES;
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearLogsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearLogsButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    [self.clearLogsButton setTitle:@" Clear" forState:UIControlStateNormal];
    self.clearLogsButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.clearLogsButton.tintColor = [XXRootViewController secondaryAccentColor];
    self.clearLogsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearLogsButton addTarget:self action:@selector(clearLogsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // --- Feedback Element ---
    self.feedbackLabel = [[UILabel alloc] init];
    self.feedbackLabel.text = @"";
    self.feedbackLabel.textAlignment = NSTextAlignmentCenter;
    self.feedbackLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.feedbackLabel.textColor = [XXRootViewController secondaryAccentColor];
    self.feedbackLabel.numberOfLines = 0;
    self.feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
}

- (UIView *)createCardViewWithRadius:(CGFloat)radius {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [XXRootViewController cardColor];
    view.layer.cornerRadius = radius;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    // Optional: Add subtle shadow
    // view.layer.shadowColor = [UIColor blackColor].CGColor;
    // view.layer.shadowOffset = CGSizeMake(0, 2);
    // view.layer.shadowRadius = 4.0f;
    // view.layer.shadowOpacity = 0.3f;
    return view;
}

- (UILabel *)createHeaderLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textColor = [XXRootViewController secondaryAccentColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentLeft;
    return label;
}

- (void)revertInfoButtonTapped:(UIButton *)sender {
    [self logMessage:@"[~] Info button tapped."];
    [self triggerHapticFeedback];
    self.feedbackLabel.text = @"Frida default port is 27042";
    self.feedbackLabel.textColor = [XXRootViewController secondaryAccentColor];

    // Optional: Clear the feedback after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Check if the message is still the info message before clearing
        if ([self.feedbackLabel.text isEqualToString:@"Frida default port is 27042"]) {
            self.feedbackLabel.text = @"";
        }
    });
}

- (void)setupViewsAndLayout {
    [self.view addSubview:self.portCardView];
    [self.view addSubview:self.configCardView];
    [self.view addSubview:self.logCardView];
    [self.view addSubview:self.feedbackLabel];

    CGFloat cardPadding = 20.0f;
    CGFloat internalPadding = 15.0f;

    [self.portCardView addSubview:self.currentPortHeaderLabel];
    [self.portCardView addSubview:self.statusLabel];
    [self.configCardView addSubview:self.configHeaderLabel];
    [self.configCardView addSubview:self.portTextField];
    [self.configCardView addSubview:self.applyButton];
    UIStackView *revertStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.revertButton, self.revertInfoButton]];
    revertStack.axis = UILayoutConstraintAxisHorizontal;
    revertStack.spacing = 8;
    revertStack.alignment = UIStackViewAlignmentCenter;
    revertStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.configCardView addSubview:revertStack];
    [self.logCardView addSubview:self.logHeaderLabel];
    [self.logCardView addSubview:self.logTextView];
    [self.logCardView addSubview:self.clearLogsButton];


    // --- NOW Activate All Constraints ---
    [NSLayoutConstraint activateConstraints:@[
        // --- Port Card Layout ---
        [self.portCardView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:cardPadding],
        [self.portCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:cardPadding],
        [self.portCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-cardPadding],
        [self.currentPortHeaderLabel.topAnchor constraintEqualToAnchor:self.portCardView.topAnchor constant:internalPadding],
        [self.currentPortHeaderLabel.leadingAnchor constraintEqualToAnchor:self.portCardView.leadingAnchor constant:internalPadding],
        [self.currentPortHeaderLabel.trailingAnchor constraintEqualToAnchor:self.portCardView.trailingAnchor constant:-internalPadding],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.currentPortHeaderLabel.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.portCardView.leadingAnchor constant:internalPadding],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.portCardView.trailingAnchor constant:-internalPadding],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.portCardView.bottomAnchor constant:-internalPadding],

        // --- Config Card Layout ---
        // Card position relative to previous card / main view
        [self.configCardView.topAnchor constraintEqualToAnchor:self.portCardView.bottomAnchor constant:cardPadding],
        [self.configCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:cardPadding],
        [self.configCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-cardPadding],
        // Internal constraints
        [self.configHeaderLabel.topAnchor constraintEqualToAnchor:self.configCardView.topAnchor constant:internalPadding],
        [self.configHeaderLabel.leadingAnchor constraintEqualToAnchor:self.configCardView.leadingAnchor constant:internalPadding],
        [self.configHeaderLabel.trailingAnchor constraintEqualToAnchor:self.configCardView.trailingAnchor constant:-internalPadding],
        [self.portTextField.topAnchor constraintEqualToAnchor:self.configHeaderLabel.bottomAnchor constant:10],
        [self.portTextField.leadingAnchor constraintEqualToAnchor:self.configCardView.leadingAnchor constant:internalPadding],
        [self.portTextField.trailingAnchor constraintEqualToAnchor:self.configCardView.trailingAnchor constant:-internalPadding],
        [self.portTextField.heightAnchor constraintEqualToConstant:48],
        [self.applyButton.topAnchor constraintEqualToAnchor:self.portTextField.bottomAnchor constant:20],
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.configCardView.leadingAnchor constant:internalPadding],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:self.configCardView.trailingAnchor constant:-internalPadding],
        [self.applyButton.heightAnchor constraintEqualToConstant:44],
        // Revert Button Stack constraints
        [revertStack.topAnchor constraintEqualToAnchor:self.applyButton.bottomAnchor constant:15],
        [revertStack.centerXAnchor constraintEqualToAnchor:self.configCardView.centerXAnchor],
        [revertStack.bottomAnchor constraintEqualToAnchor:self.configCardView.bottomAnchor constant:-internalPadding],

        // --- Log Card Layout ---
         // Card position relative to previous card / main view
        [self.logCardView.topAnchor constraintEqualToAnchor:self.configCardView.bottomAnchor constant:cardPadding],
        [self.logCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:cardPadding],
        [self.logCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-cardPadding],
        [self.logCardView.heightAnchor constraintEqualToConstant:200], // Fixed height for log view card
        // Internal constraints
        [self.logHeaderLabel.topAnchor constraintEqualToAnchor:self.logCardView.topAnchor constant:internalPadding],
        [self.logHeaderLabel.leadingAnchor constraintEqualToAnchor:self.logCardView.leadingAnchor constant:internalPadding],
        [self.clearLogsButton.centerYAnchor constraintEqualToAnchor:self.logHeaderLabel.centerYAnchor],
        [self.clearLogsButton.trailingAnchor constraintEqualToAnchor:self.logCardView.trailingAnchor constant:-internalPadding],
        [self.logHeaderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.clearLogsButton.leadingAnchor constant:-10],
        [self.logTextView.topAnchor constraintEqualToAnchor:self.logHeaderLabel.bottomAnchor constant:10],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:self.logCardView.leadingAnchor constant:internalPadding],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:self.logCardView.trailingAnchor constant:-internalPadding],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:self.logCardView.bottomAnchor constant:-internalPadding],

        // --- Feedback Label Layout ---
        // Position below log card
        [self.feedbackLabel.topAnchor constraintEqualToAnchor:self.logCardView.bottomAnchor constant:15],
        [self.feedbackLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:cardPadding],
        [self.feedbackLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-cardPadding],
    ]];
}

- (void)githubButtonTapped:(id)sender {
    NSLog(@"[FridaCtrlApp] GitHub button tapped.");
    [self triggerHapticFeedback];// Optional haptic
    NSString *repoURLString = @"https://github.com/Xplo8E";
    NSURL *githubURL = [NSURL URLWithString:repoURLString];
    if (!githubURL) {
        NSLog(@"[FridaCtrlApp] Error: Invalid GitHub URL string configured: %@", repoURLString);
        NSString* errorMsg = @"Error: Invalid GitHub URL configured.";
        [self logMessage:[NSString stringWithFormat:@"[-] %@", errorMsg]];
         dispatch_async(dispatch_get_main_queue(), ^{
             self.feedbackLabel.text = errorMsg;
             self.feedbackLabel.textColor = [XXRootViewController logTagBadColor];
         });
        return;
    }

    NSString *alertTitle = @"Made with ❤️ by Xplo8E";
    NSString *alertMessage = @"Tap 'Open Link' to visit the Developer's GitHub.";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                   message:alertMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Open Link"
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"[FridaCtrlApp] User confirmed opening GitHub URL.");
        [self logMessage:@"[~] Opening GitHub page..."];

        [[UIApplication sharedApplication] openURL:githubURL options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                NSLog(@"[FridaCtrlApp] Failed to open GitHub URL after confirmation.");
                NSString* errorMsg = @"Error: Could not open URL.";
                 [self logMessage:[NSString stringWithFormat:@"[-] %@", errorMsg]];
                 dispatch_async(dispatch_get_main_queue(), ^{
                    self.feedbackLabel.text = errorMsg;
                    self.feedbackLabel.textColor = [XXRootViewController logTagBadColor];
                 });
            }
        }];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"[FridaCtrlApp] User cancelled opening GitHub URL.");
        [self logMessage:@"[~] Cancelled opening link."];
    }];

    [alert addAction:openAction];
    [alert addAction:cancelAction];
    dispatch_async(dispatch_get_main_queue(), ^{
         [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)logMessage:(NSString *)originalMessage { 
    dispatch_async(dispatch_get_main_queue(), ^{
        // Safety check for nil input
        if (!originalMessage) return;

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *prefix = @"[~]";// Default info prefix
        UIColor *prefixColor = [XXRootViewController logTagInfoColor];
        NSString *messageToLog = originalMessage;

        if ([originalMessage hasPrefix:@"Error:"]) {
            prefix = @"[-]";
            prefixColor = [XXRootViewController logTagBadColor];
            // Decide if you want to keep "Error: " in the log or strip it
            // messageToLog = [[originalMessage substringFromIndex:(@"Error: ").length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];// Optional: Strip "Error: "
        } else if ([originalMessage hasPrefix:@"[~]"]) {
             prefix = @"[~]";
             prefixColor = [XXRootViewController logTagInfoColor];
             messageToLog = [[originalMessage substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        } else if ([originalMessage hasPrefix:@"[+]"]) {
             prefix = @"[+]";
             prefixColor = [XXRootViewController logTagGoodColor];
             messageToLog = [[originalMessage substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        } else if ([originalMessage hasPrefix:@"[-]"]) {
             prefix = @"[-]";
             prefixColor = [XXRootViewController logTagBadColor];
             messageToLog = [[originalMessage substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] init];
        UIFont *logFont = self.logTextView.font ?: [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];

        // Timestamp (muted gray)
        [logLine appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@] ", timestamp] attributes:@{
            NSFontAttributeName: logFont,
            NSForegroundColorAttributeName: [XXRootViewController secondaryAccentColor]
        }]];
        // Prefix (colored)
         [logLine appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", prefix] attributes:@{
            NSFontAttributeName: logFont, // Consider bold? [UIFont boldSystemFontOfSize:logFont.pointSize]
            NSForegroundColorAttributeName: prefixColor
        }]];
         // Message (Use the potentially modified messageToLog variable)
         [logLine appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", messageToLog] attributes:@{ 
            NSFontAttributeName: logFont,
            NSForegroundColorAttributeName: [UIColor whiteColor] 
        }]];

        if (self.logTextView) {
            NSMutableAttributedString *currentLog = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [currentLog appendAttributedString:logLine];
            self.logTextView.attributedText = currentLog;
            // --- End Append ---

            // --- Scroll to Bottom ---
            if(self.logTextView.text.length > 0 ) {
                NSRange bottom = NSMakeRange(self.logTextView.attributedText.length -1, 1);
                [self.logTextView scrollRangeToVisible:bottom];
            }
            // --- End Scroll ---
        } else {
            // Fallback if text view isn't ready yet
            NSLog(@"[FridaCtrlApp] LogView not ready. Log: %@", logLine.string);
        }
    });
} 


- (void)clearLogsButtonTapped:(UIButton *)sender {
     [self triggerHapticFeedback];
     dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = @"";
        [self logMessage:@"[~] Logs cleared."];
     });
}

// MARK: - Actions
- (void)applyButtonTapped:(UIButton *)sender {
    [self logMessage:@"Apply button tapped."];
    [self triggerHapticFeedback];
    [self dismissKeyboard];
    NSString *portText = self.portTextField.text;
    if (!portText || [portText length] == 0) { [self logMessage:@"[-] Error: Port empty."];self.feedbackLabel.text = @"Error: Enter port.";self.feedbackLabel.textColor = [UIColor systemRedColor];return;}
    NSScanner *scanner = [NSScanner scannerWithString:portText];BOOL isNumeric = [scanner scanInteger:NULL] && [scanner isAtEnd];
    if (!isNumeric) { [self logMessage:@"[-] Error: Port not numeric."];self.feedbackLabel.text = @"Error: Invalid port (digits only).";self.feedbackLabel.textColor = [UIColor systemRedColor];return;}
    int portNumber = [portText intValue];
    if (portNumber <= 0 || portNumber > 65535) { [self logMessage:@"[-] Error: Port out of range."];self.feedbackLabel.text = @"Error: Port must be 1-65535.";self.feedbackLabel.textColor = [UIColor systemRedColor];return;}

    self.feedbackLabel.text = @"Processing...";self.feedbackLabel.textColor = [UIColor systemGrayColor];
    [self logMessage:[NSString stringWithFormat:@"[~] Calling helper: --set-port %@", portText]];
    NSArray *args = @[@"--set-port", portText];
    [self callHelperToolAndUpdateUI:args];
}

- (void)revertButtonTapped:(UIButton *)sender {
    [self logMessage:@"Revert button tapped."];
    [self triggerHapticFeedback];
    [self dismissKeyboard];
    self.feedbackLabel.text = @"Processing...";self.feedbackLabel.textColor = [UIColor systemGrayColor];
    [self logMessage:@"[~] Calling helper: --revert-default"];
    NSArray *args = @[@"--revert-default"];
    [self callHelperToolAndUpdateUI:args];
}

- (void)dismissKeyboard { [self.view endEditing:YES];}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self dismissKeyboard];return YES;}

- (void)updateStatusLabel:(NSString *)statusText {
     NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
     NSString *prefix = @"";
     UIColor *prefixColor = [UIColor systemGrayColor];// Default color for "Loading/Error/Invalid"

     if ([statusText containsString:@"Default"]) {
         prefix = @"🟢 ";// Green circle SF Symbol
         prefixColor = [XXRootViewController logTagGoodColor];
     } else if ([statusText containsString:@"Current Port:"] && ![statusText containsString:@"Error"] && ![statusText containsString:@"Invalid"] && ![statusText containsString:@"Loading"]) {
         // Assume custom port if contains "Current Port:" and no error keywords
         prefix = @"🟠 ";
         prefixColor = [UIColor systemOrangeColor];
     }
     if (prefix.length > 0) {
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:prefix attributes:@{ NSForegroundColorAttributeName: prefixColor }]];
     }

     [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:statusText attributes:@{
         NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightMedium],
         NSForegroundColorAttributeName: [UIColor whiteColor] // White text on dark card
     }]];

     self.statusLabel.attributedText = attributedString;
}


- (int)runProcessWithArguments:(NSArray<NSString *> *)arguments
                 standardOutput:(NSData * __autoreleasing *)standardOutput // ARC bridge
                  standardError:(NSData * __autoreleasing *)standardError  // ARC bridge
{
    // Find Helper Path
    NSString *actualHelperPath = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *rootlessHelperPath = @"/var/jb/usr/bin/fridactrlhelper";
    if ([fileManager fileExistsAtPath:rootlessHelperPath]) { actualHelperPath = rootlessHelperPath;}
    else {
        NSString *rootfulHelperPath = @"/usr/bin/fridactrlhelper";
        if ([fileManager fileExistsAtPath:rootfulHelperPath]) { actualHelperPath = rootfulHelperPath;}
    }
    if (!actualHelperPath) {
        NSString *errorMsg = @"Error: Helper tool not found. Reinstall package?";
        if (standardError) *standardError = [errorMsg dataUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"[FridaCtrlApp] %@", errorMsg);return -1;
    }
    NSLog(@"[FridaCtrlApp] Using helper: %@", actualHelperPath);
    const char *cPath = [actualHelperPath fileSystemRepresentation];

    // Variable Setup
    int ret = 0;int status = -1;pid_t pid = -1;
    posix_spawn_file_actions_t file_actions;
    int pipe_stdout[2] = {-1, -1};int pipe_stderr[2] = {-1, -1};
    const char **argv = NULL;
    NSMutableData *outData = nil;NSMutableData *errData = nil;// Declare before potential goto
    if (standardOutput) *standardOutput = nil;if (standardError) *standardError = nil;

    // Prepare argv
    size_t argc = arguments.count + 1;
    argv = (const char **)calloc(argc + 1, sizeof(char *));
    if (!argv) { NSLog(@"[FridaCtrlApp] Failed alloc argv");ret = ENOMEM;goto cleanup_capture;}
    argv[0] = cPath;
    for (size_t i = 0;i < arguments.count;++i) { argv[i + 1] = [arguments[i] fileSystemRepresentation];}
    argv[argc] = NULL;

    // Prepare file actions and pipes
    ret = posix_spawn_file_actions_init(&file_actions);
    if (ret != 0) { NSLog(@"[FridaCtrlApp] actions_init failed: %s", strerror(ret));goto cleanup_capture;}
    if (pipe(pipe_stdout) != 0 || pipe(pipe_stderr) != 0) { perror("[FridaCtrlApp] pipe() failed");ret = errno;goto cleanup_capture;}
    ret = posix_spawn_file_actions_adddup2(&file_actions, pipe_stdout[1], STDOUT_FILENO);if (ret != 0) goto cleanup_capture;
    ret = posix_spawn_file_actions_adddup2(&file_actions, pipe_stderr[1], STDERR_FILENO);if (ret != 0) goto cleanup_capture;
    ret = posix_spawn_file_actions_addclose(&file_actions, pipe_stdout[0]);if (ret != 0) goto cleanup_capture;
    ret = posix_spawn_file_actions_addclose(&file_actions, pipe_stderr[0]);if (ret != 0) goto cleanup_capture;
    ret = posix_spawn_file_actions_addclose(&file_actions, pipe_stdout[1]);if (ret != 0) goto cleanup_capture;
    ret = posix_spawn_file_actions_addclose(&file_actions, pipe_stderr[1]);if (ret != 0) goto cleanup_capture;

    // Spawn
    ret = posix_spawn(&pid, cPath, &file_actions, NULL, (char* const*)argv, environ);

    // Post-spawn cleanup in parent
    posix_spawn_file_actions_destroy(&file_actions);
    if (pipe_stdout[1] != -1) { close(pipe_stdout[1]);pipe_stdout[1] = -1;}
    if (pipe_stderr[1] != -1) { close(pipe_stderr[1]);pipe_stderr[1] = -1;}
    free(argv);argv = NULL;

    if (ret != 0) { // Handle spawn failure
        NSLog(@"[FridaCtrlApp] posix_spawn failed: %s", strerror(ret));
        if (pipe_stdout[0] != -1) close(pipe_stdout[0]);
        if (pipe_stderr[0] != -1) close(pipe_stderr[0]);
        return -1;
    }
    NSLog(@"[FridaCtrlApp] Launched PID: %d", pid);

    // Read output - Initialize data objects HERE
    outData = [NSMutableData data];errData = [NSMutableData data];
    char buffer[1024];ssize_t bytesRead;
    while ((bytesRead = read(pipe_stdout[0], buffer, sizeof(buffer))) > 0) { [outData appendBytes:buffer length:bytesRead];}
    while ((bytesRead = read(pipe_stderr[0], buffer, sizeof(buffer))) > 0) { [errData appendBytes:buffer length:bytesRead];}
    close(pipe_stdout[0]);pipe_stdout[0] = -1;// Close read ends
    close(pipe_stderr[0]);pipe_stderr[0] = -1;

    // Assign captured data
    if (standardOutput) *standardOutput = [outData copy];
    if (standardError) *standardError = [errData copy];

    // Wait for child
    NSLog(@"[FridaCtrlApp] Waiting for PID: %d", pid);
    pid_t waitedPid = waitpid(pid, &status, 0);
    if (waitedPid == -1) { perror("[FridaCtrlApp] waitpid failed");return -1;}

    if (WIFEXITED(status)) { // Normal exit
        int exitStatus = WEXITSTATUS(status);
        NSLog(@"[FridaCtrlApp] PID %d exited normally with status: %d", pid, exitStatus);
        return exitStatus;
    } else if (WIFSIGNALED(status)) { // Crashed on signal
        int signal = WTERMSIG(status);
        NSLog(@"[FridaCtrlApp] PID %d terminated by signal: %d", pid, signal);
        return -2;// Use distinct code for signal termination
    } else { // Other abnormal exit
         NSLog(@"[FridaCtrlApp] PID %d exited abnormally (Unknown Status: %d).", pid, status);
    }

    return -3;// Generic abnormal exit code

cleanup_capture: // Label for errors during setup before spawn
    NSLog(@"[FridaCtrlApp] Cleanup after setup error %d: %s", ret, strerror(ret));
    if (argv) free(argv);
    // file_actions might not be init'd, but destroy is usually safe
    posix_spawn_file_actions_destroy(&file_actions);
    if (pipe_stdout[0] != -1) close(pipe_stdout[0]);if (pipe_stdout[1] != -1) close(pipe_stdout[1]);
    if (pipe_stderr[0] != -1) close(pipe_stderr[0]);if (pipe_stderr[1] != -1) close(pipe_stderr[1]);
    if (standardOutput) *standardOutput = nil;if (standardError) *standardError = nil;
    return -1;// Indicate error during setup
}

// Wrapper: Calls the helper tool and updates the UI based on the result
- (void)callHelperToolAndUpdateUI:(NSArray<NSString *> *)arguments {
     NSData * __autoreleasing outputData = nil;
     NSData * __autoreleasing errorData = nil;

     // NSLog(@"[FridaCtrlApp] Calling helper with args: %@", [arguments componentsJoinedByString:@" "]);

     int status = [self runProcessWithArguments:arguments
                           standardOutput:&outputData
                            standardError:&errorData];

     NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
     NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];

     // Log helper results
     NSLog(@"[FridaCtrlApp] Helper returned status: %d", status);
     if (outputString && outputString.length > 0) NSLog(@"[FridaCtrlApp] Helper stdout:\n%@", outputString);
     if (errorString && errorString.length > 0) NSLog(@"[FridaCtrlApp] Helper stderr:\n%@", errorString);

     // Update UI on main thread
     dispatch_async(dispatch_get_main_queue(), ^{
         if (status == 0) {
             NSString *successMsg = @"[+] Operation successful!";
              if (outputString && [outputString containsString:@"Operation completed successfully"]) {
                 self.feedbackLabel.text = @"Operation successful!";
             } else {
                  self.feedbackLabel.text = @"Success";
                  successMsg = @"[+] Success (No specific msg).";
             }
             self.feedbackLabel.textColor = [XXRootViewController logTagGoodColor];
             [self logMessage:successMsg];// Log success
             // Refresh the displayed status after successful action
             [self fetchCurrentPortStatus];
         } else {
              // Construct error message for UI feedback label
              NSString *displayError = @"Error: Operation failed.";
              if (errorString && errorString.length > 0) { // Prefer stderr
                 displayError = [errorString stringByReplacingOccurrencesOfString:@"[FridaCtrlHelper] Error: " withString:@""];
                 displayError = [NSString stringWithFormat:@"Error: %@", [displayError stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
              } else if (outputString && outputString.length > 0) { // Use stdout if stderr empty
                 displayError = [NSString stringWithFormat:@"Info: %@", [outputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
              } else { // Generic code
                  displayError = [NSString stringWithFormat:@"Error: Failed (Code: %d)", status];
              }
              self.feedbackLabel.text = displayError;
              self.feedbackLabel.textColor = [XXRootViewController logTagBadColor];
               [self logMessage:[NSString stringWithFormat:@"[-] %@", displayError]];// Log the error
              // Refresh status even on failure
              [self fetchCurrentPortStatus];
         }
         // Clear input field after any action attempt
         self.portTextField.text = @"";
     });
}


// Fetches status from helper using --get-status and updates the statusLabel
- (void)fetchCurrentPortStatus {
    // Log only in debug console, not user log view
    NSLog(@"[FridaCtrlApp] Fetching current port status...");
    dispatch_async(dispatch_get_main_queue(), ^{
         [self updateStatusLabel:@"Loading..."];// Update status label via helper
         // self.feedbackLabel.text = @"";// Clear feedback during status fetch
    });

    NSArray *args = @[@"--get-status"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData * __autoreleasing outputData = nil;
        NSData * __autoreleasing errorData = nil;

        int status = [self runProcessWithArguments:args
                              standardOutput:&outputData
                               standardError:&errorData];

        NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *logStatus = @"";
            NSString *statusText = @"Error";// Default to error

            if (status == 0 && outputString) { // Success and got output
                NSString *trimmedOutput = [outputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                if ([trimmedOutput isEqualToString:@"default"]) {
                    statusText = @"Default (27042)";
                } else { // Check if output is a valid port number
                    NSScanner *scanner = [NSScanner scannerWithString:trimmedOutput];
                    BOOL isNumeric = [scanner scanInteger:NULL] && [scanner isAtEnd];
                    if (isNumeric) {
                        statusText = [NSString stringWithFormat:@"%@", trimmedOutput];// Just the port number
                    } else { // Invalid output from helper
                         NSLog(@"[FridaCtrlApp] Error: Invalid status from helper: %@", trimmedOutput);
                         statusText = @"Invalid";
                         logStatus = [NSString stringWithFormat:@"[-] Error: Invalid status from helper: %@", trimmedOutput];
                    }
                }
                if (logStatus.length == 0) logStatus = [NSString stringWithFormat:@"[~] Status updated: %@", statusText];

            } else { // Helper failed during get-status
                 NSString *errMsg = errorString ?: @"<No Stderr>";
                 logStatus = [NSString stringWithFormat:@"[-] Error fetching status (Code: %d): %@", status, errMsg];
                 statusText = @"Error";
                 self.feedbackLabel.text = [NSString stringWithFormat:@"Error fetching status (Code: %d)", status];
                 self.feedbackLabel.textColor = [XXRootViewController logTagBadColor];
            }
             [self updateStatusLabel:statusText];
             [self logMessage:logStatus];
        });
    });
}

@end