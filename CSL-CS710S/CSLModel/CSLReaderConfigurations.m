//
//  CSLReaderConfigurations.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLReaderConfigurations.h"

@implementation CSLReaderConfigurations

+ (void) setAntennaPortsAndPowerForTags:(BOOL)isInitial {
    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108) {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        if([CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel == 0) {
            //use global settings
            [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:TRUE
                                                          InventoryMode:0
                                                          InventoryAlgo:0
                                                                 StartQ:0
                                                            ProfileMode:0
                                                                Profile:0
                                                          FrequencyMode:0
                                                       FrequencyChannel:0
                                                           isEASEnabled:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
            
            if (isInitial) {
                //disable all other ports
                for (int i=1;i<16;i++) {
                    [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:FALSE
                                                                  InventoryMode:0
                                                                  InventoryAlgo:0
                                                                         StartQ:0
                                                                    ProfileMode:0
                                                                        Profile:0
                                                                  FrequencyMode:0
                                                               FrequencyChannel:0
                                                                   isEASEnabled:0];
                }
            }
        }
        else {
            //iterate through all the power level
            for (int i=0;i<16;i++) {
                int dwell=[[CSLRfidAppEngine sharedAppEngine].settings.dwellTime[i] intValue];
                //enforcing dwell time != 0 when tag focus is enabled
                if ([CSLRfidAppEngine sharedAppEngine].settings.tagFocus) {
                    dwell=2000;
                }
                [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                NSLog(@"Power level %d: %@", i, (i >= [CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel) ? @"OFF" : @"ON");
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:((i >= [CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel) ? FALSE : TRUE)
                                                              InventoryMode:0
                                                              InventoryAlgo:0
                                                                     StartQ:0
                                                                ProfileMode:0
                                                                    Profile:0
                                                              FrequencyMode:0
                                                           FrequencyChannel:0
                                                               isEASEnabled:0];
                [[CSLRfidAppEngine sharedAppEngine].reader setPower:[[CSLRfidAppEngine sharedAppEngine].settings.powerLevel[i] intValue] / 10];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:dwell];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:dwell == 0 ? 65535 : 0];
            }
        }
    }
    else if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS463){
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        //iterate through all the power level
        for (int i=0;i<4;i++) {
            int dwell=[[CSLRfidAppEngine sharedAppEngine].settings.dwellTime[i] intValue];
            //enforcing dwell time != 0 when tag focus is enabled
            if ([CSLRfidAppEngine sharedAppEngine].settings.tagFocus) {
                dwell=2000;
            }
            [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
            NSLog(@"Antenna %d: %@", i, [(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue] ? @"ON" : @"OFF");
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:[(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue]
                                                          InventoryMode:0
                                                          InventoryAlgo:0
                                                                 StartQ:0
                                                            ProfileMode:0
                                                                Profile:0
                                                          FrequencyMode:0
                                                       FrequencyChannel:0
                                                           isEASEnabled:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:[[CSLRfidAppEngine sharedAppEngine].settings.powerLevel[i] intValue] / 10];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:dwell];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:dwell == 0 ? 65535 : 0];
        }
    }
    else
    {
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetAntennaConfig:0 PortEnable:TRUE TargetToggle:[CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB];
        [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetInventoryRoundControl:0
                                                                       InitialQ:[CSLRfidAppEngine sharedAppEngine].settings.QValue
                                                                           MaxQ:15
                                                                           MinQ:0
                                                                  NumMinQCycles:3
                                                                     FixedQMode:[CSLRfidAppEngine sharedAppEngine].settings.algorithm == FIXEDQ ? TRUE : FALSE
                                                              QIncreaseUseQuery:TRUE
                                                              QDecreaseUseQuery:TRUE
                                                                        Session:[CSLRfidAppEngine sharedAppEngine].settings.session
                                                              SelInQueryCommand:([CSLRfidAppEngine sharedAppEngine].settings.FastId || [CSLRfidAppEngine sharedAppEngine].settings.prefilterIsEnabled) ? SL : ALL
                                                                    QueryTarget:[CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target
                                                                  HaltOnAllTags:0
                                                                   FastIdEnable:[CSLRfidAppEngine sharedAppEngine].settings.FastId
                                                                 TagFocusEnable:[CSLRfidAppEngine sharedAppEngine].settings.tagFocus
                                                        MaxQueriesSinceValidEpc:8
                                                                   TargetToggle:[CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? TRUE : FALSE];
    }

}

+ (void) setAntennaPortsAndPowerForTagAccess:(BOOL)isInitial {
        
    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108) {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        //disable power level ramping
        [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:TRUE
                                                      InventoryMode:0
                                                      InventoryAlgo:0
                                                             StartQ:0
                                                        ProfileMode:0
                                                            Profile:0
                                                      FrequencyMode:0
                                                   FrequencyChannel:0
                                                       isEASEnabled:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
        //disable all other ports
        if (isInitial) {
            for (int i=1;i<16;i++) {
                [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:FALSE
                                                              InventoryMode:0
                                                              InventoryAlgo:0
                                                                     StartQ:0
                                                                ProfileMode:0
                                                                    Profile:0
                                                              FrequencyMode:0
                                                           FrequencyChannel:0
                                                               isEASEnabled:0];
            }
        }
    }
    else if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS463) {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        //enable power output on selected port
        for (int i=0;i<4;i++) {
            [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
            NSLog(@"Antenna %d: %@", i, [(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue] ? @"ON" : @"OFF");
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:[CSLRfidAppEngine sharedAppEngine].settings.tagAccessPort == i ? true : false
                                                          InventoryMode:0
                                                          InventoryAlgo:0
                                                                 StartQ:0
                                                            ProfileMode:0
                                                                Profile:0
                                                          FrequencyMode:0
                                                       FrequencyChannel:0
                                                           isEASEnabled:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
        }
    }
    else
    {
        //CS710
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetAntennaConfig:0 PortEnable:TRUE TargetToggle:TRUE];
        [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetInventoryRoundControl:0
                                                                       InitialQ:0
                                                                           MaxQ:0
                                                                           MinQ:0
                                                                  NumMinQCycles:0
                                                                     FixedQMode:FIXEDQ
                                                              QIncreaseUseQuery:TRUE
                                                              QDecreaseUseQuery:TRUE
                                                                        Session:S0
                                                              SelInQueryCommand:SL
                                                                    QueryTarget:A
                                                                  HaltOnAllTags:0
                                                                   FastIdEnable:[CSLRfidAppEngine sharedAppEngine].settings.FastId
                                                                 TagFocusEnable:[CSLRfidAppEngine sharedAppEngine].settings.tagFocus
                                                        MaxQueriesSinceValidEpc:8
                                                                   TargetToggle:TRUE];
    }

}

+ (void) setAntennaPortsAndPowerForTagSearch:(BOOL)isInitial {
    
    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108) {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        //disable power level ramping
        [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:TRUE
                                                      InventoryMode:0
                                                      InventoryAlgo:0
                                                             StartQ:0
                                                        ProfileMode:0
                                                            Profile:0
                                                      FrequencyMode:0
                                                   FrequencyChannel:0
                                                       isEASEnabled:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
        //disable all other ports
        if (isInitial) {
            for (int i=1;i<16;i++) {
                [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:FALSE
                                                              InventoryMode:0
                                                              InventoryAlgo:0
                                                                     StartQ:0
                                                                ProfileMode:0
                                                                    Profile:0
                                                              FrequencyMode:0
                                                           FrequencyChannel:0
                                                               isEASEnabled:0];
            }
        }
    }
    else if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108) {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];
        //enable power output on selected port
        for (int i=0;i<4;i++) {
            [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
            NSLog(@"Antenna %d: %@", i, [(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue] ? @"ON" : @"OFF");
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:[(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue]
                                                          InventoryMode:0
                                                          InventoryAlgo:0
                                                                 StartQ:0
                                                            ProfileMode:0
                                                                Profile:0
                                                          FrequencyMode:0
                                                       FrequencyChannel:0
                                                           isEASEnabled:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
            [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
        }
    }
    else
    {
        //CS710S
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetAntennaConfig:0 PortEnable:TRUE TargetToggle:TRUE];
        [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetInventoryRoundControl:0
                                                                       InitialQ:[CSLRfidAppEngine sharedAppEngine].settings.QValue
                                                                           MaxQ:15
                                                                           MinQ:0
                                                                  NumMinQCycles:3
                                                                     FixedQMode:FIXEDQ
                                                              QIncreaseUseQuery:TRUE
                                                              QDecreaseUseQuery:TRUE
                                                                        Session:S0
                                                              SelInQueryCommand:SL
                                                                    QueryTarget:A
                                                                  HaltOnAllTags:0
                                                                   FastIdEnable:[CSLRfidAppEngine sharedAppEngine].settings.FastId
                                                                 TagFocusEnable:[CSLRfidAppEngine sharedAppEngine].settings.tagFocus
                                                        MaxQueriesSinceValidEpc:8
                                                                   TargetToggle:TRUE];
    }

}
+ (void) setConfigurationsForClearAllSelectionsAndMultibanks {
    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS710) {
        
        //for multiplebank selection
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:0
                                                                 IsEnabled:FALSE
                                                                      Bank:[CSLRfidAppEngine sharedAppEngine].settings.multibank1
                                                                    Offset:[CSLRfidAppEngine sharedAppEngine].settings.multibank1Offset
                                                                    Length:[CSLRfidAppEngine sharedAppEngine].settings.multibank1Length];
        
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:1
                                                                 IsEnabled:FALSE
                                                                      Bank:[CSLRfidAppEngine sharedAppEngine].settings.multibank2
                                                                    Offset:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Offset
                                                                    Length:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Length];
        
        //for tag selections
        for (int i=0;i<7;i++) {
            [[CSLRfidAppEngine sharedAppEngine].reader E710DeselectTag:i];
        }
        
    }
    
}

+ (void) setConfigurationsForTags {
    //LED tag is disabled by default
    [self setConfigurationsForTags:FALSE];
}

+ (void) setConfigurationsForTags:(BOOL) isLEDEnabled {

    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108 ||
        [CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS463)  {
        //set inventory configurations
        //for multiplebank inventory
        Byte tagRead=0;
        if (isLEDEnabled) {
            tagRead=1;
        }
        else if ([CSLRfidAppEngine sharedAppEngine].settings.isMultibank1Enabled && [CSLRfidAppEngine sharedAppEngine].settings.isMultibank2Enabled)
            tagRead=2;
        else if ([CSLRfidAppEngine sharedAppEngine].settings.isMultibank1Enabled)
            tagRead=1;
        else
            tagRead=0;
        
        Byte tagDelay=0;
        if (![CSLRfidAppEngine sharedAppEngine].settings.tagFocus && tagRead) {
            tagDelay=30;
        }
        
        
        [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target) querySession:[CSLRfidAppEngine sharedAppEngine].settings.session querySelect:ALL];
        [[CSLRfidAppEngine sharedAppEngine].reader selectAlgorithmParameter:[CSLRfidAppEngine sharedAppEngine].settings.algorithm];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters0:[CSLRfidAppEngine sharedAppEngine].settings.QValue maximumQ:15 minimumQ:0 ThresholdMultiplier:4];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters1:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters2:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? true : false) RunTillZero:false];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:tagRead crcErrorRead:(tagRead ? 0 : 1) QTMode:0 tagDelay:tagDelay inventoryMode:(tagRead ? 0 : 1)];
        [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:[CSLRfidAppEngine sharedAppEngine].settings.linkProfile];
        
        //prefilter
        if ([CSLRfidAppEngine sharedAppEngine].settings.prefilterIsEnabled || isLEDEnabled) {
            
            int maskOffset=0;
            if ([CSLRfidAppEngine sharedAppEngine].settings.prefilterBank == EPC)
                maskOffset=32;
            [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target) querySession:[CSLRfidAppEngine sharedAppEngine].settings.session querySelect:SL];
            [[CSLRfidAppEngine sharedAppEngine].reader clearAllTagSelect];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:[CSLRfidAppEngine sharedAppEngine].settings.prefilterBank
                                                                 maskPointer:[CSLRfidAppEngine sharedAppEngine].settings.prefilterOffset + maskOffset
                                                                  maskLength:((UInt32)([[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask length] * 4))
                                                                    maskData:(NSData*)[CSLBleReader convertHexStringToData:[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask]
                                                                  sel_action:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:1 /* force tag_select */ disableInventory:0 tagRead:tagRead crcErrorRead:true QTMode:0 tagDelay:(tagRead ? 30 : 0) inventoryMode:(tagRead ? 0 : 1)];
            
            if (isLEDEnabled)  {
                [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target) querySession:[CSLRfidAppEngine sharedAppEngine].settings.session querySelect:SL];
                [[CSLRfidAppEngine sharedAppEngine].reader clearAllTagSelect];
                [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:1];
                [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID
                                                                     maskPointer:0
                                                                      maskLength:24
                                                                        maskData:[CSLBleReader convertHexStringToData:@"E201E2"]
                                                                      sel_action:0];
                [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:1 /* force tag_select */ disableInventory:0 tagRead:tagRead crcErrorRead:true QTMode:0 tagDelay:(tagRead ? 30 : 0) inventoryMode:(tagRead ? 0 : 1)];
                
            }
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader clearAllTagSelect];
        }
        
        //postfilter
        if ([CSLRfidAppEngine sharedAppEngine].settings.postfilterIsEnabled) {
            
            //Pad one hex digit if mask length is odd
            NSString* maskString = [CSLRfidAppEngine sharedAppEngine].settings.postfilterMask;
            if ([[CSLRfidAppEngine sharedAppEngine].settings.postfilterMask length] % 2 != 0) {
                maskString = [NSString stringWithFormat:@"%@%@", [CSLRfidAppEngine sharedAppEngine].settings.postfilterMask, @"0"];
            }
            
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchSelect:0x00];
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchConfiguration:true
                                                                        matchOn:[CSLRfidAppEngine sharedAppEngine].settings.postfilterIsNotMatchMaskEnabled
                                                                    matchLength:[[CSLRfidAppEngine sharedAppEngine].settings.postfilterMask length] * 4
                                                                    matchOffset:[CSLRfidAppEngine sharedAppEngine].settings.postfilterOffset];
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchMask:((UInt32)([[CSLRfidAppEngine sharedAppEngine].settings.postfilterMask length] * 4))
                                                              maskData:(NSData*)[CSLBleReader convertHexStringToData:maskString]];
            
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchSelect:0x00];
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchConfiguration:false
                                                                        matchOn:false
                                                                    matchLength:0x0000
                                                                    matchOffset:0x0000];
        }
        
        
        if ([CSLRfidAppEngine sharedAppEngine].settings.FastId) {
            [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target) querySession:[CSLRfidAppEngine sharedAppEngine].settings.session querySelect:SL];
//            [[CSLRfidAppEngine sharedAppEngine].reader clearAllTagSelect];
//            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
//            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID maskPointer:0 maskLength:24 maskData:[CSLBleReader convertHexStringToData:@"E2801100"] sel_action:0];
            [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:1 /* force tag_select */ disableInventory:0 tagRead:tagRead crcErrorRead:true QTMode:0 tagDelay:(tagRead ? 30 : 0) inventoryMode:(tagRead ? 0 : 1)];
        }
        
        if (isLEDEnabled) {
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_BANK:USER acc_bank2:0];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_PTR:112];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_CNT:1 secondBank:0];
        }
        else {
            // if multibank read is enabled
            if (tagRead) {
                [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_BANK:[CSLRfidAppEngine sharedAppEngine].settings.multibank1 acc_bank2:[CSLRfidAppEngine sharedAppEngine].settings.multibank2];
                [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_PTR:([CSLRfidAppEngine sharedAppEngine].settings.multibank2Offset << 16) + [CSLRfidAppEngine sharedAppEngine].settings.multibank1Offset];
                [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_CNT:(tagRead ? [CSLRfidAppEngine sharedAppEngine].settings.multibank1Length : 0) secondBank:(tagRead==2 ? [CSLRfidAppEngine sharedAppEngine].settings.multibank2Length : 0)];
            }
        }
        NSLog(@"Tag focus value: %d", [CSLRfidAppEngine sharedAppEngine].settings.tagFocus);
        //Impinj Extension
        [[CSLRfidAppEngine sharedAppEngine].reader setImpinjExtension:[CSLRfidAppEngine sharedAppEngine].settings.tagFocus
                                                               fastId:[CSLRfidAppEngine sharedAppEngine].settings.FastId
                                                       blockWriteMode:0];
        //LNA settings
        [[CSLRfidAppEngine sharedAppEngine].reader setLNAParameters:[CSLRfidAppEngine sharedAppEngine].reader
                                                      rflnaHighComp:[CSLRfidAppEngine sharedAppEngine].settings.rfLnaHighComp
                                                          rflnaGain:[CSLRfidAppEngine sharedAppEngine].settings.rfLna
                                                          iflnaGain:[CSLRfidAppEngine sharedAppEngine].settings.ifLna
                                                          ifagcGain:[CSLRfidAppEngine sharedAppEngine].settings.ifAgc];
    }
    else
    {
        //for multiplebank inventory
        //skip settings for LED tags
        if (!isLEDEnabled) {
            [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:0
                                                                     IsEnabled:[CSLRfidAppEngine sharedAppEngine].settings.isMultibank1Enabled
                                                                          Bank:[CSLRfidAppEngine sharedAppEngine].settings.multibank1
                                                                        Offset:[CSLRfidAppEngine sharedAppEngine].settings.multibank1Offset
                                                                        Length:[CSLRfidAppEngine sharedAppEngine].settings.multibank1Length];
            
            [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:1
                                                                     IsEnabled:[CSLRfidAppEngine sharedAppEngine].settings.isMultibank2Enabled && [CSLRfidAppEngine sharedAppEngine].settings.isMultibank2Enabled
                                                                          Bank:[CSLRfidAppEngine sharedAppEngine].settings.multibank2
                                                                        Offset:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Offset
                                                                        Length:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Length];
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:0
                                                                     IsEnabled:TRUE
                                                                          Bank:USER
                                                                        Offset:112
                                                                        Length:1];
            
            [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:1
                                                                     IsEnabled:FALSE
                                                                          Bank:0
                                                                        Offset:0
                                                                        Length:0];
        }
        
        //enforce link profile 244 for LED tags
        if (isLEDEnabled)
            [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:MID_244];
        else
            [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:[CSLRfidAppEngine sharedAppEngine].settings.linkProfile];
        
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetDuplicateEliminationRollingWindow:[CSLRfidAppEngine sharedAppEngine].settings.DuplicateEliminiationWindow];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetIntraPacketDelay:4];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetEventPacketUplinkEnable:TRUE InventoryEnd:FALSE CrcError:TRUE TagReadRate:TRUE];
        
        
        //prefilter
        if ([CSLRfidAppEngine sharedAppEngine].settings.prefilterIsEnabled) {
            
            int maskOffset=0;
            if ([CSLRfidAppEngine sharedAppEngine].settings.prefilterBank == EPC)
                maskOffset=32;
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:0 /*+ ([CSLRfidAppEngine sharedAppEngine].settings.FastId ? 1 : 0)*/
                       maskBank:[CSLRfidAppEngine sharedAppEngine].settings.prefilterBank
                    maskPointer:[CSLRfidAppEngine sharedAppEngine].settings.prefilterOffset + maskOffset
                     maskLength:[[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask length] * 4
                       maskData:[CSLBleReader convertHexStringToData:[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask]
                         target:4
                         action:0
                postConfigDelay:0];
            NSLog(@"selection: %d maskbank: %d mask pointer: %d mask length: %lu mask Data: %@ ", 0 + ([CSLRfidAppEngine sharedAppEngine].settings.FastId ? 1 : 0), [CSLRfidAppEngine sharedAppEngine].settings.prefilterBank, [CSLRfidAppEngine sharedAppEngine].settings.prefilterOffset + maskOffset, (unsigned long)([[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask length] * 4), [CSLBleReader convertHexStringToData:[CSLRfidAppEngine sharedAppEngine].settings.prefilterMask]);
        }
        
        //LED Tags
        if (isLEDEnabled) {
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:1
                                                            maskBank:TID
                                                         maskPointer:0
                                                          maskLength:24
                                                            maskData:[CSLBleReader convertHexStringToData:@"E201E2"]
                                                              target:4
                                                              action:0
                                                     postConfigDelay:0];
            NSLog(@"LED tag CS6861 flashing is enabled");
        }
    }
    
}

+ (void) setConfigurationsForImpinjTags {

    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108 ||
        [CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS463)  {
        //set inventory configurations
        //for multiplebank inventory
        Byte tagRead=1;
        
        Byte tagDelay=0;
        if (![CSLRfidAppEngine sharedAppEngine].settings.tagFocus && tagRead) {
            tagDelay=30;
        }
        
        
        [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? A : [CSLRfidAppEngine sharedAppEngine].settings.target) querySession:[CSLRfidAppEngine sharedAppEngine].settings.session querySelect:ALL];
        [[CSLRfidAppEngine sharedAppEngine].reader selectAlgorithmParameter:[CSLRfidAppEngine sharedAppEngine].settings.algorithm];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters0:[CSLRfidAppEngine sharedAppEngine].settings.QValue maximumQ:15 minimumQ:0 ThresholdMultiplier:4];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters1:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters2:([CSLRfidAppEngine sharedAppEngine].settings.target == ToggleAB ? true : false) RunTillZero:false];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:tagRead crcErrorRead:(tagRead ? 0 : 1) QTMode:0 tagDelay:tagDelay inventoryMode:(tagRead ? 0 : 1)];
        [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:[CSLRfidAppEngine sharedAppEngine].settings.linkProfile];
        
        // if multibank read is enabled
        if (tagRead) {
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_BANK:[CSLRfidAppEngine sharedAppEngine].settings.multibank1 acc_bank2:[CSLRfidAppEngine sharedAppEngine].settings.multibank2];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_PTR:([CSLRfidAppEngine sharedAppEngine].settings.multibank2Offset << 16) + [CSLRfidAppEngine sharedAppEngine].settings.multibank1Offset];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_CNT:(tagRead ? [CSLRfidAppEngine sharedAppEngine].settings.multibank1Length : 0) secondBank:(tagRead==2 ? [CSLRfidAppEngine sharedAppEngine].settings.multibank2Length : 0)];
        }
        
        [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
        [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID
                                                             maskPointer:12
                                                              maskLength:13
                                                                maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%4X", 0x0118]]
                                                              sel_action:0];

        
    }
    else
    {
        //for multiplebank inventory
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:0
                                                                 IsEnabled:TRUE
                                                                      Bank:TID
                                                                    Offset:0
                                                                    Length:6];
        
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:1
                                                                 IsEnabled:FALSE
                                                                      Bank:[CSLRfidAppEngine sharedAppEngine].settings.multibank2
                                                                    Offset:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Offset
                                                                    Length:[CSLRfidAppEngine sharedAppEngine].settings.multibank2Length];
        
        [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:0
                   maskBank:TID
                maskPointer:12
                 maskLength:13
                   maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%4X", 0x0118]]
                     target:4
                     action:0
            postConfigDelay:0];
        
        [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:[CSLRfidAppEngine sharedAppEngine].settings.linkProfile];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetDuplicateEliminationRollingWindow:[CSLRfidAppEngine sharedAppEngine].settings.DuplicateEliminiationWindow];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetIntraPacketDelay:4];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetEventPacketUplinkEnable:TRUE InventoryEnd:FALSE CrcError:TRUE TagReadRate:TRUE];

    }
    
}

+ (void) setAntennaPortsAndPowerForTemperatureTags:(BOOL)isInitial {

    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS710) {
        //CS710S
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetAntennaConfig:0 PortEnable:TRUE TargetToggle:TRUE];
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel!=SYSTEMSETTING) {
            if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==HIGHPOWER)
                [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:30];
            else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==LOWPOWER)
                [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:16];
            else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==MEDIUMPOWER)
                [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:23];
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:0 PowerLevel:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        }
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetInventoryRoundControl:0
                                                                       InitialQ:[CSLRfidAppEngine sharedAppEngine].settings.QValue
                                                                           MaxQ:15
                                                                           MinQ:0
                                                                  NumMinQCycles:3
                                                                     FixedQMode:[CSLRfidAppEngine sharedAppEngine].settings.algorithm == FIXEDQ ? TRUE : FALSE
                                                              QIncreaseUseQuery:TRUE
                                                              QDecreaseUseQuery:TRUE
                                                                        Session:S1
                                                              SelInQueryCommand:SL
                                                                    QueryTarget:A
                                                                  HaltOnAllTags:0
                                                                   FastIdEnable:FALSE
                                                                 TagFocusEnable:FALSE
                                                        MaxQueriesSinceValidEpc:8
                                                                   TargetToggle:TRUE];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetDuplicateEliminationRollingWindow:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:0 time:2000];
    }
    else
    {
        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS];    //0x0700
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==HIGHPOWER)
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:30];
        else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==LOWPOWER)
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:16];
        else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==MEDIUMPOWER)
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:23];
        else
            [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
        
        
        if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS108) {
            if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel!=SYSTEMSETTING) {
                //use pre-defined three level settings
                [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:0];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:TRUE
                                                              InventoryMode:0
                                                              InventoryAlgo:0
                                                                     StartQ:0
                                                                ProfileMode:0
                                                                    Profile:0
                                                              FrequencyMode:0
                                                           FrequencyChannel:0
                                                               isEASEnabled:0];
                if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==HIGHPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:30];
                else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==LOWPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:16];
                else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==MEDIUMPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:23];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
                
                //disable all other channels
                if (isInitial) {
                    for (int i=1;i<16;i++) {
                        [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:FALSE
                                                                      InventoryMode:0
                                                                      InventoryAlgo:0
                                                                             StartQ:0
                                                                        ProfileMode:0
                                                                            Profile:0
                                                                      FrequencyMode:0
                                                                   FrequencyChannel:0
                                                                       isEASEnabled:0];
                    }
                }
            }
            else {
                if([CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel == 0) {
                    //use global settings
                    [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:0];
                    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:TRUE
                                                                  InventoryMode:0
                                                                  InventoryAlgo:0
                                                                         StartQ:0
                                                                    ProfileMode:0
                                                                        Profile:0
                                                                  FrequencyMode:0
                                                               FrequencyChannel:0
                                                                   isEASEnabled:0];
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:[CSLRfidAppEngine sharedAppEngine].settings.power / 10];
                    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:2000];
                    [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:0];
                    //disable all other ports
                    for (int i=1;i<16;i++) {
                        [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:FALSE
                                                                      InventoryMode:0
                                                                      InventoryAlgo:0
                                                                             StartQ:0
                                                                        ProfileMode:0
                                                                            Profile:0
                                                                      FrequencyMode:0
                                                                   FrequencyChannel:0
                                                                       isEASEnabled:0];
                    }
                }
                else {
                    //iterate through all the power level
                    for (int i=0;i<16;i++) {
                        int dwell=[[CSLRfidAppEngine sharedAppEngine].settings.dwellTime[i] intValue];
                        [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                        NSLog(@"Power level %d: %@", i, (i >= [CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel) ? @"OFF" : @"ON");
                        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:((i >= [CSLRfidAppEngine sharedAppEngine].settings.numberOfPowerLevel) ? FALSE : TRUE)
                                                                      InventoryMode:0
                                                                      InventoryAlgo:0
                                                                             StartQ:0
                                                                        ProfileMode:0
                                                                            Profile:0
                                                                      FrequencyMode:0
                                                                   FrequencyChannel:0
                                                                       isEASEnabled:0];
                        [[CSLRfidAppEngine sharedAppEngine].reader setPower:[(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.powerLevel[i] intValue] / 10];
                        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:dwell];
                        [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:dwell == 0 ? 65535 : 0];
                    }
                }
            }
        }
        else {  //CS463
            //iterate through all the power level
            for (int i=0;i<4;i++) {
                int dwell=[[CSLRfidAppEngine sharedAppEngine].settings.dwellTime[i] intValue];
                [[CSLRfidAppEngine sharedAppEngine].reader selectAntennaPort:i];
                NSLog(@"Antenna %d: %@", i, [(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue] ? @"ON" : @"OFF");
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaConfig:[(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.isPortEnabled[i] boolValue]
                                                              InventoryMode:0
                                                              InventoryAlgo:0
                                                                     StartQ:0
                                                                ProfileMode:0
                                                                    Profile:0
                                                              FrequencyMode:0
                                                           FrequencyChannel:0
                                                               isEASEnabled:0];
                if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==HIGHPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:30];
                else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==LOWPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:16];
                else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.powerLevel==MEDIUMPOWER)
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:23];
                else
                    [[CSLRfidAppEngine sharedAppEngine].reader setPower:[(NSNumber*)[CSLRfidAppEngine sharedAppEngine].settings.powerLevel[i] intValue] / 10];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaDwell:dwell];
                [[CSLRfidAppEngine sharedAppEngine].reader setAntennaInventoryCount:dwell == 0 ? 65535 : 0];
            }
        }
    }
}

+ (void) setConfigurationsForTemperatureTags {
    
    MEMORYBANK multibank1;
    Byte multibank1Offset;
    Byte multibank1Length;
    BOOL isMultibank1Enabled;
    
    MEMORYBANK multibank2;
    Byte multibank2Offset;
    Byte multibank2Length;
    BOOL isMultibank2Enabled;
    
    //pre-configure inventory
    //hardcode multibank inventory parameter for RFMicron tag reading (EPC+OCRSSI+TEMPERATURE)
    isMultibank1Enabled = true;
    isMultibank2Enabled = true;
    
    //check if Xerxes or Magnus tag
    if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==XERXES) {
        multibank1=USER;
        multibank1Offset=0x12;    //word address 0xC in the RESERVE bank
        multibank1Length=0x04;
        multibank2=RESERVED;
        multibank2Offset=0x0A;
        multibank2Length=0x05;
    }
    else {
        //check and see if this is S2 or S3 chip for capturing sensor code
        multibank1=RESERVED;
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==MAGNUSS3) {
            multibank1Offset=12;    //word address 0xC in the RESERVE bank
            multibank1Length=3;
        }
        else {
            multibank1Offset=11;    //word address 0xB in the RESERVE bank
            multibank1Length=1;
        }
        
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==MAGNUSS3) {
            multibank2=USER;
            multibank2Offset=8;
            multibank2Length=4;
        }
        else {
            multibank2=RESERVED;
            multibank2Offset=13;
            multibank2Length=1;
        }
    }
    
    //multiple bank select
    unsigned char emptyByte[] = {0x00};
    unsigned char OCRSSI[] = {0x20};
    
    if ([CSLRfidAppEngine sharedAppEngine].reader.readerModelNumber==CS710) {

        [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:MID_244];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetIntraPacketDelay:0];
        [[CSLRfidAppEngine sharedAppEngine].reader E710SetEventPacketUplinkEnable:TRUE InventoryEnd:FALSE CrcError:TRUE TagReadRate:TRUE];
        
        [self setConfigurationsForClearAllSelectionsAndMultibanks];
        
        //for multiplebank inventory
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:0
                                                                 IsEnabled:isMultibank1Enabled
                                                                      Bank:multibank1
                                                                    Offset:multibank1Offset
                                                                    Length:multibank1Length];
        
        [[CSLRfidAppEngine sharedAppEngine].reader E710MultibankReadConfig:1
                                                                 IsEnabled:isMultibank2Enabled && isMultibank2Enabled
                                                                      Bank:multibank2
                                                                    Offset:multibank2Offset
                                                                    Length:multibank2Length];
        
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==XERXES) {
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:0
                       maskBank:TID
                    maskPointer:0
                     maskLength:32
                       maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", XERXES]]
                         target:4
                         action:0
                postConfigDelay:0];
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:1
                       maskBank:USER
                    maskPointer:0x03B0
                     maskLength:8
                       maskData:[NSData dataWithBytes:emptyByte length:sizeof(emptyByte)]
                         target:4
                         action:5
                postConfigDelay:15];
        }
        else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==MAGNUSS3) {
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:0
                       maskBank:TID
                    maskPointer:0
                     maskLength:28
                       maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", MAGNUSS3]]
                         target:4
                         action:0
                postConfigDelay:0];
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:1
                       maskBank:USER
                    maskPointer:0xE0
                     maskLength:0
                       maskData:[NSData dataWithBytes:emptyByte length:sizeof(emptyByte)]
                         target:4
                         action:2
                postConfigDelay:0];
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:2
                       maskBank:USER
                    maskPointer:0xD0
                     maskLength:8
                       maskData:[NSData dataWithBytes:OCRSSI length:sizeof(OCRSSI)]
                         target:4
                         action:2
                postConfigDelay:0];
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:0
                       maskBank:TID
                    maskPointer:0
                     maskLength:28
                       maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", MAGNUSS2]]
                         target:4
                         action:0
                postConfigDelay:0];
            [[CSLRfidAppEngine sharedAppEngine].reader E710SelectTag:1
                       maskBank:USER
                    maskPointer:0xA0
                     maskLength:8
                       maskData:[NSData dataWithBytes:OCRSSI length:sizeof(OCRSSI)]
                         target:4
                         action:2
                postConfigDelay:0];
        }
        
        
    }
    else
    {
        //for multiplebank inventory
        Byte tagRead=0;
        if (isMultibank1Enabled && isMultibank2Enabled)
            tagRead=2;
        else if (isMultibank1Enabled)
            tagRead=1;
        else
            tagRead=0;
        
        [[CSLRfidAppEngine sharedAppEngine].reader selectAlgorithmParameter:DYNAMICQ];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters0:[CSLRfidAppEngine sharedAppEngine].settings.QValue maximumQ:15 minimumQ:0 ThresholdMultiplier:4];   //0x0903
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters1:5];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters2:true /*hardcoding toggle A/B*/ RunTillZero:false];     //x0905
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:DYNAMICQ MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:0 crcErrorRead:0 QTMode:0 tagDelay:0 inventoryMode:0]; //0x0901
        
        [[CSLRfidAppEngine sharedAppEngine].reader selectAlgorithmParameter:FIXEDQ];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters0:[CSLRfidAppEngine sharedAppEngine].settings.QValue maximumQ:0 minimumQ:0 ThresholdMultiplier:0];   //0x0903
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters1:5];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryAlgorithmParameters2:true /*hardcoding toggle A/B*/ RunTillZero:false];     //x0905
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:FIXEDQ MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:0 crcErrorRead:0 QTMode:0 tagDelay:0 inventoryMode:0]; //0x0901
        
        [[CSLRfidAppEngine sharedAppEngine].reader setQueryConfigurations:A querySession:S1 querySelect:SL];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:DYNAMICQ MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:0 crcErrorRead:0 QTMode:0 tagDelay:0 inventoryMode:0]; //0x0901
        [[CSLRfidAppEngine sharedAppEngine].reader setLinkProfile:RANGE_DRM];
        
        //select the TID for either S2 or S3 chip
        [[CSLRfidAppEngine sharedAppEngine].reader clearAllTagSelect];
        
        if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==XERXES) {
            
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID maskPointer:0 maskLength:32 maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", XERXES]] sel_action:0];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:1];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:USER maskPointer:0x03B0 maskLength:8 maskData:[NSData dataWithBytes:emptyByte length:sizeof(emptyByte)] sel_action:5 delayTime:15];
            
        }
        else if ([CSLRfidAppEngine sharedAppEngine].temperatureSettings.sensorType==MAGNUSS3) {
            
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID maskPointer:0 maskLength:28 maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", MAGNUSS3]] sel_action:0];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:1];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:USER maskPointer:0xE0 maskLength:0 maskData:[NSData dataWithBytes:emptyByte length:sizeof(emptyByte)] sel_action:2];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:2];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:USER maskPointer:0xD0 maskLength:8 maskData:[NSData dataWithBytes:OCRSSI length:sizeof(OCRSSI)] sel_action:2];
            
        }
        else {
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:0];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:TID maskPointer:0 maskLength:28 maskData:[CSLBleReader convertHexStringToData:[NSString stringWithFormat:@"%8X", MAGNUSS2]] sel_action:0];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGMSK_DESC_SEL:1];
            [[CSLRfidAppEngine sharedAppEngine].reader selectTagForInventory:USER maskPointer:0xA0 maskLength:8 maskData:[NSData dataWithBytes:OCRSSI length:sizeof(OCRSSI)] sel_action:2];
        }
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryCycleDelay:0];
        [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:0 disableInventory:0 tagRead:tagRead crcErrorRead:true QTMode:0 tagDelay:(tagRead ? 30 : 0) inventoryMode:(tagRead ? 0 : 1)];
        
        
        // if multibank read is enabled
        if (tagRead) {
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_BANK:multibank1 acc_bank2:multibank2];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_PTR:(multibank2Offset << 16) + multibank1Offset];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_CNT:(tagRead ? multibank1Length : 0) secondBank:(tagRead==2 ? multibank2Length : 0)];
            [[CSLRfidAppEngine sharedAppEngine].reader TAGACC_ACCPWD:0x00000000];
            [[CSLRfidAppEngine sharedAppEngine].reader setInventoryConfigurations:[CSLRfidAppEngine sharedAppEngine].settings.algorithm MatchRepeats:0 tagSelect:1 disableInventory:0 tagRead:tagRead crcErrorRead:true QTMode:0 tagDelay:(tagRead ? 30 : 0) inventoryMode:(tagRead ? 0 : 1)];
            [[CSLRfidAppEngine sharedAppEngine].reader setEpcMatchConfiguration:false matchOn:false matchLength:0x00000 matchOffset:0x00000];
        }
    }
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
