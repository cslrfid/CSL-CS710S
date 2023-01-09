//
//  CSLBleReader.h
//
//  Created by Carlson Lam on 31/7/2022.
//  Copyright © 2022 Convergence Systems Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSLBleInterface.h"
#import "CSLBleTag.h"
#import "CSLReaderBattery.h"
#import "CSLReaderBarcode.h"
#import "CSLReaderFrequency.h"

#define COMMAND_TIMEOUT_1S 1000
#define COMMAND_TIMEOUT_2S 2000
#define COMMAND_TIMEOUT_3S 3000
#define COMMAND_TIMEOUT_4S 4000
#define COMMAND_TIMEOUT_5S 5000
#define COMMAND_TIMEOUT_10S 10000

#define COMMAND_ANTCYCLE_CONTINUOUS 0xFFFF

///Query sessions
typedef NS_ENUM(Byte, SESSION)
{
    S0 = 0,
    S1,
    S2,
    S3
};

///Query target
typedef NS_ENUM(Byte, TARGET)
{
    A = 0x00,
    B,
    ToggleAB
};

///Query algorithm
typedef NS_ENUM(Byte, QUERYALGORITHM)
{
    FIXEDQ = 0x00,
    DYNAMICQ = 0x03
};

///Link profile
typedef NS_ENUM(Byte, LINKPROFILE)
{
    MID_103 = 0x00,
    MID_120,
    MID_345,
    MID_302,
    MID_323,
    MID_344,
    MID_223,
    MID_222,
    MID_241,
    MID_244,
    MID_285
};
//Argument to underlying Query
typedef NS_ENUM(Byte, QUERYSELECT)
{
    ALL = 0x00,
    SL = 0x03
};

//Reader type (fixed or handheld)
typedef NS_ENUM(Byte, READERTYPE)
{
    CS108 = 0x00,
    CS463 = 0x01,
    CS710 = 0x02
};

@class CSLBleReader;             //define class, so protocol can see CSLBleReader class
/**
 Delegate of the reader events
 */
@protocol CSLBleReaderDelegate <NSObject>   //define delegate protocol
/**
 This will be triggered when reader receives a new tag response during its operations
 @param sender CSLBleReader object of the connected reader
 @param tag Reference to the CSLBleTag object being returned
 */
- (void) didReceiveTagResponsePacket: (CSLBleReader *) sender tagReceived:(CSLBleTag*)tag;  //define delegate method to be implemented within another class
/**
 This will be triggered when the trigger key on the reader has chagned state (pressed/released)
 @param sender CSLBleReader object of the connected reader
 @param state State of the trigger key (0=released, 1=pressed)
 */
- (void) didTriggerKeyChangedState: (CSLBleReader *) sender keyState:(BOOL)state;
/**
 This will be triggered when reader receives battery level notification on every 5 seconds
 @param sender CSLBleReader object of the connected reader
 @param battPct Battery level in percentage
 */
- (void) didReceiveBatteryLevelIndicator: (CSLBleReader *) sender batteryPercentage:(int)battPct;
/**
 This will be triggered when a barcode is being scanned
 @param sender CSLBleReader object of the connected reader
 @param barcode Barcode data in CSLReaderBarcode object
 */
- (void) didReceiveBarcodeData: (CSLBleReader *) sender scannedBarcode:(CSLReaderBarcode*)barcode;
/**
 This will be triggered when reader receives a tag access response during its operations
 @param sender CSLBleReader object of the connected reader
 @param tag Reference to the CSLBleTag object being returned
 */
- (void) didReceiveTagAccessData: (CSLBleReader *) sender tagReceived:(CSLBleTag*)tag;  //define delegate method to be implemented within another class
@end //end protocol

/**
 This object class holds the core function of the reader API and it allows developers to configure and control the device being connnected.
 It is a sub-class of CSLBleInterface, which handles the low-level Bluetooth LE connectiviites.
 */
@interface CSLBleReader : CSLBleInterface
/** This is a buffer for all the tags that have been sorted with all duplicates removed.
Insertion/update of tag data is based on binary searching algorithm for better efficiency especially when the number of tags in buffer raises.
 */
@property NSMutableArray * filteredBuffer;
///This property holds the number of tags being read.  It is reset within a specific time interval (1 second by default)
@property NSInteger rangingTagCount;
///This property holds the number of unique tags being read.  It is reset within a specific time interval (1 second by default)
@property NSInteger uniqueTagCount;
///This property holds the number of tags being read.  It is reset within a specific time interval (1 second by default)
@property NSInteger readerTagRate;
///Enumeration type that holds the battery status information.  Its value is is being updated by a scheduled timer when batteery level notifications return on every 5 seconds
@property CSLReaderBattery* batteryInfo;
///This property indicates if the reader is either in tag access or inventory mode
@property BOOL isTagAccessMode;
///Reader type (fixed or handheld)
@property READERTYPE readerModelNumber;
///
@property CSLCircularQueue * cmdRespQueue;
///Delegate instance that follows the CSLBleReaderDelegate protocol
@property (nonatomic, weak) id <CSLBleReaderDelegate> readerDelegate;

///This error will be cleared every time when a host command is being initiated and set after and command-end response
@property unsigned short lastMacErrorCode;

/**
 Static method that converts hexdcecimal string to binary data
 
 @param hexString It holds the hexidecimal string to be converted
 @return NSData value
 */
+ (NSData *)convertHexStringToData:(NSString *)hexString;
/**
 Static method that converts binary data to hexdcecimal string
 
 @param data It holds the binary data to be converted
 @return NSString hexdecimal string
*/
+ (NSString*) convertDataToHexString:(NSData*) data;
/**
 Static method that converts 16 bit RSSI data to actual value
 
 @param high_byte It holds high byte of the RSSI value
 @param low_byte It holds low byte of the RSSI value
 @return dobule RSSI in dBuV
 */
+ (double)decodeRSSI:(Byte)high_byte lowByte:(Byte) low_byte;
/**
 initialization selector that:
 - call init selector of the super class CSLBleInterface
 - initialize tag count properties
 - initialize internal buffer queue
 */
- (id)init;
/**
 dealloc selector that:
 - stop radio if it is currently active
 - release selector to the delegates
 */
- (void)dealloc;
/**
 Read OEM data that contains product-specific information such as country code, antenna version and frequency channel information
 @param intf CSLBleInterface that references to the current reader instance
 @param addr Address of the memory location
 @param data UInt32 that holds the value of the data address
 @return TRUE if the operation is successful
 */
- (BOOL)readOEMData:(CSLBleInterface*)intf atAddr:(unsigned short)addr forData:(UInt32*)data;
/**
 Get current country enum of reader
 @param intf CSLBleInterface that references to the current reader instance
 @param data UInt32 that holds the value of the data address
 @return TRUE if the operation is successful
 */
- (BOOL)getCountryEnum:(CSLBleInterface*)intf forData:(UInt32*)data;
/**
 Read OEM data that contains product-specific information such as country code, antenna version and frequency channel information
 @param intf CSLBleInterface that references to the current reader instance
 @param addr Address of the memory location
 @param len Length of regsiter in bytes
 @param data UInt32 that holds the value of the data address
 @return TRUE if the operation is successful
 */
- (BOOL)E710ReadRegister:(CSLBleInterface*)intf atAddr:(unsigned short)addr regLength:(Byte)len forData:(NSData**)data;
/**
 Write OEM data that contains product-specific information such as country code, antenna version and frequency channel information
 @param intf CSLBleInterface that references to the current reader instance
 @param addr Address of the memory location
 @param len Length of regsiter in bytes
 @param data NSData pointer that reference the value of the data to be written
 @return TRUE if the operation is successful
 */
- (BOOL)E710WriteRegister:(CSLBleInterface*)intf atAddr:(unsigned short)addr regLength:(Byte)len forData:(NSData*)data error:(Byte*)error_code;
/**
Set frequency band based on the region selected
@param frequencySelector channel number selected
@param config channel enable/disable
@param mult_div frequncy multdiv
@param pll_cc pllcc
@return TRUE if the operation is successful
*/
- (BOOL)setFrequencyBand:(UInt32)frequencySelector bandState:(BOOL) config multdiv:(UInt32)mult_div pllcc:(UInt32) pll_cc;
/**
Set hopping frequency based on region selected
@param frequencyInfo CSLReaderFrequency object that initialized baesd ont he OEM data from the reader
@param region Code of the region being selected
@return TRUE if the operation is successful
*/
- (BOOL) SetHoppingChannel:(CSLReaderFrequency*) frequencyInfo RegionCode:(NSString*)region;
/**
Set fixed frequency based on region and channel selected
@param frequencyInfo CSLReaderFrequency object that initialized baesd ont he OEM data from the reader
@param region Code of the region being selected
@param index Index of the selected frequency channel
@return TRUE if the operation is successful
*/
- (BOOL) SetFixedChannel:(CSLReaderFrequency*) frequencyInfo RegionCode:(NSString*)region channelIndex:(UInt32)index;
/**
Set PLLCC based on the region selected
@param region Code of the region being selected
@return PLLCC value of the selected region
*/
- (UInt32) GetPllcc:(NSString*) region;
/**
Write LNA configurations to the reader
@param intf CSLBleInterface that references to the current reader instance
@param rflna_high_comp The rflna_gain setting generates the following RF-LNA gains
0 = 1 dB
2 = 7 dB
3 = 13 dB
@param rflna_gain The iflna_gain setting generates the following IF-LNA gains
0 = 24 dB
1 = 18 dB
3 = 12 dB
7 = 6 dB
@param ifagc_gain The ifagc_gain setting generates the following AGC gain values
0 = -12 dB
4 = -6 dB
6 = 0 dB
7 = 6 dB
@return TRUE if the operation is successful
*/
- (BOOL)setLNAParameters:(CSLBleInterface*)intf rflnaHighComp:(Byte)rflna_high_comp rflnaGain:(Byte)rflna_gain iflnaGain:(Byte)iflna_gain ifagcGain:(Byte)ifagc_gain;
/**
Write Impinj Extensions register
@param tag_Focus If this feature is enabled, once a tag has been singulated it will remain out of the tag population (the tag's session 1 inventoried flag remains in B state) until the inventory operation is complete.
0=disabled
1=enabled
@param fast_id If this feature is enabled and a M4 tag is in the field, then the 6-word M4 TID will be returned along with the EPC when the tag is singulated.
0=disabled
1=enabled
@param blockwrite_mode Determines the maximum number of words to write per BlockWrite transaction with the tag.
0 = Auto-detect (Default). One or two word BlockWrite will be determined automatically.
1 = Force one word BlockWrite. Unconditionally use one word BlockWrites in all cases.
2 = Force two word BlockWrite. Unconditionally use two word BlockWrites in all cases. A protocol error will occur if the tags in the field do not support this feature.
3-15 = Reserved for future use
@return TRUE if the operation is successful
*/
- (BOOL)setImpinjExtension:(Byte)tag_Focus fastId:(Byte)fast_id blockWriteMode:(Byte)blockwrite_mode;
/**
 Enable/disable barcode reader
 @param enable TRUE/FALSE for turning on/off the barcode reader module
 @return TRUE if the operation is successful
 */
- (BOOL)barcodeReader:(BOOL)enable;
/**
Send command to barcode reader
@param command Serial command to be sent to the barcode reader module
@return TRUE if the operation is successful
*/
- (BOOL)barcodeReaderSendCommand:(NSData*)command;
/**
 Start barcode reading continuously
 @return TRUE if the operation is successful
 */
- (BOOL)startBarcodeReading;
/**
 Stop barcode reading
 @return TRUE if the operation is successful
 */
- (BOOL)stopBarcodeReading;
/**
 Send serial command to barcode reader module
  @return TRUE if the operation is successful
 @note Please refer to Newland serial programming command manual for further details
 */
- (BOOL)sendBarcodeCommandData: (NSData*)data;
/**
 Power on/off RFID module
 @param enable TRUE/FALSE for turning on/off the RFID module
 @return TRUE if the operation is successful
 */
- (BOOL)powerOnRfid:(BOOL)enable;
/**
 Obtain Bluetooth firmware version
 @param versionNumber Pointer to an instance of NSString that receives the version information
 @return TRUE if the operation is successful
 */
- (BOOL)getBtFirmwareVersion:(NSString **)versionNumber;
/**
 Obtain device name (name showing up during device discovery)
 @param deviceName Pointer to an instance of NSString that receives the device name
 @return TRUE if the operation is successful
 */
- (BOOL)getConnectedDeviceName:(NSString **) deviceName;
/**
 Obtain Silicon Lab IC firmware version
 @param slVersion Pointer to an instance of NSString that receives the firmware version
 @return TRUE if the operation is successful
 */
- (BOOL)getSilLabIcVersion:(NSString **) slVersion;
/**
 Obtain RFID board serial number
 @param serialNumber Pointer to an instance of NSString that receives the serial number information
 @return TRUE if the operation is successful
 */
- (BOOL)getRfidBrdSerialNumber:(NSString**) serialNumber;
/**
 Obtain PCB board version information
 @param boardVersion Pointer to an instance of NSString that receives the PCB version information
 @return TRUE if the operation is successful
 */
- (BOOL)getPcBBoardVersion:(NSString**) boardVersion;
/**
 Send abort command to the device for stopping RFID operations (e.g. inventory, tag read/write, etc.)
 @return TRUE if the operation is successful
 */
- (BOOL)sendAbortCommand;
/**
 Polling trigger key status
 @return TRUE if the operation is successful
 */
- (BOOL)getTriggerKeyStatus;
/**
 Start battery level reporting (notification every 5 seconds)
Once it is started, the delegate will be triggered everytime when a battery level notification is being returned
 @return TRUE if the operation is successful
 */
- (BOOL)startBatteryAutoReporting;
/**
 Stop battery level reporting (notification every 5 seconds)
 @return TRUE if the operation is successful
 */
- (BOOL)getSingleBatteryReport;
/**
 Get single battery reporting
 @return TRUE if the operation is successful
 */
- (BOOL)stopBatteryAutoReporting;
/**
 Obtain RFID module firmware version
 @param versionInfo Pointer to an instance of NSString that receives the RFID firmware version
 @return TRUE if the operation is successful
 */
- (BOOL)getRfidFwVersionNumber:(NSString**) versionInfo;
/**
Set output power of the reader
 @param powerInDbm Power in the range of 0.0-32.0 dBm
 @return TRUE if the operation is successful
 */
- (BOOL)setPower:(double) powerInDbm;
/**
Set output power of the reader
 
 @param port_number antenna port to be configured
 @param powerInDbm Power (0.01 dBm step, 0 to 3000)

 @return TRUE if the operation is successful
 */
- (BOOL)setPower:(Byte)port_number
      PowerLevel:(int)powerInDbm;
/**
 Set antenna cycle
 @param cycles Should set to 0 (continous) all the time as CS710 is running with a single antenna
 @return TRUE if the operation is successful
 */
- (BOOL)setAntennaCycle:(NSUInteger) cycles;
/**
 Set antenna dwell time
 @param timeInMilliseconds number of milliseconds to communicate on this antenna during a given Antenna Cycle.
 0x00000000 indicates that dwell time should not be used.
 @return TRUE if the operation is successful
 */
- (BOOL)setAntennaDwell:(NSUInteger) timeInMilliseconds;
/**
 Set antenna dwell time
 @param port_number antenna port to be configured
 @param timeInMilliseconds number of milliseconds to communicate on this antenna during a given Antenna Cycle.
 0x00000000 indicates that dwell time should not be used.
 @return TRUE if the operation is successful
 */
- (BOOL)setAntennaDwell:(Byte)port_number
                   time:(NSUInteger)timeInMilliseconds;
/**
 Set reader mode
 @param port_number antenna port to be configured
 @param mode_id The RF mode to use when transmitting and receiving data
 @return TRUE if the operation is successful
 */
- (BOOL)setRfMode:(Byte)port_number
             mode:(NSUInteger)mode_id;
/**
Select antenna port
@param portIndex Port number between 0-15
@return TRUE if the operation is successful
*/
- (BOOL)selectAntennaPort:(NSUInteger) portIndex;
/**
Set antenna configurations (obsolete for CS710)
@param isEnable Enable/disable antenna port
@param mode Inventory mode
0 = Global mode (use global parameters). CS710 must set as 0.
1 = Local mode (use port dedicated parameters)
@param algo Inventory algorithm
@param qValue Starting Q value. 0 - 15
@param pMode Profile mode
0 = Global mode (use last CURRENT_PROFILE parameters). CS710 must set as 0.
1 = Local mode (use port dedicated parameters)
@param pValue 0-3
@param fMode Frequency mode
0 = Global mode (use first enabled frequency). CS710 must set as 0.
1 = Local mode (use port dedicated frequency)
@param fChannel Frequency channel
@param eas Eas_enable
1=EAS detection enabled
0=EAS detection disabled
@return TRUE if the operation is successful
*/
- (BOOL)setAntennaConfig:(BOOL)isEnable
   InventoryMode:(Byte)mode
   InventoryAlgo:(Byte)algo
          StartQ:(Byte)qValue
     ProfileMode:(Byte)pMode
         Profile:(Byte)pValue
   FrequencyMode:(Byte)fMode
FrequencyChannel:(Byte)fChannel
            isEASEnabled:(BOOL)eas;
/**
Set antenna configuration (enable/disable)
@param port_number antenna port to be configured
@param isEnable Enable/disable antenna port
@return TRUE if the operation is successful
*/
- (BOOL)setAntennaConfig:(Byte)port_number
              PortEnable:(BOOL)isEnable;
/**
Set antenna inventory count (obsolete for CS710)
@param count Number of inventory rounds for current port
0x00000000 indicates that inventory round count should not be used.
@return TRUE if the operation is successful
*/
- (BOOL)setAntennaInventoryCount:(NSUInteger) count;
/**
 Set link profile from the four selections
 @param profile LINKPROFILE data type that represents 1 of the 4 link profile
 @return TRUE if the operation is successful
 */
- (BOOL)setLinkProfile:(LINKPROFILE) profile;
/**
Select which set of algorithm parameter registers to access.
 @param algorithm zero based index of descriptor to access 0 through 3
 @return TRUE if the operation is successful
 */
- (BOOL)selectAlgorithmParameter:(QUERYALGORITHM) algorithm;
/**
 The algorithm that will be used for the next Inventory command. The definition of each register varies depending on the algorithm chosen. For instance, if you wish to set the
 parameters for algorithm 1, then set selectAlgorithmParameter to 1 and load parameters as specified.
 @param startQ Starting Q value
 @param maxQ Maximum Q value
 @param minQ Minimum Q Value
 @param tmult Threshold multiplier. This is a fixed point fraction with the decimal point between bit 2 and 3.
 The field looks like bbbbbb.bb which allows fractional values of ½ , ¼ and ¾ .
@return TRUE if the operation is successful
 */
- (BOOL)setInventoryAlgorithmParameters0:(Byte) startQ maximumQ:(Byte)maxQ minimumQ:(Byte)minQ ThresholdMultiplier:(Byte)tmult;
/**
 The algorithm that will be used for the next Inventory command. The definition of each register varies depending on the algorithm chosen. For instance, if you wish to set the
 parameters for algorithm 1, then set selectAlgorithmParameter to 1 and load parameters as specified.
 @param retry Number of times to retry a query / query rep sequence for the session/target before flipping the target or exiting. For example, if q is 2 then there will be one query and 4 query reps for each retry.
 @return TRUE if the operation is successful
 */
- (BOOL)setInventoryAlgorithmParameters1:(Byte) retry;
/**
 The algorithm that will be used for the next Inventory command. The definition of each register varies depending on the algorithm chosen. For instance, if you wish to set the
 parameters for algorithm 1, then set selectAlgorithmParameter to 1 and load parameters as specified.
 @param toggle If set to one, the target will flip from A to B or B to A after all rounds have been run on the current target. This is done after no tags have been read if continuous mode is selected and all retry's have been run.
 @param rtz Continue running inventory rounds until a round is completed without reading any tags.
 @return TRUE if the operation is successful
 */
- (BOOL)setInventoryAlgorithmParameters2:(BOOL) toggle RunTillZero:(BOOL)rtz;
/**
 Inventory configuration. Configure parameters used in underlying inventory operations
 @param inventoryAlgorithm Inventory algorithm to use.
 @param match_rep Stop after "N" tags inventoried (zero indicates no stop)
 @param tag_sel 1 = enable tag select prior to inventory, read, write, lock or kill.  0 = no select issued.
 @param disable_inventory Do not run inventory
 @param tag_read 0 = no tag read issued
 1 = enable read 1 bank after inventory
 2 = enable read 2 banks after inventory
 @param crc_err_read 0 = disable crc error read
 1 = enable crc error read
 @param QT_mode 0 = disable QT temporary read private EPC
 1 = enable QT temporary read private EPC
 @param tag_delay Time delay for each tag in ms (use to reduce tag rate).  Value should be between 1 to 65
 @param inv_mode 0 = normal mode
 1 = compact mode
 @return TRUE if the operation is successful
 */
- (BOOL)setInventoryConfigurations:(QUERYALGORITHM) inventoryAlgorithm MatchRepeats:(Byte)match_rep tagSelect:(Byte)tag_sel disableInventory:(Byte)disable_inventory tagRead:(Byte)tag_read crcErrorRead:(Byte) crc_err_read QTMode:(Byte) QT_mode tagDelay:(Byte) tag_delay inventoryMode:(Byte)inv_mode;
/**
 Configure parameters used in underlying Query and inventory operations.
 @param queryTarget Starting Target argument (A or B) to underlying Query.  0 = A; 1 = B.
 @param query_session Session argument to underlying Query.  0= S0; 1 = S1; 2 = S2; 3 = S3.
 @param query_sel Select argument to underlying Query.  0 = All; 1 = All; 2 = ~SL; 3 = SL;
 Recommend to Set 0 for inventory operation.
 Recommend to Set 3 for tag select operation. Reference to INV_CFG and TAGMSK_DESC_CFG.
 @return TRUE if the operation is successful
 */
- (BOOL)setQueryConfigurations:(TARGET) queryTarget querySession:(SESSION)query_session querySelect:(QUERYSELECT)query_sel;
/**
Set inventory round control
@param port_number Enable/disable antenna port
@param init_q  The initial Q value to use to start the round.
@param max_q The maximum allowed Q value
@param min_q The minimum allowed Q value
@param num_min_cycles The number of Empty Minimum Q querys or no valid EPCs required to end the Inventory Round
@param fixed_q_mode Operate the Inventory round as a single pass through the slots No Q adjustment
@param q_inc_use_query If this is true the Q algorithm will send a Full Query instead of a QueryAdj command when increasing the Q.
@param q_dec_use_query If this is true the Q algorithm will send a Full Query instead of a QueryAdj command when decreasing Q
@param session The Gen2 session to use in the Query and other Query like Gen2 packets. This encoding matches the encoding specified in the Gen2 specification. This defaults to 1 if TagFocus is enabled.
@param sel_query_command The Sel field in the Query command. This encoding matches the encoding specified in the Gen2 specification. This defaults to 1 if TagFocus or FastId are enabled.
@param query_target Indicates A or B target for session flag values. This encoding matches the encoding specified in the Gen2 specification.
@param halt_on_all_tags When set, this will cause the modem to issue a ReqRn to open every tag that it reads and then allow the host to perform Gen2 access commands on that tag.
@param fast_id_enable When set, this will cause the modem to automatically perform the extra operations required for FastID operation. This forces the select flag to 1
@param tag_focus_enable Controls whether or not to enable tag focus at the beginning of every inventory round. This forces the select and session flags to 1.
@param max_queries_since_valid_epc  This is a control for the dynamic Q algorithm which is how may Query or QueryAdj founds it is allowed to send since it received a valid EPC. If it reaches this value it will immediately end the Inventory round
@param target_toggle  (0 = No, 1 = Yes)
@return TRUE if the operation is successful
*/
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
                    TargetToggle:(Byte)target_toggle;
/**
 Set duplicate eliminiation rolling window in seconds
 @param rollingWindowInSeconds Duplicate elimination rolling window in seconds.
 @return TRUE if the operation is successful
 */
- (BOOL)setDuplicateEliminationRollingWindow:(Byte)rollingWindowInSeconds;
/**
 Set intra packet delay
 @param delayInMilliseconds Default 4 msec,, to control and minimize Bluetooth path packet loss
 @return TRUE if the operation is successful
 */
- (BOOL)setIntraPacketDelay:(Byte)delayInMilliseconds;
/**
 16 possible events to be enabled or disabled
 @param keep_alive Default 4 msec,, to control and minimize Bluetooth path packet loss
 @param inventory_end Default 4 msec,, to control and minimize Bluetooth path packet loss
 @param crc_error Default 4 msec,, to control and minimize Bluetooth path packet loss
 @param tag_read_rate Default 4 msec,, to control and minimize Bluetooth path packet loss
 @return TRUE if the operation is successful
 */
- (BOOL)setEventPacketUplinkEnable:(BOOL)keep_alive
                      InventoryEnd:(BOOL)inventory_end
                      CrcError:(BOOL)crc_error
                      TagReadRate:(BOOL)tag_read_rate;
/**
 Start Inventory asynchornously
 @return TRUE if the operation is successful
 */
- (BOOL)startInventory;
/**
 Stop Inventory
 @return TRUE if the operation is successful
 */
- (BOOL)stopInventory;
/**
 Set power mode of the device
 @param isLowPowerMode Normal Mode = 0, low power standby mode = 1
 @return TRUE if the operation is successful
 */
- (BOOL)setPowerMode:(BOOL)isLowPowerMode;
/**
 Start the data packet decoding routine, where a selector will be running on a background thread and decode the received packet if commands were being sent out previously.  Results will be returned to the recvQueue (for asynchornous commands)  and to cmdRespQueue (for synchronous commands)
 */
- (void)decodePacketsInBufferAsync;

@end
