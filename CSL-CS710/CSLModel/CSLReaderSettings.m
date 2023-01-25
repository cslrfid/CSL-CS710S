//
//  CSLReaderSettings.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLReaderSettings.h"

@implementation CSLReaderSettings

@synthesize power;
@synthesize session;
@synthesize target;
@synthesize algorithm;
@synthesize linkProfile;
@synthesize tagPopulation;
@synthesize QValue;
@synthesize isQOverride;
@synthesize enableSound;
@synthesize region;
@synthesize channel;

-(id)init {
    if (self = [super init])  {
        //set default values
        self.tagPopulation=60;
        self.isQOverride=false;
        self.QValue=7;
        self.power = 300;
        self.tagAccessPort = 0;
        self.session = S0;
        self.target = ToggleAB;
        self.algorithm = DYNAMICQ;
        self.linkProfile=MID_345;
        self.DuplicateEliminiationWindow = 0;
        self.enableSound=true;
        self.tagFocus=0;    //tag focus disable by default
        self.FastId=0;    //fast id disable by default
        self.rfLnaHighComp = 1;
        self.rfLna=0;   //1 dB
        self.ifLna=0;   //24 dB
        self.ifAgc=4;   //-6 dB
        self.isMultibank1Enabled=false;
        self.multibank1=TID;
        self.multibank1Offset=0;
        self.multibank1Length=2;
        self.isMultibank2Enabled=false;
        self.multibank2=USER;
        self.multibank2Offset=0;
        self.multibank2Length=2;
        self.numberOfPowerLevel=0;
        self.region=@"";
        self.channel=@"";
        self.powerLevel = [NSMutableArray array];
        //300, 290, 280....
        for (int n = 0; n < 16; n++)
            [self.powerLevel addObject:[NSString stringWithFormat:@"%d", 300]];
        self.dwellTime = [NSMutableArray array];
        //Set dwell time to 200ms for all ports
        for (int n = 0; n < 16; n++)
            [self.dwellTime addObject:@"2000"];
        //For CS463, disable all ports except port 0
        self.isPortEnabled = [NSMutableArray array];
        [self.isPortEnabled addObject:[[NSNumber alloc] initWithBool:TRUE]];
        for (int n = 1 ; n < 4; n++)
            [self.isPortEnabled addObject:[[NSNumber alloc] initWithBool:FALSE]];
        
        self.prefilterBank=EPC;
        self.prefilterMask=@"1234";
        self.prefilterOffset=0;
        self.prefilterIsEnabled=false;
        self.postfilterMask=@"1234";
        self.postfilterOffset=0;
        self.postfilterIsNotMatchMaskEnabled=false;
        self.postfilterIsEnabled=false;
    }
    return self;
}


@end