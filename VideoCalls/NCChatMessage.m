//
//  NCChatMessage.m
//  VideoCalls
//
//  Created by Ivan Sein on 23.04.18.
//  Copyright © 2018 struktur AG. All rights reserved.
//

#import "NCChatMessage.h"

@implementation NCChatMessage

+ (instancetype)messageWithDictionary:(NSDictionary *)messageDict
{
    if (!messageDict) {
        return nil;
    }
    
    NCChatMessage *message = [[NCChatMessage alloc] init];
    message.actorId = [messageDict objectForKey:@"actorId"];
    message.actorType = [messageDict objectForKey:@"actorType"];
    message.messageId = [[messageDict objectForKey:@"id"] integerValue];
    message.message = [messageDict objectForKey:@"message"];
    message.messageParameters = [messageDict objectForKey:@"messageParameters"];
    message.timestamp = [[messageDict objectForKey:@"timestamp"] integerValue];
    message.token = [messageDict objectForKey:@"token"];
    
    id actorDisplayName = [messageDict objectForKey:@"actorDisplayName"];
    if (!actorDisplayName || [actorDisplayName isEqualToString:@""]) {
        message.actorDisplayName = @"Guest";
    } else {
        if ([actorDisplayName isKindOfClass:[NSString class]]) {
            message.actorDisplayName = actorDisplayName;
        } else {
            message.actorDisplayName = [actorDisplayName stringValue];
        }
    }
    
    return message;
}

- (NSString *)parsedMessage
{
    NSString *originalMessage = _message;
    NSString *parsedMessage = originalMessage;
    NSError *error = nil;
    NSRegularExpression *mentionRegex = [NSRegularExpression regularExpressionWithPattern:@"\\{([^}]+)\\}" options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *matches = [mentionRegex matchesInString:originalMessage
                                             options:0
                                               range:NSMakeRange(0, [originalMessage length])];
    for (NSTextCheckingResult *match in matches) {
        NSString* mention = [originalMessage substringWithRange:match.range];
        NSString *mentionId = [mention substringFromIndex:1];
        mentionId = [mentionId substringToIndex:[mentionId length] -1];
        NSDictionary *parameters = [_messageParameters objectForKey:mentionId];
        if (parameters) {
            NSString *mentionDisplayName = [NSString stringWithFormat:@"@%@", [parameters objectForKey:@"name"]];
            parsedMessage = [parsedMessage stringByReplacingOccurrencesOfString:mention withString:mentionDisplayName];
        }
    }
    return parsedMessage;
}

@end
