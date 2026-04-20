//
//  WeightSensor.m
//  LidAngleSensor
//

#import "WeightSensor.h"
#import <AppKit/AppKit.h>

static const double kPressureToGrams = 500.0;

@interface WeightSensor ()
@property (nonatomic, assign) double lastPressure;
@property (nonatomic, strong) id localEventMonitor;
@end

@implementation WeightSensor

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastPressure = 0.0;
        [self setupMonitor];
    }
    return self;
}

- (void)dealloc {
    [self stopWeightUpdates];
}

- (BOOL)isAvailable {
    return self.localEventMonitor != nil;
}

- (void)setupMonitor {
    __weak typeof(self) weakSelf = self;
    NSEventMask mask = NSEventMaskPressure | NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged;
    self.localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
        WeightSensor *strongSelf = weakSelf;
        if (!strongSelf) {
            return event;
        }
        if ([event respondsToSelector:@selector(pressure)]) {
            strongSelf.lastPressure = event.pressure;
        }
        return event;
    }];
}

- (double)massGrams {
    if (!self.isAvailable) {
        return -2.0;
    }
    double p = self.lastPressure;
    if (p <= 0.001) {
        return 0.0;
    }
    return p * kPressureToGrams;
}

- (void)stopWeightUpdates {
    if (self.localEventMonitor) {
        [NSEvent removeMonitor:self.localEventMonitor];
        self.localEventMonitor = nil;
    }
}

@end
