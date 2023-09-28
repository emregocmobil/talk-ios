//
//  NCRoom.h
//  VideoCalls
//
//  Created by Ivan Sein on 12.07.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NCRoomParticipant.h"

typedef enum NCRoomType {
    kNCRoomTypeOneToOneCall = 1,
    kNCRoomTypeGroupCall,
    kNCRoomTypePublicCall
} NCRoomType;

@interface NCRoom : NSObject

@property (nonatomic, assign) NSInteger roomId;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) NCRoomType type;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) BOOL hasPassword;
@property (nonatomic, assign) NCParticipantType participantType;
@property (nonatomic, assign) NSInteger lastPing;
@property (nonatomic, assign) NSInteger numGuests;
@property (nonatomic, assign) NSInteger unreadMessages;
@property (nonatomic, copy) NSString *guestList;
@property (nonatomic, copy) NSDictionary *participants;

+ (instancetype)roomWithDictionary:(NSDictionary *)roomDict;

- (BOOL)isPublic;
- (BOOL)canModerate;
- (BOOL)isNameEditable;
- (BOOL)isDeletable;

@end
