//
//  CSLReaderBarcode.m
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import "../include/CSLReaderBarcode.h"

@interface CSLReaderBarcode() {
    NSMutableDictionary *codeIdDescriptons;
}
+ (NSString*) stripLeadingEciIndicator:(NSString*) hexString;
@end

@implementation CSLReaderBarcode

@synthesize serialData;
@synthesize barcodeValue;
@synthesize aimId;
@synthesize codeId;

- (id)init
{
    return [self initWithSerialData:nil];
}

- (id) initWithSerialData:(NSData *)data {
    if (self = [super init]) {
        
        codeIdDescriptons=[[NSMutableDictionary alloc] init];
        [codeIdDescriptons setObject:@"Code-128/EAN-128" forKey:@"j"];
        [codeIdDescriptons setObject:@"AIM-128" forKey:@"f"];
        [codeIdDescriptons setObject:@"EAN-8/EAN-13" forKey:@"d"];
        [codeIdDescriptons setObject:@"UPC-E/UPC-A" forKey:@"c"];
        [codeIdDescriptons setObject:@"Interleaved 2 of 5/ITF" forKey:@"e"];
        [codeIdDescriptons setObject:@"Matrix 2 of 5" forKey:@"v"];
        [codeIdDescriptons setObject:@"Code 39" forKey:@"b"];
        [codeIdDescriptons setObject:@"Codabar" forKey:@"a"];
        [codeIdDescriptons setObject:@"Code 93" forKey:@"i"];
        [codeIdDescriptons setObject:@"Code 11" forKey:@"H"];
        [codeIdDescriptons setObject:@"GS1 Databar(RSS)" forKey:@"R"];
        [codeIdDescriptons setObject:@"EAN/UCC Composite" forKey:@"y"];
        [codeIdDescriptons setObject:@"ISBN" forKey:@"B"];
        [codeIdDescriptons setObject:@"ISSN" forKey:@"n"];
        [codeIdDescriptons setObject:@"Matrix 2 of 5(European Matrix 2)" forKey:@"v"];
        [codeIdDescriptons setObject:@"Industrial 25" forKey:@"D"];
        [codeIdDescriptons setObject:@"Standard 25" forKey:@"s"];
        [codeIdDescriptons setObject:@"Plessey" forKey:@"p"];
        [codeIdDescriptons setObject:@"MSI-Plessey" forKey:@"m"];
        [codeIdDescriptons setObject:@"QR Code" forKey:@"Q"];
        [codeIdDescriptons setObject:@"Aztec" forKey:@"z"];
        [codeIdDescriptons setObject:@"Data Matrix" forKey:@"u"];
        [codeIdDescriptons setObject:@"Maxicode" forKey:@"x"];
        [codeIdDescriptons setObject:@"Chinese Sensible Code" forKey:@"h"];
        [codeIdDescriptons setObject:@"Plessey" forKey:@"p"];
        
        serialData=data;
        [self extractBarcodeFromSerialData];
    }
    return self;
}

//Self-prefix / self-suffix bytes the EM3296 is configured to wrap every scan with.
static NSString * const kBarcodeSelfPrefix = @"020007101713";   //6 bytes
static NSString * const kBarcodeSelfSuffix = @"050111160304";   //6 bytes

//Upper bound on the accumulated hex buffer.  A completed barcode is stripped/reset
//immediately, so anything past this size means we are accumulating garbage from a
//never-completing scan - reset instead of growing without bound.
static const NSUInteger kBarcodeMaxHexLength = 65536;   //~32 KB of payload

//Cross-packet accumulation buffer, shared across CSLReaderBarcode instances so that a
//barcode split over several notification packets can be stitched back together.  It is
//touched from the background packet-decode thread, so all access is serialised on the
//class.  It is cleared on every terminal path (complete, corrupted, fresh scan) and by
//+resetAccumulator when the decode loop detects a dropped BLE packet.
static NSString* barcodeHexString = @"";

- (NSString*) extractBarcodeFromSerialData {

    @synchronized ([CSLReaderBarcode class]) {

        NSString* incoming = [CSLReaderBarcode convertDataToHexString:serialData];

        //A packet that begins with the self-prefix is the start of a new barcode:
        //drop any residue left over from a previous incomplete/abandoned scan.
        if ([incoming length] >= [kBarcodeSelfPrefix length] &&
            [[incoming substringToIndex:[kBarcodeSelfPrefix length]] isEqualToString:kBarcodeSelfPrefix])
            barcodeHexString = @"";

        //Guard against unbounded growth from a scan that never completes.
        if ([barcodeHexString length] > kBarcodeMaxHexLength) {
            NSLog(@"Barcode buffer exceeded maximum length.  Clearing buffer.");
            barcodeHexString = @"";
        }

        barcodeHexString = [barcodeHexString stringByAppendingString:incoming];

        if ([barcodeHexString length] < 32 ){
            NSLog(@"Invalid barcode serial data - %@", barcodeHexString);
            return nil;
        }

        //check if we have received complete data
        if ([[barcodeHexString substringToIndex:12] containsString:kBarcodeSelfPrefix] &&
            [[barcodeHexString substringFromIndex:[barcodeHexString length]-14] containsString:kBarcodeSelfSuffix]) {
            barcodeHexString=[barcodeHexString substringFromIndex:12];      //remove self-prefix
            if ([[barcodeHexString substringFromIndex:[barcodeHexString length]-12] isEqualToString:kBarcodeSelfSuffix])
                barcodeHexString=[barcodeHexString substringToIndex:[barcodeHexString length]-12];  //remove self-suffix
            else
                barcodeHexString=[barcodeHexString substringToIndex:[barcodeHexString length]-14];  //remove self-suffix
        }
        else if ([[barcodeHexString substringToIndex:12] containsString:kBarcodeSelfPrefix] &&
            [barcodeHexString containsString:kBarcodeSelfSuffix]) {
            NSLog(@"Corrupted barcode data returned.  Clearing buffer - %@", barcodeHexString);
            barcodeHexString=@"";
            return nil;
        }
        else if ([barcodeHexString containsString:kBarcodeSelfPrefix] &&
            [[barcodeHexString substringFromIndex:[barcodeHexString length]-14] containsString:kBarcodeSelfSuffix]) {
            NSLog(@"Corrupted barcode data returned.  Clearing buffer - %@", barcodeHexString);
            barcodeHexString=@"";
            return nil;
        }
        else
        {
            NSLog(@"Incomplete barcode data received - %@", barcodeHexString);
            return nil;
        }

        NSLog(@"Barcode extracted - %@", barcodeHexString);

        //Code ID (1 byte) - single-character key such as "Q" (QR), "z" (Aztec).
        NSString* codeIdKey=[CSLReaderBarcode convertHexStringToAscii:[barcodeHexString substringToIndex:2]];
        codeId=[codeIdDescriptons objectForKey:codeIdKey];
        barcodeHexString=[barcodeHexString substringFromIndex:2];

        //AIM ID (3 bytes: "]" + 2 chars).
        aimId=[CSLReaderBarcode convertHexStringToAscii:[barcodeHexString substringToIndex:6]];
        barcodeHexString=[barcodeHexString substringFromIndex:6];

        //With ECI output enabled the Newland engine prefixes 2D barcode data with an
        //AIM ECI indicator: a backslash (0x5C) followed by a 6-digit ECI code - e.g.
        //"\000026" (ECI 26 = UTF-8) seen ahead of a UTF-8 QR payload.  Strip that
        //indicator so it does not leak into barcodeValue.  Detection is exact
        //(backslash + six ASCII digits); under the ECI protocol a literal backslash
        //in the data is doubled to "\\", so real data is never mistaken for an
        //indicator.  Gated to the 2D code IDs, where ECI indicators occur.
        static NSString * const k2DCodeIdKeys = @"Qzux";   //QR, Aztec, Data Matrix, Maxicode
        if ([codeIdKey length] == 1 && [k2DCodeIdKeys containsString:codeIdKey])
            barcodeHexString=[CSLReaderBarcode stripLeadingEciIndicator:barcodeHexString];

        barcodeValue=[CSLReaderBarcode convertHexStringToAscii:barcodeHexString];
        barcodeHexString=@"";
    }

    return barcodeValue;
}

//Clears the cross-packet accumulation buffer.  Called by the decode loop when a
//barcode BLE packet is lost (out-of-order sequence number) so the partial, now
//unrecoverable, scan is discarded instead of being stitched into corrupted data.
+ (void) resetAccumulator {
    @synchronized ([CSLReaderBarcode class]) {
        barcodeHexString = @"";
    }
}

//Strips a leading AIM ECI indicator - a backslash (0x5C) followed by six decimal
//digits, 7 bytes total (e.g. "\000026" for ECI 26 / UTF-8) - from a hex string.
//Returns the input unchanged when no such indicator is present.
+ (NSString*) stripLeadingEciIndicator:(NSString*) hexString {
    const NSUInteger indicatorHexLen = 14;   //7 bytes: 0x5C + six ASCII digits
    if ([hexString length] < indicatorHexLen)
        return hexString;
    if (![[hexString substringToIndex:2] isEqualToString:@"5C"])   //leading backslash?
        return hexString;
    for (NSUInteger h = 2; h < indicatorHexLen; h += 2) {
        NSString* byteHex = [hexString substringWithRange:NSMakeRange(h, 2)];
        unsigned int value = 0;
        sscanf([byteHex cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
        if (value < 0x30 || value > 0x39)   //each must be an ASCII digit 0-9
            return hexString;
    }
    return [hexString substringFromIndex:indicatorHexLen];
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

+ (NSString*) convertHexStringToAscii:(NSString*) hexString {
    //Collect the parsed bytes into a buffer and decode the whole buffer at once.
    //The Newland scan engine emits its payload as UTF-8, so decoding byte-by-byte
    //(the previous behaviour) split every multi-byte character - e.g. '×' (U+00D7,
    //UTF-8 0xC3 0x97) became two separate code points and rendered as mojibake
    //("√ó").  Decoding the full byte buffer as UTF-8 reconstructs such characters
    //correctly.  ISO-Latin-1 is used as a fallback for payloads that are not valid
    //UTF-8; that fallback never returns nil, preserving the non-nil barcodeValue
    //contract expected by the caller.
    NSMutableData * data = [NSMutableData dataWithCapacity:[hexString length] / 2];
    NSUInteger i = 0;
    while (i + 1 < [hexString length])
    {
        NSString * hexChar = [hexString substringWithRange: NSMakeRange(i, 2)];
        unsigned int value = 0;
        sscanf([hexChar cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
        i += 2;
    }

    NSString * decoded = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (decoded == nil)
        decoded = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return decoded;
}

@end
