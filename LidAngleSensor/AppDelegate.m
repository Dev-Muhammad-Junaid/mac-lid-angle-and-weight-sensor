//
//  AppDelegate.m
//  LidAngleSensor
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "CreakAudioEngine.h"
#import "ThereminAudioEngine.h"
#import "NSLabel.h"

typedef NS_ENUM(NSInteger, AudioMode) {
    AudioModeCreak,
    AudioModeTheremin
};

@interface AppDelegate ()
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;
@property (strong, nonatomic) NSLabel *angleLabel;
@property (strong, nonatomic) NSLabel *velocityLabel;
@property (strong, nonatomic) NSLabel *statusLabel;
@property (strong, nonatomic) NSImageView *heroSymbolView;
@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSSegmentedControl *modeSelector;
@property (strong, nonatomic) NSStackView *rootStack;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (nonatomic, assign) AudioMode currentAudioMode;
@end

@implementation AppDelegate

- (nullable NSImage *)systemImage:(NSString *)name {
    if (@available(macOS 11.0, *)) {
        NSImage *base = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:22 weight:NSFontWeightRegular];
        return [base imageWithSymbolConfiguration:cfg];
    }
    return nil;
}

- (nullable NSImage *)systemImage:(NSString *)name pointSize:(CGFloat)pt {
    if (@available(macOS 11.0, *)) {
        NSImage *base = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:pt weight:NSFontWeightMedium];
        return [base imageWithSymbolConfiguration:cfg];
    }
    return nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.currentAudioMode = AudioModeCreak;
    [self createWindow];
    [self initializeLidSensor];
    [self initializeAudioEngines];
    [self startUpdatingDisplay];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.creakAudioEngine stopEngine];
    [self.thereminAudioEngine stopEngine];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)createWindow {
    NSRect windowFrame = NSMakeRect(100, 100, 360, 280);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Lid Angle";
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];

    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    self.window.contentView = contentView;

    self.heroSymbolView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    self.heroSymbolView.image = [self systemImage:@"laptopcomputer" pointSize:28];
    self.heroSymbolView.imageScaling = NSImageScaleProportionallyDown;
    self.heroSymbolView.contentTintColor = NSColor.secondaryLabelColor;
    self.heroSymbolView.translatesAutoresizingMaskIntoConstraints = NO;

    self.angleLabel = [[NSLabel alloc] init];
    self.angleLabel.stringValue = @"…";
    self.angleLabel.font = [NSFont monospacedDigitSystemFontOfSize:44 weight:NSFontWeightLight];
    self.angleLabel.textColor = NSColor.labelColor;
    self.angleLabel.alignment = NSTextAlignmentLeft;

    NSStackView *angleRow = [NSStackView stackViewWithViews:@[self.heroSymbolView, self.angleLabel]];
    angleRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    angleRow.alignment = NSLayoutAttributeCenterY;
    angleRow.spacing = 14;
    angleRow.distribution = NSStackViewDistributionFill;

    [self.heroSymbolView.widthAnchor constraintEqualToConstant:32].active = YES;
    [self.heroSymbolView.heightAnchor constraintEqualToConstant:28].active = YES;

    self.velocityLabel = [[NSLabel alloc] init];
    self.velocityLabel.stringValue = @"0°/s";
    self.velocityLabel.font = [NSFont monospacedDigitSystemFontOfSize:15 weight:NSFontWeightRegular];
    self.velocityLabel.textColor = NSColor.secondaryLabelColor;
    self.velocityLabel.alignment = NSTextAlignmentCenter;

    self.statusLabel = [[NSLabel alloc] init];
    self.statusLabel.stringValue = @"";
    self.statusLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;
    self.statusLabel.alignment = NSTextAlignmentCenter;

    self.modeSelector = [[NSSegmentedControl alloc] init];
    self.modeSelector.segmentCount = 2;
    self.modeSelector.segmentStyle = NSSegmentStyleRounded;
    self.modeSelector.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.modeSelector.selectedSegment = 0;
    self.modeSelector.target = self;
    self.modeSelector.action = @selector(modeChanged:);
    self.modeSelector.translatesAutoresizingMaskIntoConstraints = NO;

    NSImage *creakImg = [self systemImage:@"waveform" pointSize:14];
    NSImage *therImg = [self systemImage:@"music.note" pointSize:14];
    if (creakImg) {
        [self.modeSelector setImage:creakImg forSegment:0];
        [self.modeSelector setLabel:@"" forSegment:0];
    } else {
        [self.modeSelector setLabel:@"Creak" forSegment:0];
    }
    if (therImg) {
        [self.modeSelector setImage:therImg forSegment:1];
        [self.modeSelector setLabel:@"" forSegment:1];
    } else {
        [self.modeSelector setLabel:@"Tone" forSegment:1];
    }
    self.modeSelector.toolTip = @"Sound style";

    self.audioToggleButton = [[NSButton alloc] init];
    self.audioToggleButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.audioToggleButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.audioToggleButton.target = self;
    self.audioToggleButton.action = @selector(toggleAudio:);
    self.audioToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.audioToggleButton.toolTip = @"Play or stop sound";
    [self refreshAudioButtonAppearance];

    NSStackView *controlsRow = [[NSStackView alloc] init];
    controlsRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controlsRow.alignment = NSLayoutAttributeCenterY;
    controlsRow.spacing = 10;
    controlsRow.distribution = NSStackViewDistributionFill;
    [controlsRow addArrangedSubview:self.modeSelector];
    [controlsRow addArrangedSubview:self.audioToggleButton];
    [self.modeSelector setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.audioToggleButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.rootStack = [[NSStackView alloc] init];
    self.rootStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.rootStack.alignment = NSLayoutAttributeCenterX;
    self.rootStack.spacing = 10;
    self.rootStack.edgeInsets = NSEdgeInsetsMake(20, 28, 22, 28);
    self.rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rootStack addArrangedSubview:angleRow];
    [self.rootStack addArrangedSubview:self.velocityLabel];
    [self.rootStack addArrangedSubview:self.statusLabel];
    [self.rootStack setCustomSpacing:18 afterView:self.statusLabel];
    [self.rootStack addArrangedSubview:controlsRow];

    [contentView addSubview:self.rootStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.rootStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.rootStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.rootStack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.rootStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [self.modeSelector.widthAnchor constraintGreaterThanOrEqualToConstant:120],
        [self.audioToggleButton.widthAnchor constraintEqualToConstant:40],
        [self.audioToggleButton.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)refreshAudioButtonAppearance {
    id engine = [self currentAudioEngine];
    BOOL on = engine && [engine isEngineRunning];
    NSImage *img = [self systemImage:(on ? @"speaker.wave.2.fill" : @"speaker.slash") pointSize:16];
    if (img) {
        self.audioToggleButton.image = img;
        self.audioToggleButton.title = @"";
        self.audioToggleButton.imagePosition = NSImageOnly;
    } else {
        self.audioToggleButton.image = nil;
        self.audioToggleButton.title = on ? @"Stop" : @"Play";
        self.audioToggleButton.imagePosition = NSNoImage;
    }
}

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];
    if (self.lidSensor.isAvailable) {
        self.statusLabel.stringValue = @"";
        self.heroSymbolView.contentTintColor = NSColor.controlAccentColor;
    } else {
        self.angleLabel.stringValue = @"—";
        self.angleLabel.textColor = NSColor.systemRedColor;
        self.statusLabel.stringValue = @"No lid sensor";
        self.statusLabel.textColor = NSColor.secondaryLabelColor;
        self.heroSymbolView.contentTintColor = NSColor.systemRedColor;
    }
}

- (void)initializeAudioEngines {
    self.creakAudioEngine = [[CreakAudioEngine alloc] init];
    self.thereminAudioEngine = [[ThereminAudioEngine alloc] init];

    BOOL hasCreak = (self.creakAudioEngine != nil);
    BOOL hasTheremin = (self.thereminAudioEngine != nil);

    if (!hasCreak) {
        [self.modeSelector setEnabled:NO forSegment:0];
    }
    if (!hasTheremin) {
        [self.modeSelector setEnabled:NO forSegment:1];
    }

    if (!hasCreak && hasTheremin) {
        self.currentAudioMode = AudioModeTheremin;
        self.modeSelector.selectedSegment = 1;
    } else if (hasCreak && !hasTheremin) {
        self.currentAudioMode = AudioModeCreak;
        self.modeSelector.selectedSegment = 0;
    }

    if (!hasCreak && !hasTheremin) {
        self.audioToggleButton.enabled = NO;
        self.modeSelector.enabled = NO;
    }
}

- (IBAction)toggleAudio:(id)sender {
    id currentEngine = [self currentAudioEngine];
    if (!currentEngine) {
        return;
    }
    if ([currentEngine isEngineRunning]) {
        [currentEngine stopEngine];
    } else {
        [currentEngine startEngine];
    }
    [self refreshAudioButtonAppearance];
}

- (IBAction)modeChanged:(id)sender {
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    AudioMode newMode = (AudioMode)control.selectedSegment;

    id currentEngine = [self currentAudioEngine];
    BOOL wasRunning = currentEngine && [currentEngine isEngineRunning];
    if (wasRunning) {
        [currentEngine stopEngine];
    }

    self.currentAudioMode = newMode;

    if (wasRunning) {
        id newEngine = [self currentAudioEngine];
        if (newEngine) {
            [newEngine startEngine];
        }
    }
    [self refreshAudioButtonAppearance];
}

- (id)currentAudioEngine {
    switch (self.currentAudioMode) {
        case AudioModeCreak:
            return self.creakAudioEngine;
        case AudioModeTheremin:
            return self.thereminAudioEngine;
        default:
            return self.creakAudioEngine;
    }
}

- (void)startUpdatingDisplay {
    self.updateTimer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                               target:self
                                             selector:@selector(updateAngleDisplay)
                                             userInfo:nil
                                              repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
}

- (void)updateAngleDisplay {
    if (!self.lidSensor.isAvailable) {
        return;
    }

    double angle = [self.lidSensor lidAngle];
    if (angle == -2.0) {
        self.angleLabel.stringValue = @"!";
        self.angleLabel.textColor = NSColor.systemOrangeColor;
        self.statusLabel.stringValue = @"Read error";
        self.statusLabel.textColor = NSColor.systemOrangeColor;
        return;
    }

    self.angleLabel.stringValue = [NSString stringWithFormat:@"%.1f°", angle];
    self.angleLabel.textColor = NSColor.labelColor;
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;

    id currentEngine = [self currentAudioEngine];
    if (currentEngine) {
        [currentEngine updateWithLidAngle:angle];
        double velocity = [currentEngine currentVelocity];
        int v = (int)round(velocity);
        self.velocityLabel.stringValue = [NSString stringWithFormat:@"%d°/s", v];
    }

    NSString *hint;
    if (angle < 5.0) {
        hint = @"Closed";
    } else if (angle < 45.0) {
        hint = @"Ajar";
    } else if (angle < 100.0) {
        hint = @"Open";
    } else {
        hint = @"Wide open";
    }
    self.statusLabel.stringValue = hint;

    [self refreshAudioButtonAppearance];
}

@end
