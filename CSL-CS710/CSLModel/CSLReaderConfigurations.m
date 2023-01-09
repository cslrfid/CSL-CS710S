//
//  CSLReaderConfigurations.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLReaderConfigurations.h"

@implementation CSLReaderConfigurations

+ (void) setAntennaPortsAndPowerForTags:(BOOL)isInitial {
        
    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:0 PortEnable:TRUE];
    [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:[CSLRfidAppEngine sharedAppEngine].settings.power];
    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
            
}

+ (void) setAntennaPortsAndPowerForTagAccess:(BOOL)isInitial {
    
    

}

+ (void) setAntennaPortsAndPowerForTagSearch:(BOOL)isInitial {
    

}

+ (void) setConfigurationsForTags {
    [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:[CSLRfidAppEngine sharedAppEngine].settings.linkProfile];
    [[CSLRfidAppEngine sharedAppEngine].reader SetInventoryRoundControl:0
                                                               InitialQ:[CSLRfidAppEngine sharedAppEngine].settings.QValue
                                                                   MaxQ:15
                                                                   MinQ:0
                                                          NumMinQCycles:3
                                                             FixedQMode:[CSLRfidAppEngine sharedAppEngine].settings.algorithm == FIXEDQ ? TRUE : FALSE
                                                      QIncreaseUseQuery:TRUE
                                                      QDecreaseUseQuery:TRUE
                                                                Session:[CSLRfidAppEngine sharedAppEngine].settings.session 
                                                      SelInQueryCommand:0
                                                            QueryTarget:[CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target
                                                          HaltOnAllTags:0
                                                           FastIdEnable:[CSLRfidAppEngine sharedAppEngine].settings.FastId
                                                         TagFocusEnable:[CSLRfidAppEngine sharedAppEngine].settings.tagFocus
                                                MaxQueriesSinceValidEpc:8
                                                           TargetToggle:[CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? TRUE : FALSE];
    [[CSLRfidAppEngine sharedAppEngine].reader setDuplicateEliminationRollingWindow:[CSLRfidAppEngine sharedAppEngine].settings.DuplicateEliminiationWindow];
    [[CSLRfidAppEngine sharedAppEngine].reader setIntraPacketDelay:4];
    [[CSLRfidAppEngine sharedAppEngine].reader setEventPacketUplinkEnable:TRUE InventoryEnd:FALSE CrcError:TRUE TagReadRate:TRUE];
    
}

+ (void) setAntennaPortsAndPowerForTemperatureTags:(BOOL)isInitial {

    
}

+ (void) setConfigurationsForTemperatureTags {
    
    
}

+ (void) setReaderRegionAndFrequencies
{
    //frequency configurations
    if ([CSLRfidAppEngine sharedAppEngine].readerRegionFrequency.isFixed) {
        [[CSLRfidAppEngine sharedAppEngine].reader SetFixedChannel:[CSLRfidAppEngine sharedAppEngine].readerRegionFrequency
                                                        RegionCode:[CSLRfidAppEngine sharedAppEngine].settings.region
                                                      channelIndex:[[CSLRfidAppEngine sharedAppEngine].settings.channel intValue]];
    }
    else {
        [[CSLRfidAppEngine sharedAppEngine].reader SetHoppingChannel:[CSLRfidAppEngine sharedAppEngine].readerRegionFrequency
                                                          RegionCode:[CSLRfidAppEngine sharedAppEngine].settings.region];
    }
}

@end
