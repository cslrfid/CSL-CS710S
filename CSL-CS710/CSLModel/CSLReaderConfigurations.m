//
//  CSLReaderConfigurations.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLReaderConfigurations.h"

@implementation CSLReaderConfigurations

+ (void) setAntennaPortsAndPowerForTags:(BOOL)isInitial {
    [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:3000];
    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
    [[CSLRfidAppEngine sharedAppEngine].reader setRfMode:0 mode:103];

}

+ (void) setAntennaPortsAndPowerForTagAccess:(BOOL)isInitial {
    
    

}

+ (void) setAntennaPortsAndPowerForTagSearch:(BOOL)isInitial {
    

}

+ (void) setConfigurationsForTags {
    [[CSLRfidAppEngine sharedAppEngine].reader SetInventoryRoundControl:0
                                                               InitialQ:7
                                                                   MaxQ:15
                                                                   MinQ:0
                                                          NumMinQCycles:3
                                                             FixedQMode:0
                                                      QIncreaseUseQuery:TRUE
                                                      QDecreaseUseQuery:TRUE
                                                                Session:0
                                                      SelInQueryCommand:0
                                                            QueryTarget:0
                                                          HaltOnAllTags:0
                                                           FastIdEnable:0
                                                         TagFocusEnable:0
                                                MaxQueriesSinceValidEpc:8
                                                           TargetToggle:1];
    [[CSLRfidAppEngine sharedAppEngine].reader setDuplicateEliminationRollingWindow:8];
    [[CSLRfidAppEngine sharedAppEngine].reader setIntraPacketDelay:4];
    [[CSLRfidAppEngine sharedAppEngine].reader setEventPacketUplinkEnable:TRUE InventoryEnd:FALSE CrcError:TRUE TagReadRate:TRUE];
    
}

+ (void) setAntennaPortsAndPowerForTemperatureTags:(BOOL)isInitial {

    
}

+ (void) setConfigurationsForTemperatureTags {
    
    
}

+ (void) setReaderRegionAndFrequencies
{

}

@end
