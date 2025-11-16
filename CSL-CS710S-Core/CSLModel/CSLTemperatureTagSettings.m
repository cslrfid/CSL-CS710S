//
//  CSLTemperatureTagSettings.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "../include/CSLTemperatureTagSettings.h"

@implementation CSLTemperatureTagSettings


-(id)init {
    if (self = [super init])  {
        //set default values
        self.isTemperatureAlertEnabled=false;
        self.temperatureAlertLowerLimit=2;
        self.temperatureAlertUpperLimit=8;
        self.rssiLowerLimit=8;
        self.rssiUpperLimit=18;
        self.sensorType=MAGNUSS3;
        self.reading=TEMPERATURE;
        self.powerLevel=SYSTEMSETTING;
        self.tagIdFormat=HEX;
        self.moistureAlertCondition=ALERT_GREATER;
        self.moistureAlertValue=100;
        self.NumberOfRollingAvergage=3;
        self.unit=CELCIUS;
        self.temperatureAveragingBuffer = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) setTemperatureValueForAveraging:(NSNumber*)temperatureValue EPCID:(NSString*)epc {
    
    CSLCircularQueue* temperatureQueue = (CSLCircularQueue*)[self.temperatureAveragingBuffer objectForKey:epc];
    if (temperatureQueue != nil) {
        if ([temperatureQueue count] >= self.NumberOfRollingAvergage) {
            [temperatureQueue deqObject];
            [temperatureQueue enqObject:temperatureValue];
        }
        else {
            [temperatureQueue enqObject:temperatureValue];
        }
    }
    else  {
        temperatureQueue=[[CSLCircularQueue alloc] initWithCapacity:100];
        [temperatureQueue enqObject:temperatureValue];
        [self.temperatureAveragingBuffer setObject:temperatureQueue forKey:epc];
    }
}

- (NSNumber*) getTemperatureValueAveraging:(NSString*)epc {
    double average=0.0;
    CSLCircularQueue* temperatureQueue = (CSLCircularQueue*)[self.temperatureAveragingBuffer objectForKey:epc];
    if (temperatureQueue != nil) {
        if ([temperatureQueue count] >= self.NumberOfRollingAvergage) {
            for (int i=0;i<[temperatureQueue count];i++) {
                average += [((NSNumber*)[temperatureQueue objectAtIndex:i]) doubleValue];
            }
            return [NSNumber numberWithDouble:average/[temperatureQueue count]];
        }
        else {
            return nil;
        }
    }
    else {
        return nil;
    }
}

- (void) removeTemperatureAverageForEpc:(NSString*)epc {
    CSLCircularQueue* temperatureQueue = (CSLCircularQueue*)[self.temperatureAveragingBuffer objectForKey:epc];
    if (temperatureQueue != nil) {
        [self.temperatureAveragingBuffer removeObjectForKey:epc];
    }
}

+ (double) convertCelciusToFahrenheit:(double)temperatureInCelcius {
    return ((temperatureInCelcius * 9/5) + 32);
}

+ (double) convertFahrenheitToCelcius:(double)temperatureInFahrenheit {
    return ((temperatureInFahrenheit - 32) * 5/9);
}

@end
