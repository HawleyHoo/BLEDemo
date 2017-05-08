//
//  HYBLEManager.h

//  Created by on 15/9/14.
//  Copyright (c) 2015年 Savvy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef NS_ENUM(NSInteger, BluetoothStatus)
{
    BluetoothStatusNoOperate = 0,
    BluetoothStatusSearching,
    BluetoothStatusFoundPeripheral,
    BluetoothStatusConnectOk,
    BluetoothStatusConnectFailed,
    BluetoothStatusTransferring,
    BluetoothStatusCompleteTransfer,
    BluetoothStatusDisConnect,
};

typedef void (^BluetoothStatusBlock)(BluetoothStatus status);


@protocol HYBLEManagerDelegate <NSObject>

@optional
- (void)bleManagerDidFindPeripherals;

- (void)bleManagerDidUpdateBleConnectionStatus:(BluetoothStatus)status;


@end

@interface HYBLEManager : NSObject

@property (weak, nonatomic) id<HYBLEManagerDelegate> delegate;

@property (strong, nonatomic) NSMutableArray *devices;

+ (instancetype)sharedManager;

- (void)startScaning;

- (void)stopScanning;

- (void)cancelPeripheralConnection;
//  Description：start to scan the bluetooth device
- (void)startScaning:(BluetoothStatusBlock)block;

- (void)connectPeripheral:(CBPeripheral *)peripheral;



@end
