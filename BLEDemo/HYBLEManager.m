//
//  HYBLEManager.m

//  Created by  on 15/9/14.
//  Copyright (c) 2015年 Savvy. All rights reserved.
//

#import "HYBLEManager.h"




#ifdef DEBUG
#   define NSLog(format, ...) NSLog(format, ##__VA_ARGS__);
#else
#   define NSLog(format, ...)
#endif

#define WEAKSELF    __weak      typeof(self)  weakSelf = self
#define STRONGSELF  __strong    typeof(self)  strongSelf = weakSelf

static NSString* const kServiceUUID =               @"00001000-0000-1000-8000-00805F9B34FB";
static NSString* const kReadCharacteristicUUID =    @"00001002-0000-1000-8000-00805F9B34FB";
static NSString* const kWriteCharacteristicUUID =   @"00001001-0000-1000-8000-00805F9B34FB";


@interface HYBLEManager ()<CBCentralManagerDelegate, CBPeripheralDelegate, NSCopying>
{
    Byte _countHightByte;
    Byte _countLowByte;
}
@property (nonatomic) dispatch_queue_t operationQueue;

@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
//  中心设备管理器
@property (nonatomic, strong) CBCentralManager *centralManager;
//  连接的外围设备
@property (nonatomic, strong) CBPeripheral *servicePeripheral;


@property (nonatomic, assign) BOOL isBluetoothEnable;

@property (nonatomic, copy) BluetoothStatusBlock bleSBlock;

@property (nonatomic, strong) CBUUID *serviceUUID;


@end


@implementation HYBLEManager
- (CBUUID *)serviceUUID {
    if (_serviceUUID == nil) {
        _serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    }
    return _serviceUUID;
}

static HYBLEManager *_sharedinstance = nil;

- (instancetype)init
{
    NSLog(@" --- %s", __func__);
    if (self = [super init]) {
        _devices = [NSMutableArray array];
        NSString *queueName = NSStringFromClass([self class]);
        _operationQueue = dispatch_queue_create([queueName UTF8String], NULL);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_operationQueue];
    }
    return self;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    NSLog(@" --- %s", __func__);
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        _sharedinstance = [super allocWithZone:zone];
    });
    return _sharedinstance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _sharedinstance;
}

+ (instancetype)sharedManager
{
    NSLog(@" --- %s", __func__);
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        _sharedinstance = [[self allocWithZone:NULL] init];
    });
    return _sharedinstance;
}


/*
- (void)cleanup
{
    if (!_servicePeripheral.isConnected)
    {
        return;
    }
    
    if (_servicePeripheral.services != nil)
    {
        for (CBService *service in _servicePeripheral.services)
        {
            if (service.characteristics != nil)
            {
                for (CBCharacteristic *characteristic in service.characteristics)
                {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kReadCharacteristicUUID]])
                    {
                        if (characteristic.isNotifying)
                        {
                            [_servicePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }//for
            }
        }//for
    }
    
    [_centralManager cancelPeripheralConnection:_servicePeripheral];
    [self updateBleStatus:BluetoothStatusDisConnect];
    DEBUG_METHOD(@"------重新启动扫描---");
    [_centralManager scanForPeripheralsWithServices:@[] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO }];
    [self updateBleStatus:BluetoothStatusSearching];
}
*/

#pragma mark ---
- (void)syncUserTime {
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *str = [formatter stringFromDate:date];
    
    int year = [[str substringWithRange:NSMakeRange(2, 2)] intValue];
    int month = [[str substringWithRange:NSMakeRange(4, 2)] intValue];
    int day = [[str substringWithRange:NSMakeRange(6, 2)] intValue];
    int hour = [[str substringWithRange:NSMakeRange(8, 2)] intValue];
    int minute = [[str substringWithRange:NSMakeRange(10, 2)] intValue];
    int second = [[str substringFromIndex:12] intValue];
    
    NSLog(@" user date %@    %d %d %d %d %d %d", str, year, month, day, hour, minute, second);
    //NSLog(@"   %d %d %d %d %d %d", (Byte)year, (Byte)month, (Byte)day, (Byte)hour, (Byte)minute, (Byte)second);
    
    Byte LValue[20] = {0};
    LValue[0] = 0xAA;
    LValue[1] = (Byte)year;
    LValue[2] = (Byte)month;
    LValue[3] = (Byte)day;
    LValue[4] = (Byte)hour;
    LValue[5] = (Byte)minute;
    LValue[6] = 0x01;
    LValue[7] = 0x00;
    LValue[8] = 0x00;
    LValue[9] = 0x00;
    LValue[10] = 0x00;
    LValue[11] = 0x00;
    LValue[12] = 0x00;
    LValue[13] = 0x00;
    LValue[14] = 0x00;
    LValue[15] = 0x00;
    LValue[16] = 0x00;
    LValue[17] = 0x00;
    LValue[18] = 0x00;
    LValue[19] = (Byte)(0x1000 - (year + month +day + hour + minute + 1) & 0xFF);
    
    NSLog(@"sync time :%x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x",LValue[0],LValue[1],LValue[2],LValue[3],LValue[4],LValue[5],LValue[6],LValue[7],LValue[8],LValue[9],LValue[10],LValue[11],LValue[12],LValue[13],LValue[14],LValue[15],LValue[16],LValue[17],LValue[18],LValue[19]);
    
    [self writeDataWithPeripheral:_servicePeripheral LValue:&LValue length:sizeof(LValue)];
}




- (void)writeDataWithPeripheral:(CBPeripheral *)peripheral LValue:(const void *)value length:(int)length
{
    if (_writeCharacteristic && peripheral) {
        NSData *data = [NSData dataWithBytes:value length:length];
        NSLog(@"write length %lu data  %@", sizeof(data), data);
        [peripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

#pragma mark --- 扫描设备
- (void)startScaning:(BluetoothStatusBlock)block
{
    if (_servicePeripheral && (_servicePeripheral.state == CBPeripheralStateConnected) )
    {
        return;
    }
    _bleSBlock = block;
    
    [self startScaning];
}

- (void)startScaning
{
    [self updateBleStatus:BluetoothStatusSearching];
    
    [_centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO }];
    
}

- (void)stopScanning
{
    [_centralManager stopScan];
    [self.devices removeAllObjects];
}

- (void)updateBleStatus:(BluetoothStatus)status
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self didUpdateBleConnectionInfo:status];
        if (_bleSBlock)
        {
            _bleSBlock(status);
//            [self didUpdateBleConnectionInfo:status];
        }
    });
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    [self stopScanning];
    //NSLog(@" peripheral %@", peripheral);
    self.servicePeripheral = peripheral;
    self.centralManager.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    //CBConnectPeripheralOptionNotifyOnDisconnectionKey
}

- (void)cancelPeripheralConnection
{
    [_centralManager cancelPeripheralConnection:_servicePeripheral];
    self.devices = [NSMutableArray array];
}

#pragma mark ---BLE ConnectionInfo
- (void)didUpdateBleConnectionInfo:(BluetoothStatus)status
{
    
    if ([self.delegate respondsToSelector:@selector(bleManagerDidUpdateBleConnectionStatus:)]) {
        [self.delegate bleManagerDidUpdateBleConnectionStatus:status];
    }
    /*
    switch (status)
    {
        case BluetoothStatusNoOperate:
        {
            NSLog(@"蓝牙设备未连接");
        }
            break;
        case BluetoothStatusSearching:
        {
            NSLog(@"正在搜索蓝牙设备");
        }
            break;
        case BluetoothStatusFoundPeripheral:
        {
            NSLog(@"发现蓝牙设备");
        }
            break;
        case BluetoothStatusConnectOk:
        {
            NSLog(@"成功连接蓝牙设备");
        }
            break;
        case BluetoothStatusConnectFailed:
        {
            NSLog(@"连接蓝牙设备失败");
        }
            break;
        case BluetoothStatusTransferring:
        {
            NSLog(@"正在读取蓝牙数据");
        }
            break;
        case BluetoothStatusCompleteTransfer:
        {
            NSLog(@"完成蓝牙数据读取");
        }
            break;
        case BluetoothStatusDisConnect:
        {
            NSLog(@"蓝牙设备断开连接");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //[ILikeBluettoothTool sendAllRequest];
            });
            
            
        }
            break;
        default:
            break;
    }*/
}

#pragma mark --- CBCentralManager代理方法 (中心服务器状态更新后)
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        {
            NSLog(@" 初始的时候是未知的（刚刚创建的时候）");
            
        } break;
            
        case CBCentralManagerStateResetting:
        {
            NSLog(@"蓝牙设备重置状态");
            
        } break;
            
        case CBCentralManagerStateUnsupported:
        {
            NSLog(@"设备不支持的状态");
            
        } break;
            
        case CBCentralManagerStateUnauthorized:
        {
            NSLog(@"设备未授权状态");
            
        } break;
            
        case CBCentralManagerStatePoweredOff:
        {
            NSLog(@"设备关闭状态");
            [self stopScanning];
            
        } break;
            
        case CBCentralManagerStatePoweredOn:
        {
            NSLog(@"蓝牙设备可以使用");
            [self startScaning];
            _isBluetoothEnable = YES;
            
        } break;
            
        default:{
            _isBluetoothEnable = NO;
        }
            break;
    }
    
}

/**
 *  发现外围设备
 *
 *  @param central           中心设备
 *  @param peripheral        外围设备
 *  @param advertisementData 特征数据
 *  @param RSSI              信号质量（信号强度）
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
//    NSLog(@" %@ \n %@ \n %@ ", peripheral.name , peripheral.identifier, advertisementData);
    //NSLog(@" %@ ", peripheral.name);
    
    if ([self.devices containsObject:peripheral]) return;
    else {
        [self.devices addObject:peripheral];
        if ([self.delegate respondsToSelector:@selector(bleManagerDidFindPeripherals)]) {
            [self.delegate bleManagerDidFindPeripherals];
            NSLog(@"--------------- %@", self.devices);
        }
    }
    
}

//连接到外围设备
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"连接外围设备成功!");
    [self updateBleStatus:BluetoothStatusConnectOk];
    self.servicePeripheral = peripheral;
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    
}
//连接外围设备失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"连接外围设备失败!");
    [self updateBleStatus:BluetoothStatusConnectFailed];
    
    
}
//  外设断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"-----外设断开连接------%@",error);
    [self updateBleStatus:BluetoothStatusDisConnect];
    
//    if (_servicePeripheral) {
//        self.centralManager.delegate = self;
//        [self.centralManager connectPeripheral:_servicePeripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
//    }
    
    
}
#pragma mark --- CBPeripheralDelegate 发现服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@" %s  %@", __FUNCTION__, error);
        return;
    }
    for (CBService *service in peripheral.services) {
        NSLog(@"service     %@", service.UUID);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            //[peripheral discoverCharacteristics:nil forService:service];
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kReadCharacteristicUUID], [CBUUID UUIDWithString:kWriteCharacteristicUUID]] forService:service];
        }
    }
    
}
//   发现特征值
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristic: %@", [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"characteristic %@  %lx   %@", characteristic.UUID, characteristic.properties ,characteristic.descriptors);
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kReadCharacteristicUUID]]) {
            [peripheral readValueForCharacteristic:characteristic];
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kWriteCharacteristicUUID]]) {
            self.writeCharacteristic = characteristic;
        }
    }
    
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kReadCharacteristicUUID]] )
    {
        if (characteristic.isNotifying)
        {
            NSLog(@"Notification began on %@", characteristic);
            [peripheral readValueForCharacteristic:characteristic];
        }
        else
        {
            NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
            //[_centralManager cancelPeripheralConnection:_servicePeripheral];
            NSLog(@"------重新启动连接---");
//            self.centralManager.delegate = self;
//            [self.centralManager connectPeripheral:_servicePeripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
            [self updateBleStatus:BluetoothStatusSearching];
        }
    }
}
/*
#ifdef _FOR_DEBUG_
-(BOOL) respondsToSelector:(SEL)aSelector {
    printf("SELECTOR: %s\n", [NSStringFromSelector(aSelector) UTF8String]);
    return [super respondsToSelector:aSelector];
}
#endif*/

//   与外设做数据交互 (读写)
//   读特征值的信息
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error didUpdateValueForCharacteristic: %@", error.localizedDescription);
    }
    [self updateBleStatus:BluetoothStatusTransferring];
    NSLog(@"--------------------------------------------------------------------");
    //NSLog(@" uuid %@", characteristic.UUID.UUIDString);
    NSLog(@"characteristic value %@ ", characteristic.value);
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kReadCharacteristicUUID]])
    {
        Byte cValue[20] = {0};
        NSData *data = characteristic.value;
        [data getBytes:&cValue length:data.length];
        
        NSLog(@"%x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x",cValue[0],cValue[1],cValue[2],cValue[3],cValue[4],cValue[5],cValue[6],cValue[7],cValue[8],cValue[9],cValue[10],cValue[11],cValue[12],cValue[13],cValue[14],cValue[15],cValue[16],cValue[17],cValue[18],cValue[19]);
        
    }
   
    
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error didUpdateValueForCharacteristic: %@", error.localizedDescription);
    }
    NSLog(@"%s", __FUNCTION__);
}








#pragma mark --- data exchange
- (NSData *)hexToBytes:(NSString *)str {
    NSMutableData *mutData = [NSMutableData data];
    for (int index = 0; index + 2<= str.length; index+=2) {
        NSRange range = NSMakeRange(index, 2);
        NSString *hexStr = [str substringWithRange:range];
        NSScanner *scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [mutData appendBytes:&intValue length:1];
    }
    return mutData;
}

// 校验和
- (NSData *)getCheckSum:(NSString *)byteStr {
    int length = (int)byteStr.length / 2;
    NSData *data = [self hexToBytes:byteStr];
    Byte *bytes = (unsigned char *)[data bytes];
    Byte sum = 0;
    for (int index =0 ; index < length; index++) {
        sum += bytes[index];
    }
    int sumT = sum;
    int at = 256 - sumT;
    
    if (at == 256) {
        at = 0;
    }
    NSString *str = [NSString stringWithFormat:@"%@%@", byteStr, [self ToHex:at]];
    
    return [self hexToBytes:str];
}

//将十进制转化为十六进制
- (NSString *)ToHex:(int)tmpid {
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig) {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
                break;
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
    }
    //不够一个字节凑0
    if(str.length == 1){
        return [NSString stringWithFormat:@"0%@",str];
    }else{
        return str;
    }
}


//  十进制转二进制
- (NSString *)toBinarySystemWithDecimalSystem:(int)num length:(int)length
{
    int remainder = 0;      //余数
    int divisor = 0;        //除数
    
    NSString * prepare = @"";
    
    while (true)
    {
        remainder = num%2;
        divisor = num/2;
        num = divisor;
        prepare = [prepare stringByAppendingFormat:@"%d",remainder];
        
        if (divisor == 0)
        {
            break;
        }
    }
    //倒序输出
    NSString * result = @"";
    for (int i = length -1; i >= 0; i --)
    {
        if (i <= prepare.length - 1) {
            result = [result stringByAppendingFormat:@"%@",
                      [prepare substringWithRange:NSMakeRange(i , 1)]];
            
        }else{
            result = [result stringByAppendingString:@"0"];
            
        }
    }
    return result;
}

//  二进制转十进制
- (NSString *)toDecimalWithBinary:(NSString *)binary
{
    int ll = 0 ;
    int  temp = 0 ;
    for (int i = 0; i < binary.length; i ++)
    {
        temp = [[binary substringWithRange:NSMakeRange(i, 1)] intValue];
        temp = temp * powf(2, binary.length - i - 1);
        ll += temp;
    }
    
    NSString * result = [NSString stringWithFormat:@"%d",ll];
    
    return result;
}

// 十六进制转二进制
- (NSString *)getBinaryByhex:(NSString *)hex binary:(NSString *)binary
{
    NSMutableDictionary  *hexDic = [[NSMutableDictionary alloc] init];
    hexDic = [[NSMutableDictionary alloc] initWithCapacity:16];
    [hexDic setObject:@"0000" forKey:@"0"];
    [hexDic setObject:@"0001" forKey:@"1"];
    [hexDic setObject:@"0010" forKey:@"2"];
    [hexDic setObject:@"0011" forKey:@"3"];
    [hexDic setObject:@"0100" forKey:@"4"];
    [hexDic setObject:@"0101" forKey:@"5"];
    [hexDic setObject:@"0110" forKey:@"6"];
    [hexDic setObject:@"0111" forKey:@"7"];
    [hexDic setObject:@"1000" forKey:@"8"];
    [hexDic setObject:@"1001" forKey:@"9"];
    [hexDic setObject:@"1010" forKey:@"a"];
    [hexDic setObject:@"1011" forKey:@"b"];
    [hexDic setObject:@"1100" forKey:@"c"];
    [hexDic setObject:@"1101" forKey:@"d"];
    [hexDic setObject:@"1110" forKey:@"e"];
    [hexDic setObject:@"1111" forKey:@"f"];
    
    NSMutableString *binaryString=[[NSMutableString alloc] init];
    if (hex.length) {
        for (int i=0; i<[hex length]; i++) {
            NSRange rage;
            rage.length = 1;
            rage.location = i;
            NSString *key = [hex substringWithRange:rage];
            [binaryString appendString:hexDic[key]];
        }
        
    }else{
        for (int i=0; i<binary.length; i+=4) {
            NSString *subStr = [binary substringWithRange:NSMakeRange(i, 4)];
            int index = 0;
            for (NSString *str in hexDic.allValues) {
                index ++;
                if ([subStr isEqualToString:str]) {
                    [binaryString appendString:hexDic.allKeys[index-1]];
                    break;
                }
            }
        }
    }
    return binaryString;
}

// int转NSData
- (NSData *)setId:(int)Id {
    //用4个字节接收
    Byte bytes[4];
    bytes[0] = (Byte)(Id>>24);
    bytes[1] = (Byte)(Id>>16);
    bytes[2] = (Byte)(Id>>8);
    bytes[3] = (Byte)(Id);
    NSData *data = [NSData dataWithBytes:bytes length:4];
    return data;
}

// NSData转int
- (unsigned)parseIntFromData:(NSData *)data{
    NSString *dataDescription = [data description];
    NSString *dataAsString = [dataDescription substringWithRange:NSMakeRange(1, [dataDescription length] -2)];
    
    unsigned intData = 0;
    NSScanner *scanner = [NSScanner scannerWithString:dataAsString];
    [scanner scanHexInt:&intData];
    return intData;
}
// 接受到的数据0x00000a0122
- (void)test {
    NSData *data = [NSData data];
    //4字节表示的int
    NSData *intData = [data subdataWithRange:NSMakeRange(2, 4)];
    int value = CFSwapInt32BigToHost(*(int*)([intData bytes]));//655650
    //2字节表示的int
    NSData *intData2 = [data subdataWithRange:NSMakeRange(4, 2)];
    int value2 = CFSwapInt16BigToHost(*(int*)([intData bytes]));//290
    //1字节表示的int
    char *bs = (unsigned char *)[[data subdataWithRange:NSMakeRange(5, 1) ] bytes];
    int value3 = *bs;//34
}




@end
