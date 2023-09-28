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

#import "NCSignalingMessage.h"

@class NCExternalSignalingController;
@class TalkAccount;

@protocol NCExternalSignalingControllerDelegate <NSObject>

- (void)externalSignalingController:(NCExternalSignalingController *)externalSignalingController didReceivedSignalingMessage:(NSDictionary *)signalingMessageDict;
- (void)externalSignalingController:(NCExternalSignalingController *)externalSignalingController didReceivedParticipantListMessage:(NSDictionary *)participantListMessageDict;
- (void)externalSignalingControllerShouldRejoinCall:(NCExternalSignalingController *)externalSignalingController;
- (void)externalSignalingControllerWillRejoinCall:(NCExternalSignalingController *)externalSignalingController;

@end

@interface NCExternalSignalingController : NSObject

@property (nonatomic, strong) NSString *currentRoom;
@property (nonatomic, strong) TalkAccount *account;
@property (nonatomic, weak) id<NCExternalSignalingControllerDelegate> delegate;

- (instancetype)initWithAccount:(TalkAccount *)account server:(NSString *)serverUrl andTicket:(NSString *)ticket;
- (BOOL)isEnabled;
- (BOOL)hasMCU;
- (NSString *)sessionId;
- (void)joinRoom:(NSString *)roomId withSessionId:(NSString *)sessionId;
- (void)leaveRoom:(NSString *)roomId;
- (void)sendCallMessage:(NCSignalingMessage *)message;
- (void)requestOfferForSessionId:(NSString *)sessionId andRoomType:(NSString *)roomType;
- (NSString *)getUserIdFromSessionId:(NSString *)sessionId;
- (void)disconnect;
- (void)forceReconnect;

@end
