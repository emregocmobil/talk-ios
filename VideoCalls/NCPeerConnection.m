//
//  NCPeerConnection.m
//  VideoCalls
//
//  Created by Ivan Sein on 29.09.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import "NCPeerConnection.h"

#import "ARDSDPUtils.h"
#import "NCSignalingMessage.h"
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCDataChannelConfiguration.h>
#import <WebRTC/RTCIceServer.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCMediaStream.h>


@interface NCPeerConnection () <RTCPeerConnectionDelegate, RTCDataChannelDelegate>

@property (nonatomic, strong) RTCPeerConnectionFactory *peerConnectionFactory;
@property (nonatomic, strong) NSMutableArray *queuedRemoteCandidates;

@end

@implementation NCPeerConnection

- (instancetype)initWithSessionId:(NSString *)sessionId andICEServers:(NSArray *)iceServers forAudioOnlyCall:(BOOL)audioOnly
{
    self = [super init];
    
    if (self) {
        _peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
        
        RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc]
                                            initWithMandatoryConstraints:nil
                                            optionalConstraints:nil];
        
        RTCConfiguration *config = [[RTCConfiguration alloc] init];
        [config setIceServers:iceServers];
        
        RTCPeerConnection *peerConnection = [_peerConnectionFactory peerConnectionWithConfiguration:config
                                                                                        constraints:constraints
                                                                                           delegate:self];
        
        _peerConnection = peerConnection;
        _peerId = sessionId;
        _isAudioOnly = audioOnly;
    }
    
    return self;
}

- (instancetype)initForMCUWithSessionId:(NSString *)sessionId andICEServers:(NSArray *)iceServers forAudioOnlyCall:(BOOL)audioOnly
{
    self = [self initWithSessionId:sessionId andICEServers:iceServers forAudioOnlyCall:audioOnly];
    
    if (self) {
        _isMCUPublisherPeer = YES;
    }
    
    return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[NCPeerConnection class]]) {
        NCPeerConnection *otherConnection = (NCPeerConnection *)object;
        return [otherConnection.peerConnection isEqual:self.peerConnection];
    }
    
    return NO;
}

- (void)dealloc {
//    [self close];
    NSLog(@"NCPeerConnection dealloc");
}

#pragma mark - Public

- (void)addICECandidate:(RTCIceCandidate *)candidate
{
    BOOL queueCandidates = self.peerConnection == nil || self.peerConnection.signalingState != RTCSignalingStateStable;
    
    if (!_peerConnection.remoteDescription) {
        if (!self.queuedRemoteCandidates) {
            self.queuedRemoteCandidates = [NSMutableArray array];
        }
        NSLog(@"Queued a remote ICE candidate for later.");
        [self.queuedRemoteCandidates addObject:candidate];
    } else {
        NSLog(@"Adding a remote ICE candidate.");
        [self.peerConnection addIceCandidate:candidate];
    }
}

- (void)drainRemoteCandidates
{
    NSLog(@"Drain %lu remote ICE candidates.", (unsigned long)[self.queuedRemoteCandidates count]);
    
    for (RTCIceCandidate *candidate in self.queuedRemoteCandidates) {
        [self.peerConnection addIceCandidate:candidate];
    }
    self.queuedRemoteCandidates = nil;
}

- (void)removeRemoteCandidates
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.queuedRemoteCandidates removeAllObjects];
    self.queuedRemoteCandidates = nil;
}

- (void)setRemoteDescription:(RTCSessionDescription *)sessionDescription
{
    __weak NCPeerConnection *weakSelf = self;
    RTCSessionDescription *sdpPreferringCodec = [ARDSDPUtils descriptionForDescription:sessionDescription preferredVideoCodec:@"H264"];
    [_peerConnection setRemoteDescription:sdpPreferringCodec completionHandler:^(NSError *error) {
        NCPeerConnection *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf peerConnectionDidSetSessionDescriptionWithError:error];
        }
    }];
}

- (void)sendOffer
{
    //Create data channel before creating the offer to enable data channels
    RTCDataChannelConfiguration* config = [[RTCDataChannelConfiguration alloc] init];
    config.isNegotiated = NO;
    _localDataChannel = [_peerConnection dataChannelForLabel:@"status" configuration:config];
    _localDataChannel.delegate = self;
    [_peerConnection offerForConstraints:[self defaultOfferConstraints] completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
        __weak NCPeerConnection *weakSelf = self;
        [_peerConnection setLocalDescription:sdp completionHandler:^(NSError *error) {
            NCPeerConnection *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf.delegate peerConnection:strongSelf needsToSendSessionDescription:sdp];
            }
        }];
    }];
}

- (void)sendPublishOfferToMCU
{
    //Create data channel before creating the offer to enable data channels
    RTCDataChannelConfiguration* config = [[RTCDataChannelConfiguration alloc] init];
    config.isNegotiated = NO;
    _localDataChannel = [_peerConnection dataChannelForLabel:@"status" configuration:config];
    _localDataChannel.delegate = self;
    [_peerConnection offerForConstraints:[self mcuOfferConstraints] completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
        __weak NCPeerConnection *weakSelf = self;
        [_peerConnection setLocalDescription:sdp completionHandler:^(NSError *error) {
            NCPeerConnection *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf.delegate peerConnection:strongSelf needsToSendSessionDescription:sdp];
            }
        }];
    }];
}

- (void)close
{
    RTCMediaStream *localStream = [self.peerConnection.localStreams firstObject];
    if (localStream) {
        [self.peerConnection removeStream:localStream];
    }
    [self.peerConnection close];

    self.remoteStream = nil;
    self.localDataChannel = nil;
    self.remoteDataChannel = nil;
    self.peerConnection = nil;
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged
{
    NSLog(@"Signaling state with '%@' changed to: %@", self.peerId, [self stringForSignalingState:stateChanged]);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Received %lu video tracks and %lu audio tracks from %@",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count,
              self.peerId);
        
        self.remoteStream = stream;
        [self.delegate peerConnection:self didAddStream:stream];
        
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream
{
    NSLog(@"Stream was removed from %@.", self.peerId);
#warning Check if if is the same stream?
    self.remoteStream = nil;
    [self.delegate peerConnection:self didRemoveStream:stream];
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection
{
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState
{
    NSLog(@"ICE state with '%@' changed to: %@", self.peerId, [self stringForConnectionState:newState]);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate peerConnection:self didChangeIceConnectionState:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState
{
    NSLog(@"ICE gathering state with '%@' changed to : %@", self.peerId, [self stringForGatheringState:newState]);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate
{
    NSLog(@"Peer '%@' did generate Ice Candidate: %@", self.peerId, candidate);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate peerConnection:self didGenerateIceCandidate:candidate];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    NSLog(@"PeerConnection didRemoveIceCandidates delegate has been called.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel
{
    if ([dataChannel.label isEqualToString:@"status"]) {
        _remoteDataChannel = dataChannel;
        _remoteDataChannel.delegate = self;
        NSLog(@"Remote data channel '%@' was opened.", dataChannel.label);
    } else {
        NSLog(@"Data channel '%@' was opened.", dataChannel.label);
    }
}

#pragma mark - RTCDataChannelDelegate

- (void)dataChannelDidChangeState:(RTCDataChannel *)dataChannel
{
    NSLog(@"Data cahnnel '%@' did change state: %ld", dataChannel.label, (long)dataChannel.readyState);
    if (dataChannel.readyState == RTCDataChannelStateOpen && [dataChannel.label isEqualToString:@"status"]) {
        [self.delegate peerConnectionDidOpenStatusDataChannel:self];
    }
}

- (void)dataChannel:(RTCDataChannel *)dataChannel didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer
{
    NSDictionary *message = [self getDataChannelMessageFromJSONData:buffer.data];
    NSString *messageType =[message objectForKey:@"type"];
    
    NSLog(@"Data channel '%@' did receive message: %@", dataChannel.label, messageType);
    
    if ([messageType isEqualToString:@"nickChanged"]) {
        id messagePayload = [message objectForKey:@"payload"];
        NSString *nick = @"";
        if ([messagePayload isKindOfClass:[NSString class]]) {
            nick = messagePayload;
        } else if ([messagePayload isKindOfClass:[NSDictionary class]]) {
            nick = [messagePayload objectForKey:@"name"];
        }
        _peerName = nick;
        [self.delegate peerConnection:self didReceivePeerNick:nick];
    } else {
        // Check remote audio/video status
        if ([messageType isEqualToString:@"audioOn"]) {
            _isRemoteAudioDisabled = NO;
        } else if ([messageType isEqualToString:@"audioOff"]) {
            _isRemoteAudioDisabled = YES;
        } else if ([messageType isEqualToString:@"videoOn"]) {
            _isRemoteVideoDisabled = NO;
        } else if ([messageType isEqualToString:@"videoOff"]) {
            _isRemoteVideoDisabled = YES;
        } else if ([messageType isEqualToString:@"speaking"]) {
            _isPeerSpeaking = YES;
        } else if ([messageType isEqualToString:@"stoppedSpeaking"]) {
            _isPeerSpeaking = NO;
        }
        
        [self.delegate peerConnection:self didReceiveStatusDataChannelMessage:messageType];
    }
}

- (NSDictionary *)getDataChannelMessageFromJSONData:(NSData *)jsonData
{
    NSError *error;
    NSDictionary* messageDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:kNilOptions
                                                                  error:&error];
    
    if (!messageDict) {
        NSLog(@"Error parsing data channel message: %@", error);
    }
    
    return messageDict;
}

- (NSData *)createDataChannelMessage:(NSDictionary *)message
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:0
                                                         error:&error];
    
    if (!jsonData) {
        NSLog(@"Error creating data channel message: %@", error);
    }
    
    return jsonData;
}

- (void)sendDataChannelMessageOfType:(NSString *)type withPayload:(id)payload
{
    NSDictionary *message = @{@"type": type};
    
    if (payload) {
        message = @{@"type": type,
                    @"payload": payload};
    }
    
    NSData *jsonMessage = [self createDataChannelMessage:message];
    RTCDataBuffer *dataBuffer = [[RTCDataBuffer alloc] initWithData:jsonMessage isBinary:NO];
    
    if (_localDataChannel) {
        [_localDataChannel sendData:dataBuffer];
    } else if (_remoteDataChannel) {
        [_remoteDataChannel sendData:dataBuffer];
    } else {
        NSLog(@"No data channel opened");
    }
}

#pragma mark - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnectionForSessionDidCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    if (error) {
        NSLog(@"Failed to create session description for peer %@. Error: %@", _peerId, error);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Did create session sescriptionfor peer %@", _peerId);
        // Set H264 as preferred codec.
        RTCSessionDescription *sdpPreferringCodec = [ARDSDPUtils descriptionForDescription:sdp preferredVideoCodec:@"H264"];
        __weak NCPeerConnection *weakSelf = self;
        [_peerConnection setLocalDescription:sdpPreferringCodec completionHandler:^(NSError *error) {
            NCPeerConnection *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf peerConnectionDidSetSessionDescriptionWithError:error];
            }
        }];
        
        [self.delegate peerConnection:self needsToSendSessionDescription:sdpPreferringCodec];
    });
}

- (void)peerConnectionDidSetSessionDescriptionWithError:(NSError *)error
{
    if (error) {
        NSLog(@"Failed to set session description for peer %@. Error: %@", _peerId, error);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        NSLog(@"Did set session description for peer %@", _peerId);
        if (!_peerConnection.localDescription) {
            NSLog(@"Creating local description for peer %@", _peerId);
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            __weak NCPeerConnection *weakSelf = self;
            //Create data channel before sending answer
            RTCDataChannelConfiguration* config = [[RTCDataChannelConfiguration alloc] init];
            config.isNegotiated = NO;
            _localDataChannel = [_peerConnection dataChannelForLabel:@"status" configuration:config];
            _localDataChannel.delegate = self;
            [_peerConnection answerForConstraints:constraints completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
                NCPeerConnection *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf peerConnectionForSessionDidCreateSessionDescription:sdp error:error];
                }
            }];
        }
        
        if (_peerConnection.remoteDescription) {
            [self drainRemoteCandidates];
        }
    });
}

#pragma mark - Utils

- (RTCMediaConstraints *)defaultAnswerConstraints
{
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints
{
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true"
                                           };
    
    if (_isAudioOnly) {
        mandatoryConstraints = @{
                                 @"OfferToReceiveAudio" : @"true",
                                 @"OfferToReceiveVideo" : @"false"
                                 };
    }
    
    NSDictionary *optionalConstraints = @{
                                          @"internalSctpDataChannels": @"true",
                                          @"DtlsSrtpKeyAgreement": @"true"
                                          };
    
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc]
                                        initWithMandatoryConstraints:mandatoryConstraints
                                        optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCMediaConstraints *)mcuOfferConstraints
{
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"false",
                                           @"OfferToReceiveVideo" : @"false"
                                           };
    
    NSDictionary *optionalConstraints = @{
                                          @"internalSctpDataChannels": @"true",
                                          @"DtlsSrtpKeyAgreement": @"true"
                                          };
    
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc]
                                        initWithMandatoryConstraints:mandatoryConstraints
                                        optionalConstraints:optionalConstraints];
    return constraints;
}

- (NSString *)stringForSignalingState:(RTCSignalingState)state
{
    switch (state) {
        case RTCSignalingStateStable:
            return @"Stable";
            break;
        case RTCSignalingStateHaveLocalOffer:
            return @"Have Local Offer";
            break;
        case RTCSignalingStateHaveRemoteOffer:
            return @"Have Remote Offer";
            break;
        case RTCSignalingStateClosed:
            return @"Closed";
            break;
        default:
            return @"Other state";
            break;
    }
}

- (NSString *)stringForConnectionState:(RTCIceConnectionState)state
{
    switch (state) {
        case RTCIceConnectionStateNew:
            return @"New";
            break;
        case RTCIceConnectionStateChecking:
            return @"Checking";
            break;
        case RTCIceConnectionStateConnected:
            return @"Connected";
            break;
        case RTCIceConnectionStateCompleted:
            return @"Completed";
            break;
        case RTCIceConnectionStateFailed:
            return @"Failed";
            break;
        case RTCIceConnectionStateDisconnected:
            return @"Disconnected";
            break;
        case RTCIceConnectionStateClosed:
            return @"Closed";
            break;
        default:
            return @"Other state";
            break;
    }
}

- (NSString *)stringForGatheringState:(RTCIceGatheringState)state
{
    switch (state) {
        case RTCIceGatheringStateNew:
            return @"New";
            break;
        case RTCIceGatheringStateGathering:
            return @"Gathering";
            break;
        case RTCIceGatheringStateComplete:
            return @"Complete";
            break;
        default:
            return @"Other state";
            break;
    }
}

@end
