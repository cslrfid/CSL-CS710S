//
//  CSLBleReader+AccessControl.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLBleReader+AccessControl.h"

@implementation CSLBleReader (AccessControl)

- (BOOL)setParametersForTagAccess {
    
    if(![self setAntennaCycle:1])
        return false;
    if (![self setQueryConfigurations:A querySession:S0 querySelect:SL])
        return false;
    if (![self selectAlgorithmParameter:FIXEDQ])
        return false;
    if (![self setInventoryAlgorithmParameters0:0 maximumQ:0 minimumQ:0 ThresholdMultiplier:0])
        return false;
    if (![self setInventoryAlgorithmParameters2:0 RunTillZero:0])
        return false;
    
    return true;
}

- (BOOL)setParametersForTagSearch {
    
    if(![self setAntennaCycle:COMMAND_ANTCYCLE_CONTINUOUS])
        return false;
    if (![self setQueryConfigurations:A querySession:S0 querySelect:SL])
        return false;
    if (![self selectAlgorithmParameter:FIXEDQ])
        return false;
    if (![self setInventoryAlgorithmParameters0:0 maximumQ:0 minimumQ:0 ThresholdMultiplier:0])
        return false;
    if (![self setInventoryAlgorithmParameters2:0 RunTillZero:0])
        return false;
    
    return true;
}

- (BOOL) TAGMSK_DESC_SEL:(Byte)desc_idx {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_DESC_SEL - Write this register to select which Select descriptor and corresponding mask register set to access.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_DESC_SEL[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0x08, desc_idx & 0x07, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_DESC_SEL length:sizeof(TAGMSK_DESC_SEL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_DESC_SEL, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_DESC_SEL sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_DESC_SEL sent FAILED");
        return false;
    }
}

- (BOOL) TAGMSK_DESC_CFG:(BOOL)isEnable selectTarget:(Byte)sel_target selectAction:(Byte)sel_action {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_DESC_CFG - Specify the parameters for a Select operation");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_DESC_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x08, (isEnable & 0x01) + ((sel_target << 1) & 0x0E) + ((sel_action << 4) & 0x70), 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_DESC_CFG length:sizeof(TAGMSK_DESC_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_DESC_CFG, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_DESC_CFG sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_DESC_CFG sent FAILED");
        return false;
    }
}

- (BOOL) TAGMSK_DESC_CFG:(BOOL)isEnable selectTarget:(Byte)sel_target selectAction:(Byte)sel_action delayTime:(Byte)delay {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_DESC_CFG - Specify the parameters for a Select operation");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_DESC_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x08, (isEnable & 0x01) + ((sel_target << 1) & 0x0E) + ((sel_action << 4) & 0x70), delay & 0xFF, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_DESC_CFG length:sizeof(TAGMSK_DESC_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_DESC_CFG, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_DESC_CFG sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_DESC_CFG sent FAILED");
        return false;
    }
}

- (BOOL) TAGACC_DESC_CFG:(BOOL)isVerify retryCount:(Byte)count {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_DESC_CFG - Specify the parameters for a Select operation");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_DESC_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x0A, (isVerify & 0x01) + ((count << 1) & 0x03E), 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_DESC_CFG length:sizeof(TAGACC_DESC_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_DESC_CFG, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_DESC_CFG sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_DESC_CFG sent FAILED");
        return false;
    }
}

- (BOOL) TAGMSK_BANK:(MEMORYBANK)bank {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_BANK - Specify which memory bank is applied to during Select.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_BANK[] = {0x80, 0x02, 0x70, 0x01, 0x02, 0x08, (bank & 0x03), 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_BANK length:sizeof(TAGMSK_BANK)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_BANK, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_BANK sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_BANK sent FAILED");
        return false;
    }
}
- (BOOL) TAGMSK_PTR:(UInt16)ptr {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_PTR - Specify the bit offset in tag memory at which the configured mask will be applied during Select.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_PTR[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x08, ptr & 0xFF, (ptr >> 8) & 0xFF, (ptr >> 16) & 0xFF, (ptr >> 24) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_PTR length:sizeof(TAGMSK_PTR)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_PTR, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_PTR sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_PTR sent FAILED");
        return false;
    }
}
- (BOOL) TAGMSK_LEN:(Byte)length {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGMSK_LEN - Specify the bit offset in tag memory at which the configured mask will be applied during Select.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK_LEN[] = {0x80, 0x02, 0x70, 0x01, 0x04, 0x08, length & 0xFF, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK_LEN length:sizeof(TAGMSK_LEN)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK_LEN, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGMSK_LEN sent OK");
        return true;
    }
    else {
        NSLog(@"TAGMSK_LEN sent FAILED");
        return false;
    }
}

- (BOOL) setTAGMSK:(UInt16)TAGMSKAddr tagMask:(UInt32)mask {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"setTAGMSK - Write the tag mask data.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGMSK[] = {0x80, 0x02, 0x70, 0x01, TAGMSKAddr & 0xFF, (TAGMSKAddr >> 8) & 0xFF, (mask >> 24) & 0xFF, (mask >> 16) & 0xFF, (mask >> 8) & 0xFF, mask & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGMSK length:sizeof(TAGMSK)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGMSK, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"setTAGMSK sent OK");
        return true;
    }
    else {
        NSLog(@"setTAGMSK sent FAILED");
        return false;
    }
}

- (BOOL) TAGACC_BANK:(MEMORYBANK)bank acc_bank2:(MEMORYBANK)bank2 {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_BANK - Specify which memory bank is applied to during access.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_BANK[] = {0x80, 0x02, 0x70, 0x01, 0x02, 0x0A, (bank & 0x03) + ((bank2 << 2) & 0x0C), 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_BANK length:sizeof(TAGACC_BANK)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_BANK, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_BANK sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_BANK sent FAILED");
        return false;
    }
}
- (BOOL) TAGACC_PTR:(UInt32)ptr secondBank:(UInt32)ptr2 {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_PTR - Specify the offset (16 bit words) in tag memory for tag accesses.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_PTR[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x0A, ptr & 0xFF, (ptr >> 8) & 0xFF, ptr2 & 0xFF, (ptr2 >> 8) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_PTR length:sizeof(TAGACC_PTR)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_PTR, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_PTR sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_PTR sent FAILED");
        return false;
    }
}
- (BOOL) TAGACC_PTR:(UInt32)ptr {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_PTR - Specify the offset (16 bit words) in tag memory for tag accesses.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_PTR[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x0A, ptr & 0xFF, (ptr >> 8) & 0xFF, (ptr >> 16) & 0xFF, (ptr >> 24) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_PTR length:sizeof(TAGACC_PTR)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_PTR, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_PTR sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_PTR sent FAILED");
        return false;
    }
}

- (BOOL) TAGACC_CNT:(Byte)length secondBank:(Byte)length2 {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_CNT - Write this register to specify the number of 16 bit words that should be accessed.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_CNT[] = {0x80, 0x02, 0x70, 0x01, 0x04, 0x0A, length & 0xFF, length2 & 0xFF, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_CNT length:sizeof(TAGACC_CNT)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_CNT, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_CNT sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_CNT sent FAILED");
        return false;
    }
}
- (BOOL) TAGACC_ACCPWD:(UInt32)password {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_ACCPWD - Set this register to the access password.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_ACCPWD[] = {0x80, 0x02, 0x70, 0x01, 0x06, 0x0A, password & 0xFF, (password >> 8) & 0xFF, (password >> 16) & 0xFF, (password >> 24) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_ACCPWD length:sizeof(TAGACC_ACCPWD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_ACCPWD, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_ACCPWD sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_ACCPWD sent FAILED");
        return false;
    }
}
- (BOOL) TAGACC_KILLPWD:(UInt32)password {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_KILLPWD - Set this register to the access password.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_KILLPWD[] = {0x80, 0x02, 0x70, 0x01, 0x07, 0x0A, password & 0xFF, (password >> 8) & 0xFF, (password >> 16) & 0xFF, (password >> 24) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_KILLPWD length:sizeof(TAGACC_KILLPWD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_KILLPWD, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_KILLPWD sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_KILLPWD sent FAILED");
        return false;
    }
}

- (BOOL) setTAGWRDAT:(UInt16)TAGWRDATAddr data_word:(UInt16)word data_offset:(UInt16)offset {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"setTAGWRDAT - Set these registers to valid data prior to issuing the “Write” command (0x11).");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char setTAGWRDAT[] = {0x80, 0x02, 0x70, 0x01, TAGWRDATAddr & 0xFF, (TAGWRDATAddr >> 8) & 0xFF, word & 0xFF, (word >> 8) & 0xFF, offset & 0xFF, (offset >> 8) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:setTAGWRDAT length:sizeof(setTAGWRDAT)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], setTAGWRDAT, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"setTAGWRDAT sent OK");
        return true;
    }
    else {
        NSLog(@"setTAGWRDAT sent FAILED");
        return false;
    }
}

- (BOOL) TAGWRDAT_SEL:(UInt16)bank {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGWRDAT_SEL - Used to access the tag write buffer.  The buffer is set up as a 16 register array.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGWRDAT_SEL[] = {0x80, 0x02, 0x70, 0x01, 0x08, 0x0A, bank & 0x7, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGWRDAT_SEL length:sizeof(TAGWRDAT_SEL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGWRDAT_SEL, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGWRDAT_SEL sent OK");
        return true;
    }
    else {
        NSLog(@"TAGWRDAT_SEL sent FAILED");
        return false;
    }
}

- (BOOL) sendHostCommandWrite {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send HST_CMD 0x11 (Write Tag)...");
    NSLog(@"----------------------------------------------------------------------");
    
    //Send HST_CMD
    unsigned char HSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x11, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:HSTCMD length:sizeof(HSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 3) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] >= 3)
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], HSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x11 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x11 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    return true;
}
- (BOOL) sendHostCommandRead {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send HST_CMD 0x10 (Read Tag)...");
    NSLog(@"----------------------------------------------------------------------");
    
    //Send HST_CMD
    unsigned char HSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x10, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:HSTCMD length:sizeof(HSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 1) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] >= 1)
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], HSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x10 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x10 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    return true;
}

- (BOOL) sendHostCommandSearch {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send HST_CMD 0x10 (Search Tag)...");
    NSLog(@"----------------------------------------------------------------------");
    
    //Send HST_CMD
    unsigned char HSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x0F, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:HSTCMD length:sizeof(HSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 1) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] >= 1)
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], HSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x0F response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x0F response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    return true;
}

- (BOOL) sendHostCommandLock {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send HST_CMD 0x12 (Lock Tag)...");
    NSLog(@"----------------------------------------------------------------------");
    
    //Send HST_CMD
    unsigned char HSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0xF0, 0x12, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:HSTCMD length:sizeof(HSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 1) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] >= 1)
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], HSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x12 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x12 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    return true;
}

- (BOOL) sendHostCommandKill {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send HST_CMD 0x13 (kill Tag)...");
    NSLog(@"----------------------------------------------------------------------");
    
    //Send HST_CMD
    unsigned char HSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0xF0, 0x13, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:HSTCMD length:sizeof(HSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 1) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] >= 1)
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], HSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x13 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x13 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    return true;
}

- (BOOL) clearAllTagSelect {
    BOOL result=true;
    
    for (int i=0;i<8;i++) {
        result=[self TAGMSK_DESC_SEL:i];
        result=[self TAGMSK_DESC_CFG:false selectTarget:0 selectAction:0];
    }
    
    return result;
}

- (BOOL) setEpcMatchSelect:(Byte)idx {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@" INV_EPC_MATCH_SEL - select EPC match       ");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char INV_EPC_MATCH_SEL[] = {0x80, 0x02, 0x70, 0x01, 0x10, 0x09, idx & 0xFF, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_EPC_MATCH_SEL length:sizeof(INV_EPC_MATCH_SEL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], INV_EPC_MATCH_SEL, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"INV_EPC_MATCH_SEL sent OK");
        return true;
    }
    else {
        NSLog(@"INV_EPC_MATCH_SEL sent FAILED");
        return false;
    }
}

- (BOOL) setEpcMatchConfiguration:(BOOL)match_enable matchOn:(BOOL)epc_notEpc matchLength:(UInt16)match_length matchOffset:(UInt16)match_offset {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    UInt32 registerValue = (UInt32)(match_enable ? 1 : 0) |
                            (UInt32)(epc_notEpc ? 2 : 0) |
                            (UInt32)(match_length << 2) |
                            (UInt32)(match_offset << 11);
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"INV_EPC_MATCH_CFG - Epc match configuration register .");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char INV_EPC_MATCH_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x11, 0x09, registerValue & 0xFF, (registerValue >> 8) & 0xFF , (registerValue >> 16) & 0xFF, (registerValue >> 24) & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_EPC_MATCH_CFG length:sizeof(INV_EPC_MATCH_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], INV_EPC_MATCH_CFG, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"INV_EPC_MATCH_CFG sent OK");
        return true;
    }
    else {
        NSLog(@"INV_EPC_MATCH_CFG sent FAILED");
        return false;
    }

}

- (BOOL) setEpcMatchMask:(UInt32)maskLength maskData:(NSData*)mask  {
    
    BOOL result=true;
    
    NSLog(@"EPC match mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    

    if (maskLength > 0 && mask.length > 0) {
        result=[self setTAGMSK:INV_EPC_MSK_0_3 tagMask:((UInt32)(((Byte *)[mask bytes])[0] << 24)) + ((UInt32)(((Byte *)[mask bytes])[1] << 16)) + ((UInt32)(((Byte *)[mask bytes])[2] << 8)) + ((UInt32)((Byte *)[mask bytes])[3])];
    }
    if (maskLength > 32 && mask.length > 4) {
        result=[self setTAGMSK:INV_EPC_MSK_4_7 tagMask:((UInt32)(((Byte *)[mask bytes])[4] << 24)) + ((UInt32)(((Byte *)[mask bytes])[5] << 16)) + ((UInt32)(((Byte *)[mask bytes])[6] << 8)) + ((UInt32)((Byte *)[mask bytes])[7])];
    }
    if (maskLength > 64 && mask.length > 8) {
        result=[self setTAGMSK:INV_EPC_MSK_8_11 tagMask:((UInt32)(((Byte *)[mask bytes])[8] << 24)) + ((UInt32)(((Byte *)[mask bytes])[9] << 16)) + ((UInt32)(((Byte *)[mask bytes])[10] << 8)) + ((UInt32)((Byte *)[mask bytes])[11])];
    }
    if (maskLength > 96 && mask.length > 12) {
        result=[self setTAGMSK:INV_EPC_MSK_12_15 tagMask:((UInt32)(((Byte *)[mask bytes])[12] << 24)) + ((UInt32)(((Byte *)[mask bytes])[13] << 16)) + ((UInt32)(((Byte *)[mask bytes])[14] << 8)) + ((UInt32)((Byte *)[mask bytes])[15])];
    }
    if (maskLength > 128 && mask.length > 16) {
        result=[self setTAGMSK:INV_EPC_MSK_16_19 tagMask:((UInt32)(((Byte *)[mask bytes])[16] << 24)) + ((UInt32)(((Byte *)[mask bytes])[17] << 16)) + ((UInt32)(((Byte *)[mask bytes])[18] << 8)) + ((UInt32)((Byte *)[mask bytes])[19])];
    }
    if (maskLength > 160 && mask.length > 20) {
        result=[self setTAGMSK:INV_EPC_MSK_20_23 tagMask:((UInt32)(((Byte *)[mask bytes])[20] << 24)) + ((UInt32)(((Byte *)[mask bytes])[21] << 16)) + ((UInt32)(((Byte *)[mask bytes])[22] << 8)) + ((UInt32)((Byte *)[mask bytes])[23])];
    }
    if (maskLength > 192 && mask.length > 24) {
        result=[self setTAGMSK:INV_EPC_MSK_24_27 tagMask:((UInt32)(((Byte *)[mask bytes])[24] << 24)) + ((UInt32)(((Byte *)[mask bytes])[25] << 16)) + ((UInt32)(((Byte *)[mask bytes])[26] << 8)) + ((UInt32)((Byte *)[mask bytes])[27])];
    }
    if (maskLength > 224 && mask.length > 28) {
        result=[self setTAGMSK:INV_EPC_MSK_28_31 tagMask:((UInt32)(((Byte *)[mask bytes])[28] << 24)) + ((UInt32)(((Byte *)[mask bytes])[29] << 16)) + ((UInt32)(((Byte *)[mask bytes])[30] << 8)) + ((UInt32)((Byte *)[mask bytes])[31])];
    }
    
    return result;
}

- (BOOL) setInventoryCycleDelay:(UInt32) cycle_delay {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"INV_CYCLE_DELAY - Delay time between inventory cycle.");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char INV_CYCLE_DELAY[] = {0x80, 0x02, 0x70, 0x01, 0x0F, 0x0F, cycle_delay & 0x000000FF, (cycle_delay & 0x0000FF00) >> 8, (cycle_delay & 0x00FF0000) >> 16, (cycle_delay & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_CYCLE_DELAY length:sizeof(INV_CYCLE_DELAY)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], INV_CYCLE_DELAY, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"INV_CYCLE_DELAY sent OK");
        return true;
    }
    else {
        NSLog(@"INV_CYCLE_DELAY sent FAILED");
        return false;
    }
    
}

- (BOOL) selectTagForInventory:(MEMORYBANK)maskbank maskPointer:(UInt16)ptr maskLength:(UInt32)length maskData:(NSData*)mask sel_action:(Byte)action {
    
    BOOL result=true;
    
    NSLog(@"Tag select mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    
    //Select the desired tag
    result=[self TAGMSK_DESC_CFG:true selectTarget:4 /* SL*/ selectAction:action];
    result=[self TAGMSK_BANK:maskbank];
    result=[self TAGMSK_PTR:ptr];
    result=[self TAGMSK_LEN:length];
    if (length > 0 && mask.length > 0) {
        result=[self setTAGMSK:TAGMSK_0_3 tagMask:((UInt32)(((Byte *)[mask bytes])[0] << 24)) + ((UInt32)(((Byte *)[mask bytes])[1] << 16)) + ((UInt32)(((Byte *)[mask bytes])[2] << 8)) + ((UInt32)((Byte *)[mask bytes])[3])];
    }
    if (length > 32 && mask.length > 4) {
        result=[self setTAGMSK:TAGMSK_4_7 tagMask:((UInt32)(((Byte *)[mask bytes])[4] << 24)) + ((UInt32)(((Byte *)[mask bytes])[5] << 16)) + ((UInt32)(((Byte *)[mask bytes])[6] << 8)) + ((UInt32)((Byte *)[mask bytes])[7])];
    }
    if (length > 64 && mask.length > 8) {
        result=[self setTAGMSK:TAGMSK_8_11 tagMask:((UInt32)(((Byte *)[mask bytes])[8] << 24)) + ((UInt32)(((Byte *)[mask bytes])[9] << 16)) + ((UInt32)(((Byte *)[mask bytes])[10] << 8)) + ((UInt32)((Byte *)[mask bytes])[11])];
    }
    if (length > 96 && mask.length > 12) {
        result=[self setTAGMSK:TAGMSK_12_15 tagMask:((UInt32)(((Byte *)[mask bytes])[12] << 24)) + ((UInt32)(((Byte *)[mask bytes])[13] << 16)) + ((UInt32)(((Byte *)[mask bytes])[14] << 8)) + ((UInt32)((Byte *)[mask bytes])[15])];
    }
    if (length > 128 && mask.length > 16) {
        result=[self setTAGMSK:TAGMSK_16_19 tagMask:((UInt32)(((Byte *)[mask bytes])[16] << 24)) + ((UInt32)(((Byte *)[mask bytes])[17] << 16)) + ((UInt32)(((Byte *)[mask bytes])[18] << 8)) + ((UInt32)((Byte *)[mask bytes])[19])];
    }
    if (length > 160 && mask.length > 20) {
        result=[self setTAGMSK:TAGMSK_20_23 tagMask:((UInt32)(((Byte *)[mask bytes])[20] << 24)) + ((UInt32)(((Byte *)[mask bytes])[21] << 16)) + ((UInt32)(((Byte *)[mask bytes])[22] << 8)) + ((UInt32)((Byte *)[mask bytes])[23])];
    }
    if (length > 192 && mask.length > 24) {
        result=[self setTAGMSK:TAGMSK_24_27 tagMask:((UInt32)(((Byte *)[mask bytes])[24] << 24)) + ((UInt32)(((Byte *)[mask bytes])[25] << 16)) + ((UInt32)(((Byte *)[mask bytes])[26] << 8)) + ((UInt32)((Byte *)[mask bytes])[27])];
    }
    if (length > 224 && mask.length > 28) {
        result=[self setTAGMSK:TAGMSK_28_31 tagMask:((UInt32)(((Byte *)[mask bytes])[28] << 24)) + ((UInt32)(((Byte *)[mask bytes])[29] << 16)) + ((UInt32)(((Byte *)[mask bytes])[30] << 8)) + ((UInt32)((Byte *)[mask bytes])[31])];
    }
    
    return result;
}

- (BOOL) selectTagForInventory:(MEMORYBANK)maskbank maskPointer:(UInt16)ptr maskLength:(UInt32)length maskData:(NSData*)mask sel_action:(Byte)action delayTime:(Byte)delay {
    
    BOOL result=true;
    
    NSLog(@"Tag select mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    
    //Select the desired tag
    result=[self TAGMSK_DESC_CFG:true selectTarget:4 /* SL*/ selectAction:action delayTime:delay];
    result=[self TAGMSK_BANK:maskbank];
    result=[self TAGMSK_PTR:ptr];
    result=[self TAGMSK_LEN:length];
    if (length > 0 && mask.length > 0) {
        result=[self setTAGMSK:TAGMSK_0_3 tagMask:((UInt32)(((Byte *)[mask bytes])[0] << 24)) + ((UInt32)(((Byte *)[mask bytes])[1] << 16)) + ((UInt32)(((Byte *)[mask bytes])[2] << 8)) + ((UInt32)((Byte *)[mask bytes])[3])];
    }
    if (length > 32 && mask.length > 4) {
        result=[self setTAGMSK:TAGMSK_4_7 tagMask:((UInt32)(((Byte *)[mask bytes])[4] << 24)) + ((UInt32)(((Byte *)[mask bytes])[5] << 16)) + ((UInt32)(((Byte *)[mask bytes])[6] << 8)) + ((UInt32)((Byte *)[mask bytes])[7])];
    }
    if (length > 64 && mask.length > 8) {
        result=[self setTAGMSK:TAGMSK_8_11 tagMask:((UInt32)(((Byte *)[mask bytes])[8] << 24)) + ((UInt32)(((Byte *)[mask bytes])[9] << 16)) + ((UInt32)(((Byte *)[mask bytes])[10] << 8)) + ((UInt32)((Byte *)[mask bytes])[11])];
    }
    if (length > 96 && mask.length > 12) {
        result=[self setTAGMSK:TAGMSK_12_15 tagMask:((UInt32)(((Byte *)[mask bytes])[12] << 24)) + ((UInt32)(((Byte *)[mask bytes])[13] << 16)) + ((UInt32)(((Byte *)[mask bytes])[14] << 8)) + ((UInt32)((Byte *)[mask bytes])[15])];
    }
    if (length > 128 && mask.length > 16) {
        result=[self setTAGMSK:TAGMSK_16_19 tagMask:((UInt32)(((Byte *)[mask bytes])[16] << 24)) + ((UInt32)(((Byte *)[mask bytes])[17] << 16)) + ((UInt32)(((Byte *)[mask bytes])[18] << 8)) + ((UInt32)((Byte *)[mask bytes])[19])];
    }
    if (length > 160 && mask.length > 20) {
        result=[self setTAGMSK:TAGMSK_20_23 tagMask:((UInt32)(((Byte *)[mask bytes])[20] << 24)) + ((UInt32)(((Byte *)[mask bytes])[21] << 16)) + ((UInt32)(((Byte *)[mask bytes])[22] << 8)) + ((UInt32)((Byte *)[mask bytes])[23])];
    }
    if (length > 192 && mask.length > 24) {
        result=[self setTAGMSK:TAGMSK_24_27 tagMask:((UInt32)(((Byte *)[mask bytes])[24] << 24)) + ((UInt32)(((Byte *)[mask bytes])[25] << 16)) + ((UInt32)(((Byte *)[mask bytes])[26] << 8)) + ((UInt32)((Byte *)[mask bytes])[27])];
    }
    if (length > 224 && mask.length > 28) {
        result=[self setTAGMSK:TAGMSK_28_31 tagMask:((UInt32)(((Byte *)[mask bytes])[28] << 24)) + ((UInt32)(((Byte *)[mask bytes])[29] << 16)) + ((UInt32)(((Byte *)[mask bytes])[30] << 8)) + ((UInt32)((Byte *)[mask bytes])[31])];
    }
    
    return result;
}

- (BOOL) selectTag:(MEMORYBANK)maskbank maskPointer:(UInt16)ptr maskLength:(UInt32)length maskData:(NSData*)mask {
    
    BOOL result=true;
    
    NSLog(@"Tag select mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    
    //Select the desired tag
    result=[self TAGMSK_DESC_CFG:true selectTarget:4 /* SL*/ selectAction:0];
    result=[self TAGMSK_BANK:maskbank];
    result=[self TAGMSK_PTR:ptr];
    result=[self TAGMSK_LEN:length];
    if (length > 0 && mask.length > 0) {
        result=[self setTAGMSK:TAGMSK_0_3 tagMask:((UInt32)(((Byte *)[mask bytes])[0] << 24)) + ((UInt32)(((Byte *)[mask bytes])[1] << 16)) + ((UInt32)(((Byte *)[mask bytes])[2] << 8)) + ((UInt32)((Byte *)[mask bytes])[3])];
    }
    if (length > 32 && mask.length > 4) {
        result=[self setTAGMSK:TAGMSK_4_7 tagMask:((UInt32)(((Byte *)[mask bytes])[4] << 24)) + ((UInt32)(((Byte *)[mask bytes])[5] << 16)) + ((UInt32)(((Byte *)[mask bytes])[6] << 8)) + ((UInt32)((Byte *)[mask bytes])[7])];
    }
    if (length > 64 && mask.length > 8) {
        result=[self setTAGMSK:TAGMSK_8_11 tagMask:((UInt32)(((Byte *)[mask bytes])[8] << 24)) + ((UInt32)(((Byte *)[mask bytes])[9] << 16)) + ((UInt32)(((Byte *)[mask bytes])[10] << 8)) + ((UInt32)((Byte *)[mask bytes])[11])];
    }
    if (length > 96 && mask.length > 12) {
        result=[self setTAGMSK:TAGMSK_12_15 tagMask:((UInt32)(((Byte *)[mask bytes])[12] << 24)) + ((UInt32)(((Byte *)[mask bytes])[13] << 16)) + ((UInt32)(((Byte *)[mask bytes])[14] << 8)) + ((UInt32)((Byte *)[mask bytes])[15])];
    }
    if (length > 128 && mask.length > 16) {
        result=[self setTAGMSK:TAGMSK_16_19 tagMask:((UInt32)(((Byte *)[mask bytes])[16] << 24)) + ((UInt32)(((Byte *)[mask bytes])[17] << 16)) + ((UInt32)(((Byte *)[mask bytes])[18] << 8)) + ((UInt32)((Byte *)[mask bytes])[19])];
    }
    if (length > 160 && mask.length > 20) {
        result=[self setTAGMSK:TAGMSK_20_23 tagMask:((UInt32)(((Byte *)[mask bytes])[20] << 24)) + ((UInt32)(((Byte *)[mask bytes])[21] << 16)) + ((UInt32)(((Byte *)[mask bytes])[22] << 8)) + ((UInt32)((Byte *)[mask bytes])[23])];
    }
    if (length > 192 && mask.length > 24) {
        result=[self setTAGMSK:TAGMSK_24_27 tagMask:((UInt32)(((Byte *)[mask bytes])[24] << 24)) + ((UInt32)(((Byte *)[mask bytes])[25] << 16)) + ((UInt32)(((Byte *)[mask bytes])[26] << 8)) + ((UInt32)((Byte *)[mask bytes])[27])];
    }
    if (length > 224 && mask.length > 28) {
        result=[self setTAGMSK:TAGMSK_28_31 tagMask:((UInt32)(((Byte *)[mask bytes])[28] << 24)) + ((UInt32)(((Byte *)[mask bytes])[29] << 16)) + ((UInt32)(((Byte *)[mask bytes])[30] << 8)) + ((UInt32)((Byte *)[mask bytes])[31])];
    }
    
    //stop after 1 tag inventoried, enable tag select, compact mode
    [self setInventoryConfigurations:FIXEDQ MatchRepeats:1 tagSelect:1 disableInventory:0 tagRead:0 crcErrorRead:1 QTMode:0 tagDelay:0 inventoryMode:0];
    
    return result;
}

- (BOOL) E710SelectTag:(Byte)set_number
              maskBank:(MEMORYBANK)maskbank
           maskPointer:(UInt32)ptr
            maskLength:(Byte)length
              maskData:(NSData*)mask
                target:(Byte)target
                action:(Byte)action
       postConfigDelay:(Byte)post_delay {
    
    Byte errorCode;
    NSData* regData;
    
    NSLog(@"Tag select mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    
    //Select the desired tag
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    unsigned short startAddress = 0x3140 + set_number * 42;
    
    //bank to be selected
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (Byte)maskbank } length:1];
    if (![self E710WriteRegister:self atAddr:startAddress+1 regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration bank select failed. Error code: %d", errorCode);
        return false;
    }
    
    //select offset (number of bits)
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (ptr & 0xFF000000) >> 24, (ptr & 0x00FF0000) >> 16, (ptr & 0x0000FF00) >> 8, ptr & 0x000000FF } length:4];
    if (![self E710WriteRegister:self atAddr:startAddress+2 regLength:4 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set offset failed. Error code: %d", errorCode);
        return false;
    }

    //select length (number of bits)
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ length } length:1];
    if (![self E710WriteRegister:self atAddr:startAddress+6 regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set length failed. Error code: %d", errorCode);
        return false;
    }
    
    //mask data: pad zero until getting 32 bytes
    NSMutableData *paddedData = [NSMutableData dataWithData:mask];
    [paddedData increaseLengthBy:(32 - [mask length])];
    if (![self E710WriteRegister:self atAddr:startAddress+7 regLength:[paddedData length] forData:[NSData dataWithData:paddedData] timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set mask failed. Error code: %d", errorCode);
        return false;
    }
    
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ target } length:1];
    if (![self E710WriteRegister:self atAddr:startAddress+39 regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set target failed. Error code: %d", errorCode);
        return false;
    }
    
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ action } length:1];
    if (![self E710WriteRegister:self atAddr:startAddress+40 regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set action failed. Error code: %d", errorCode);
        return false;
    }
    
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ post_delay } length:1];
    if (![self E710WriteRegister:self atAddr:startAddress+41 regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration set post configuration delay failed. Error code: %d", errorCode);
        return false;
    }
    
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ 1 } length:1];
    //enable set
    if (![self E710WriteRegister:self atAddr:startAddress regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration enable set failed. Error code: %d", errorCode);
        return false;
    }
    
    NSLog(@"RFID SelectConfiguration sent: OK");
    return true;
}

- (BOOL) E710DeselectTag:(Byte)set_number {
    
    Byte errorCode;
    NSData* regData;
    
    //Select the desired tag
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    unsigned short startAddress = 0x3140 + set_number * 42;
    
    //bank to be selected
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ 0 } length:1];
    //disable set
    if (![self E710WriteRegister:self atAddr:startAddress regLength:1 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"RFID SelectConfiguration disable set failed. Error code: %d", errorCode);
        return false;
    }
    
    NSLog(@"RFID SelectConfiguration sent: OK");
    return true;
}

- (BOOL) selectTagForSearch:(MEMORYBANK)maskbank maskPointer:(UInt16)ptr maskLength:(UInt32)length maskData:(NSData*)mask {
    return [self selectTagForSearch:maskbank maskPointer:ptr maskLength:length maskData:mask ledTags:FALSE];
}

- (BOOL) selectTagForSearch:(MEMORYBANK)maskbank maskPointer:(UInt16)ptr maskLength:(UInt32)length maskData:(NSData*)mask ledTags:(BOOL)isLEDEnabled {
    
    BOOL result=true;
    
    NSLog(@"Tag select mask in hex: %@", [CSLBleReader convertDataToHexString:mask] );
    
    //Select the desired tag
    result=[self TAGMSK_DESC_SEL:0];
    result=[self TAGMSK_DESC_CFG:true selectTarget:4 /* SL*/ selectAction:0];
    result=[self TAGMSK_BANK:maskbank];
    result=[self TAGMSK_PTR:ptr];
    result=[self TAGMSK_LEN:length];
    if (length > 0 && mask.length > 0) {
        result=[self setTAGMSK:TAGMSK_0_3 tagMask:((UInt32)(((Byte *)[mask bytes])[0] << 24)) + ((UInt32)(((Byte *)[mask bytes])[1] << 16)) + ((UInt32)(((Byte *)[mask bytes])[2] << 8)) + ((UInt32)((Byte *)[mask bytes])[3])];
    }
    if (length > 32 && mask.length > 4) {
        result=[self setTAGMSK:TAGMSK_4_7 tagMask:((UInt32)(((Byte *)[mask bytes])[4] << 24)) + ((UInt32)(((Byte *)[mask bytes])[5] << 16)) + ((UInt32)(((Byte *)[mask bytes])[6] << 8)) + ((UInt32)((Byte *)[mask bytes])[7])];
    }
    if (length > 64 && mask.length > 8) {
        result=[self setTAGMSK:TAGMSK_8_11 tagMask:((UInt32)(((Byte *)[mask bytes])[8] << 24)) + ((UInt32)(((Byte *)[mask bytes])[9] << 16)) + ((UInt32)(((Byte *)[mask bytes])[10] << 8)) + ((UInt32)((Byte *)[mask bytes])[11])];
    }
    if (length > 96 && mask.length > 12) {
        result=[self setTAGMSK:TAGMSK_12_15 tagMask:((UInt32)(((Byte *)[mask bytes])[12] << 24)) + ((UInt32)(((Byte *)[mask bytes])[13] << 16)) + ((UInt32)(((Byte *)[mask bytes])[14] << 8)) + ((UInt32)((Byte *)[mask bytes])[15])];
    }
    if (length > 128 && mask.length > 16) {
        result=[self setTAGMSK:TAGMSK_16_19 tagMask:((UInt32)(((Byte *)[mask bytes])[16] << 24)) + ((UInt32)(((Byte *)[mask bytes])[17] << 16)) + ((UInt32)(((Byte *)[mask bytes])[18] << 8)) + ((UInt32)((Byte *)[mask bytes])[19])];
    }
    if (length > 160 && mask.length > 20) {
        result=[self setTAGMSK:TAGMSK_20_23 tagMask:((UInt32)(((Byte *)[mask bytes])[20] << 24)) + ((UInt32)(((Byte *)[mask bytes])[21] << 16)) + ((UInt32)(((Byte *)[mask bytes])[22] << 8)) + ((UInt32)((Byte *)[mask bytes])[23])];
    }
    if (length > 192 && mask.length > 24) {
        result=[self setTAGMSK:TAGMSK_24_27 tagMask:((UInt32)(((Byte *)[mask bytes])[24] << 24)) + ((UInt32)(((Byte *)[mask bytes])[25] << 16)) + ((UInt32)(((Byte *)[mask bytes])[26] << 8)) + ((UInt32)((Byte *)[mask bytes])[27])];
    }
    if (length > 224 && mask.length > 28) {
        result=[self setTAGMSK:TAGMSK_28_31 tagMask:((UInt32)(((Byte *)[mask bytes])[28] << 24)) + ((UInt32)(((Byte *)[mask bytes])[29] << 16)) + ((UInt32)(((Byte *)[mask bytes])[30] << 8)) + ((UInt32)((Byte *)[mask bytes])[31])];
    }
    
    //stop after 1 tag inventoried, enable tag select, compact mode
    if (!isLEDEnabled)
        [self setInventoryConfigurations:FIXEDQ MatchRepeats:0 tagSelect:1 disableInventory:0 tagRead:0 crcErrorRead:1 QTMode:0 tagDelay:30 inventoryMode:0];
    else
        [self setInventoryConfigurations:FIXEDQ MatchRepeats:0 tagSelect:1 /* force tag_select */ disableInventory:0 tagRead:1 crcErrorRead:true QTMode:0 tagDelay:30 inventoryMode:0];
    
    return result;
}

- (BOOL) startTagMemoryRead:(MEMORYBANK)bank dataOffset:(UInt16)offset dataCount:(UInt16)count ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {
    
    BOOL result=true;
    CSLBlePacket *recvPacket;
    
    result=[self setParametersForTagAccess];
    self.isTagAccessMode=true;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        result=[self selectTag:mask_bank maskPointer:32 maskLength:mask_Length  maskData:mask_data];
    
    result = [self TAGACC_BANK:bank acc_bank2:0];
    result = [self TAGACC_PTR:offset];
    result = [self TAGACC_CNT:count secondBank:0];
    result = [self TAGACC_ACCPWD:password];
    result = [self sendHostCommandRead];
    
    //wait for the command-begin and command-end packet
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] < 2) {
        NSLog(@"Tag read command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //command-begin
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
        [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        self.lastMacErrorCode=0x0000;
        NSLog(@"Receive read command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive read command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //decode command-end
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0180"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0100"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00)
        )
        NSLog(@"Receive read command-end response: OK");
    else
    {
        NSLog(@"Receive read command-end response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL) E710StartTagMemoryRead:(MEMORYBANK)bank dataOffset:(UInt16)offset dataCount:(UInt16)count ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {
    
    BOOL result=true;
    Byte errorCode;
    NSData* regData;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        [self E710SelectTag:0
                   maskBank:mask_bank
                maskPointer:mask_pointer
                 maskLength:mask_Length
                   maskData:mask_data
                     target:4
                     action:0
            postConfigDelay:0];
    
    //set access password
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (password & 0xFF000000) >> 24, (password & 0x00FF0000 )>> 16, (password & 0x0000FF00) >> 8, password & 0x000000FF } length:4];
    if (![self E710WriteRegister:self atAddr:0x38A6 regLength:4 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryRead failed. Failed to set access password.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //for Multi-bank read configurations
    //For EPC bank, read one full
    Byte MBOffset = bank == EPC ? offset - 1 : offset;
    if (MBOffset < 0)
        MBOffset = 0;
    if (![self E710MultibankReadConfig:0 IsEnabled:TRUE Bank:bank Offset:MBOffset Length:(bank == EPC ? count+1 : count)]) {
        NSLog(@"E710StartTagMemoryRead failed. Failed to set mulit-bank read.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    //disable other two sets of config
    if (![self E710MultibankReadConfig:1 IsEnabled:FALSE Bank:0 Offset:0 Length:0]) {
        NSLog(@"E710StartTagMemoryRead failed. Failed to set mulit-bank read.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    if (![self E710MultibankReadConfig:2 IsEnabled:FALSE Bank:0 Offset:0 Length:0]) {
        NSLog(@"E710StartTagMemoryRead failed. Failed to set mulit-bank read.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    result = [self E710SSCSLRFIDReadMB];
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL)E710SSCSLRFIDReadMB {

    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10B1 timeOutInSeconds:1])
    {
        NSLog(@"Read mulit-bank data: OK");
        return true;

    }
    NSLog(@"Read mulit-bank data: FAILED");
    return false;
    
}

- (BOOL)E710SSCSLRFIDWriteMB {

    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10B2 timeOutInSeconds:1])
    {
        NSLog(@"Write mulit-bank data: OK");
        return true;

    }
    NSLog(@"Write mulit-bank data: FAILED");
    return false;
    
}

- (BOOL)E710SCSLRFIDLock {
    
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10B7 timeOutInSeconds:1])
    {
        NSLog(@"RFID Lock: OK");
        return true;
        
    }
    NSLog(@"RFID Lock: FAILED");
    return false;
    
}

- (BOOL)E710SCSLRFIDKill {
    
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10B8 timeOutInSeconds:1])
    {
        NSLog(@"RFID Kill: OK");
        return true;
        
    }
    NSLog(@"RFID Kill: FAILED");
    return false;
    
}

- (BOOL)StartSelectInventory{
    
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10A3 timeOutInSeconds:1])
    {
        NSLog(@"RFID Tag Search: OK");
        connectStatus = TAG_OPERATIONS;
        return true;
        
    }
    NSLog(@"RFID Tag Search: FAILED");
    return false;
    
}

- (BOOL)E710SCSLRFIDAuthenticate {
    
    if (self.readerModelNumber != CS710) {
        NSLog(@"RFID command failed. Invalid reader");
        return false;
    }
    
    if ([self E710SendShortOperationCommand:self CommandCode:0x10B9 timeOutInSeconds:1])
    {
        NSLog(@"RFID Tag authentication: OK");
        return true;
        
    }
    NSLog(@"RFID Tag authentication: FAILED");
    return false;
    
}

- (BOOL) startTagMemoryWrite:(MEMORYBANK)bank dataOffset:(UInt16)offset dataCount:(UInt16)count writeData:(NSData*)data ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {
    
    int ptr, ptr2;  //tag write buffer pointer
    BOOL result=true;
    CSLBlePacket *recvPacket;
    
    result=[self setParametersForTagAccess];
    self.isTagAccessMode=true;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        result=[self selectTag:mask_bank maskPointer:32 maskLength:mask_Length  maskData:mask_data];
    
    result = [self TAGACC_DESC_CFG:true retryCount:7];
    result = [self TAGACC_BANK:bank acc_bank2:0];
    result = [self TAGACC_PTR:offset];
    result = [self TAGACC_CNT:count secondBank:0];
    result = [self TAGACC_ACCPWD:password];

    
    ptr=0; ptr2=0;
    while ([data length] > ptr2) {
        //set TAGWRDAT bank
        [self TAGWRDAT_SEL:(ptr2/32)];
        
        if ([data length]  > ptr2) {
            result = [self setTAGWRDAT:0x0A09 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length]  > ptr2) {
            result = [self setTAGWRDAT:0x0A0A data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length]  > ptr2) {
            result = [self setTAGWRDAT:0x0A0B data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length]  > ptr2) {
            result = [self setTAGWRDAT:0x0A0C data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length]  > ptr2) {
            result = [self setTAGWRDAT:0x0A0D data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A0E data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A0F data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A10 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A11 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A12 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A13 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A14 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A15 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A16 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A17 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
        if ([data length] > ptr2) {
            result = [self setTAGWRDAT:0x0A18 data_word:((((Byte*)[data bytes])[ptr2] << 8)+((Byte*)[data bytes])[ptr2+1]) data_offset:ptr];
            ptr++; ptr2+=2;
        }
    }
    
    result = [self sendHostCommandWrite];
    
    //wait for the command-begin and command-end packet
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] < 2) {
        NSLog(@"Tag read command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //command-begin
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        self.lastMacErrorCode=0x0000;
        NSLog(@"Receive read command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive read command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //decode command-end
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0180"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0100"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00)
        )
        NSLog(@"Receive read command-end response: OK");
    else
    {
        NSLog(@"Receive read command-end response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }

    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL) E710StartTagMemoryWrite:(MEMORYBANK)bank dataOffset:(UInt16)offset dataCount:(UInt16)count writeData:(NSData*)data ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {

    BOOL result=true;
    Byte errorCode;
    NSData* regData;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        [self E710SelectTag:0
                   maskBank:mask_bank
                maskPointer:mask_pointer
                 maskLength:mask_Length
                   maskData:mask_data
                     target:4
                     action:0
            postConfigDelay:0];
    
    //set access password
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (password & 0xFF000000) >> 24, (password & 0x00FF0000 )>> 16, (password & 0x0000FF00) >> 8, password & 0x000000FF } length:4];
    if (![self E710WriteRegister:self atAddr:0x38A6 regLength:4 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryWrite failed. Failed to set access password.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //for Multi-bank read configurations
    //For EPC bank, read one full
    if (![self E710MultibankWriteConfig:0 IsEnabled:TRUE Bank:bank Offset:offset Length:count forData:data]) {
        NSLog(@"E710StartTagMemoryWrite failed. Failed to set mulit-bank write.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    result = [self E710SSCSLRFIDWriteMB];
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL) startTagSearch:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {
    return [self startTagSearch:mask_bank maskPointer:mask_pointer maskLength:mask_Length maskData:mask_data ledTag:FALSE];
}

- (BOOL) startTagSearch:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data ledTag:(BOOL)isLEDEnabled {
    
    if (self.readerModelNumber != CS710) {
        BOOL result=true;
        CSLBlePacket *recvPacket;
        
        result=[self setParametersForTagSearch];
        self.isTagAccessMode=true;
        
        //if mask data is not nil, tag will be selected before reading
        if (mask_data != nil)
            result=[self selectTagForSearch:mask_bank maskPointer:32 maskLength:mask_Length  maskData:mask_data ledTags:isLEDEnabled];
        
        if(isLEDEnabled) {
            [self TAGACC_BANK:USER acc_bank2:0];
            [self TAGACC_PTR:112];
            [self TAGACC_CNT:1 secondBank:0];
        }
        
        if (! isLEDEnabled)
            result = [self sendHostCommandSearch];
        else
            return [self startInventory];
        
        //wait for the command-begin and command-end packet
        for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
            if ([self.cmdRespQueue count] >= 1)
                break;
            [NSThread sleepForTimeInterval:0.001f];
        }
        
        if ([self.cmdRespQueue count] < 1) {
            NSLog(@"Tag search command timed out.");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
        
        //command-begin
        recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
        if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
             [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
            ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
             [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
            ) {
            self.lastMacErrorCode=0x0000;
            NSLog(@"Receive search command-begin response: OK");
        }
        else
        {
            NSLog(@"Receive search command-begin response: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return FALSE;
        }
        connectStatus=TAG_OPERATIONS;
        //[self performSelectorInBackground:@selector(decodePacketsInBufferAsync) withObject:(nil)];
        return true;
    }
    else {
        BOOL result=true;
        
        //if mask data is not nil, tag will be selected before reading
        if (mask_data != nil)
            [self E710SelectTag:0
                       maskBank:mask_bank
                    maskPointer:mask_pointer
                     maskLength:mask_Length
                       maskData:mask_data
                         target:4
                         action:0
                postConfigDelay:0];
        
        //LED Tags
        if (isLEDEnabled) {
            [self E710MultibankReadConfig:0
                                IsEnabled:TRUE
                                     Bank:USER
                                   Offset:112
                                   Length:1];
            
            NSLog(@"LED tag CS6861 flashing is enabled");
        }
        
        if (isLEDEnabled)
            result = [self E710StartSelectMBInventory];
        else
            result = [self E710StartSelectCompactInventory];
        
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return result;
    }
}

- (BOOL)stopTagSearch {
    
    return [self stopInventory];

}

- (void)stopTagSearchBlocking {
    
    @autoreleasepool {
        //Initialize data
        CSLBlePacket* packet= [[CSLBlePacket alloc] init];
        
        if (connectStatus==TAG_OPERATIONS)
        {
            NSLog(@"----------------------------------------------------------------------");
            NSLog(@"Abort command for tag search...");
            NSLog(@"----------------------------------------------------------------------");
            //Send abort command
            unsigned char abortCmd[] = {0x80, 0x02, 0x40, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
            packet.prefix=0xA7;
            packet.connection = Bluetooth;
            packet.payloadLength=0x0A;
            packet.deviceId=RFID;
            packet.Reserve=0x82;
            packet.direction=Downlink;
            packet.crc1=0;
            packet.crc2=0;
            packet.payload=[NSData dataWithBytes:abortCmd length:sizeof(abortCmd)];
            
            NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
            [self sendPackets:packet];
        }
    }
    
}
- (BOOL) TAGACC_LOCKCFG:(UInt32)lockCommandConfigBits {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [self.cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"TAGACC_LOCKCFG - Specify the parameters for a lock operation");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char TAGACC_LOCKCFG[] = {0x80, 0x02, 0x70, 0x01, 0x05, 0x0A, (lockCommandConfigBits & 0xFF), (lockCommandConfigBits & 0xFF00) >> 8, (lockCommandConfigBits & 0xF0000) >> 16, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TAGACC_LOCKCFG length:sizeof(TAGACC_LOCKCFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([self.cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([self.cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[self.cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], TAGACC_LOCKCFG, 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"TAGACC_LOCKCFG sent OK");
        return true;
    }
    else {
        NSLog(@"TAGACC_LOCKCFG sent FAILED");
        return false;
    }
}

- (BOOL) startTagMemoryLock:(UInt32)lockCommandConfigBits ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data{
    
    BOOL result=true;
    CSLBlePacket *recvPacket;
    
    result=[self setParametersForTagAccess];
    self.isTagAccessMode=true;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        result=[self selectTag:mask_bank maskPointer:32 maskLength:mask_Length  maskData:mask_data];
    
    result = [self TAGACC_DESC_CFG:true retryCount:7];
    result = [self TAGACC_LOCKCFG:lockCommandConfigBits];
    result = [self TAGACC_ACCPWD:password];
    result = [self sendHostCommandLock];
    
    //wait for the command-begin and command-end packet
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] < 2) {
        NSLog(@"Tag read command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //command-begin
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        self.lastMacErrorCode=0x0000;
        NSLog(@"Receive read command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive read command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //decode command-end
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0180"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0100"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00)
        )
        NSLog(@"Receive lock command-end response: OK");
    else
    {
        NSLog(@"Receive lock command-end response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL) E710StartTagMemoryLock:(UInt32)lockCommandConfigBits ACCPWD:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data {
    
    BOOL result=true;
    Byte errorCode;
    NSData* regData;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        [self E710SelectTag:0
                   maskBank:mask_bank
                maskPointer:mask_pointer
                 maskLength:mask_Length
                   maskData:mask_data
                     target:4
                     action:0
            postConfigDelay:0];
    
    //set access password
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (password & 0xFF000000) >> 24, (password & 0x00FF0000 )>> 16, (password & 0x0000FF00) >> 8, password & 0x000000FF } length:4];
    if (![self E710WriteRegister:self atAddr:0x38A6 regLength:4 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryLock failed. Failed to set access password.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //for setting mask and action bits
    //mask bits
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (lockCommandConfigBits & 0xC0000) >> 18, (lockCommandConfigBits & 0x3FC00) >> 10 } length:2];
    if (![self E710WriteRegister:self atAddr:0x38AE regLength:2 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryLock failed. Failed to set lock mask.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //action bits
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (lockCommandConfigBits & 0x300) >> 8, lockCommandConfigBits & 0xFF } length:2];
    if (![self E710WriteRegister:self atAddr:0x38B0 regLength:2 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryLock failed. Failed to set lock action.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    result = [self E710SCSLRFIDLock];
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
    
}

- (BOOL) startTagMemoryKill:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data{
    
    BOOL result=true;
    CSLBlePacket *recvPacket;
    
    result=[self setParametersForTagAccess];
    self.isTagAccessMode=true;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        result=[self selectTag:mask_bank maskPointer:32 maskLength:mask_Length  maskData:mask_data];
    
    result = [self TAGACC_DESC_CFG:true retryCount:7];
    result = [self TAGACC_KILLPWD:password];
    result = [self sendHostCommandKill];
    
    //wait for the command-begin and command-end packet
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([self.cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([self.cmdRespQueue count] < 2) {
        NSLog(@"Tag kill command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //command-begin
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        self.lastMacErrorCode=0x0000;
        NSLog(@"Receive kill command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive kill command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //decode command-end
    recvPacket = ((CSLBlePacket *)[self.cmdRespQueue deqObject]);
    if (
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0180"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0100"] && ((Byte *)[recvPacket.payload bytes])[14] == 0x00 && ((Byte *)[recvPacket.payload bytes])[15] == 0x00)
        )
        NSLog(@"Receive kill command-end response: OK");
    else
    {
        NSLog(@"Receive kill command-end response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}

- (BOOL) E710StartTagMemoryKill:(UInt32)password maskBank:(MEMORYBANK)mask_bank maskPointer:(UInt16)mask_pointer maskLength:(UInt32)mask_Length maskData:(NSData*)mask_data{
    
    BOOL result=true;
    Byte errorCode;
    NSData* regData;
    
    //if mask data is not nil, tag will be selected before reading
    if (mask_data != nil)
        [self E710SelectTag:0
                   maskBank:mask_bank
                maskPointer:mask_pointer
                 maskLength:mask_Length
                   maskData:mask_data
                     target:4
                     action:0
            postConfigDelay:0];
    
    //set kill password
    regData = [[NSData alloc] initWithBytes:(unsigned char[]){ (password & 0xFF000000) >> 24, (password & 0x00FF0000 )>> 16, (password & 0x0000FF00) >> 8, password & 0x000000FF } length:4];
    if (![self E710WriteRegister:self atAddr:0x38AA regLength:4 forData:regData timeOutInSeconds:1 error:&errorCode])
    {
        NSLog(@"E710StartTagMemoryKill failed. Failed to set kill password.  Error code: %d", errorCode);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
        
    result = [self E710SCSLRFIDKill];
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return result;
}
@end
