//
//  NCAPISessionManager.m
//  VideoCalls
//
//  Created by Ivan Sein on 30.11.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import "NCAPISessionManager.h"
#import "CCCertificate.h"

@implementation NCAPISessionManager

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    self = [super initWithSessionConfiguration:configuration];
    if (self) {
        _userAgent = [NSString stringWithFormat:@"Mozilla/5.0 (iOS) Nextcloud-Talk v%@",
                      [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
        
        self.responseSerializer = [[AFJSONResponseSerializer alloc] init];
        self.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
        
        AFSecurityPolicy* policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        self.securityPolicy = policy;
        
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [self.requestSerializer setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
        [self.requestSerializer setValue:_userAgent forHTTPHeaderField:@"User-Agent"];
    }
    return self;
}

-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

@end
