//
//  STAccelerometer.m
//  TISensorTag
//
//  Created by Andre Muis on 11/14/13.
//  Copyright (c) 2013 Andre Muis. All rights reserved.
//

#import "STAccelerometer.h"

#import "STAcceleration.h"
#import "STConstants.h"

@interface STAccelerometer ()
{
    BOOL _enabled;
}

@property (readonly, strong, nonatomic) id<STSensorTagDelegate> sensorTagDelegate;
@property (readonly, strong, nonatomic) CBPeripheral *sensorTagPeripheral;
@property (readonly, strong, nonatomic) STAcceleration *rollingAcceleration;

@end

@implementation STAccelerometer

- (id)initWithSensorTagDelegate: (id<STSensorTagDelegate>)sensorTagDelegate
            sensorTagPeripheral: (CBPeripheral *)sensorTagPeripheral
{
    self = [super init];
    
    if (self)
    {
        _sensorTagDelegate = sensorTagDelegate;
        _sensorTagPeripheral = sensorTagPeripheral;
        _rollingAcceleration = [[STAcceleration alloc] initWithXComponent: 0.0 yComponent: 0.0 zComponent: 0.0];
        _dataCharacteristicUUID = [CBUUID UUIDWithString: STAccelerometerDataCharacteristicUUIDString];
        _dataCharacteristic = nil;
        
        _configurationCharacteristicUUID = [CBUUID UUIDWithString: STAccelerometerConfigurationCharacteristicUUIDString];
        _configurationCharacteristic = nil;
        
        _periodCharacteristicUUID = [CBUUID UUIDWithString: STAccelerometerPeriodCharacteristicUUIDString];
        _periodCharacteristic = nil;
    }
    
    return self;
}

- (BOOL)configured
{
    if (self.dataCharacteristic != nil &&
        self.configurationCharacteristic != nil &&
        self.periodCharacteristic != nil)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)enabled
{
    return _enabled;
}

- (void)setEnabled: (BOOL)enabled
{
    if (enabled == YES && _enabled == NO)
    {
        _enabled = YES;
 
        uint8_t enableValue = STSensorEnableValue;
        
        [self.sensorTagPeripheral writeValue: [NSData dataWithBytes: &enableValue length: 1]
                           forCharacteristic: self.configurationCharacteristic
                                        type: CBCharacteristicWriteWithResponse];
        
        [self.sensorTagPeripheral setNotifyValue: YES
                               forCharacteristic: self.dataCharacteristic];
    }
    else if (enabled == NO && _enabled == YES)
    {
        _enabled = NO;
        
        [self.sensorTagPeripheral setNotifyValue: NO
                               forCharacteristic: self.dataCharacteristic];
        
        uint8_t disableValue = STSensorDisableValue;
        
        [self.sensorTagPeripheral writeValue: [NSData dataWithBytes: &disableValue length: 1]
                           forCharacteristic: self.configurationCharacteristic
                                        type: CBCharacteristicWriteWithResponse];
    }
}

- (void)sensorTagPeripheralDidUpdateValueForCharacteristic: (CBCharacteristic *)characteristic
{
    if ([characteristic.UUID isEqual: self.dataCharacteristicUUID] == YES)
    {
        [self.sensorTagDelegate sensorTagDidUpdateAcceleration: [self accelerationWithCharacteristicValue: characteristic.value]];
        [self.sensorTagDelegate sensorTagDidUpdateSmoothedAcceleration: [self smoothedAccelerationWithCharacteristicValue: characteristic.value]];
    }
}

- (void)updateWithPeriodInMilliseconds: (int)periodInMilliseconds
{
    uint8_t periodData = (uint8_t)(periodInMilliseconds / 10);
    [self.sensorTagPeripheral writeValue: [NSData dataWithBytes: &periodData length: 1]
                       forCharacteristic: self.periodCharacteristic
                                    type: CBCharacteristicWriteWithResponse];
}

- (STAcceleration *)accelerationWithCharacteristicValue: (NSData *)characteristicValue
{
    char scratchVal[characteristicValue.length];
    [characteristicValue getBytes: &scratchVal length: 3];
    
    STAcceleration *acceleration = [[STAcceleration alloc] initWithXComponent: (scratchVal[0] * 1.0) / (256 / STAccelerometerRange)
                                                                   yComponent: (scratchVal[1] * 1.0) / (256 / STAccelerometerRange)
                                                                   zComponent: (scratchVal[2] * 1.0) / (256 / STAccelerometerRange)];
    
    return acceleration;
}

- (STAcceleration *)smoothedAccelerationWithCharacteristicValue: (NSData *)characteristicValue
{
    STAcceleration *acceleration = [self accelerationWithCharacteristicValue: characteristicValue];
    
    self.rollingAcceleration.xComponent = (acceleration.xComponent * STAccelerometerHighPassFilteringFactor) +
    (self.rollingAcceleration.xComponent * (1.0 - STAccelerometerHighPassFilteringFactor));
    
    self.rollingAcceleration.yComponent = (acceleration.yComponent * STAccelerometerHighPassFilteringFactor) +
    (self.rollingAcceleration.yComponent * (1.0 - STAccelerometerHighPassFilteringFactor));
    
    self.rollingAcceleration.zComponent = (acceleration.zComponent * STAccelerometerHighPassFilteringFactor) +
    (self.rollingAcceleration.zComponent * (1.0 - STAccelerometerHighPassFilteringFactor));
    
    acceleration.xComponent = acceleration.xComponent - self.rollingAcceleration.xComponent;
    acceleration.yComponent = acceleration.yComponent - self.rollingAcceleration.yComponent;
    acceleration.zComponent = acceleration.zComponent - self.rollingAcceleration.zComponent;

    return acceleration;
}

@end


















