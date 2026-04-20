//
//  AppDelegate.m
//  LidAngleSensor
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "WeightSensor.h"
#import "CreakAudioEngine.h"
#import "ThereminAudioEngine.h"
#import "NSLabel.h"

typedef NS_ENUM(NSInteger, AudioMode) {
    AudioModeCreak,
    AudioModeTheremin
};

static NSString *const kMasterVolumeDefaultsKey = @"LidAngleMasterVolume";

@interface AppDelegate ()
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) WeightSensor *weightSensor;
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;

@property (strong, nonatomic) NSStackView *rootStack;
@property (strong, nonatomic) NSStackView *metricRow;
@property (strong, nonatomic) NSStackView *lidColumn;
@property (strong, nonatomic) NSStackView *weightColumn;
@property (strong, nonatomic) NSBox *columnDivider;
@property (strong, nonatomic) NSLayoutConstraint *columnEqualWidth;

@property (strong, nonatomic) NSLabel *angleLabel;
@property (strong, nonatomic) NSLabel *velocityLabel;
@property (strong, nonatomic) NSLabel *statusLabel;
@property (strong, nonatomic) NSLabel *weightLabel;
@property (strong, nonatomic) NSPopUpButton *weightUnitPopUp;

@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSSegmentedControl *modeSelector;
@property (strong, nonatomic) NSSlider *volumeSlider;
@property (strong, nonatomic) NSLabel *volumeValueLabel;

@property (strong, nonatomic) NSTimer *updateTimer;
@property (nonatomic, assign) AudioMode currentAudioMode;

/// Avoid relayout thrash: only update labels when values actually change.
@property (nonatomic, assign) NSInteger audioPlayButtonStateCache;
@property (copy, nonatomic) NSString *lastStatusHintShown;
@property (nonatomic, assign) NSInteger lastVelocityShown;
@property (copy, nonatomic) NSString *lastWeightTextShown;
@property (nonatomic, assign) NSInteger lastAngleTenthsShown;
@end

@implementation AppDelegate

#pragma mark - SF Symbols

- (nullable NSImage *)systemImage:(NSString *)name fallback:(NSString *)fallbackName pointSize:(CGFloat)pt {
    if (@available(macOS 11.0, *)) {
        NSImage *base = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        if (!base && fallbackName) {
            base = [NSImage imageWithSystemSymbolName:fallbackName accessibilityDescription:nil];
        }
        if (!base) {
            return nil;
        }
        NSImageSymbolConfiguration *cfg;
        if (@available(macOS 12.0, *)) {
            cfg = [NSImageSymbolConfiguration configurationWithPointSize:pt weight:NSFontWeightMedium scale:NSImageSymbolScaleMedium];
        } else {
            cfg = [NSImageSymbolConfiguration configurationWithPointSize:pt weight:NSFontWeightMedium];
        }
        return [base imageWithSymbolConfiguration:cfg];
    }
    return nil;
}

- (nullable NSImage *)systemImage:(NSString *)name pointSize:(CGFloat)pt {
    return [self systemImage:name fallback:nil pointSize:pt];
}

#pragma mark - Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.currentAudioMode = AudioModeCreak;
    self.audioPlayButtonStateCache = -2;
    self.lastVelocityShown = NSIntegerMin;
    self.lastAngleTenthsShown = NSIntegerMin;
    self.weightSensor = [[WeightSensor alloc] init];
    [self createWindow];
    [self initializeLidSensor];
    [self configureWeightUI];
    [self initializeAudioEngines];
    [self startUpdatingDisplay];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.weightSensor stopWeightUpdates];
    [self.creakAudioEngine stopEngine];
    [self.thereminAudioEngine stopEngine];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - Window layout

- (void)createWindow {
    NSRect windowFrame = NSMakeRect(80, 80, 720, 360);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Lid Angle Sensor";
    self.window.minSize = NSMakeSize(560, 320);
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];

    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    self.window.contentView = contentView;

    NSFont *valueFont = [NSFont monospacedDigitSystemFontOfSize:36 weight:NSFontWeightLight];
    NSFont *secondaryFont = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    NSFont *statusFont = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];

    self.angleLabel = [[NSLabel alloc] init];
    self.angleLabel.stringValue = @"…";
    self.angleLabel.font = valueFont;
    self.angleLabel.textColor = NSColor.labelColor;
    self.angleLabel.alignment = NSTextAlignmentLeft;
    self.angleLabel.maximumNumberOfLines = 1;
    self.angleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.angleLabel.widthAnchor constraintEqualToConstant:200].active = YES;

    self.velocityLabel = [[NSLabel alloc] init];
    self.velocityLabel.stringValue = @"0°/s";
    self.velocityLabel.font = secondaryFont;
    self.velocityLabel.textColor = NSColor.secondaryLabelColor;
    self.velocityLabel.alignment = NSTextAlignmentLeft;
    self.velocityLabel.maximumNumberOfLines = 1;

    self.statusLabel = [[NSLabel alloc] init];
    self.statusLabel.stringValue = @"";
    self.statusLabel.font = statusFont;
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;
    self.statusLabel.alignment = NSTextAlignmentLeft;
    self.statusLabel.maximumNumberOfLines = 1;

    self.weightLabel = [[NSLabel alloc] init];
    self.weightLabel.stringValue = @"—";
    self.weightLabel.font = valueFont;
    self.weightLabel.textColor = NSColor.labelColor;
    self.weightLabel.alignment = NSTextAlignmentLeft;
    self.weightLabel.maximumNumberOfLines = 1;
    self.weightLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.weightLabel.widthAnchor constraintEqualToConstant:200].active = YES;

    self.weightUnitPopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.weightUnitPopUp addItemsWithTitles:@[@"g", @"kg", @"lb", @"oz"]];
    self.weightUnitPopUp.target = self;
    self.weightUnitPopUp.action = @selector(weightUnitChanged:);
    self.weightUnitPopUp.toolTip = @"Unit";
    self.weightUnitPopUp.font = secondaryFont;

    self.lidColumn = [[NSStackView alloc] init];
    self.lidColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.lidColumn.alignment = NSLayoutAttributeLeading;
    self.lidColumn.spacing = 8;
    self.lidColumn.edgeInsets = NSEdgeInsetsMake(0, 0, 0, 12);
    [self.lidColumn addArrangedSubview:self.angleLabel];
    [self.lidColumn addArrangedSubview:self.velocityLabel];
    [self.lidColumn addArrangedSubview:self.statusLabel];

    self.weightColumn = [[NSStackView alloc] init];
    self.weightColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.weightColumn.alignment = NSLayoutAttributeLeading;
    self.weightColumn.spacing = 8;
    self.weightColumn.edgeInsets = NSEdgeInsetsMake(0, 12, 0, 0);
    [self.weightColumn addArrangedSubview:self.weightLabel];
    [self.weightColumn addArrangedSubview:self.weightUnitPopUp];

    self.columnDivider = [[NSBox alloc] init];
    self.columnDivider.boxType = NSBoxSeparator;
    self.columnDivider.translatesAutoresizingMaskIntoConstraints = NO;

    self.metricRow = [[NSStackView alloc] init];
    self.metricRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.metricRow.alignment = NSLayoutAttributeTop;
    self.metricRow.spacing = 0;
    self.metricRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.metricRow addArrangedSubview:self.lidColumn];
    [self.metricRow addArrangedSubview:self.columnDivider];
    [self.metricRow addArrangedSubview:self.weightColumn];
    [self.lidColumn setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.weightColumn setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.columnDivider.widthAnchor constraintEqualToConstant:1].active = YES;

    self.columnEqualWidth = [self.lidColumn.widthAnchor constraintEqualToAnchor:self.weightColumn.widthAnchor];

    self.modeSelector = [[NSSegmentedControl alloc] init];
    self.modeSelector.segmentCount = 2;
    self.modeSelector.segmentStyle = NSSegmentStyleRounded;
    self.modeSelector.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.modeSelector.selectedSegment = 0;
    self.modeSelector.target = self;
    self.modeSelector.action = @selector(modeChanged:);
    self.modeSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSelector.toolTip = @"Creak vs alien tone";

    NSImage *creakImg = [self systemImage:@"waveform" pointSize:14];
    if (creakImg) {
        [self.modeSelector setImage:creakImg forSegment:0];
        [self.modeSelector setLabel:@"" forSegment:0];
    } else {
        [self.modeSelector setLabel:@"Creak" forSegment:0];
    }
    [self.modeSelector setImage:nil forSegment:1];
    [self.modeSelector setLabel:@"👽" forSegment:1];
    [self.modeSelector setWidth:48 forSegment:1];
    [self.modeSelector setWidth:48 forSegment:0];

    self.audioToggleButton = [[NSButton alloc] init];
    self.audioToggleButton.bezelStyle = NSBezelStyleShadowlessSquare;
    self.audioToggleButton.bordered = NO;
    self.audioToggleButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.audioToggleButton.target = self;
    self.audioToggleButton.action = @selector(toggleAudio:);
    self.audioToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.audioToggleButton.toolTip = @"Play or stop sound";
    [self updateAudioPlayButtonIfNeeded];
    [self.audioToggleButton.widthAnchor constraintEqualToConstant:40].active = YES;
    [self.audioToggleButton.heightAnchor constraintEqualToConstant:32].active = YES;

    self.volumeSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.volumeSlider.minValue = 0.0;
    self.volumeSlider.maxValue = 1.0;
    self.volumeSlider.doubleValue = 1.0;
    self.volumeSlider.target = self;
    self.volumeSlider.action = @selector(volumeSliderChanged:);
    self.volumeSlider.toolTip = @"Output level";
    self.volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;

    self.volumeValueLabel = [[NSLabel alloc] init];
    self.volumeValueLabel.stringValue = @"100%";
    self.volumeValueLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.volumeValueLabel.textColor = NSColor.tertiaryLabelColor;
    self.volumeValueLabel.alignment = NSTextAlignmentRight;
    [self.volumeValueLabel.widthAnchor constraintEqualToConstant:36].active = YES;

    NSStackView *audioRow = [[NSStackView alloc] init];
    audioRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    audioRow.alignment = NSLayoutAttributeCenterY;
    audioRow.spacing = 10;
    audioRow.distribution = NSStackViewDistributionFill;
    [audioRow addArrangedSubview:self.modeSelector];
    [audioRow addArrangedSubview:self.audioToggleButton];
    [audioRow addArrangedSubview:self.volumeSlider];
    [audioRow addArrangedSubview:self.volumeValueLabel];
    [self.volumeSlider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.rootStack = [[NSStackView alloc] init];
    self.rootStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.rootStack.alignment = NSLayoutAttributeWidth;
    self.rootStack.spacing = 16;
    self.rootStack.edgeInsets = NSEdgeInsetsMake(20, 24, 20, 24);
    self.rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rootStack addArrangedSubview:self.metricRow];
    [self.rootStack addArrangedSubview:audioRow];

    [contentView addSubview:self.rootStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.rootStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.rootStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.rootStack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.rootStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
    ]];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:kMasterVolumeDefaultsKey] != nil) {
        self.volumeSlider.doubleValue = [defs doubleForKey:kMasterVolumeDefaultsKey];
    } else {
        self.volumeSlider.doubleValue = 1.0;
    }
    [self updateVolumePercentLabel];
}

#pragma mark - Audio UI

/// Speaker-only play button; only mutates UI when play/stop state changes (prevents layout thrash at 60 Hz while tilting).
- (void)updateAudioPlayButtonIfNeeded {
    id engine = [self currentAudioEngine];
    BOOL on = engine && [engine isEngineRunning];
    NSInteger code = on ? 1 : 0;
    if (code == self.audioPlayButtonStateCache) {
        return;
    }
    self.audioPlayButtonStateCache = code;

    NSImage *img = [self systemImage:(on ? @"speaker.wave.3.fill" : @"speaker.slash")
                             fallback:(on ? @"speaker.wave.2.fill" : @"speaker.slash")
                              pointSize:16];
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

- (void)updateVolumePercentLabel {
    int pct = (int)llround(self.volumeSlider.doubleValue * 100.0);
    self.volumeValueLabel.stringValue = [NSString stringWithFormat:@"%d%%", pct];
}

- (void)applyMasterOutputVolume {
    float v = (float)self.volumeSlider.doubleValue;
    if (self.creakAudioEngine) {
        [self.creakAudioEngine setMasterOutputVolume:v];
    }
    if (self.thereminAudioEngine) {
        [self.thereminAudioEngine setMasterOutputVolume:v];
    }
}

- (IBAction)volumeSliderChanged:(id)sender {
    (void)sender;
    [self updateVolumePercentLabel];
    [[NSUserDefaults standardUserDefaults] setDouble:self.volumeSlider.doubleValue forKey:kMasterVolumeDefaultsKey];
    [self applyMasterOutputVolume];
}

#pragma mark - Weight

- (void)configureWeightUI {
    BOOL ok = self.weightSensor.isAvailable;
    self.weightColumn.hidden = !ok;
    self.columnDivider.hidden = !ok;
    self.columnEqualWidth.active = ok;
    self.weightUnitPopUp.enabled = ok;
    if (!ok) {
        self.weightLabel.stringValue = @"";
    }
}

- (NSInteger)massUnitIndex {
    return self.weightUnitPopUp.indexOfSelectedItem;
}

- (NSString *)formattedMassFromGrams:(double)g {
    NSInteger u = [self massUnitIndex];
    switch (u) {
        case 0:
            return [NSString stringWithFormat:@"%.1f g", g];
        case 1:
            return [NSString stringWithFormat:@"%.3f kg", g / 1000.0];
        case 2:
            return [NSString stringWithFormat:@"%.3f lb", g / 453.59237];
        case 3:
            return [NSString stringWithFormat:@"%.2f oz", g / 28.349523125];
        default:
            return @"—";
    }
}

- (IBAction)weightUnitChanged:(id)sender {
    (void)sender;
}

#pragma mark - Sensors & engines

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];
    if (self.lidSensor.isAvailable) {
        self.statusLabel.stringValue = @"";
    } else {
        self.angleLabel.stringValue = @"—";
        self.angleLabel.textColor = NSColor.systemRedColor;
        self.statusLabel.stringValue = @"No lid sensor on this Mac.";
        self.statusLabel.textColor = NSColor.secondaryLabelColor;
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
        self.volumeSlider.enabled = NO;
    }

    [self applyMasterOutputVolume];
    self.audioPlayButtonStateCache = -2;
    [self updateAudioPlayButtonIfNeeded];
}

- (IBAction)toggleAudio:(id)sender {
    (void)sender;
    id currentEngine = [self currentAudioEngine];
    if (!currentEngine) {
        return;
    }
    if ([currentEngine isEngineRunning]) {
        [currentEngine stopEngine];
    } else {
        [currentEngine startEngine];
        [self applyMasterOutputVolume];
    }
    self.audioPlayButtonStateCache = -2;
    [self updateAudioPlayButtonIfNeeded];
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
            [self applyMasterOutputVolume];
        }
    }
    self.audioPlayButtonStateCache = -2;
    [self updateAudioPlayButtonIfNeeded];
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
        self.lastStatusHintShown = nil;
        self.lastVelocityShown = NSIntegerMin;
        self.lastAngleTenthsShown = NSIntegerMin;
        return;
    }

    int angleTenths = (int)lround(angle * 10.0);
    if (angleTenths != self.lastAngleTenthsShown) {
        self.lastAngleTenthsShown = angleTenths;
        self.angleLabel.stringValue = [NSString stringWithFormat:@"%.1f°", angle];
    }
    self.angleLabel.textColor = NSColor.labelColor;
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;

    id currentEngine = [self currentAudioEngine];
    if (currentEngine) {
        [currentEngine updateWithLidAngle:angle];
        double velocity = [currentEngine currentVelocity];
        int v = (int)round(velocity);
        if (v != self.lastVelocityShown) {
            self.lastVelocityShown = v;
            self.velocityLabel.stringValue = [NSString stringWithFormat:@"%d°/s", v];
        }
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
    if (![hint isEqualToString:self.lastStatusHintShown]) {
        self.lastStatusHintShown = [hint copy];
        self.statusLabel.stringValue = hint;
    }

    if (!self.weightColumn.isHidden) {
        double g = [self.weightSensor massGrams];
        NSString *wtext = (g < -1.5) ? @"—" : [self formattedMassFromGrams:g];
        if (![wtext isEqualToString:self.lastWeightTextShown]) {
            self.lastWeightTextShown = [wtext copy];
            self.weightLabel.stringValue = wtext;
        }
    }

    [self updateAudioPlayButtonIfNeeded];
}

@end
