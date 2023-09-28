/**
 * @copyright Copyright (c) 2020 Ivan Sein <ivan@nextcloud.com>
 *
 * @author Ivan Sein <ivan@nextcloud.com>
 *
 * @license GNU GPL version 3 or any later version
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

#import "NCRoomParticipant.h"
#import "NCChatMessage.h"

typedef enum NCRoomType {
    kNCRoomTypeOneToOne = 1,
    kNCRoomTypeGroup,
    kNCRoomTypePublic,
    kNCRoomTypeChangelog
} NCRoomType;

typedef enum NCRoomNotificationLevel {
    kNCRoomNotificationLevelDefault = 0,
    kNCRoomNotificationLevelAlways,
    kNCRoomNotificationLevelMention,
    kNCRoomNotificationLevelNever
} NCRoomNotificationLevel;

typedef enum NCRoomReadOnlyState {
    NCRoomReadOnlyStateReadWrite = 0,
    NCRoomReadOnlyStateReadOnly
} NCRoomReadOnlyState;

typedef enum NCRoomLobbyState {
    NCRoomLobbyStateAllParticipants = 0,
    NCRoomLobbyStateModeratorsOnly
} NCRoomLobbyState;

extern NSString * const NCRoomObjectTypeFile;
extern NSString * const NCRoomObjectTypeSharePassword;

@interface NCRoom : RLMObject

@property (nonatomic, copy) NSString *internalId; // accountId@token
@property (nonatomic, assign) NSInteger roomId;
@property (nonatomic, copy) NSString *accountId;
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
@property (nonatomic, assign) BOOL unreadMention;
@property (nonatomic, copy) NSString *guestList;
@property (nonatomic, strong) RLMArray<RLMString> *participants;
@property (nonatomic, assign) NSInteger lastActivity;
@property (nonatomic, copy) NSString *lastMessageId;
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, assign) NCRoomNotificationLevel notificationLevel;
@property (nonatomic, copy) NSString *objectType;
@property (nonatomic, copy) NSString *objectId;
@property (nonatomic, assign) NCRoomReadOnlyState readOnlyState;
@property (nonatomic, assign) NCRoomLobbyState lobbyState;
@property (nonatomic, assign) NSInteger lobbyTimer;
@property (nonatomic, assign) NSInteger lastReadMessage;
@property (nonatomic, assign) BOOL canStartCall;
@property (nonatomic, assign) BOOL hasCall;
@property (nonatomic, assign) NSInteger lastUpdate;

+ (instancetype)roomWithDictionary:(NSDictionary *)roomDict;
+ (instancetype)roomWithDictionary:(NSDictionary *)roomDict andAccountId:(NSString *)accountId;
+ (void)updateRoom:(NCRoom *)managedRoom withRoom:(NCRoom *)room;

- (BOOL)isPublic;
- (BOOL)canModerate;
- (BOOL)isNameEditable;
- (BOOL)isLeavable;
- (BOOL)userCanStartCall;
- (NSString *)deletionMessage;
- (NSString *)notificationLevelString;
- (NSString *)stringForNotificationLevel:(NCRoomNotificationLevel)level;
- (NSString *)lastMessageString;
- (NCChatMessage *)lastMessage;

@end
