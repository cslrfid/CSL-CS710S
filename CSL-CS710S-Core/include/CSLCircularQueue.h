//
//  CSLCircularQueue.h
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSLBleTag.h"

/**
 Circular queue for storing tag response data
 */
@interface CSLCircularQueue : NSObject <NSFastEnumeration>

///Define the maximum number of elements that the instance can hold
@property (nonatomic, assign, readonly) NSUInteger capacity;
///Number of element that the instance is holding
@property (nonatomic, assign, readonly) NSUInteger count;

///Initializing the instance with a defined capacity
- (id)initWithCapacity:(NSUInteger)capacity;

///Enqueu object into the queue
- (void)enqObject:(id)obj; // Enqueue
/**Dnqueu object from the queue
 @return id Reference to the returned object
 */
- (id)deqObject;           // Dequeue
/**Return reference to a specific object in the queue
  @return id Reference to the returned object
 */
- (id)objectAtIndex:(NSUInteger)index;
/**Remove all objects in queue
 */
- (void)removeAllObjects;
/**Calculate the rolling average of the tag search RSSI
 */
- (Byte)calculateRollingAverage;
@end


