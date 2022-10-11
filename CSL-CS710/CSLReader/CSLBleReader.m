//
//  CSLBleReader.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "CSLBleReader.h"

//define private methods and variables

@interface CSLBleReader() {
    CSLCircularQueue * cmdRespQueue;     //Buffer for storing response packet(s) after issuing a command synchronously
    Byte SequenceNumber;
}
- (void) stopInventoryBlocking;

@end

@implementation CSLBleReader

@synthesize filteredBuffer;
@synthesize delegate; //synthesize CSLBleReaderDelegate delegate
@synthesize rangingTagCount;
@synthesize uniqueTagCount;
@synthesize readerTagRate;
@synthesize batteryInfo;
@synthesize cmdRespQueue;

- (id) init
{
    if (self = [super init])
    {
        rangingTagCount=0;
        uniqueTagCount=0;
        batteryInfo=[[CSLReaderBattery alloc] initWithPcBVersion:1.8];
        cmdRespQueue=[[CSLCircularQueue alloc] initWithCapacity:16000];
        SequenceNumber=0;
    }
    return self;
}

- (void) dealloc
{
    
    
}

- (void) connectDevice:(CBPeripheral*) peripheral {

    [super connectDevice:peripheral];
    [self performSelectorInBackground:@selector(decodePacketsInBufferAsync) withObject:(nil)];
    
}

- (BOOL)readOEMData:(CSLBleInterface*)intf atAddr:(unsigned short)addr forData:(UInt32*)data
{
    @synchronized(self) {
        if (self.connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [cmdRespQueue removeAllObjects];
    
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    UInt32 OEMData=0;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Read OEM data (address: 0x%X)...", addr);
    NSLog(@"----------------------------------------------------------------------");
    //read OEM Address
    unsigned char OEMAddr[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0x05, addr & 0x000000FF, (addr & 0x0000FF00) >> 8, (addr & 0x00FF0000) >> 16, (addr & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:OEMAddr length:sizeof(OEMAddr)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [intf sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] !=0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }

    if ([cmdRespQueue count] != 0)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }

    if (memcmp([recvPacket.payload bytes], OEMAddr, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Set OEM data address: OK");
    else
    {
        NSLog(@"Set OEM data address: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    NSLog(@"Send HST_CMD 0x00000003 to read OEM data...");
    //Send HST_CMD
    unsigned char OEMHSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x03, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:OEMHSTCMD length:sizeof(OEMHSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [intf sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
        
    //command-begin
    recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        NSLog(@"Receive HST_CMD 0x03 command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive HST_CMD 0x03 command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    //OEM read response
    if ([recvPacket.payload length] < 50) {
        NSLog(@"Receive HST_CMD 0x03 response (length check): FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(36, 2)] isEqualToString:@"01"] &&
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(40, 4)] isEqualToString:@"0730"])) {

        OEMData = ((Byte *)[recvPacket.payload bytes])[30] +
        (((Byte *)[recvPacket.payload bytes])[31] << 8) +
        (((Byte *)[recvPacket.payload bytes])[32] << 16) +
        (((Byte *)[recvPacket.payload bytes])[33] << 24);
        
        *data = OEMData;


    }
    else
    {
        NSLog(@"Receive HST_CMD 0x03 command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }

    
    //command-end
    //recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(68, 2)] isEqualToString:@"02"] ||
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(68, 2)] isEqualToString:@"01"]) &&
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(72, 4)] isEqualToString:@"0180"] ||
         [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(72, 4)] isEqualToString:@"0100"]) &&
        ((Byte *)[recvPacket.payload bytes])[46] == 0x00 &&
        ((Byte *)[recvPacket.payload bytes])[47] == 0x00) {
        self.lastMacErrorCode=(((Byte *)[recvPacket.payload bytes])[15] << 8) + (((Byte *)[recvPacket.payload bytes])[14]);
        NSLog(@"Receive HST_CMD 0x03 command-end response: OK");
    }
    else
    {
        NSLog(@"Receive HST_CMD 0x03 command-end response: FAILED");
        self.lastMacErrorCode=(((Byte *)[recvPacket.payload bytes])[15] << 8) + (((Byte *)[recvPacket.payload bytes])[14]);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
    
}

- (BOOL)setFrequencyBand:(UInt32)frequencySelector bandState:(BOOL) config multdiv:(UInt32)mult_div pllcc:(UInt32) pll_cc {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write selector address to register RFTC_FRQCH_SEL 0x0C01");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char FRQCH_SEL[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x0C, frequencySelector & 0xFF, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:FRQCH_SEL length:sizeof(FRQCH_SEL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], FRQCH_SEL, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set FRQCH_SEL: OK");
        else {
            NSLog(@"Set FRQCH_SEL: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    packet= [[CSLBlePacket alloc] init];
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write config address to register RFTC_FRQCH_CFG 0x0C02");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char FRQCH_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x02, 0x0C, config ? 1 : 0, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:FRQCH_CFG length:sizeof(FRQCH_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], FRQCH_CFG, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set FRQCH_CFG: OK");
        else {
            NSLog(@"Set FRQCH_CFG: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    if (config) {
        packet= [[CSLBlePacket alloc] init];
        NSLog(@"----------------------------------------------------------------------");
        NSLog(@"Write multdiv address to register RFTC_FRQCH_DESC_PLLDIVMULT 0x0C03");
        NSLog(@"----------------------------------------------------------------------");
        
        unsigned char PLLDIVMULT[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x0C, mult_div & 0x000000FF, (mult_div & 0x0000FF00) >> 8, (mult_div & 0x00FF0000) >> 16, (mult_div & 0xFF000000) >> 24};
        packet.prefix=0xA7;
        packet.connection = Bluetooth;
        packet.payloadLength=0x0A;
        packet.deviceId=RFID;
        packet.Reserve=0x82;
        packet.direction=Downlink;
        packet.crc1=0;
        packet.crc2=0;
        packet.payload=[NSData dataWithBytes:PLLDIVMULT length:sizeof(PLLDIVMULT)];
        
        NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
        [self sendPackets:packet];
        
        for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
            if([cmdRespQueue count] != 0)
                break;
            [NSThread sleepForTimeInterval:0.001f];
        }
        
        if ([cmdRespQueue count] != 0) {
            recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
            if (memcmp([recvPacket.payload bytes], PLLDIVMULT, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
                NSLog(@"Set PLLDIVMULT: OK");
            else {
                NSLog(@"Set PLLDIVMULT: FAILED");
                connectStatus=CONNECTED;
                [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
                return false;
            }
        }
        else {
            NSLog(@"Command response failure.");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
        
        packet= [[CSLBlePacket alloc] init];
        NSLog(@"----------------------------------------------------------------------");
        NSLog(@"Write PLLCC address to register RFTC_FRQCH_DESC_PLLDACCTL 0x0C04");
        NSLog(@"----------------------------------------------------------------------");
        
        unsigned char PLLCC[] = {0x80, 0x02, 0x70, 0x01, 0x04, 0x0C, pll_cc & 0x000000FF, (pll_cc & 0x0000FF00) >> 8, (pll_cc & 0x00FF0000) >> 16, (pll_cc & 0xFF000000) >> 24};
        packet.prefix=0xA7;
        packet.connection = Bluetooth;
        packet.payloadLength=0x0A;
        packet.deviceId=RFID;
        packet.Reserve=0x82;
        packet.direction=Downlink;
        packet.crc1=0;
        packet.crc2=0;
        packet.payload=[NSData dataWithBytes:PLLCC length:sizeof(PLLCC)];
        
        NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
        [self sendPackets:packet];
        
        for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
            if([cmdRespQueue count] != 0)
                break;
            [NSThread sleepForTimeInterval:0.001f];
        }
        
        if ([cmdRespQueue count] != 0) {
            recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
            if (memcmp([recvPacket.payload bytes], PLLCC, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
                NSLog(@"Set PLLCC: OK");
            else {
                NSLog(@"Set PLLCC: FAILED");
                connectStatus=CONNECTED;
                [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
                return false;
            }
        }
        else {
            NSLog(@"Command response failure.");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;

}

- (BOOL) SetHoppingChannel:(CSLReaderFrequency*) frequencyInfo RegionCode:(NSString*)region {
    
    UInt32 channelCount=(UInt32)[(NSArray*)frequencyInfo.FrequencyValues[region] count];
    
    //Enable channels
    for (UInt32 i = 0; i < channelCount; i++)
    {
        
        if (![self setFrequencyBand:i
                     bandState:true
                       multdiv:[[((NSArray*)[frequencyInfo.FrequencyValues objectForKey:region]) objectAtIndex:i] unsignedIntValue]
                         pllcc:[self GetPllcc:region]])
            return false;

    }

    //Disable channels
    for (UInt32 i = channelCount; i < 50; i++)
    {
        if (![self setFrequencyBand:i
                     bandState:false
                       multdiv:0
                         pllcc:0])
            return false;
    }
    return true;
}

- (BOOL) SetFixedChannel:(CSLReaderFrequency*) frequencyInfo RegionCode:(NSString*)region channelIndex:(UInt32)index {
    
    //get the frequncy value of the selected index
    int ind=[[((NSArray*)[frequencyInfo.FrequencyIndex objectForKey:region]) objectAtIndex:index] unsignedIntValue];
    UInt32 frequencyValue=[[((NSArray*)[frequencyInfo.FrequencyValues objectForKey:region]) objectAtIndex:ind] unsignedIntValue];
    
    
    //Enable channel
    if(![self setFrequencyBand:0
                 bandState:true
                   multdiv:frequencyValue
                     pllcc:[self GetPllcc:region]])
        return false;

    //Disable channels
    for (uint i = 1; i < 50; i++)
    {
        if(![self setFrequencyBand:i
                     bandState:false
                       multdiv:0
                         pllcc:0])
            return false;
    }

    return true;
}

- (UInt32) GetPllcc:(NSString*) region {


     if ([region isEqualToString:@"G800"] ||
         [region isEqualToString:@"ETSI"] ||
         [region isEqualToString:@"IN"]) {
         
         return 0x14070400;
     }
            
     return 0x14070200;
}
         
- (BOOL)setLNAParameters:(CSLBleInterface*)intf rflnaHighComp:(Byte)rflna_high_comp rflnaGain:(Byte)rflna_gain iflnaGain:(Byte)iflna_gain ifagcGain:(Byte)ifagc_gain
{
    @synchronized(self) {
        if (self.connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    
        connectStatus=BUSY;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [cmdRespQueue removeAllObjects];
    
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write HST_MBP_ADDR (address: 0x0400)...");
    NSLog(@"----------------------------------------------------------------------");
    //Write address 0x0405 for ANA_RX_GAIN_NORM
    unsigned int addr = 0x0405;
    unsigned char MBPAddr[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0x04, addr & 0x000000FF, (addr & 0x0000FF00) >> 8, (addr & 0x00FF0000) >> 16, (addr & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:MBPAddr length:sizeof(MBPAddr)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [intf sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] !=0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }

    if ([cmdRespQueue count] != 0)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }

    if (memcmp([recvPacket.payload bytes], MBPAddr, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Set MBP address: OK");
    else
    {
        NSLog(@"Set MBP address: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    packet= [[CSLBlePacket alloc] init];
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write HST_MBP_DATA (address: 0x0401)...");
    NSLog(@"----------------------------------------------------------------------");
    //Write address 0x0405 for ANA_RX_GAIN_NORM
    unsigned int data = (ifagc_gain & 0x07) | ((iflna_gain & 0x07) << 3) | ((rflna_gain & 0x03) << 6) | ((rflna_high_comp & 0x1) << 8);
    unsigned char MBPData[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x04, data & 0x000000FF, (data & 0x0000FF00) >> 8, (data & 0x00FF0000) >> 16, (data & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:MBPData length:sizeof(MBPData)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [intf sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] !=0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }

    if ([cmdRespQueue count] != 0)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }

    if (memcmp([recvPacket.payload bytes], MBPData, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Set MBP data: OK");
    else
    {
        NSLog(@"Set MBP data: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    NSLog(@"Send HST_CMD 0x00000006 to write to tilden register...");
    //Send HST_CMD
    unsigned char TILHSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x06, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:TILHSTCMD length:sizeof(TILHSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [intf sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 1)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    

    if (memcmp([recvPacket.payload bytes], TILHSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x06 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x06 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return TRUE;
}

- (BOOL)setImpinjExtension:(Byte)tag_Focus fastId:(Byte)fast_id blockWriteMode:(Byte)blockwrite_mode  {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set Impinj extension register
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set Impinj extension register 0x0203");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned int value=(blockwrite_mode & 0x0F) | ((tag_Focus & 0x01) << 4) | ((fast_id & 0x01) << 5);
    unsigned char IMPJ_EXT[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x02, value & 0xFF, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:IMPJ_EXT length:sizeof(IMPJ_EXT)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], IMPJ_EXT, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set Impinj extension: OK");
        else {
            NSLog(@"Set Impinj extension: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)barcodeReader:(BOOL)enable
{
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
    [cmdRespQueue removeAllObjects];

    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    //power on barcode
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Power %s barcode module...", enable ? "on" : "off");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char barcodeOn[]= {0x90, 0x00};
    if (!enable)
        barcodeOn[1]=0x01;
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=Barcode;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:barcodeOn length:sizeof(barcodeOn)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], barcodeOn, sizeof(barcodeOn)) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"Power %s barcode module OK", enable ? "on" : "off");
        return true;
    }
    else {
        NSLog(@"Power %s barcode module FAILED", enable ? "on" : "off");
        return false;
    }
}


- (BOOL)barcodeReaderSendCommand:(NSData*)command
{
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
    [cmdRespQueue removeAllObjects];

    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    //power on barcode
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Send command to barcode reader");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char barcodeCmd[]= {0x90, 0x03};
    unsigned char barcodeRsp[]= {0x91, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02+[command length];
    packet.deviceId=Barcode;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    
    NSMutableData *payload = [[NSData dataWithBytes:barcodeCmd length:sizeof(barcodeCmd)] mutableCopy];
    [payload appendData:command];
    packet.payload=[payload copy];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] > 1)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] > 1)
        payloadData = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    if (memcmp([payloadData bytes], barcodeCmd, sizeof(barcodeCmd)) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"Send barcode command OK");
    }
    else {
        NSLog(@"end barcode command FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    payloadData = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;

    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], barcodeRsp, sizeof(barcodeRsp)) == 0 && ((Byte *)[payloadData bytes])[2] == 0x06) {
        NSLog(@"Barcode command ACCEPTED");
        return true;
    }
    else {
        NSLog(@"Barcode command REJECTED");
        return false;
    }
    
    
}

- (BOOL)sendBarcodeCommandData: (NSData*)data
{
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
    [cmdRespQueue removeAllObjects];
    
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    //power on barcode
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@" Send command to barcode ");
    NSLog(@"----------------------------------------------------------------------");
    //unsigned char barcodeStart[] = {0x90, 0x03, 0x1b, 0x33};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x04;
    packet.deviceId=Barcode;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithData:data];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], [data bytes], 2) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"Send barcode command OK");
        return true;
    }
    else {
        NSLog(@"Sned barcode command FAILED");
        return false;
    }
}


- (BOOL)startBarcodeReading
{
    unsigned char dataBytes[] = {0x1B, 0x33};
    NSData* data=[NSData dataWithBytes:dataBytes length:2];
    NSLog(@"Start barcode reading...");
    if ([self barcodeReaderSendCommand:data])
        return true;
    else
        return false;
}

- (BOOL)stopBarcodeReading
{
    unsigned char dataBytes[] = {0x1B, 0x30};
    NSData* data=[NSData dataWithBytes:dataBytes length:2];
    NSLog(@"Stop barcode reading...");
    if ([self barcodeReaderSendCommand:data])
        return true;
    else
        return false;
}

- (BOOL)powerOnRfid:(BOOL)enable
{
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * payloadData;
    
    //power RFID
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Power %s RFID module...", enable ? "on" : "off");
    NSLog(@"----------------------------------------------------------------------");
    unsigned char powerRfid[] = {0x80, (enable ? 0x00 : 0x01)};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:powerRfid length:sizeof(powerRfid)];

    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];

    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] != 0)
        payloadData = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    if (memcmp([payloadData bytes], powerRfid, sizeof(powerRfid)) == 0 && ((Byte *)[payloadData bytes])[2] == 0x00) {
        NSLog(@"Power %s RFID module OK", (enable ? "on" : "off"));
        return true;
    }
    else {
        NSLog(@"Power %s RFID module FAILED", (enable ? "on" : "off"));
        return false;
    }
}
- (BOOL)getBtFirmwareVersion:(NSString **)versionNumber
{
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSData * versionInfo;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get Bluetooth IC firmware version...");
    NSLog(@"----------------------------------------------------------------------");
    //Get BT IC FW version
    unsigned char getBTFWVersion[] = {0xC0, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=BluetoothIC;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:getBTFWVersion length:sizeof(getBTFWVersion)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];

    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
       if([cmdRespQueue count] != 0)
           break;
           [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] != 0)
        versionInfo = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
    else
    {
        NSLog(@"Command timed out.");
        NSLog(@"Get BT IC firmware version: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    NSString * btFwVersion = [NSString stringWithFormat:@"%d.%d.%d", ((Byte*)[versionInfo bytes])[2], ((Byte*)[versionInfo bytes])[3], ((Byte*)[versionInfo bytes])[4]];
    NSLog(@"Bluetooth IC firmware version: %@", btFwVersion);
    
    *versionNumber=btFwVersion;
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL) getConnectedDeviceName:(NSString **) deviceName
{
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];

    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get device name...");
    NSLog(@"----------------------------------------------------------------------");
    //Get device name
    unsigned char dev[] = {0xC0, 0x04};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=BluetoothIC;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:dev length:sizeof(dev)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
            [NSThread sleepForTimeInterval:0.001f];
    }
        
    if ([cmdRespQueue count] != 0) {
        NSData * name = [((CSLBlePacket *)[cmdRespQueue deqObject]).payload subdataWithRange:NSMakeRange(2, 21)];
        *deviceName = [NSString stringWithUTF8String:[name bytes]];
        NSLog(@"Device Name: %@", *deviceName);
    }
    else {
        NSLog(@"Command timed out.");
        NSLog(@"Get connected device name: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}
- (BOOL)getSilLabIcVersion:(NSString **) slVersion
{
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get SilconLab IC firmware version...");
    NSLog(@"----------------------------------------------------------------------");

    //Get SilconLab IC firmware version
    unsigned char SiLabFWVersion[] = {0xB0, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=SiliconLabIC;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:SiLabFWVersion length:sizeof(SiLabFWVersion)];

    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];

    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    if ([cmdRespQueue count] != 0) {
        NSData * versionInfo = ((CSLBlePacket *)[cmdRespQueue deqObject]).payload;
        *slVersion=[NSString stringWithFormat:@"%d.%d.%d", ((Byte*)[versionInfo bytes])[2], ((Byte*)[versionInfo bytes])[3], ((Byte*)[versionInfo bytes])[4]];
        NSLog(@"SilconLab IC firmware version: %@", *slVersion);
    }
    else {
        NSLog(@"Command timed out.");
        NSLog(@"Get SilconLab IC firmware version: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}


- (BOOL)getRfidBrdSerialNumber:(NSString**) serialNumber {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];

    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get 13 bytes serial number...");
    NSLog(@"----------------------------------------------------------------------");
    //Get 16 bytes serial number
    unsigned char sn[] = {0xB0, 0x04, 00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x03;
    packet.deviceId=SiliconLabIC;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:sn length:sizeof(sn)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        CSLBlePacket* packet = (CSLBlePacket *)[cmdRespQueue deqObject];
        if ([packet.payload length] >= 15) {
            NSData * name = [packet.payload subdataWithRange:NSMakeRange(2, 13)];
            *serialNumber=[NSString stringWithUTF8String:[name bytes]];
            NSLog(@"13 byte serial number: %@", *serialNumber);
        }
    }
    if ([*serialNumber length] != 13) {
        NSLog(@"Get 13 byte serial number: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)getPcBBoardVersion:(NSString**) boardVersion {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get board version...");
    NSLog(@"----------------------------------------------------------------------");
    //Get 16 bytes serial number
    unsigned char sn[] = {0xB0, 0x04, 00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x03;
    packet.deviceId=SiliconLabIC;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:sn length:sizeof(sn)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        CSLBlePacket* packet=(CSLBlePacket *)[cmdRespQueue deqObject];
        if([packet.payload length]>=18) {
            NSData * name =[packet.payload subdataWithRange:NSMakeRange(15, 3)];
            *boardVersion=[NSString stringWithFormat:@"%@.%@", [[NSString stringWithUTF8String:[name bytes]] substringToIndex:1], [[NSString stringWithUTF8String:[name bytes]] substringFromIndex:1]];
            NSLog(@"PCB board version: %@", *boardVersion);
        }
    }
    if([*boardVersion length] < 3) {
        NSLog(@"Command timed out.");
        NSLog(@"Get PCB board version: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}


- (BOOL)sendAbortCommand {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED && connectStatus!=TAG_OPERATIONS)  //reader is not idling for downlink command and not performing inventory
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    }
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket* recvPacket;
    BOOL isAborted=false;

    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Abort command (SCSLRFIDStopOperation)...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort command
    unsigned char abortCmd[] = {0x80, 0x02, 0x80, 0xB3, 0x10, 0xAE, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x09	;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:abortCmd length:sizeof(abortCmd)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
                
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] >= 3 )
        {
            recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
            if (![[recvPacket getPacketPayloadInHexString] containsString:@"800200"]) {
                break;
            }
            recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
            if ([[recvPacket getPacketPayloadInHexString] containsString:@"810051E210AE000000"]) {
                isAborted=true;
                break;
            }
            
            recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
            if ([[recvPacket getPacketPayloadInHexString] containsString:@"810051E210AE000000"]) {
                isAborted=true;
                break;
            }
            
        }
        else
            [NSThread sleepForTimeInterval:0.001f];
    }
    
    if (isAborted) {
        NSLog(@"Abort command: OK");
        return true;
    }
    else {
        NSLog(@"Abort command response: FAILED");
        return false;
    }

}

- (BOOL)getTriggerKeyStatus {

    @synchronized(self) {
        if (connectStatus!=CONNECTED && connectStatus!=TAG_OPERATIONS)  //reader is not idling for downlink command and not performing inventory
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    }
    [cmdRespQueue removeAllObjects];

    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    //CSLBlePacket* recvPacket;

    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get trigger key status command...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort command
    unsigned char getTriggerKeyStatus[] = {0xA0, 0x01};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=Notification;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:getTriggerKeyStatus length:sizeof(getTriggerKeyStatus)];

    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];

    connectStatus=CONNECTED;
    return true;
}


- (BOOL)startBatteryAutoReporting {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED && connectStatus!=TAG_OPERATIONS)  //reader is not idling for downlink command and not performing inventory
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    }
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket* recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Start battery auto reporting command...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort command
    unsigned char startBattReporting[] = {0xA0, 0x02};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=Notification;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:startBattReporting length:sizeof(startBattReporting)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] !=0)
    {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], startBattReporting, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Start battery auto reporting sent: OK");
        else {
            NSLog(@"Start battery auto reporting sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
        
    }
    else {
        NSLog(@"Command timed out.");
        NSLog(@"Start battery auto reporting: FAILED");
        connectStatus=CONNECTED;
        return false;
    }
    connectStatus=CONNECTED;
    return true;
}

- (BOOL)getSingleBatteryReport  {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED && connectStatus!=TAG_OPERATIONS)  //reader is not idling for downlink command and not performing inventory
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    }
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    //CSLBlePacket* recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Get single battery report command...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort command
    unsigned char getSingleBatteryReport[] = {0xA0, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=Notification;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:getSingleBatteryReport length:sizeof(getSingleBatteryReport)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    /*
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] !=0)
    {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], getSingleBatteryReport, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Get single battery report sent: OK");
        else {
            NSLog(@"Get single battery report sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
        
    }
    else {
        NSLog(@"Command timed out.");
        NSLog(@"Get single battery report: FAILED");
        connectStatus=CONNECTED;
        return false;
    }
     */
    connectStatus=CONNECTED;
    return true;
}

- (BOOL)stopBatteryAutoReporting {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED && connectStatus!=TAG_OPERATIONS)  //reader is not idling for downlink command and not performing inventory
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
    }
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket* recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Stop battery auto reporting command...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort command
    unsigned char stopBattReporting[] = {0xA0, 0x03};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x02;
    packet.deviceId=Notification;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:stopBattReporting length:sizeof(stopBattReporting)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] !=0)
    {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], stopBattReporting, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Stop battery auto reporting sent: OK");
        else {
            NSLog(@"Stop battery auto reporting sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
        
    }
    else {
        NSLog(@"Command timed out.");
        NSLog(@"Stop battery auto reporting: FAILED");
        connectStatus=CONNECTED;
        return false;
    }
    connectStatus=CONNECTED;
    return true;
}

- (BOOL)getRfidFwVersionNumber:(NSString**) versionInfo {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Read regiseter 0x0008 RFID firmware version number...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char rfidFWVersion[] = {0x80, 0x02, 0x80, 0xB3, 0x14, 0x71, ++SequenceNumber, 0x00, 0x04, 0x01, 0x00, 0x08, 0x20};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0D;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:rfidFWVersion length:sizeof(rfidFWVersion)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], rfidFWVersion, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID firmware version command sent: OK");
        else {
            NSLog(@"RFID firmware version command sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x14 && ((Byte*)[recvPacket.payload bytes])[5] == 0x71 &&
        ((Byte*)[recvPacket.payload bytes])[6] == rfidFWVersion[6] && [recvPacket.payload length] == 41) {
        *versionInfo = [[NSString alloc] initWithData:[recvPacket.payload subdataWithRange:NSMakeRange(9, 32)] encoding:NSUTF8StringEncoding];
        NSLog(@"RFID firmware: %@", *versionInfo);
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}


- (BOOL)getRfidBuildVersionNumber:(int*) buildInfo {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Read regiseter 0x0028 RFID build number...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char rfidFWVersion[] = {0x80, 0x02, 0x80, 0xB3, 0x14, 0x71, ++SequenceNumber, 0x00, 0x04, 0x01, 0x00, 0x28, 0x04};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0D;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:rfidFWVersion length:sizeof(rfidFWVersion)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], rfidFWVersion, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID firmware build command sent: OK");
        else {
            NSLog(@"RFID firmware build command sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    unsigned short byte1;
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x14 && ((Byte*)[recvPacket.payload bytes])[5] == 0x71 &&
        ((Byte*)[recvPacket.payload bytes])[6] == rfidFWVersion[6] && [recvPacket.payload length] == 13) {
        byte1 = ((Byte*)[recvPacket.payload bytes])[9];
        *buildInfo=byte1;
        NSLog(@"RFID build number: %d", *buildInfo);
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}
    
- (BOOL)setPower:(double) powerInDbm {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set antenna power (ANT_PORT_POWER) command reg_addr=0x0706
    unsigned int power=(unsigned int)(powerInDbm / 0.1);
    unsigned char ANT_PORT_POWER[] = {0x80, 0x02, 0x70, 0x01, 0x06, 0x07, power & 0x000000FF, (power & 0x0000FF00) >> 8, (power & 0x00FF0000) >> 16, (power & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_PORT_POWER length:sizeof(ANT_PORT_POWER)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_PORT_POWER, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna power command sent: OK");
        else {
            NSLog(@"Set antenna power command sent: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
        
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setPower:(Byte)port_number
      PowerLevel:(int)powerInDbm {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSUInteger startAddress = 0x3033 + (16 * port_number);
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter AntennaPortConfig (2-bytes) for setting power level...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char rfidPower[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x06, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x02, (powerInDbm & 0xFF00) >> 8, powerInDbm & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0F;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:rfidPower length:sizeof(rfidPower)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], rfidPower, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set power command sent: OK");
        else {
            NSLog(@"RFID set power command sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == rfidPower[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setAntennaDwell:(Byte)port_number
                   time:(NSUInteger)timeInMilliseconds {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSUInteger startAddress = 0x3031 + (16 * port_number);
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter AntennaPortConfig (2-bytes) for setting dwell time...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char dwellTime[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x06, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x02, (timeInMilliseconds & 0xFF00) >> 8, timeInMilliseconds & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0F;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:dwellTime length:sizeof(dwellTime)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], dwellTime, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set dwell time command sent: OK");
        else {
            NSLog(@"RFID set dwell time command sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == dwellTime[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setRfMode:(Byte)port_number
             mode:(NSUInteger)mode_id {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSUInteger startAddress = 0x303E + (16 * port_number);
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter AntennaPortConfig (2-bytes) for setting reader mode...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char readerMode[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x06, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x02, (mode_id & 0xFF00) >> 8, mode_id & 0xFF};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0F;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:readerMode length:sizeof(readerMode)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], readerMode, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set reader mode command sent: OK");
        else {
            NSLog(@"RFID set reader mode command sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == readerMode[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)SetInventoryRoundControl:(Byte)port_number
                        InitialQ:(Byte)init_q
                            MaxQ:(Byte)max_q
                            MinQ:(Byte)min_q
                   NumMinQCycles:(Byte)num_min_cycles
                      FixedQMode:(BOOL)fixed_q_mode
               QIncreaseUseQuery:(BOOL)q_inc_use_query
               QDecreaseUseQuery:(BOOL)q_dec_use_query
                         Session:(Byte)session
               SelInQueryCommand:(Byte)sel_query_command
                     QueryTarget:(BOOL)query_target
                   HaltOnAllTags:(BOOL)halt_on_all_tags
                    FastIdEnable:(BOOL)fast_id_enable
                  TagFocusEnable:(BOOL)tag_focus_enable
         MaxQueriesSinceValidEpc:(NSUInteger)max_queries_since_valid_epc
                    TargetToggle:(Byte)target_toggle {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSUInteger startAddress = 0x3035 + (16 * port_number);
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter AntennaPortConfig (9-bytes) for setting InventoryRoundControl...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char inventoryControl[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x0D, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x09,
        ((tag_focus_enable & 0x01) << 2) + ((fast_id_enable & 0x01) << 1) + (halt_on_all_tags & 0x01),
        ((query_target & 0x01) << 7) + ((sel_query_command & 0x03) << 5) + ((session & 0x03) << 3) + ((q_dec_use_query & 0x01) << 2) + ((q_inc_use_query & 0x01) << 1) + (fixed_q_mode & 0x01),
        ((num_min_cycles & 0xF) << 4) + (min_q & 0xF),
        ((max_q & 0xF) << 4) + (init_q & 0xF),
        (max_queries_since_valid_epc & 0xFF000000) >> 24,
        (max_queries_since_valid_epc & 0x00FF0000) >> 16,
        (max_queries_since_valid_epc & 0x0000FF00) >> 8,
        max_queries_since_valid_epc & 0x000000FF,
        target_toggle
    };
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x16;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:inventoryControl length:sizeof(inventoryControl)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], inventoryControl, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set InventoryRoundControl sent: OK");
        else {
            NSLog(@"RFID set InventoryRoundControl sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == inventoryControl[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    ///////////// (part 2)
    startAddress = 0x3035 + (16 * port_number);
    unsigned char inventoryControl2[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x05, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x01, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0E;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:inventoryControl2 length:sizeof(inventoryControl2)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], inventoryControl2, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set InventoryRoundControl (part 2) sent: OK");
        else {
            NSLog(@"RFID set InventoryRoundControl (part 2) sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == inventoryControl2[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    /////////////
    
    /////////////(part 3)
    startAddress = 0x3039 + (16 * port_number);
    unsigned char inventoryControl3[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x08, 0x01, (startAddress & 0xFF00) >> 8, startAddress & 0xFF, 0x04,
        (max_queries_since_valid_epc & 0xFF000000) >> 24,
        (max_queries_since_valid_epc & 0x00FF0000) >> 16,
        (max_queries_since_valid_epc & 0x0000FF00) >> 8,
        max_queries_since_valid_epc & 0x000000FF
    };
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x11;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:inventoryControl3 length:sizeof(inventoryControl3)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], inventoryControl3, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set InventoryRoundControl (part 3) sent: OK");
        else {
            NSLog(@"RFID set InventoryRoundControl (part 3) sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == inventoryControl3[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    /////////////
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setDuplicateEliminationRollingWindow:(Byte)rollingWindowInSeconds {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter 3900 for setting duplicate elimination rolling window...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char duplicateElim[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x05, 0x01, 0x39, 0x00, 0x01, rollingWindowInSeconds};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0E;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:duplicateElim length:sizeof(duplicateElim)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], duplicateElim, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set duplicate elimination rolling window sent: OK");
        else {
            NSLog(@"RFID set duplicate elimination rolling window sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == duplicateElim[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setIntraPacketDelay:(Byte)delayInMilliseconds {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter 3908 for setting intra packet delay...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char intraPacketDelay[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x05, 0x01, 0x39, 0x08, 0x01, delayInMilliseconds};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0E;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:intraPacketDelay length:sizeof(intraPacketDelay)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], intraPacketDelay, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set intra packet delay sent: OK");
        else {
            NSLog(@"RFID set intra packet delay sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == intraPacketDelay[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setEventPacketUplinkEnable:(BOOL)keep_alive
                      InventoryEnd:(BOOL)inventory_end
                      CrcError:(BOOL)crc_error
                      TagReadRate:(BOOL)tag_read_rate {

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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Write regiseter 3906 for setting EventPacketUplinkEnable...");
    NSLog(@"----------------------------------------------------------------------");
    //Send abort
    unsigned char eventPacket[] = {0x80, 0x02, 0x80, 0xB3, 0x9A, 0x06, ++SequenceNumber, 0x00, 0x06, 0x01, 0x39, 0x06, 0x02, 0x00,
        (keep_alive ? 0x01 : 0x00) | (inventory_end ? 0x2 : 0x00) | (crc_error ? 0x04 : 0x00) | (tag_read_rate ? 0x08 : 0x00)
    };
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0F;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:eventPacket length:sizeof(eventPacket)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] >= 2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], eventPacket, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"RFID set EventPacketUplinkEnable sent: OK");
        else {
            NSLog(@"RFID set EventPacketUplinkEnable sent: FAILED");
            connectStatus=CONNECTED;
            return false;
        }
    }
        
    recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (((Byte*)[recvPacket.payload bytes])[4] == 0x9A && ((Byte*)[recvPacket.payload bytes])[5] == 0x06 &&
        ((Byte*)[recvPacket.payload bytes])[6] == eventPacket[6] && ((Byte*)[recvPacket.payload bytes])[9] == 0) {
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}


- (BOOL)setAntennaCycle:(NSUInteger) cycles {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set antenna cycles (ANT_CYCLES) to loop forever
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set antenna cycles (ANT_CYCLES)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char ANT_CYCLES[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0x07, cycles & 0xFF, (cycles & 0xFF00) >> 8, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_CYCLES length:sizeof(ANT_CYCLES)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_CYCLES, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna cycles: OK");
        else {
            NSLog(@"Set antenna cycles: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setAntennaDwell:(NSUInteger) timeInMilliseconds {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set antenna port dwell time (ANT_PORT_DWELL)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set antenna port dwell time (ANT_PORT_DWELL)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char ANT_DWELL[] = {0x80, 0x02, 0x70, 0x01, 0x05, 0x07, timeInMilliseconds & 0xFF, (timeInMilliseconds & 0xFF00) >> 8, (timeInMilliseconds & 0xFF0000) >> 16, (timeInMilliseconds & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_DWELL length:sizeof(ANT_DWELL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_DWELL, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna dwell: OK");
        else {
            NSLog(@"Set antenna dwell: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)selectAntennaPort:(NSUInteger) portIndex {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Select antenna port (ANT_PORT_SEL)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Select antenna port (ANT_PORT_SEL)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char ANT_PORT[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x07, portIndex & 0xF, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_PORT length:sizeof(ANT_PORT)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_PORT, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna port: OK");
        else {
            NSLog(@"Set antenna port: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setAntennaConfig:(BOOL)isEnable
           InventoryMode:(Byte)mode
           InventoryAlgo:(Byte)algo
                  StartQ:(Byte)qValue
             ProfileMode:(Byte)pMode
                 Profile:(Byte)pValue
           FrequencyMode:(Byte)fMode
        FrequencyChannel:(Byte)fChannel
            isEASEnabled:(BOOL)eas {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set antenna config (ANT_PORT_CFG)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set antenna config (ANT_PORT_CFG)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char ANT_PORT_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x02, 0x07, isEnable | ((mode & 0x01) << 1) | ((algo & 0x03) << 2) | ((qValue & 0x0F) << 4), pMode | ((pValue & 0x0F) << 1) | ((fMode & 0x01) << 5) | ((fChannel & 0x03) << 6), ((fChannel & 0x3C) >> 6) | (eas << 4), 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_PORT_CFG length:sizeof(ANT_PORT_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_PORT_CFG, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna port config: OK");
        else {
            NSLog(@"Set antenna port config: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setAntennaInventoryCount:(NSUInteger) count {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set antenna inventory count (ANT_PORT_INV_CNT)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set antenna inventory count (ANT_PORT_INV_CNT)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char ANT_INV_CNT[] = {0x80, 0x02, 0x70, 0x01, 0x07, 0x07, count & 0xFF, (count & 0xFF00) >> 8, (count & 0xFF0000) >> 16, (count & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:ANT_INV_CNT length:sizeof(ANT_INV_CNT)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], ANT_INV_CNT, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set antenna dwell: OK");
        else {
            NSLog(@"Set antenna dwell: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}





- (BOOL)selectAlgorithmParameter:(QUERYALGORITHM) algorithm {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Select which set of algorithm parameter registers to access (INV_SEL) reg_addr = 0x0902
    //unsigned int desc_idx=3;    //select algortihm #3 (Dyanmic Q)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Select which set of algorithm parameter registers to access (INV_SEL)...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char INV_SEL[] = {0x80, 0x02, 0x70, 0x01, 0x02, 0x09, algorithm & 0x000000FF, (algorithm & 0x0000FF00) >> 8, (algorithm & 0x00FF0000) >> 16, (algorithm & 0xFF000000) >> 24};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_SEL length:sizeof(INV_SEL)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], INV_SEL, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Select which set of algorithm parameter registers: OK");
        else {
            NSLog(@"Select which set of algorithm parameter registers: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setInventoryAlgorithmParameters0:(Byte) startQ maximumQ:(Byte)maxQ minimumQ:(Byte)minQ ThresholdMultiplier:(Byte)tmult  {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    //Set algorithm parameters (INV_ALG_PARM_0) for DynamicQ reg_addr = 0x0901
    //Byte startQ=6, maxQ=15, minQ=0, tmult=4;
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set algorithm parameters (INV_ALG_PARM_0) addr:0x0903");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char INV_ALG_PARM[] = {0x80, 0x02, 0x70, 0x01, 0x03, 0x09, (startQ & 0x0F) + ((maxQ & 0x0F) << 4), (minQ & 0x0F) + ((tmult & 0x0F) << 4), (tmult & 0xF0) >> 4, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_ALG_PARM length:sizeof(INV_ALG_PARM)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], INV_ALG_PARM, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set algorithm parameter 0: OK");
        else {
            NSLog(@"Set algorithm parameter 0: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setInventoryAlgorithmParameters1:(Byte) retry {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set algorithm parameters (INV_ALG_PARM_1)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set algorithm parameters (INV_ALG_PARM_1) addr:0x0904");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char INV_ALG_PARM[] = {0x80, 0x02, 0x70, 0x01, 0x04, 0x09, retry, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_ALG_PARM length:sizeof(INV_ALG_PARM)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], INV_ALG_PARM, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set algorithm parameter 1: OK");
        else {
            NSLog(@"Set algorithm parameter 1: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setInventoryAlgorithmParameters2:(BOOL) toggle RunTillZero:(BOOL)rtz {
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Set algorithm parameters (INV_ALG_PARM_1)
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set algorithm parameters (INV_ALG_PARM_2) addr:0x0905");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char INV_ALG_PARM[] = {0x80, 0x02, 0x70, 0x01, 0x05, 0x09, toggle + (rtz << 1), 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_ALG_PARM length:sizeof(INV_ALG_PARM)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], INV_ALG_PARM, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set algorithm parameter 2: OK");
        else {
            NSLog(@"Set algorithm parameter 2: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setInventoryConfigurations:(QUERYALGORITHM) inventoryAlgorithm MatchRepeats:(Byte)match_rep tagSelect:(Byte)tag_sel disableInventory:(Byte)disable_inventory tagRead:(Byte)tag_read crcErrorRead:(Byte) crc_err_read QTMode:(Byte) QT_mode tagDelay:(Byte) tag_delay inventoryMode:(Byte)inv_mode {
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Select which set of algorithm parameter registers to access (INV_SEL) reg_addr = 0x0902
    //Byte Inv_algo=0x03, match_rep=0, tag_sel=0, disable_inv=0, tag_read=0, crc_err_read=1, QT_mode=0, tag_delay=0, inv_mode=1;  //inventory algorithm #3, enable crc error read, compact mode inventory
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set inventory configurations (INV_CFG) addr:0x0901...");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char INV_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x01, 0x09, (inventoryAlgorithm & 0x3F) + ((match_rep & 0x03) << 6), ((match_rep & 0xFC) >> 2) + ((tag_sel & 0x01) << 6) + ((disable_inventory & 0x01) << 7), (tag_read & 0x03) + ((crc_err_read & 0x01) << 2) + ((QT_mode & 0x01) << 3) + ((tag_delay & 0x0F) << 4), ((tag_delay & 0x30) >> 4) + ((inv_mode & 0x01) << 2)};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:INV_CFG length:sizeof(INV_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], INV_CFG, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Set inventory configurations: OK");
        else {
            NSLog(@"Set inventory configurations: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setQueryConfigurations:(TARGET) queryTarget querySession:(SESSION)query_session querySelect:(QUERYSELECT)query_sel {
    
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
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    //Select which set of algorithm parameter registers to access (INV_SEL) reg_addr = 0x0902
    //Byte query_target=0x00, query_session=1, query_sel=0;
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Configure parameters on query and inventory operations (QUERY_CFG) addr:0x0900");
    NSLog(@"----------------------------------------------------------------------");
    
    unsigned char QUERY_CFG[] = {0x80, 0x02, 0x70, 0x01, 0x00, 0x09, ((queryTarget & 0x01) << 4) + ((query_session & 0x03) << 5) + ((query_sel & 0x01) << 7), ((query_sel & 0x02) >> 1), 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:QUERY_CFG length:sizeof(QUERY_CFG)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([cmdRespQueue count] != 0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], QUERY_CFG, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Configure parameters on query and inventory operations: OK");
        else {
            NSLog(@"Configure parameters on query and inventory operations: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return true;
}

- (BOOL)setLinkProfile:(LINKPROFILE) profile
{
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
    [cmdRespQueue removeAllObjects];
    
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Set link profile...");
    NSLog(@"----------------------------------------------------------------------");
    //read OEM Address
    unsigned char linkProfile[] = {0x80, 0x02, 0x70, 0x01, 0x60, 0x0B, profile, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:linkProfile length:sizeof(linkProfile)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] !=0)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] != 0)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], linkProfile, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Set link profile: OK");
    else
    {
        NSLog(@"Set link profile: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    NSLog(@"Send HST_CMD 0x00000019 to set link profile...");
    //Send HST_CMD
    unsigned char OEMHSTCMD[] = {0x80, 0x02, 0x70, 0x01, 0x0, 0xF0, 0x19, 0x00, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x0A;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:OEMHSTCMD length:sizeof(OEMHSTCMD)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
    [self sendPackets:packet];
    
    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) { //receive data or time out in 5 seconds
        if ([cmdRespQueue count] >= 3) //command response + command begin + command end
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 3)
        recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    else
    {
        NSLog(@"Command timed out.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    if (memcmp([recvPacket.payload bytes], OEMHSTCMD, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
        NSLog(@"Receive HST_CMD 0x19 response: OK");
    else
    {
        NSLog(@"Receive HST_CMD 0x19 response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //command-begin
    recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0080"]) ||
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"] && [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0000"])
        ) {
        self.lastMacErrorCode=0x0000;
        NSLog(@"Receive HST_CMD 0x19 command-begin response: OK");
    }
    else
    {
        NSLog(@"Receive HST_CMD 0x19 command-begin response: FAILED");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    //command-end
    recvPacket = ((CSLBlePacket *)[cmdRespQueue deqObject]);
    if (([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"02"] || [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(4, 2)] isEqualToString:@"01"]) &&
        ([[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0180"] || [[recvPacket.getPacketPayloadInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"0100"]) &&
        ((Byte *)[recvPacket.payload bytes])[14] == 0x00 &&
        ((Byte *)[recvPacket.payload bytes])[15] == 0x00) {
        self.lastMacErrorCode=(((Byte *)[recvPacket.payload bytes])[15] << 8) + (((Byte *)[recvPacket.payload bytes])[14]);
        NSLog(@"Receive HST_CMD 0x19 command-end response: OK");
    }
    else
    {
        NSLog(@"Receive HST_CMD 0x19 command-end response: FAILED");
        self.lastMacErrorCode=(((Byte *)[recvPacket.payload bytes])[15] << 8) + (((Byte *)[recvPacket.payload bytes])[14]);
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return FALSE;
    }
    
    connectStatus=CONNECTED;
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    return TRUE;
}

-(BOOL)startInventory {
    
    @synchronized(self) {
        if (connectStatus!=CONNECTED)
        {
            NSLog(@"Reader is not connected or busy. Access failure");
            return false;
        }
        
        connectStatus=BUSY;
        rangingTagCount=0;
        uniqueTagCount=0;
    }
    [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
    [self.recvQueue removeAllObjects];
    [cmdRespQueue removeAllObjects];
    
    //Initialize data
    CSLBlePacket* packet= [[CSLBlePacket alloc] init];
    CSLBlePacket * recvPacket;
    
    NSLog(@"----------------------------------------------------------------------");
    NSLog(@"Operation command 0x10A2 (SCSLRFIDStartCompactInventory)...");
    NSLog(@"----------------------------------------------------------------------");
    
    NSLog(@"Send start inventory...");
    unsigned char cmd[] = {0x80, 0x02, 0x80, 0xB3, 0x10, 0xA2, ++SequenceNumber, 0x00, 0x00};
    packet.prefix=0xA7;
    packet.connection = Bluetooth;
    packet.payloadLength=0x09;
    packet.deviceId=RFID;
    packet.Reserve=0x82;
    packet.direction=Downlink;
    packet.crc1=0;
    packet.crc2=0;
    packet.payload=[NSData dataWithBytes:cmd length:sizeof(cmd)];
    
    NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);

    [self sendPackets:packet];

    for (int i=0;i<COMMAND_TIMEOUT_5S;i++) {  //receive data or time out in 5 seconds
        if([cmdRespQueue count] >=2)
            break;
        [NSThread sleepForTimeInterval:0.001f];
    }
    
    if ([cmdRespQueue count] >= 2) {
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes], cmd, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[2] == 0x00)
            NSLog(@"Start compact inventory: OK");
        else {
            NSLog(@"Start compact inventory: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
        
        recvPacket=((CSLBlePacket *)[cmdRespQueue deqObject]);
        if (memcmp([recvPacket.payload bytes]+4, cmd+4, 2) == 0 && ((Byte *)[recvPacket.payload bytes])[6] == cmd[6])
            NSLog(@"Start compact inventory: OK");
        else {
            NSLog(@"Start compact inventory: FAILED");
            connectStatus=CONNECTED;
            [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
            return false;
        }
    }
    else {
        NSLog(@"Command response failure.");
        connectStatus=CONNECTED;
        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
        return false;
    }
    
    self.isTagAccessMode=false;
    connectStatus=TAG_OPERATIONS;
    //[self performSelectorInBackground:@selector(decodePacketsInBufferAsync) withObject:(nil)];
    return true;
}

-(BOOL)stopInventory {
    
    //retry multiple times in case rfid module is busy on receiving the abort command
    for (int j=0;j<3;j++)
    {
        [self performSelectorInBackground:@selector(stopInventoryBlocking) withObject:(nil)];
        
        for (int i=0;i<COMMAND_TIMEOUT_3S;i++) {  //receive data or time out in 3 seconds
            ([[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.001]]);
            if(connectStatus == CONNECTED)
                break;
        }
        if (connectStatus != CONNECTED)
        {
            NSLog(@"Abort command response failure.  Try #%d", j+1);
            continue;
        }
        else
        {
            NSLog(@"Abort command response: OK");
            break;
        }
        
    }
    
    return ((connectStatus != CONNECTED) ? false : true);

}

-(void)stopInventoryBlocking {
    
    @autoreleasepool {
        //Initialize data
        CSLBlePacket* packet= [[CSLBlePacket alloc] init];
        
        if (connectStatus==TAG_OPERATIONS)
        {
            NSLog(@"----------------------------------------------------------------------");
            NSLog(@"Abort command (SCSLRFIDStopOperation)...");
            NSLog(@"----------------------------------------------------------------------");
            //Send abort command
            unsigned char abortCmd[] = {0x80, 0x02, 0x80, 0xB3, 0x10, 0xAE, 0x00, 0x00, 0x00};
            packet.prefix=0xA7;
            packet.connection = Bluetooth;
            packet.payloadLength=0x09    ;
            packet.deviceId=RFID;
            packet.Reserve=0x82;
            packet.direction=Downlink;
            packet.crc1=0;
            packet.crc2=0;
            packet.payload=[NSData dataWithBytes:abortCmd length:sizeof(abortCmd)];
            
            NSLog(@"BLE packet sending: %@", [packet getPacketInHexString]);
            [self sendPackets:packet];
            [self sendPackets:packet];
            [self sendPackets:packet];
        }
    }

}

- (BOOL)setPowerMode:(BOOL)isLowPowerMode
{
    return TRUE;
}

- (void)decodePacketsInBufferAsync;
{
    CSLBlePacket* packet;
    CSLReaderBarcode* barcode;
    NSString * eventCode;
    NSMutableData* rfidPacketBuffer;    //buffer to all packets returned by the rfid module
    NSString* rfidPacketBufferInHexString;
    unsigned char ecode[] = {0x81, 0x00};
    NSMutableData* tempMutableData;
    
    filteredBuffer=[[NSMutableArray alloc] init];
    rfidPacketBuffer=[[NSMutableData alloc] init];
    rfidPacketBufferInHexString=[[NSString alloc] init];
    
    int datalen;        //data length given on the RFID packet
    int sequenceNumber=0;
    
    while (self.bleDevice)  //packet decoding will continue as long as there is a connected device instance
    {
        @autoreleasepool {
            @synchronized(self.recvQueue) {
                if ([self.recvQueue count] > 0)
                {
                    //dequque the next packet received
                    packet=((CSLBlePacket *)[self.recvQueue deqObject]);
                    if ([packet isKindOfClass:[NSNull class]]) {
                        continue;
                    }
                    
                    if (packet.direction==Uplink && packet.deviceId==RFID) {
                        
                        NSLog(@"[decodePacketsInBufferAsync] Current sequence number: %d", sequenceNumber);
                        
                        //validate checksum of packet
                        if (!packet.isCRCPassed) {
                            NSLog(@"[decodePacketsInBufferAsync] Checksum verification failed.  Discarding data in buffer");
                            [rfidPacketBuffer setLength:0];
                            continue;
                        }
                    
                        if ([rfidPacketBuffer length] == 0)
                            sequenceNumber=packet.Reserve;
                        else {
                            if (packet.Reserve != (sequenceNumber+1)) {
                                NSLog(@"[decodePacketsInBufferAsync] Packet out-of-order based on sequence number.  Discarding data in buffer");
                                [rfidPacketBuffer setLength:0];
                                continue;
                            }
                            else
                                sequenceNumber++;
                        }
                    }
                }
                else
                {
                    [NSThread sleepForTimeInterval:0.001f];	
                    continue;
                }
            }
            
            NSLog(@"[decodePacketsInBufferAsync] RFID Packet buffer before arrival for packet: %@", [rfidPacketBuffer length] == 0 ? @"(EMPTY)" : [CSLBleReader convertDataToHexString:rfidPacketBuffer]);
            //append ble payload to the rfid packet buffer
            if ([rfidPacketBuffer length] == 0) {
                [rfidPacketBuffer appendData:packet.payload];
            }
            else {
                //if there were partial packet from previous iteration, append the current data after stripping out the event code and header information
                if ([[[CSLBleReader convertDataToHexString:rfidPacketBuffer] substringToIndex:4] isEqualToString:@"8100"] && packet.payloadLength>=2 && [[[CSLBleReader convertDataToHexString:packet.payload] substringToIndex:4] isEqualToString:@"8100"]) {
                    [rfidPacketBuffer appendData:[packet.payload subdataWithRange:NSMakeRange(2, packet.payloadLength - 2)]];
                    packet.payload=[NSData dataWithBytes:[rfidPacketBuffer bytes] length:[rfidPacketBuffer length]];
                }
                else {
                    //other event code
                    //drop packet and wait for next data
                    continue;
                }
            }
            //buffer in hex string format
            rfidPacketBufferInHexString=[CSLBleReader convertDataToHexString:rfidPacketBuffer];
            
            //get event code
            eventCode = [rfidPacketBufferInHexString substringToIndex:4];
        
            NSLog(@"[decodePacketsInBufferAsync] Payload to be decoded: %@", rfidPacketBufferInHexString);
        
            //**************************************
            //selector of different command responses
            if ([eventCode isEqualToString:@"8100"])    //RFID module responses
            {
                //decoding commands
                if ([rfidPacketBufferInHexString length] >= 18) //9 bytes -> 8100 + 51E2 + XXXX (command code) + XX (seq #) + XXXX (len. of payload)
                {
                    
                    datalen=((Byte *)[rfidPacketBuffer bytes])[8] + (((((Byte *)[rfidPacketBuffer bytes])[7] << 8) & 0xFF00));
                    
                    //Read register command
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"51E2"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"1471"]) {
                        NSLog(@"[decodePacketsInBufferAsync] Read register response recieved: %@", rfidPacketBufferInHexString);
                        self.lastMacErrorCode=0x0000;
                        //return packet directly to the API for decoding
                        [cmdRespQueue enqObject:packet];
                        [rfidPacketBuffer setLength:0];
                        continue;
                    }
                    
                    //Write register command
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"51E2"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"9A06"]) {
                        NSLog(@"[decodePacketsInBufferAsync] Write register response recieved: %@", rfidPacketBufferInHexString);
                        self.lastMacErrorCode=0x0000;
                        //return packet directly to the API for decoding
                        [cmdRespQueue enqObject:packet];
                        [rfidPacketBuffer setLength:0];
                        continue;
                    }
                    
                    //Opeation command - SCSLRFIDStopOperation
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"51E2"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"10AE"]) {
                        NSLog(@"[decodePacketsInBufferAsync] SCSLRFIDStopOperation command response (10AE) recieved: %@", rfidPacketBufferInHexString);
                        self.lastMacErrorCode=0x0000;
                        //return packet directly to the API for decoding
                        [cmdRespQueue enqObject:packet];
                        [rfidPacketBuffer setLength:0];
                        continue;
                    }
                    
                    //Opeation command - SCSLRFIDStartCompactInventory
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"51E2"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"10A2"]) {
                        NSLog(@"[decodePacketsInBufferAsync] SCSLRFIDStartCompactInventory command response (10A2) recieved: %@", rfidPacketBufferInHexString);
                        self.lastMacErrorCode=0x0000;
                        //return packet directly to the API for decoding
                        [cmdRespQueue enqObject:packet];
                        [rfidPacketBuffer setLength:0];
                        continue;
                    }
                    
                    //Uplink packet 3008 (csl_operation_complete)
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"49DC"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"3008"] &&
                        ((datalen + 9) * 2) == [rfidPacketBufferInHexString length]) {
                        NSLog(@"[decodePacketsInBufferAsync] CSL RFID uplink packet (csl_operation_complete) recieved: %@", rfidPacketBufferInHexString);
                        self.lastMacErrorCode=0x0000;
                        //return packet directly to the API for decoding
                        [cmdRespQueue enqObject:packet];
                        [rfidPacketBuffer setLength:0];
                        connectStatus=CONNECTED;
                        [self.delegate didInterfaceChangeConnectStatus:self]; //this will call the method for connections status chagnes.
                        continue;
                    }
                    
                    //Uplink packet 3007  (csl_miscellaneous_event)
                    datalen=((Byte *)[rfidPacketBuffer bytes])[8] + (((((Byte *)[rfidPacketBuffer bytes])[7] << 8) & 0xFF00)) ;
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"49DC"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"3007"] &&
                        ((datalen + 9) * 2) == [rfidPacketBufferInHexString length]) {
                        
                        if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(13 * 2, 4)] isEqualToString:@"0001"])
                            NSLog(@"[decodePacketsInBufferAsync] CSL RFID uplink packet (csl_miscellaneous_event) recieved: keep alive");
                        else if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(13 * 2, 4)] isEqualToString:@"0002"])
                            NSLog(@"[decodePacketsInBufferAsync] CSL RFID uplink packet (csl_miscellaneous_event) recieved: inventory around end");
                        else if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(13 * 2, 4)] isEqualToString:@"0003"])
                            NSLog(@"[decodePacketsInBufferAsync] CSL RFID uplink packet (csl_miscellaneous_event) recieved: CRC error rate=%@", [rfidPacketBufferInHexString substringWithRange:NSMakeRange(15 * 2, 4)]);
                        else if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(13 * 2, 4)] isEqualToString:@"0004"]) {
                            NSLog(@"[decodePacketsInBufferAsync] CSL RFID uplink packet (csl_miscellaneous_event) recieved: tag rate value=%@", [rfidPacketBufferInHexString substringWithRange:NSMakeRange(15 * 2, 4)]);
                            //readerTagRate=*(int*)[[CSLBleReader convertHexStringToData:[rfidPacketBufferInHexString substringWithRange:NSMakeRange(15 * 2, 4)]] bytes];
                            readerTagRate = ((((Byte *)[rfidPacketBuffer bytes])[15] << 8) & 0xFF00) + ((Byte *)[rfidPacketBuffer bytes])[16];
                        }
                        [rfidPacketBuffer setLength:0];
                        continue;
                    }
                    
                    //Uplink packet 3006 (csl_tag_read_compact)
                    if ([[rfidPacketBufferInHexString substringWithRange:NSMakeRange(4, 4)] isEqualToString:@"49DC"] &&
                        [[rfidPacketBufferInHexString substringWithRange:NSMakeRange(8, 4)] isEqualToString:@"3006"] &&
                        ((datalen + 9) * 2) == [rfidPacketBufferInHexString length]) {
                        
                        //iterate through all the tag data
                        UInt32 timestamp = ((Byte *)[rfidPacketBuffer bytes])[12] + ((((Byte *)[rfidPacketBuffer bytes])[11] << 8) & 0x0000FF00) + ((((Byte *)[rfidPacketBuffer bytes])[10] << 16) & 0x00FF0000) + ((((Byte *)[rfidPacketBuffer bytes])[9] << 24) & 0xFF000000);
                        
                        int ptr=15;     //starting point of the tag data
                        while(TRUE)
                        {
                            CSLBleTag* tag=[[CSLBleTag alloc] init];
                            
                            tag.PC =((((Byte *)[rfidPacketBuffer bytes])[ptr] << 8) & 0xFF00)+ ((Byte *)[rfidPacketBuffer bytes])[ptr+1];
                            
                            //for the case where we reaches to the end of the BLE packet but not the RFID response packet, where there will be partial packet to be returned from the next packet.  The partial tag data will be combined with the next packet being returned.
                            //8100 (two bytes) + 8 bytes RFID packet header + payload length being calcuated ont he header
                            if ((9 + datalen) > [rfidPacketBuffer length]) {
                                //stop decoding and wait for the partial tag data to be appended in the next packet arrival
                                NSLog(@"[decodePacketsInBufferAsync] partial tag data being returned.  Wait for next rfid response packet for complete tag data.");
                                break;
                            }
                            
                            tag.EPC=[rfidPacketBufferInHexString substringWithRange:NSMakeRange((ptr*2)+4, ((tag.PC >> 11) * 2) * 2)];
                            int rssiPtr = (ptr + 2) + ((tag.PC >> 11) * 2);
                            Byte hb = (Byte)((Byte *)[rfidPacketBuffer bytes])[rssiPtr];
                            Byte lb = (Byte)((Byte *)[rfidPacketBuffer bytes])[rssiPtr+1];
                            tag.rssi = (Byte)[CSLBleReader decodeRSSI:hb lowByte:lb];
                            tag.portNumber=0;
                            ptr+= (2 + ((tag.PC >> 11) * 2) + 2);
                            [self.readerDelegate didReceiveTagResponsePacket:self tagReceived:tag]; //this will call the method for handling the tag response.
                            
                            NSLog(@"[decodePacketsInBufferAsync] Tag data found: PC=%04X EPC=%@ rssi=%d", tag.PC, tag.EPC, tag.rssi);
                            tag.timestamp = [NSDate date];
                            rangingTagCount++;
                            
                            @synchronized(filteredBuffer) {
                                //insert the tag data to the sorted filteredBuffer if not duplicated
                                
                                //check and see if epc exists on the array using binary search
                                NSRange searchRange = NSMakeRange(0, [filteredBuffer count]);
                                NSUInteger findIndex = [filteredBuffer indexOfObject:tag
                                                                    inSortedRange:searchRange
                                                                          options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
                                                                  usingComparator:^(id obj1, id obj2) {
                                    NSString* str1; NSString* str2;
                                    str1 = ([obj1 isKindOfClass:[CSLReaderBarcode class]]) ? ((CSLReaderBarcode*)obj1).barcodeValue : ((CSLBleTag*)obj1).EPC;
                                    str2 = ([obj2 isKindOfClass:[CSLReaderBarcode class]]) ? ((CSLReaderBarcode*)obj2).barcodeValue : ((CSLBleTag*)obj2).EPC;
                                    return [str1 compare:str2 options:NSCaseInsensitiveSearch];
                                }];
                                
                                if ( findIndex >= [filteredBuffer count] )  //tag to be the largest.  Append to the end.
                                {
                                    [filteredBuffer insertObject:tag atIndex:findIndex];
                                    uniqueTagCount++;
                                }
                                else if ( [[filteredBuffer[findIndex] isKindOfClass:[CSLReaderBarcode class]] ? ((CSLReaderBarcode*)filteredBuffer[findIndex]).barcodeValue : ((CSLBleTag*)filteredBuffer[findIndex]).EPC caseInsensitiveCompare:tag.EPC] != NSOrderedSame)
                                {
                                    //new tag found.  insert into buffer in sorted order
                                    [filteredBuffer insertObject:tag atIndex:findIndex];
                                    uniqueTagCount++;
                                }
                                else    //tag is duplicated, but will replace the existing tag information with the new one for updating the RRSI value.
                                {
                                    [filteredBuffer replaceObjectAtIndex:findIndex withObject:tag];
                                }
                            }
                            
                            //return when pointer reaches the end of the RFID response packet.
                            if (ptr >= (datalen + 9)) {
                                NSLog(@"[decodePacketsInBufferAsync] Finished decode all tags in packet.");
                                NSLog(@"[decodePacketsInBufferAsync] Unique tags in buffer: %d", (unsigned int)[filteredBuffer count]);
                                [rfidPacketBuffer setLength:0];
                                break;
                            }
                        }
                    }
                }
            }
            else if ([eventCode isEqualToString:@"9000"]) {   //Power on barcode
                NSLog(@"[decodePacketsInBufferAsync] Power on barcode");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"9001"]) {   //Power on barcode
                NSLog(@"[decodePacketsInBufferAsync] Power off barcode");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"8000"]) {   //Power on RFID module
                NSLog(@"[decodePacketsInBufferAsync] Power on Rfid Module");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"8001"]) {   //Power off RFID module
                NSLog(@"[decodePacketsInBufferAsync] Power off Rfid Module");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"C000"]) {   //Get BT firmware version
                NSLog(@"[decodePacketsInBufferAsync] Get BT firmware version");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"C004"]) {   //Get connected device name
                NSLog(@"[decodePacketsInBufferAsync] Get connected device name");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"B000"]) {   //Get SilconLab IC firmware version.
                NSLog(@"[decodePacketsInBufferAsync] Get SilconLab IC firmware version.");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"B004"]) {   //Get 16 byte serial number.
                NSLog(@"[decodePacketsInBufferAsync] Get 16 byte serial number.");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"8002"]) {   //RFID firmware command response
                NSLog(@"[decodePacketsInBufferAsync] RFID firmware command response.");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"A103"]) {
                //Trigger key is released.  Trigger callback delegate method
                NSLog(@"[decodePacketsInBufferAsync] Trigger key: OFF");
                [rfidPacketBuffer setLength:0];
                [self.readerDelegate didTriggerKeyChangedState:self keyState:false]; //this will call the method for handling the tag response.
            }
            else if ([eventCode isEqualToString:@"A102"]) {
                //Trigger key is pressed.  Trigger callback delegate method
                NSLog(@"[decodePacketsInBufferAsync] Trigger key: ON");
                [rfidPacketBuffer setLength:0];
                [self.readerDelegate didTriggerKeyChangedState:self keyState:true]; //this will call the method for handling the tag response.
            }
            else if ([eventCode isEqualToString:@"A002"]) {
                NSLog(@"[decodePacketsInBufferAsync] Battery auto reporting: ON");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"A003"]) {
                NSLog(@"[decodePacketsInBufferAsync] Battery auto reporting: OFF");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"A000"]) {
                NSLog(@"[decodePacketsInBufferAsync] Battery auto reporting Return: 0x%@", [rfidPacketBufferInHexString substringWithRange:NSMakeRange(4,4)]);
                //if (connectStatus==TAG_OPERATIONS)
                //    [batteryInfo setBatteryMode:INVENTORY];
                //else
                //    [batteryInfo setBatteryMode:IDLE];
                [self.readerDelegate didReceiveBatteryLevelIndicator:self batteryPercentage:[batteryInfo getBatteryPercentageByVoltage:(double)((((Byte *)[rfidPacketBuffer bytes])[2] * 256) + ((Byte *)[rfidPacketBuffer bytes])[3]) / 1000.00f]];
                [rfidPacketBuffer setLength:0];
            }
            else if ([eventCode isEqualToString:@"A001"]) {
                NSLog(@"[decodePacketsInBufferAsync] Trigger key state Return: 0x%@", [rfidPacketBufferInHexString substringWithRange:NSMakeRange(4,2)]);
                [rfidPacketBuffer setLength:0];
                if (((Byte *)[rfidPacketBuffer bytes])[2])
                    [self.readerDelegate didTriggerKeyChangedState:self keyState:true]; //this will call the method for handling the tag response.
                else
                    [self.readerDelegate didTriggerKeyChangedState:self keyState:false]; //this will call the method for handling the tag response.
            }
            else if ([eventCode isEqualToString:@"9003"]) {
                NSLog(@"[decodePacketsInBufferAsync] Barcode command sent.");
                [rfidPacketBuffer setLength:0];
                [cmdRespQueue enqObject:packet];
            }
            else if ([eventCode isEqualToString:@"9100"]) {
                NSLog(@"[decodePacketsInBufferAsync] Barcode data received.");
                NSData* barcodeRsp=[rfidPacketBuffer subdataWithRange:NSMakeRange(2, [rfidPacketBuffer length]-2)];
                if ([barcodeRsp length] == 1) {
                    NSLog(@"[decodePacketsInBufferAsync] Barcode command sent.");
                    [cmdRespQueue enqObject:packet];
                }
                else {
                    barcode=[[CSLReaderBarcode alloc] initWithSerialData:[rfidPacketBuffer subdataWithRange:NSMakeRange(2, [rfidPacketBuffer length]-2)]];
                    if (barcode.aimId != nil && barcode.codeId != nil && barcode.barcodeValue!=nil) {
                        NSLog(@"[decodePacketsInBufferAsync] Barcode received: Code ID=%@ AIM ID=%@ Barcode=%@", barcode.codeId, barcode.aimId, barcode.barcodeValue);
                        
                        @synchronized(filteredBuffer) {
                            //check and see if epc exists on the array using binary search
                            NSRange searchRange = NSMakeRange(0, [filteredBuffer count]);
                            NSUInteger findIndex = [filteredBuffer indexOfObject:barcode
                                                                   inSortedRange:searchRange
                                                                         options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
                                                                 usingComparator:^(id obj1, id obj2) {
                                NSString* str1; NSString* str2;
                                str1 = ([obj1 isKindOfClass:[CSLReaderBarcode class]]) ? ((CSLReaderBarcode*)obj1).barcodeValue : ((CSLBleTag*)obj1).EPC;
                                str2 = ([obj2 isKindOfClass:[CSLReaderBarcode class]]) ? ((CSLReaderBarcode*)obj2).barcodeValue : ((CSLBleTag*)obj2).EPC;
                                return [str1 compare:str2 options:NSCaseInsensitiveSearch];
                            }];
                            
                            if ( findIndex >= [filteredBuffer count] )  //tag to be the largest.  Append to the end.
                                [filteredBuffer insertObject:barcode atIndex:findIndex];
                            else if ( [[filteredBuffer[findIndex] isKindOfClass:[CSLReaderBarcode class]] ? ((CSLReaderBarcode*)filteredBuffer[findIndex]).barcodeValue : ((CSLBleTag*)filteredBuffer[findIndex]).EPC caseInsensitiveCompare:barcode.barcodeValue] != NSOrderedSame)
                                //new tag found.  insert into buffer in sorted order
                                [filteredBuffer insertObject:barcode atIndex:findIndex];
                            else    //tag is duplicated, but will replace the existing tag information with the new one for updating the RRSI value.
                                [filteredBuffer replaceObjectAtIndex:findIndex withObject:barcode];
                        }
                        [self.readerDelegate didReceiveBarcodeData:self scannedBarcode:barcode];
                    }
                }
                [rfidPacketBuffer setLength:0];
            }
            else if ([eventCode isEqualToString:@"9101"]) {
                NSLog(@"[decodePacketsInBufferAsync] Barcode data good read.");
                [rfidPacketBuffer setLength:0];
            }
            else {
                //for all other event code that is not covered.
                [rfidPacketBuffer setLength:0];
            }
        }
    }
    NSLog(@"[decodePacketsInBufferAsync] Ended!");
}

+ (NSString*) convertDataToHexString:(NSData*) data {
    
    @try {
        int dlen=(int)[data length];
        NSMutableString* hexStr = [NSMutableString stringWithCapacity:dlen];
        
        
        for(int i = 0; i < [data length]; i++)
            [hexStr appendFormat:@"%02X", ((Byte*)[data bytes])[i]];
        
        return [NSString stringWithString: hexStr];
    }
    @catch (NSException* exception)
    {
        NSLog(@"Exception on convertDataToHexString: %@", exception.description);
        return nil;
    }
}

+ (NSData *)convertHexStringToData:(NSString *)hexString {
    
    const char *hexChar = [hexString UTF8String];
    
    Byte *bt = malloc(sizeof(Byte)*(hexString.length/2));
    
    char tmpChar[3] = {'\0','\0','\0'};
    
    int btIndex = 0;
    
    for (int i=0; i<hexString.length; i += 2) {
        
        tmpChar[0] = hexChar[i];
        
        tmpChar[1] = hexChar[i+1];
        
        bt[btIndex] = strtoul(tmpChar, NULL, 16);
        
        btIndex ++;
        
    }
    
    NSData *data = [NSData dataWithBytes:bt length:btIndex];
    
    free(bt);
    
    return data;
    
}

    
+ (double)decodeRSSI:(Byte)high_byte lowByte:(Byte) low_byte {
    int rssi = high_byte & 0x00FF;
    rssi = rssi << 8;
    rssi |= low_byte & 0x00FF;
    if ((Byte)(high_byte & 0x0080) != 0) {
        rssi = 65536 - rssi;
        rssi = -rssi;
    }
    double result = (double) rssi;
    result /= 100;
    result = result + 106.98;
    return result;
    
}


@end
