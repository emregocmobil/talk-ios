//
//  NCSettingsController.m
//  VideoCalls
//
//  Created by Ivan Sein on 26.06.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import "NCSettingsController.h"

#import "NCAPIController.h"

@implementation NCSettingsController

NSString * const kNCServerKey           = @"ncServer";
NSString * const kNCUserKey             = @"ncUser";
NSString * const kNCUserDisplayNameKey  = @"ncUserDisplayName";
NSString * const kNCTokenKey            = @"ncToken";
NSString * const kNCPushTokenKey        = @"ncPushToken";

+ (NCSettingsController *)sharedInstance
{
    static dispatch_once_t once;
    static NCSettingsController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self readValuesFromKeyChain];
    }
    return self;
}

- (void)readValuesFromKeyChain
{
    _ncServer = [UICKeyChainStore stringForKey:kNCServerKey];
    _ncUser = [UICKeyChainStore stringForKey:kNCUserKey];
    _ncUserDisplayName = [UICKeyChainStore stringForKey:kNCUserDisplayNameKey];
    _ncToken = [UICKeyChainStore stringForKey:kNCTokenKey];
    _ncPushToken = [UICKeyChainStore stringForKey:kNCPushTokenKey];
}

- (void)cleanAllStoredValues
{
    _ncServer = nil;
    _ncUser = nil;
    _ncUserDisplayName = nil;
    _ncToken = nil;
    _ncPushToken = nil;
    
    [UICKeyChainStore removeAllItems];
    
#warning TODO - Restore NCAPIController in a diferent way
    [[NCAPIController sharedInstance] setAuthHeaderWithUser:NULL andToken:NULL];
}

@end
