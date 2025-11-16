//
//  CSLReaderConfigurations.h
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSLRfidAppEngine.h"


NS_ASSUME_NONNULL_BEGIN

@interface CSLReaderConfigurations : NSObject

+ (void) setAntennaPortsAndPowerForTags:(BOOL)isInitial;
+ (void) setAntennaPortsAndPowerForTagAccess:(BOOL)isInitial;
+ (void) setAntennaPortsAndPowerForTagSearch:(BOOL)isInitial;
+ (void) setAntennaPortsAndPowerForTemperatureTags:(BOOL)isInitial;
+ (void) setConfigurationsForTags;
+ (void) setConfigurationsForTags:(BOOL) isLEDEnabled;
+ (void) setConfigurationsForImpinjTags;
+ (void) setConfigurationsForTemperatureTags;
+ (void) setConfigurationsForClearAllSelectionsAndMultibanks;

+ (void) setReaderRegionAndFrequencies;

@end

NS_ASSUME_NONNULL_END
