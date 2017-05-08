//
//  ViewController.m
//  BLEDemo
//
//  Created by 胡杨 on 16/7/26.
//  Copyright © 2016年 Hawley. All rights reserved.
//

#import "ViewController.h"
#import "HYBLEManager.h"


#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
@interface ViewController ()<UITableViewDataSource, UITableViewDelegate, HYBLEManagerDelegate>

@property (nonatomic, strong) HYBLEManager *BLEManager;

@property (nonatomic, strong) NSArray *tableItems;

@property (nonatomic, weak) UITableView *tableview;

@property (nonatomic, weak) UIButton *button;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    HYBLEManager *manager = [HYBLEManager sharedManager];
    manager.delegate = self;
    self.BLEManager = manager;
    [manager startScaning:^(BluetoothStatus status) {
        
        switch (status)
        {
            case BluetoothStatusNoOperate:
            {
                NSLog(@"Bluetooth device is not connected.");
                
            }
                break;
            case BluetoothStatusSearching:
            {
                NSLog(@"Searching the bluetooth device.");
            }
                break;
            case BluetoothStatusFoundPeripheral:
            {
                NSLog(@"The bluetooth device is found.");
            }
                break;
            case BluetoothStatusConnectOk:
            {
                NSLog(@"Connect successfully");
            }
                break;
            case BluetoothStatusConnectFailed:
            {
                NSLog(@"Connect failed");
            }
                break;
            case BluetoothStatusTransferring:
            {
                NSLog(@"Data is transferring.");
            }
                break;
            case BluetoothStatusCompleteTransfer:
            {
                NSLog(@"Complete to transfer the data.");
            }
                break;
            case BluetoothStatusDisConnect:
            {
                NSLog(@"Bluetooth is disconnected.");
                
            }
                break;
            default:
                break;
        }
    }];
    
    [self setupView];
}

- (void)setupView {
    UITableView *tableview = [[UITableView alloc] initWithFrame:CGRectMake(0, 64, kWidth, kHeight - 124) style:UITableViewStyleGrouped];
    self.tableview = tableview;
    tableview.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kWidth, 0.1)];
    tableview.backgroundColor = [UIColor clearColor];
    tableview.dataSource = self;
    tableview.delegate = self;
    tableview.rowHeight = 60;
//    tableview.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:tableview];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(30, kHeight - 68, kWidth - 60, 36)];
    self.button = button;
    button.backgroundColor = UIColor.redColor;
    [button setTitle:@"停  止" forState:UIControlStateNormal];
    [button setTitle:@"扫  描" forState:UIControlStateSelected];
    [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)buttonClicked:(UIButton *)button {
    button.selected = !button.isSelected;
    //NSLog(@"--- %@", button.currentTitle);
    if (button.isSelected) {
        [self.BLEManager stopScanning];
        NSLog(@" stop ");
    } else {
        self.tableItems = nil;
        [self.tableview reloadData];
        [self.BLEManager startScaning];
        [self.tableview reloadData];
        NSLog(@"scaning");
    }
}

- (void)bleManagerDidFindPeripherals {
    
    NSLog(@"----bleManagerDidFindPeripherals---- device %@", self.BLEManager.devices);
    self.tableItems = [self.BLEManager.devices copy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableview reloadData];
    });
    
}

#pragma mark - UITableView Datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tableItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    CBPeripheral *peripheral = self.tableItems[indexPath.row];
    cell.detailTextLabel.text = peripheral.name;
    cell.textLabel.text = [NSString stringWithFormat:@"第%ld个 %@", (long)indexPath.row, peripheral.identifier];
    
    
    return cell;
}

#pragma mark - UITableView Delegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
