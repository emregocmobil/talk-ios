//
//  NCSignalingMessage.h
//  VideoCalls
//
//  Created by Ivan Sein on 04.08.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "WebRTC/RTCIceCandidate.h"
#import "WebRTC/RTCSessionDescription.h"

extern NSString *const kRoomTypeVideo;
extern NSString *const kRoomTypeScreen;

typedef enum {
    kNCSignalingMessageTypeUknown,
    kNCSignalingMessageTypeCandidate,
    kNCSignalingMessageTypeOffer,
    kNCSignalingMessageTypeAnswer,
    kNCSignalingMessageTypeUnshareScreen,
} NCSignalingMessageType;


@interface NCSignalingMessage : NSObject

@property(nonatomic, readonly) NSString *from;
@property(nonatomic, readonly) NSString *to;
@property(nonatomic, readonly) NSString *sid;
@property(nonatomic, readonly) NSString *type;
@property(nonatomic, readonly) NSDictionary *payload;
@property(nonatomic, readonly) NSString *roomType;

+ (NCSignalingMessage *)messageFromJSONString:(NSString *)jsonString;
+ (NCSignalingMessage *)messageFromJSONDictionary:(NSDictionary *)jsonDict;
+ (NSString *)getMessageSid;
- (NSDictionary *)messageDict;
- (NSDictionary *)functionDict;
- (NCSignalingMessageType)messageType;

@end

@interface NCICECandidateMessage : NCSignalingMessage

@property(nonatomic, readonly) RTCIceCandidate *candidate;

- (instancetype)initWithValues:(NSDictionary *)values;
- (instancetype)initWithCandidate:(RTCIceCandidate *)candidate
                             from:(NSString *)from
                               to:(NSString *)to
                              sid:(NSString *)sid
                         roomType:(NSString *)roomType;

@end

@interface NCSessionDescriptionMessage : NCSignalingMessage

@property(nonatomic, readonly) RTCSessionDescription *sessionDescription;
@property(nonatomic, readonly) NSString *nick;

- (instancetype)initWithValues:(NSDictionary *)values;
- (instancetype)initWithSessionDescription:(RTCSessionDescription *)sessionDescription
                                      from:(NSString *)from
                                        to:(NSString *)to
                                       sid:(NSString *)sid
                                  roomType:(NSString *)roomType
                                      nick:(NSString *)nick;


@end

@interface NCUnshareScreenMessage : NCSignalingMessage

- (instancetype)initWithValues:(NSDictionary *)values;

@end

