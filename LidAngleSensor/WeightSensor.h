//
//  WeightSensor.h
//  LidAngleSensor
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Estimates mass from Force Touch trackpad pressure (very approximate). Requires contact with the pad.
@interface WeightSensor : NSObject

@property (nonatomic, assign, readonly, getter=isAvailable) BOOL available;

/// Mass in grams (uncalibrated estimate). Returns -2 if pressure monitoring is unavailable.
- (double)massGrams;

- (void)stopWeightUpdates;

@end

NS_ASSUME_NONNULL_END
