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

#import "NCRoom.h"
#import "NCChatController.h"
#import "NCChatViewController.h"
#import "CallViewController.h"

// Room
extern NSString * const NCRoomsManagerDidJoinRoomNotification;
extern NSString * const NCRoomsManagerDidLeaveRoomNotification;
extern NSString * const NCRoomsManagerDidUpdateRoomsNotification;
extern NSString * const NCRoomsManagerDidUpdateRoomNotification;
// Call
extern NSString * const NCRoomsManagerDidStartCallNotification;

@interface NCRoomController : NSObject

@property (nonatomic, strong) NSString *userSessionId;
@property (nonatomic, assign) BOOL inCall;
@property (nonatomic, assign) BOOL inChat;

@end

@interface NCRoomsManager : NSObject

@property (nonatomic, strong) NCChatViewController *chatViewController;
@property (nonatomic, strong) CallViewController *callViewController;

+ (instancetype)sharedInstance;
// Room
- (NSArray *)roomsForAccountId:(NSString *)accountId witRealm:(RLMRealm *)realm;
- (NCRoom *)roomWithToken:(NSString *)token forAccountId:(NSString *)accountId;
- (void)updateRoomsUpdatingUserStatus:(BOOL)updateStatus;
- (void)updateRoom:(NSString *)token;
- (void)joinRoom:(NSString *)token;
- (void)rejoinRoom:(NSString *)token;
// Chat
- (void)startChatInRoom:(NCRoom *)room;
- (void)leaveChatInRoom:(NSString *)token;
// Call
- (void)startCall:(BOOL)video inRoom:(NCRoom *)room;
- (void)joinCallWithCallToken:(NSString *)token withVideo:(BOOL)video;

@end
