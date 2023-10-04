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

#import <AVFoundation/AVFoundation.h>
#import <ContactsUI/ContactsUI.h>
#import <QuickLook/QuickLook.h>
#import <PhotosUI/PhotosUI.h>

@import NextcloudKit;

#import "NCChatViewController.h"

#import "AFImageDownloader.h"
#import "JDStatusBarNotification.h"
#import "NSDate+DateTools.h"
#import "UIButton+AFNetworking.h"
#import "UIResponder+SLKAdditions.h"
#import "UIView+Toast.h"

#import "AppDelegate.h"
#import "BarButtonItemWithActivity.h"
#import "CallKitManager.h"
#import "ChatMessageTableViewCell.h"
#import "DateHeaderView.h"
#import "DirectoryTableViewController.h"
#import "GroupedChatMessageTableViewCell.h"
#import "FileMessageTableViewCell.h"
#import "GeoLocationRichObject.h"
#import "LocationMessageTableViewCell.h"
#import "MapViewController.h"
#import "MessageSeparatorTableViewCell.h"
#import "ObjectShareMessageTableViewCell.h"
#import "PlaceholderView.h"
#import "NCAPIController.h"
#import "NCAppBranding.h"
#import "NCChatFileController.h"
#import "NCChatMessage.h"
#import "NCChatTitleView.h"
#import "NCConnectionController.h"
#import "NCDatabaseManager.h"
#import "NCExternalSignalingController.h"
#import "NCMessageParameter.h"
#import "NCMessageTextView.h"
#import "NCNavigationController.h"
#import "NCRoomsManager.h"
#import "NCSettingsController.h"
#import "NCUserInterfaceController.h"
#import "NCUtils.h"
#import "QuotedMessageView.h"
#import "ReplyMessageView.h"
#import "RoomInfoTableViewController.h"
#import "ShareViewController.h"
#import "ShareConfirmationViewController.h"
#import "ShareItem.h"
#import "SystemMessageTableViewCell.h"
#import "ShareLocationViewController.h"
#import "VoiceMessageRecordingView.h"
#import "VoiceMessageTableViewCell.h"
#import "VoiceMessageTranscribeViewController.h"
#import "NextcloudTalk-Swift.h"


#define k_send_message_button_tag   99
#define k_voice_record_button_tag   98

#define k_send_message_button_tag   99
#define k_voice_record_button_tag   98

typedef enum NCChatMessageAction {
    kNCChatMessageActionReply = 1,
    kNCChatMessageActionForward,
    kNCChatMessageActionCopy,
    kNCChatMessageActionResend,
    kNCChatMessageActionDelete,
    kNCChatMessageActionReplyPrivately,
    kNCChatMessageActionOpenFileInNextcloud,
    kNCChatMessageActionAddReaction
} NCChatMessageAction;

NSString * const kActionTypeTranscribeVoiceMessage   = @"transcribe-voice-message";

@interface NCChatViewController () <UIGestureRecognizerDelegate,
                                    UINavigationControllerDelegate,
                                    UITextFieldDelegate,
                                    PHPickerViewControllerDelegate,
                                    UIImagePickerControllerDelegate,
                                    UIDocumentPickerDelegate,
                                    ShareViewControllerDelegate,
                                    ShareConfirmationViewControllerDelegate,
                                    FileMessageTableViewCellDelegate,
                                    NCChatFileControllerDelegate,
                                    QLPreviewControllerDelegate,
                                    QLPreviewControllerDataSource,
                                    ChatMessageTableViewCellDelegate,
                                    ShareLocationViewControllerDelegate,
                                    LocationMessageTableViewCellDelegate,
                                    VoiceMessageTableViewCellDelegate,
                                    ObjectShareMessageTableViewCellDelegate,
                                    PollCreationViewControllerDelegate,
                                    SystemMessageTableViewCellDelegate,
                                    AVAudioRecorderDelegate,
                                    AVAudioPlayerDelegate,
                                    CNContactPickerDelegate,
                                    NCChatTitleViewDelegate,
                                    VLCKitVideoViewControllerDelegate,
                                    UITextViewDelegate>

@property (nonatomic, strong) NCChatTitleView *titleView;
@property (nonatomic, strong) PlaceholderView *chatBackgroundView;
@property (nonatomic, strong) NSMutableDictionary *messages;
@property (nonatomic, strong) NSMutableArray *dateSections;
@property (nonatomic, strong) NSMutableDictionary *mentionsDict;
@property (nonatomic, strong) NSMutableArray *autocompletionUsers;
@property (nonatomic, assign) BOOL hasPresentedLobby;
@property (nonatomic, assign) BOOL hasRequestedInitialHistory;
@property (nonatomic, assign) BOOL hasReceiveInitialHistory;
@property (nonatomic, assign) BOOL retrievingHistory;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL hasJoinedRoom;
@property (nonatomic, assign) BOOL startReceivingMessagesAfterJoin;
@property (nonatomic, assign) BOOL offlineMode;
@property (nonatomic, assign) BOOL hasStoredHistory;
@property (nonatomic, assign) BOOL hasStopped;
@property (nonatomic, assign) NSInteger lastReadMessage;
@property (nonatomic, strong) NCChatMessage *unreadMessagesSeparator;
@property (nonatomic, assign) NSInteger chatViewPresentedTimestamp;
@property (nonatomic, strong) UIActivityIndicatorView *loadingHistoryView;
@property (nonatomic, strong) NCChatMessage *firstUnreadMessage;
@property (nonatomic, strong) UIButton *unreadMessageButton;
@property (nonatomic, strong) NSTimer *lobbyCheckTimer;
@property (nonatomic, strong) ReplyMessageView *replyMessageView;
@property (nonatomic, strong) UIImagePickerController *imagePicker;
@property (nonatomic, strong) BarButtonItemWithActivity *videoCallButton;
@property (nonatomic, strong) BarButtonItemWithActivity *voiceCallButton;
@property (nonatomic, assign) BOOL isPreviewControllerShown;
@property (nonatomic, strong) NSString *previewControllerFilePath;
@property (nonatomic, strong) dispatch_group_t animationDispatchGroup;
@property (nonatomic, strong) dispatch_queue_t animationDispatchQueue;
@property (nonatomic, strong) UIView *inputbarBorderView;
@property (nonatomic, strong) UILongPressGestureRecognizer *voiceMessageLongPressGesture;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) VoiceMessageRecordingView *voiceMessageRecordingView;
@property (nonatomic, assign) CGPoint longPressStartingPoint;
@property (nonatomic, assign) CGFloat cancelHintLabelInitialPositionX;
@property (nonatomic, assign) BOOL recordCancelled;
@property (nonatomic, strong) AVAudioPlayer *voiceMessagesPlayer;
@property (nonatomic, strong) NSTimer *playerProgressTimer;
@property (nonatomic, strong) NCChatFileStatus *playerAudioFileStatus;
@property (nonatomic, strong) EmojiTextField *emojiTextField;
@property (nonatomic, strong) DatePickerTextField *datePickerTextField;
@property (nonatomic, strong) NCChatMessage *interactingMessage;
@property (nonatomic, strong) NSIndexPath *lastMessageBeforeInteraction;
@property (nonatomic, strong) NSTimer *messageExpirationTimer;
@property (nonatomic, strong) UIButton *scrollToBottomButton;
@property (nonatomic, strong) PHPickerViewController *photoPicker;
@property (nonatomic, assign) BOOL isTyping;
@property (nonatomic, strong) NSTimer *stopTypingTimer;
@property (nonatomic, strong) NSTimer *typingTimer;
@property (nonatomic, strong) UIView *contextMenuReactionView;
@property (nonatomic, strong) UIView *contextMenuMessageView;
@property (nonatomic, copy, nullable) void (^contextMenuActionBlock)(void);

@end

@implementation NCChatViewController

NSString * const NCChatViewControllerReplyPrivatelyNotification = @"NCChatViewControllerReplyPrivatelyNotification";
NSString * const NCChatViewControllerForwardNotification = @"NCChatViewControllerForwardNotification";
NSString * const NCChatViewControllerTalkToUserNotification = @"NCChatViewControllerTalkToUserNotification";

- (instancetype)initForRoom:(NCRoom *)room
{
    self = [super initWithTableViewStyle:UITableViewStylePlain];
    if (self) {
        self.room = room;
        self.chatController = [[NCChatController alloc] initForRoom:room];
        self.hidesBottomBarWhenPushed = YES;
        // Fixes problem with tableView contentSize on iOS 11
        self.tableView.estimatedRowHeight = 0;
        self.tableView.estimatedSectionHeaderHeight = 0;

        // Register a SLKTextView subclass, if you need any special appearance and/or behavior customisation.
        [self registerClassForTextView:[NCMessageTextView class]];

        // Register ReplyMessageView class, conforming to SLKVisibleViewProtocol, as a custom reply view.
        [self registerClassForReplyView:[ReplyMessageView class]];

        // Register TypingIndicatorView class, conforming to SLKVisibleViewProtocol, as a custom typing indicator view.
        [self registerClassForTypingIndicatorView:[TypingIndicatorView class]];

        // Set image downloader to file preview imageviews.
        [FilePreviewImageView setSharedImageDownloader:[[NCAPIController sharedInstance] imageDownloader]];
        // Initialize the animation dispatch group/queue
        NSString *dispatchQueueIdentifier = [NSString stringWithFormat:@"%@.%@", groupIdentifier, @"animationQueue"];
        const char *dispatchQueueIdentifierChar = [dispatchQueueIdentifier UTF8String];
        self.animationDispatchGroup = dispatch_group_create();
        self.animationDispatchQueue = dispatch_queue_create(dispatchQueueIdentifierChar, DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willShowKeyboard:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wllHideHideKeyboard:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateRoom:) name:NCRoomsManagerDidUpdateRoomNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didJoinRoom:) name:NCRoomsManagerDidJoinRoomNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLeaveRoom:) name:NCRoomsManagerDidLeaveRoomNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveInitialChatHistory:) name:NCChatControllerDidReceiveInitialChatHistoryNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveInitialChatHistoryOffline:) name:NCChatControllerDidReceiveInitialChatHistoryOfflineNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveChatHistory:) name:NCChatControllerDidReceiveChatHistoryNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveChatMessages:) name:NCChatControllerDidReceiveChatMessagesNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSendChatMessage:) name:NCChatControllerDidSendChatMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveChatBlocked:) name:NCChatControllerDidReceiveChatBlockedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewerCommonReadMessage:) name:NCChatControllerDidReceiveNewerCommonReadMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveCallStartedMessage:) name:NCChatControllerDidReceiveCallStartedMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveCallEndedMessage:) name:NCChatControllerDidReceiveCallEndedMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveUpdateMessage:) name:NCChatControllerDidReceiveUpdateMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveHistoryCleared:) name:NCChatControllerDidReceiveHistoryClearedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMessagesInBackground:) name:NCChatControllerDidReceiveMessagesInBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionStateHasChanged:) name:NCConnectionStateHasChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFailRequestingCallTransaction:) name:CallKitManagerDidFailRequestingCallTransaction object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateParticipants:) name:NCExternalSignalingControllerDidUpdateParticipantsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveStartedTyping:) name:NCExternalSignalingControllerDidReceiveStartedTypingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveStoppedTyping:) name:NCExternalSignalingControllerDidReceiveStoppedTypingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveParticipantJoin:) name:NCExternalSignalingControllerDidReceiveJoinOfParticipant object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveParticipantLeave:) name:NCExternalSignalingControllerDidReceiveLeaveOfParticipant object:nil];

        // Notifications when runing on Mac 
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:@"NSApplicationDidBecomeActiveNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:@"NSApplicationDidResignActiveNotification" object:nil];
    }
    
    return self;
}
    
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"Dealloc NCChatViewController");
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitleView];
    [self configureActionItems];
    
    // Disable room info, input bar and call buttons until joining the room
    [self disableRoomControls];
    
    self.messages = [[NSMutableDictionary alloc] init];
    self.mentionsDict = [[NSMutableDictionary alloc] init];
    self.dateSections = [[NSMutableArray alloc] init];

    self.bounces = NO;
    self.shakeToClearEnabled = YES;
    self.keyboardPanningEnabled = YES;
    self.shouldScrollToBottomAfterKeyboardShows = NO;
    self.inverted = NO;
    
    [self showSendMessageButton];
    [self.leftButton setImage:[UIImage systemImageNamed:@"paperclip"] forState:UIControlStateNormal];
    self.leftButton.accessibilityLabel = NSLocalizedString(@"Share a file from your Nextcloud", nil);
    self.leftButton.accessibilityHint = NSLocalizedString(@"Double tap to open file browser", nil);
    
    self.textInputbar.autoHideRightButton = NO;
    NSInteger chatMaxLength = [[NCSettingsController sharedInstance] chatMaxLengthConfigCapability];
    self.textInputbar.maxCharCount = chatMaxLength;
    self.textInputbar.counterStyle = SLKCounterStyleLimitExceeded;
    self.textInputbar.counterPosition = SLKCounterPositionTop;
    // Only show char counter when chat is limited to 1000 chars
    if (chatMaxLength == kDefaultChatMaxLength) {
        self.textInputbar.counterStyle = SLKCounterStyleCountdownReversed;
    }
    self.textInputbar.translucent = NO;
    self.textInputbar.contentInset = UIEdgeInsetsMake(8, 4, 8, 4);
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    self.textInputbar.backgroundColor = [UIColor whiteColor];
    [self.textInputbar setSemanticContentAttribute:UISemanticContentAttributeForceLeftToRight];
    
    // Make sure we update the textView frame
    [self.textView layoutSubviews];
    self.textView.layer.cornerRadius = self.textView.frame.size.height / 2;
    
    // Make sure we update the textView frame
    [self.textView layoutSubviews];
    self.textView.layer.cornerRadius = self.textView.frame.size.height / 2;
    
    [self.textInputbar.editorTitle setTextColor:[UIColor darkGrayColor]];
    [self.textInputbar.editorLeftButton setTintColor:[UIColor systemBlueColor]];
    [self.textInputbar.editorRightButton setTintColor:[UIColor systemBlueColor]];
    
    self.navigationController.navigationBar.tintColor = [NCAppBranding themeTextColor];
    self.navigationController.navigationBar.barTintColor = [NCAppBranding themeColor];
    self.tabBarController.tabBar.tintColor = [NCAppBranding themeColor];

    UIColor *themeColor = [NCAppBranding themeColor];
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = themeColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName:[NCAppBranding themeTextColor]};
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;

    [self.view setBackgroundColor:[UIColor systemBackgroundColor]];
    [self.textInputbar setBackgroundColor:[UIColor systemBackgroundColor]];

    [self.textInputbar.editorTitle setTextColor:[UIColor labelColor]];
    [self.textView.layer setBorderWidth:1.0];
    [self.textView.layer setBorderColor:[UIColor systemGray4Color].CGColor];
    
    // Hide default top border of UIToolbar
    [self.textInputbar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
    
    // Add new border subView to inputbar
    self.inputbarBorderView = [UIView new];
    [self.inputbarBorderView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin];
    self.inputbarBorderView.frame = CGRectMake(0, 0, self.textInputbar.frame.size.width, 1);
    self.inputbarBorderView.hidden = YES;
    self.inputbarBorderView.backgroundColor = [UIColor systemGray6Color];

    [self.textInputbar addSubview:self.inputbarBorderView];
    
    // Add emoji textfield for reactions
    _emojiTextField = [[EmojiTextField alloc] init];
    _emojiTextField.delegate = self;
    [self.view addSubview:_emojiTextField];

    // Add datePicker textfield for remind me later
    _datePickerTextField = [[DatePickerTextField alloc] init];
    _datePickerTextField.delegate = self;
    [self.view addSubview:_datePickerTextField];

    // Set delegate to retrieve typing events
    self.textView.delegate = self;

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[ChatMessageTableViewCell class] forCellReuseIdentifier:ChatMessageCellIdentifier];
    [self.tableView registerClass:[ChatMessageTableViewCell class] forCellReuseIdentifier:ReplyMessageCellIdentifier];
    [self.tableView registerClass:[GroupedChatMessageTableViewCell class] forCellReuseIdentifier:GroupedChatMessageCellIdentifier];
    [self.tableView registerClass:[FileMessageTableViewCell class] forCellReuseIdentifier:FileMessageCellIdentifier];
    [self.tableView registerClass:[FileMessageTableViewCell class] forCellReuseIdentifier:GroupedFileMessageCellIdentifier];
    [self.tableView registerClass:[LocationMessageTableViewCell class] forCellReuseIdentifier:LocationMessageCellIdentifier];
    [self.tableView registerClass:[LocationMessageTableViewCell class] forCellReuseIdentifier:GroupedLocationMessageCellIdentifier];
    [self.tableView registerClass:[SystemMessageTableViewCell class] forCellReuseIdentifier:SystemMessageCellIdentifier];
    [self.tableView registerClass:[SystemMessageTableViewCell class] forCellReuseIdentifier:InvisibleSystemMessageCellIdentifier];
    [self.tableView registerClass:[VoiceMessageTableViewCell class] forCellReuseIdentifier:VoiceMessageCellIdentifier];
    [self.tableView registerClass:[VoiceMessageTableViewCell class] forCellReuseIdentifier:GroupedVoiceMessageCellIdentifier];
    [self.tableView registerClass:[ObjectShareMessageTableViewCell class] forCellReuseIdentifier:ObjectShareMessageCellIdentifier];
    [self.tableView registerClass:[ObjectShareMessageTableViewCell class] forCellReuseIdentifier:GroupedObjectShareMessageCellIdentifier];
    [self.tableView registerClass:[MessageSeparatorTableViewCell class] forCellReuseIdentifier:MessageSeparatorCellIdentifier];
    [self.autoCompletionView registerClass:[ChatMessageTableViewCell class] forCellReuseIdentifier:AutoCompletionCellIdentifier];
    [self registerPrefixesForAutoCompletion:@[@"@"]];
    self.autoCompletionView.backgroundColor = [UIColor secondarySystemBackgroundColor];

    if (@available(iOS 15.0, *)) {
        self.autoCompletionView.sectionHeaderTopPadding = 0;
    }
    if (@available(iOS 15.0, *)) {
        self.autoCompletionView.sectionHeaderTopPadding = 0;
    }
    // Align separators to ChatMessageTableViewCell's title label
    self.autoCompletionView.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);
    
    // Chat placeholder view
    _chatBackgroundView = [[PlaceholderView alloc] init];
    [_chatBackgroundView.placeholderView setHidden:YES];
    [_chatBackgroundView.loadingView startAnimating];
    [_chatBackgroundView.placeholderTextView setText:NSLocalizedString(@"No messages yet, start the conversation!", nil)];
    [_chatBackgroundView setImage:[UIImage imageNamed:@"chat-placeholder"]];
    self.tableView.backgroundView = _chatBackgroundView;
    
    // Unread messages indicator
    _firstUnreadMessage = nil;
    _unreadMessageButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 126, 24)];
    _unreadMessageButton.backgroundColor = [NCAppBranding themeColor];
    [_unreadMessageButton setTitleColor:[NCAppBranding themeTextColor] forState:UIControlStateNormal];
    _unreadMessageButton.titleLabel.font = [UIFont systemFontOfSize:12];
    _unreadMessageButton.layer.cornerRadius = 12;
    _unreadMessageButton.clipsToBounds = YES;
    _unreadMessageButton.hidden = YES;
    _unreadMessageButton.translatesAutoresizingMaskIntoConstraints = NO;
    _unreadMessageButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f);
    _unreadMessageButton.titleLabel.minimumScaleFactor = 0.9f;
    _unreadMessageButton.titleLabel.numberOfLines = 1;
    _unreadMessageButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    
    NSString *buttonText = NSLocalizedString(@"↓ New messages", nil);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:12]};
    CGRect textSize = [buttonText boundingRectWithSize:CGSizeMake(300, 24) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:NULL];
    CGFloat buttonWidth = textSize.size.width + 20;

    [_unreadMessageButton addTarget:self action:@selector(unreadMessagesButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_unreadMessageButton setTitle:buttonText forState:UIControlStateNormal];
    
    // Unread messages separator
    _unreadMessagesSeparator = [[NCChatMessage alloc] init];
    _unreadMessagesSeparator.messageId = kUnreadMessagesSeparatorIdentifier;
    
    self.hasStoredHistory = YES;
    
    [self.view addSubview:_unreadMessageButton];
    _chatViewPresentedTimestamp = [[NSDate date] timeIntervalSince1970];
    _lastReadMessage = _room.lastReadMessage;

    __weak typeof(self) weakSelf = self;
    _scrollToBottomButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44) primaryAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf.tableView slk_scrollToBottomAnimated:YES];
    }]];

    _scrollToBottomButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [_scrollToBottomButton setTintColor:[UIColor systemBlueColor]];
    _scrollToBottomButton.layer.cornerRadius = _scrollToBottomButton.frame.size.height / 2;
    _scrollToBottomButton.clipsToBounds = YES;
    _scrollToBottomButton.alpha = 0;
    _scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollToBottomButton setImage:[UIImage systemImageNamed:@"chevron.down"] forState:UIControlStateNormal];

    [self.view addSubview:_scrollToBottomButton];
    
    // Check if there's a stored pending message
    if (_room.pendingMessage != nil) {
        [self setChatMessage:self.room.pendingMessage];
    }
    
    NSDictionary *views = @{@"unreadMessagesButton": _unreadMessageButton,
                            @"textInputbar": self.textInputbar,
                            @"scrollToBottomButton": _scrollToBottomButton,
                            @"autoCompletionView": self.autoCompletionView
    };

    NSDictionary *metrics = @{@"buttonWidth": @(buttonWidth)};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[unreadMessagesButton(24)]-5-[autoCompletionView]" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=0)-[unreadMessagesButton(buttonWidth)]-(>=0)-|" options:0 metrics:metrics views:views]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual
                                                             toItem:_unreadMessageButton attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[scrollToBottomButton(44)]-10-[autoCompletionView]" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=0)-[scrollToBottomButton(44)]-(>=0)-|" options:0 metrics:metrics views:views]];

    NSLayoutConstraint *trailingAnchor = [_scrollToBottomButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-10];
    trailingAnchor.active = YES;

    // We can't use UIColor with systemBlueColor directly, because it will switch to indigo. So make sure we actually get a blue tint here
    [self.textView setTintColor:[UIColor colorWithCGColor:[UIColor systemBlueColor].CGColor]];

    [self addMenuToLeftButton];
}

- (void)updateToolbar:(BOOL)animated
{
    void (^animations)(void) = ^void() {
        CGFloat minimumOffset = (self.tableView.contentSize.height - self.tableView.frame.size.height) - 10;
        
        if (self.tableView.contentOffset.y < minimumOffset) {
            // Scrolled -> show top border
            self.inputbarBorderView.hidden = NO;
        } else {
            // At the bottom -> no top border
            self.inputbarBorderView.hidden = YES;
        }
    };

    void (^animationsScrollButton)(void) = ^void() {
        CGFloat minimumOffset = (self.tableView.contentSize.height - self.tableView.frame.size.height) - 10;

        if (self.tableView.contentOffset.y < minimumOffset) {
            // Scrolled -> show button
            self.scrollToBottomButton.alpha = 1;
        } else {
            // At the bottom -> hide button
            self.scrollToBottomButton.alpha = 0;
        }
    };

    if (animated) {
        // Make sure the previous animation is finished before issuing another one
        dispatch_async(self.animationDispatchQueue, ^{
            dispatch_group_enter(self.animationDispatchGroup);
            dispatch_group_enter(self.animationDispatchGroup);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Make sure we use the superview of the border here
                [UIView transitionWithView:self.textInputbar
                                  duration:0.3
                                   options:UIViewAnimationOptionTransitionCrossDissolve
                                animations:animations
                                completion:^(BOOL finished) {
                    dispatch_group_leave(self.animationDispatchGroup);
                }];
            });

            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3
                                 animations:animationsScrollButton
                                 completion:^(BOOL finished) {
                    dispatch_group_leave(self.animationDispatchGroup);
                }];
            });
            
            dispatch_group_wait(self.animationDispatchGroup, DISPATCH_TIME_FOREVER);
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            animations();
            animationsScrollButton();
        });
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self checkLobbyState];
    [self checkRoomControlsAvailability];
    
    [self startObservingExpiredMessages];
    
    // Workaround for open conversations:
    // We can't get initial chat history until we join the conversation (since we are not a participant until then)
    // So for rooms that we don't know the last read message we wait until we join the room to get the initial chat history.
    if (!_hasReceiveInitialHistory && !_hasRequestedInitialHistory && _room.lastReadMessage > 0) {
        _hasRequestedInitialHistory = YES;
        [_chatController getInitialChatHistory];
    }
    
    _isVisible = YES;
    
    if (!_offlineMode) {
        [[NCRoomsManager sharedInstance] joinRoom:_room.token forCall:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];<
    
    [self savePendingMessage];
    [self saveLastReadMessage];
    [self stopVoiceMessagePlayer];

    [[JDStatusBarNotificationPresenter sharedPresenter] dismiss];
    
    _isVisible = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Leave chat when the view controller has been removed from its parent view.
    if (self.isMovingFromParentViewController) {
        [self leaveChat];
    }

    [_videoCallButton hideActivityIndicator];
    [_voiceCallButton hideActivityIndicator];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self setTitleView];
    }];
}

- (void)stopChat
{
    _hasStopped = YES;
    [_chatController stopChatController];
    [self cleanChat];
}

- (void)resumeChat
{
    _hasStopped = NO;
    if (!_hasReceiveInitialHistory && !_hasRequestedInitialHistory) {
        _hasRequestedInitialHistory = YES;
        [_chatController getInitialChatHistory];
    }
}

- (void)leaveChat
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_lobbyCheckTimer invalidate];
    [_messageExpirationTimer invalidate];
    [_chatController stopChatController];

    // In case we're typing when we leave the chat, make sure we notify everyone
    // The 'stopTyping' method makes sure to only send signaling messages when we were typing before
    [self stopTyping:NO];
    
    // If this chat view controller is for the same room as the one owned by the rooms manager
    // then we should not try to leave the chat. Since we will leave the chat when the
    // chat view controller owned by rooms manager moves from parent view controller.
    if ([[NCRoomsManager sharedInstance].chatViewController.room.token isEqualToString:_room.token] &&
        [NCRoomsManager sharedInstance].chatViewController != self) {
        return;
    }
    
    [[NCRoomsManager sharedInstance] leaveChatInRoom:_room.token];
    
    // Remove chat view controller pointer if this chat is owned by rooms manager
    // and the chat view is moving from parent view controller
    if ([NCRoomsManager sharedInstance].chatViewController == self) {
        [NCRoomsManager sharedInstance].chatViewController = nil;
    }
}

- (void)setChatMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.textView.text = message;
    });
}

#pragma mark - App lifecycle notifications

-(void)appDidBecomeActive:(NSNotification*)notification
{
    // Don't handle this event if the view is not loaded yet.
    // Otherwise we try to join the room and receive new messages while
    // viewDidLoad wasn't called, resulting in uninitialized dictionaries and crashes
    if (!self.isViewLoaded) {
        return;
    }

    // If we stopped the chat, we don't want to resume it here
    if (_hasStopped) {
        return;
    }

    // Check if new messages were added while the app was inactive (eg. via background-refresh)
    [self checkForNewStoredMessages];
    
    if (!_offlineMode) {
        [[NCRoomsManager sharedInstance] joinRoom:_room.token forCall:NO];
    }
    
    [self startObservingExpiredMessages];
}

-(void)appWillResignActive:(NSNotification*)notification
{
    // If we stopped the chat, we don't want to change anything here
    if (_hasStopped) {
        return;
    }

    _startReceivingMessagesAfterJoin = YES;
    [self removeUnreadMessagesSeparator];
    [self savePendingMessage];
    [_chatController stopChatController];
    [_messageExpirationTimer invalidate];
    [self stopTyping:NO];
    [[NCRoomsManager sharedInstance] leaveChatInRoom:_room.token];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        // We use a CGColor so we loose the automatic color changing of dynamic colors -> update manually
        [self.textView.layer setBorderColor:[UIColor systemGray4Color].CGColor];
        [self.textView setTintColor:[UIColor colorWithCGColor:[UIColor systemBlueColor].CGColor]];
        [self updateToolbar:YES];
    }
}

#pragma mark - Keyboard notifications

- (void)willShowKeyboard:(NSNotification *)notification
{
    UIResponder *currentResponder = [UIResponder slk_currentFirstResponder];
    // Skips if it's not the emoji text field
    if (currentResponder && ![currentResponder isKindOfClass:[EmojiTextField class]] && ![currentResponder isKindOfClass:[DatePickerTextField class]]) {
        return;
    }
    CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [self updateViewToShowOrHideEmojiKeyboard:keyboardRect.size.height];
    NSIndexPath *indexPath = [self indexPathForMessage:self->_interactingMessage];
    if (indexPath) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
            // Only scroll if cell is not completely visible
            if (!CGRectContainsRect(self.tableView.bounds, cellRect)) {
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            }
        });
    }
}

- (void)wllHideHideKeyboard:(NSNotification *)notification
{
    UIResponder *currentResponder = [UIResponder slk_currentFirstResponder];
    // Skips if it's not the emoji text field
    if (currentResponder && ![currentResponder isKindOfClass:[EmojiTextField class]] && ![currentResponder isKindOfClass:[DatePickerTextField class]]) {
        return;
    }
    
    [self updateViewToShowOrHideEmojiKeyboard:0.0];
    if (_lastMessageBeforeInteraction && [NCUtils isValidIndexPath:_lastMessageBeforeInteraction forTableView:self.tableView]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView scrollToRowAtIndexPath:self->_lastMessageBeforeInteraction atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        });
    }
}

#pragma mark - Connection Controller notifications

- (void)connectionStateHasChanged:(NSNotification *)notification
{
    ConnectionState connectionState = [[notification.userInfo objectForKey:@"connectionState"] intValue];
    switch (connectionState) {
        case kConnectionStateConnected:
            if (_offlineMode) {
                _offlineMode = NO;
                _startReceivingMessagesAfterJoin = YES;
                
                [self removeOfflineFooterView];
                [[NCRoomsManager sharedInstance] joinRoom:_room.token forCall:NO];
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - Keyboard notifications

- (void)willShowKeyboard:(NSNotification *)notification
{
    UIResponder *currentResponder = [UIResponder slk_currentFirstResponder];
    // Skips if it's not the emoji text field
    if (currentResponder && ![currentResponder isKindOfClass:[EmojiTextField class]]) {
        return;
    }

    CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [self updateViewToShowOrHideEmojiKeyboard:keyboardRect.size.height];
    NSIndexPath *indexPath = [self indexPathForMessage:_reactingMessage];
    if (indexPath) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
            // Only scroll if cell is not completely visible
            if (!CGRectContainsRect(self.tableView.bounds, cellRect)) {
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            }
        });
    }
}

- (void)wllHideHideKeyboard:(NSNotification *)notification
{
    UIResponder *currentResponder = [UIResponder slk_currentFirstResponder];
    // Skips if it's not the emoji text field
    if (currentResponder && ![currentResponder isKindOfClass:[EmojiTextField class]]) {
        return;
    }
    
    [self updateViewToShowOrHideEmojiKeyboard:0.0];
    if (_lastMessageBeforeReaction && [NCUtils isValidIndexPath:_lastMessageBeforeReaction forTableView:self.tableView]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView scrollToRowAtIndexPath:self->_lastMessageBeforeReaction atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        });
    }
}

#pragma mark - Connection Controller notifications

- (void)connectionStateHasChanged:(NSNotification *)notification
{
    ConnectionState connectionState = [[notification.userInfo objectForKey:@"connectionState"] intValue];
    switch (connectionState) {
        case kConnectionStateConnected:
            if (_offlineMode) {
                _offlineMode = NO;
                _startReceivingMessagesAfterJoin = YES;
                
                [self removeOfflineFooterView];
                [[NCRoomsManager sharedInstance] joinRoom:_room.token];
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - Configuration

- (void)setTitleView
{
    self.titleView = [[NCChatTitleView alloc] init];
    self.titleView.frame = CGRectMake(0, 0, MAXFLOAT, 30);
    self.titleView.delegate = self;
    self.titleView.titleTextView.accessibilityHint = NSLocalizedString(@"Double tap to go to conversation information", nil);

    if (self.navigationController.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
        self.titleView.showSubtitle = NO;
    }

    [self.titleView updateForRoom:_room];

    self.navigationItem.titleView = _titleView;
}

- (void)configureActionItems
{
    UIImageSymbolConfiguration *symbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:20];
    UIImage *videoCallImage = [UIImage systemImageNamed:@"video" withConfiguration:symbolConfiguration];
    UIImage *voiceCallImage = [UIImage systemImageNamed:@"phone" withConfiguration:symbolConfiguration];
    
    CGFloat buttonWidth = 24.0;
    CGFloat buttonPadding = 30.0;
    
    _videoCallButton = [[BarButtonItemWithActivity alloc] initWithWidth:buttonWidth withImage:videoCallImage];
    [_videoCallButton.innerButton addTarget:self action:@selector(videoCallButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    _videoCallButton.accessibilityLabel = NSLocalizedString(@"Video call", nil);
    _videoCallButton.accessibilityHint = NSLocalizedString(@"Double tap to start a video call", nil);
    
    
    _voiceCallButton = [[BarButtonItemWithActivity alloc] initWithWidth:buttonWidth withImage:voiceCallImage];
    [_voiceCallButton.innerButton addTarget:self action:@selector(voiceCallButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    _voiceCallButton.accessibilityLabel = NSLocalizedString(@"Voice call", nil);
    _voiceCallButton.accessibilityHint = NSLocalizedString(@"Double tap to start a voice call", nil);
    
    UIBarButtonItem *fixedSpace =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                    target:nil
                                                    action:nil];
    fixedSpace.width = buttonPadding;

    if ([[NCSettingsController sharedInstance] callsEnabledCapability]) {
        // Only register the call buttons when calling is enabled
        self.navigationItem.rightBarButtonItems = @[_videoCallButton, fixedSpace, _voiceCallButton];
    }
    
    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilitySilentCall]) {
        [self addMenuToCallButtons];
    }
}

#pragma mark - User Interface

- (void)showVoiceMessageRecordButton
{
    [self.rightButton setTitle:@"" forState:UIControlStateNormal];
    [self.rightButton setImage:[UIImage systemImageNamed:@"mic"] forState:UIControlStateNormal];
    self.rightButton.tag = k_voice_record_button_tag;
    self.rightButton.accessibilityLabel = NSLocalizedString(@"Record voice message", nil);
    self.rightButton.accessibilityHint = NSLocalizedString(@"Tap and hold to record a voice message", nil);

    [self addGestureRecognizerToRightButton];
}

- (void)showSendMessageButton
{
    [self.rightButton setTitle:@"" forState:UIControlStateNormal];
    [self.rightButton setImage:[UIImage systemImageNamed:@"paperplane"] forState:UIControlStateNormal];
    self.rightButton.tag = k_send_message_button_tag;
    self.rightButton.accessibilityLabel = NSLocalizedString(@"Send message", nil);
    self.rightButton.accessibilityHint = NSLocalizedString(@"Double tap to send message", nil);

    [self addMenuToRightButton];
}

- (void)disableRoomControls
{
    _titleView.userInteractionEnabled = NO;

    [_videoCallButton hideActivityIndicator];
    [_voiceCallButton hideActivityIndicator];
    [_videoCallButton setEnabled:NO];
    [_voiceCallButton setEnabled:NO];

    [self.leftButton setEnabled:NO];
    [self.rightButton setEnabled:NO];
}

- (void)checkRoomControlsAvailability
{
    if (_hasJoinedRoom && !_offlineMode) {
        // Enable room info and call buttons when we joined the room
        _titleView.userInteractionEnabled = YES;
        [_videoCallButton setEnabled:YES];
        [_voiceCallButton setEnabled:YES];
    }

    // Files/objects can only be send when we're not offline
    [self.leftButton setEnabled:!_offlineMode];

    // Always allow to start writing a message, even if we didn't join the room (yet)
    [self.rightButton setEnabled:[self canPressRightButton]];
    self.textInputbar.userInteractionEnabled = YES;

    if (![_room userCanStartCall] && !_room.hasCall) {
        // Disable call buttons
        [_videoCallButton setEnabled:NO];
        [_voiceCallButton setEnabled:NO];
    }
    
    if (_room.readOnlyState == NCRoomReadOnlyStateReadOnly || [self shouldPresentLobbyView]) {
        // Hide text input
        [self setTextInputbarHidden:YES animated:_isVisible];

        // Disable call buttons
        [_videoCallButton setEnabled:NO];
        [_voiceCallButton setEnabled:NO];
    } else if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityChatPermission] && (_room.permissions & NCPermissionChat) == 0) {
        // Hide text input
        [self setTextInputbarHidden:YES animated:_isVisible];
    } else if ([self isTextInputbarHidden]) {
        // Show text input if it was hidden in a previous state
        BOOL isAtBottom = [self.tableView slk_isAtBottom];
        [self setTextInputbarHidden:NO animated:_isVisible];

        if (isAtBottom) {
            [self.tableView slk_scrollToBottomAnimated:YES];
        }

        // Make sure the textinput has the correct height
        [self setChatMessage:self.textInputbar.textView.text];
    }
    
    if (_presentedInCall) {
        // Create a close button and remove the call buttons
        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeWhileInCall)];
        self.navigationItem.rightBarButtonItems = @[barButtonItem];
    }
}

- (void)closeWhileInCall
{
    if ([NCRoomsManager sharedInstance].callViewController) {
        [[NCRoomsManager sharedInstance].callViewController toggleChatView];
    }
}

- (void)checkLobbyState
{
    if ([self shouldPresentLobbyView]) {
        _hasPresentedLobby = YES;
        NSString *placeHolderText = NSLocalizedString(@"You are currently waiting in the lobby", nil);
        // Lobby timer
        if (_room.lobbyTimer > 0) {
            NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:_room.lobbyTimer];
            NSString *meetingStart = [NCUtils readableDateTimeFromDate:date];
            placeHolderText = [placeHolderText stringByAppendingString:[NSString stringWithFormat:@"\n\n%@\n%@", NSLocalizedString(@"This meeting is scheduled for", @"The meeting start time will be displayed after this text e.g (This meeting is scheduled for tomorrow at 10:00)"), meetingStart]];
        }
        // Room description
        if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityRoomDescription] && _room.roomDescription && ![_room.roomDescription isEqualToString:@""]) {
            placeHolderText = [placeHolderText stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", _room.roomDescription]];
        }
        // Only set it when text changes to avoid flickering in links
        if (![_chatBackgroundView.placeholderTextView.text isEqualToString:placeHolderText]) {
            [_chatBackgroundView.placeholderTextView setText:placeHolderText];
        }
        [_chatBackgroundView setImage:[UIImage imageNamed:@"lobby-placeholder"]];
        [_chatBackgroundView.placeholderView setHidden:NO];
        [_chatBackgroundView.loadingView stopAnimating];
        [_chatBackgroundView.loadingView setHidden:YES];
        // Clear current chat since chat history will be retrieve when lobby is disabled
        [self cleanChat];
    } else {
        [_chatBackgroundView.placeholderTextView setText:NSLocalizedString(@"No messages yet, start the conversation!", nil)];
        [_chatBackgroundView setImage:[UIImage imageNamed:@"chat-placeholder"]];
        [_chatBackgroundView.placeholderView setHidden:YES];
        [_chatBackgroundView.loadingView startAnimating];
        [_chatBackgroundView.loadingView setHidden:NO];
        // Stop checking lobby flag
        [_lobbyCheckTimer invalidate];
        // Retrieve initial chat history if lobby was enabled and we didn't retrieve it before
        if (!_hasReceiveInitialHistory && !_hasRequestedInitialHistory && _hasPresentedLobby) {
            _hasRequestedInitialHistory = YES;
            [_chatController getInitialChatHistory];
        }
        _hasPresentedLobby = NO;
    }
}

- (void)setOfflineFooterView
{
    BOOL isAtBottom = [self shouldScrollOnNewMessages];
    
    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 350, 24)];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.textColor = [UIColor secondaryLabelColor];
    footerLabel.font = [UIFont systemFontOfSize:12.0];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.text = NSLocalizedString(@"Offline, only showing downloaded messages", nil);
    self.tableView.tableFooterView = footerLabel;
    self.tableView.tableFooterView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    
    if (isAtBottom) {
        [self.tableView slk_scrollToBottomAnimated:YES];
    }
    
    if (isAtBottom) {
        [self.tableView slk_scrollToBottomAnimated:YES];
    }
}

- (void)removeOfflineFooterView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.tableView.tableFooterView) {
            [self.tableView.tableFooterView removeFromSuperview];
            self.tableView.tableFooterView = nil;
            
            // Scrolling after removing the tableFooterView won't scroll all the way to the bottom
            // therefore just keep the current position
            //[self.tableView slk_scrollToBottomAnimated:YES];
        }
    });
}

- (void)removeOfflineFooterView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.tableView.tableFooterView) {
            [self.tableView.tableFooterView removeFromSuperview];
            self.tableView.tableFooterView = nil;
            
            // Scrolling after removing the tableFooterView won't scroll all the way to the bottom
            // therefore just keep the current position
            //[self.tableView slk_scrollToBottomAnimated:YES];
        }
    });
}

#pragma mark - Utils

- (NSInteger)getLastReadMessage
{
    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityChatReadMarker]) {
        return _lastReadMessage;
    }
    return 0;
}

-(NCChatMessage *)getLastNonUpdateMessage
{
    for (NSInteger sectionIndex = (self->_dateSections.count - 1); sectionIndex >= 0; sectionIndex--) {
        NSDate *dateSection = [self->_dateSections objectAtIndex:sectionIndex];
        NSMutableArray *messagesInSection = [self->_messages objectForKey:dateSection];

        for (NSInteger messageIndex = (messagesInSection.count - 1); messageIndex >= 0; messageIndex--) {
            NCChatMessage *chatMessage = [messagesInSection objectAtIndex:messageIndex];

            if (chatMessage && ![chatMessage isUpdateMessage]) {
                return chatMessage;
            }
        }
    }

    return nil;
}

- (NCChatMessage *)getLastRealMessage
{
    for (NSInteger sectionIndex = (self->_dateSections.count - 1); sectionIndex >= 0; sectionIndex--) {
        NSDate *dateSection = [self->_dateSections objectAtIndex:sectionIndex];
        NSMutableArray *messagesInSection = [self->_messages objectForKey:dateSection];

        for (NSInteger messageIndex = (messagesInSection.count - 1); messageIndex >= 0; messageIndex--) {
            NCChatMessage *chatMessage = [messagesInSection objectAtIndex:messageIndex];

            // Ignore temporary messages
            if (chatMessage && chatMessage.messageId > 0) {
                return chatMessage;
            }
        }
    }

    return nil;
}

- (NCChatMessage *)getFirstRealMessage
{
    for (int section = 0; section < [_dateSections count]; section++) {
        NSDate *dateSection = [_dateSections objectAtIndex:section];
        NSMutableArray *messagesInSection = [_messages objectForKey:dateSection];
        
        for (int message = 0; message < [messagesInSection count]; message++) {
            NCChatMessage *chatMessage = [messagesInSection objectAtIndex:message];
            
            // Ignore temporary messages
            if (chatMessage && chatMessage.messageId > 0) {
                return chatMessage;
            }
        }
    }
    
    return nil;
}

- (NSString *)getHeaderStringFromDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.doesRelativeDateFormatting = YES;
    return [formatter stringFromDate:date];
}

- (void)presentJoinError:(NSString *)alertMessage
{
    NSString *alertTitle = NSLocalizedString(@"Could not join conversation", nil);

    [[JDStatusBarNotificationPresenter sharedPresenter] presentWithTitle:alertTitle subtitle:alertMessage includedStyle:JDStatusBarNotificationIncludedStyleWarning completion:nil];
    [[JDStatusBarNotificationPresenter sharedPresenter] dismissAfterDelay:8.0];
}

#pragma mark - Temporary messages

- (NCChatMessage *)createTemporaryMessage:(NSString *)message replyToMessage:(NCChatMessage *)parentMessage withMessageParameters:(NSString *)messageParameters silently:(BOOL)silently
{
    NCChatMessage *temporaryMessage = [[NCChatMessage alloc] init];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    temporaryMessage.accountId = activeAccount.accountId;
    temporaryMessage.actorDisplayName = activeAccount.userDisplayName;
    temporaryMessage.actorId = activeAccount.userId;
    temporaryMessage.timestamp = [[NSDate date] timeIntervalSince1970];
    temporaryMessage.token = _room.token;
    temporaryMessage.message = [self replaceMentionsDisplayNamesWithMentionsKeysInMessage:message usingMessageParameters:messageParameters];
    NSString * referenceId = [NSString stringWithFormat:@"temp-%f",[[NSDate date] timeIntervalSince1970] * 1000];
    temporaryMessage.referenceId = [NCUtils sha1FromString:referenceId];
    temporaryMessage.internalId = referenceId;
    temporaryMessage.isTemporary = YES;
    temporaryMessage.parentId = parentMessage.internalId;
    temporaryMessage.messageParametersJSONString = messageParameters;
    temporaryMessage.isSilent = silently;

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [realm addObject:temporaryMessage];
    }];
    NCChatMessage *unmanagedTemporaryMessage = [[NCChatMessage alloc] initWithValue:temporaryMessage];
    return unmanagedTemporaryMessage;
}

// TODO: Move to NCChatMessage?
- (NSString *)replaceMentionsDisplayNamesWithMentionsKeysInMessage:(NSString *)message usingMessageParameters:(NSString *)messageParameters
{
    NSString *resultMessage = [[message copy] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *messageParametersDict = [NCMessageParameter messageParametersDictFromJSONString:messageParameters];
    for (NSString *parameterKey in messageParametersDict.allKeys) {
        NCMessageParameter *parameter = [messageParametersDict objectForKey:parameterKey];
        NSString *parameterKeyString = [[NSString alloc] initWithFormat:@"{%@}", parameterKey];
        resultMessage = [resultMessage stringByReplacingOccurrencesOfString:parameter.mentionDisplayName withString:parameterKeyString];
    }
    return resultMessage;
}

- (NSString *)replaceMessageMentionsKeysWithMentionsDisplayNames:(NSString *)message usingMessageParameters:(NSString *)messageParameters
 {
     NSString *resultMessage = [[message copy] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
     NSDictionary *messageParametersDict = [NCMessageParameter messageParametersDictFromJSONString:messageParameters];
     for (NSString *parameterKey in messageParametersDict.allKeys) {
         NCMessageParameter *parameter = [messageParametersDict objectForKey:parameterKey];
         NSString *parameterKeyString = [[NSString alloc] initWithFormat:@"{%@}", parameterKey];
         resultMessage = [resultMessage stringByReplacingOccurrencesOfString:parameterKeyString withString:parameter.mentionDisplayName];
     }
     return resultMessage;
 }

- (void)appendTemporaryMessage:(NCChatMessage *)temporaryMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger lastSectionBeforeUpdate = self->_dateSections.count - 1;
        NSMutableArray *messages = [[NSMutableArray alloc] initWithObjects:temporaryMessage, nil];
        [self appendMessages:messages inDictionary:self->_messages];
        
        NSMutableArray *messagesForLastDate = [self->_messages objectForKey:[self->_dateSections lastObject]];
        NSIndexPath *lastMessageIndexPath = [NSIndexPath indexPathForRow:messagesForLastDate.count - 1 inSection:self->_dateSections.count - 1];
        
        [self.tableView beginUpdates];
        NSInteger newLastSection = self->_dateSections.count - 1;
        BOOL newSection = lastSectionBeforeUpdate != newLastSection;
        if (newSection) {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:newLastSection] withRowAnimation:UITableViewRowAnimationNone];
        } else {
            [self.tableView insertRowsAtIndexPaths:@[lastMessageIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
        [self.tableView endUpdates];
        
        [self.tableView scrollToRowAtIndexPath:lastMessageIndexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
    });
}

- (void)removePermanentlyTemporaryMessage:(NCChatMessage *)temporaryMessage
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        NCChatMessage *managedTemporaryMessage = [NCChatMessage objectsWhere:@"referenceId = %@ AND isTemporary = true", temporaryMessage.referenceId].firstObject;
        if (managedTemporaryMessage) {
            [realm deleteObject:managedTemporaryMessage];
        }
    }];
    [self removeTemporaryMessages:@[temporaryMessage]];
}

- (void)removeTemporaryMessages:(NSArray *)messages
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NCChatMessage *message in messages) {
            NSIndexPath *indexPath = [self indexPathForMessage:message];
            if (indexPath) {
                [self removeMessageAtIndexPath:indexPath];
            }
        }
    });
}

- (void)modifyMessageWithReferenceId:(NSString *)referenceId withBlock:(void(^)(NCChatMessage *message))block
{
    NSMutableArray *reloadIndexPaths = [NSMutableArray new];
    NSIndexPath *indexPath = [self indexPathForMessageWithReferenceId:referenceId];
    if (indexPath) {
        [reloadIndexPaths addObject:indexPath];

        // Modify the found temporary message
        NSDate *keyDate = [_dateSections objectAtIndex:indexPath.section];
        NSMutableArray *messages = [_messages objectForKey:keyDate];
        NCChatMessage *message = [messages objectAtIndex:indexPath.row];
        block(message);
    }

    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

#pragma mark - Message expiration

- (void)startObservingExpiredMessages
{
    [_messageExpirationTimer invalidate];
    [self removeExpiredMessages];
    _messageExpirationTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(removeExpiredMessages) userInfo:nil repeats:YES];
}

- (void)removeExpiredMessages
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger currentTimestamp = [[NSDate date] timeIntervalSince1970];
        for (NSInteger i = 0; i < self->_dateSections.count; i++) {
            NSDate *keyDate = [self->_dateSections objectAtIndex:i];
            NSMutableArray *messages = [self->_messages objectForKey:keyDate];
            NSMutableArray *deleteMessages = [NSMutableArray new];
            for (NSInteger j = 0; j < messages.count; j++) {
                NCChatMessage *currentMessage = messages[j];
                NSInteger messageExpirationTime = currentMessage.expirationTimestamp;
                if (messageExpirationTime > 0 && messageExpirationTime <= currentTimestamp) {
                    [deleteMessages addObject:currentMessage];
                }
            }
            if (deleteMessages.count > 0) {
                [self.tableView beginUpdates];
                [messages removeObjectsInArray:deleteMessages];
                if (messages.count > 0) {
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationTop];
                } else {
                    [self->_messages removeObjectForKey:keyDate];
                    [self sortDateSections];
                    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationTop];
                }
                [self.tableView endUpdates];
            }
        }
        [self->_chatController removeExpiredMessages];
    });
}

#pragma mark - Message updates

- (void)updateMessageWithMessageId:(NSInteger)messageId withMessage:(NCChatMessage *)updatedMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isAtBottom = [self shouldScrollOnNewMessages];
        
        NSMutableArray *reloadIndexPaths = [NSMutableArray new];
        NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:messageId];
        if (indexPath) {
            [reloadIndexPaths addObject:indexPath];
            NSDate *keyDate = [self->_dateSections objectAtIndex:indexPath.section];
            NSMutableArray *messages = [self->_messages objectForKey:keyDate];
            NCChatMessage *currentMessage = messages[indexPath.row];
            updatedMessage.isGroupMessage = currentMessage.isGroupMessage && ![currentMessage.actorType isEqualToString:@"bots"];
            messages[indexPath.row] = updatedMessage;
        }
        
        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Make sure we're really at the bottom after updating a message
            if (isAtBottom) {
                [self.tableView slk_scrollToBottomAnimated:NO];
                [self updateToolbar:NO];
            }
        });
    });
}

#pragma mark - Action Methods

- (void)unreadMessagesButtonPressed:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_firstUnreadMessage) {
            [self.tableView scrollToRowAtIndexPath:[self indexPathForMessage:self->_firstUnreadMessage] atScrollPosition:UITableViewScrollPositionNone animated:YES];
        }
    });
}

- (void)videoCallButtonPressed:(id)sender
{
    [_videoCallButton showActivityIndicator];
    [[CallKitManager sharedInstance] startCall:_room.token withVideoEnabled:YES andDisplayName:_room.displayName silently:NO withAccountId:_room.accountId];
}

- (void)voiceCallButtonPressed:(id)sender
{
    [_voiceCallButton showActivityIndicator];
    [[CallKitManager sharedInstance] startCall:_room.token withVideoEnabled:NO andDisplayName:_room.displayName silently:NO withAccountId:_room.accountId];
}

- (void)sendChatMessage:(NSString *)message withParentMessage:(NCChatMessage *)parentMessage messageParameters:(NSString *)messageParameters silently:(BOOL)silently
{
    // Create temporary message
    NCChatMessage *temporaryMessage = [self createTemporaryMessage:message replyToMessage:parentMessage withMessageParameters:messageParameters silently:silently];

    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityChatReferenceId]) {
        [self appendTemporaryMessage:temporaryMessage];
    }

    // Send message
    [_chatController sendChatMessage:temporaryMessage];
}

- (void)sendCurrentMessageSilently:(BOOL)silently
{
    NCChatMessage *replyToMessage = _replyMessageView.isVisible ? _replyMessageView.message : nil;
    NSString *messageParameters = [NCMessageParameter messageParametersJSONStringFromDictionary:_mentionsDict];
    [self sendChatMessage:self.textView.text withParentMessage:replyToMessage messageParameters:messageParameters silently:silently];
    
    [_mentionsDict removeAllObjects];
    [_replyMessageView dismiss];
    [super didPressRightButton:self];
    [self clearPendingMessage];
    [self stopTyping:YES];
}

- (BOOL)canPressRightButton
{
    BOOL canPress = [super canPressRightButton];

    // If in offline mode, we don't want to show the voice button
    if (!_offlineMode && !canPress && !_presentedInCall && [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityVoiceMessage]) {
        [self showVoiceMessageRecordButton];
        return YES;
    }
    
    [self showSendMessageButton];
    
    return canPress;
}

- (BOOL)canPressRightButton
{
    BOOL canPress = [super canPressRightButton];
    
    if (!canPress && !_presentedInCall && [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityVoiceMessage]) {
        [self showVoiceMessageRecordButton];
        return YES;
    }
    
    [self showSendMessageButton];
    
    return canPress;
}

- (void)didPressRightButton:(id)sender
{
    UIButton *button = sender;
    if (button.tag == k_send_message_button_tag) {
        [self sendCurrentMessageSilently:NO];
        [super didPressRightButton:sender];
    } else if (button.tag == k_voice_record_button_tag) {
        [self showVoiceMessageRecordHint];
    }
}

- (void)addGestureRecognizerToRightButton
{
    // Remove a potential menu so it does not interfere with the long gesture recognizer
    [self.rightButton setMenu:nil];

    // Add long press gesture recognizer for voice message recording button
    self.voiceMessageLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressInVoiceMessageRecordButton:)];
    self.voiceMessageLongPressGesture.delegate = self;
    [self.rightButton addGestureRecognizer:self.voiceMessageLongPressGesture];
}

- (void)addMenuToRightButton
{
    // Remove a gesture recognizer to not interfere with our menu
    if (self.voiceMessageLongPressGesture) {
        [self.rightButton removeGestureRecognizer:self.voiceMessageLongPressGesture];
        self.voiceMessageLongPressGesture = nil;
    }

    __weak typeof(self) weakSelf = self;
    UIAction *silentSendAction = [UIAction actionWithTitle:NSLocalizedString(@"Send without notification", nil)
                                                 image:[UIImage systemImageNamed:@"bell.slash"]
                                            identifier:nil
                                               handler:^(UIAction *action) {
        [weakSelf sendCurrentMessageSilently:YES];
    }];

    self.rightButton.menu = [UIMenu menuWithTitle:@"" children:@[silentSendAction]];
}

- (void)addMenuToCallButtons
{
    __weak typeof(self) weakSelf = self;

    UIAction *voiceCallAction = [UIAction actionWithTitle:NSLocalizedString(@"Call without notification", nil)
                                                    image:[UIImage systemImageNamed:@"bell.slash"]
                                               identifier:nil
                                                  handler:^(UIAction *action) {
        __strong typeof(self) strongSelf = weakSelf;

        [weakSelf.voiceCallButton showActivityIndicator];
        [[CallKitManager sharedInstance] startCall:strongSelf->_room.token withVideoEnabled:NO andDisplayName:strongSelf->_room.displayName
                                          silently:YES withAccountId:strongSelf->_room.accountId];
    }];

    UIAction *videoCallAction = [UIAction actionWithTitle:NSLocalizedString(@"Call without notification", nil)
                                                     image:[UIImage systemImageNamed:@"bell.slash"]
                                                identifier:nil
                                                   handler:^(UIAction *action) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [weakSelf.videoCallButton showActivityIndicator];
        [[CallKitManager sharedInstance] startCall:strongSelf->_room.token withVideoEnabled:YES andDisplayName:strongSelf->_room.displayName
                                          silently:YES withAccountId:strongSelf->_room.accountId];
    }];

    self.voiceCallButton.innerButton.menu = [UIMenu menuWithTitle:@"" children:@[voiceCallAction]];
    self.videoCallButton.innerButton.menu = [UIMenu menuWithTitle:@"" children:@[videoCallAction]];
}

- (void)addMenuToLeftButton
{
    // The keyboard will be hidden when an action is invoked. Depending on what
    // attachment is shared, not resigning might lead to a currupted chat view
    NSMutableArray *items = [[NSMutableArray alloc] init];
    __weak typeof(self) weakSelf = self;

    UIAction *cameraAction = [UIAction actionWithTitle:NSLocalizedString(@"Camera", nil)
                                                 image:[UIImage systemImageNamed:@"camera"]
                                            identifier:nil
                                               handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf checkAndPresentCamera];
    }];

    UIAction *photoLibraryAction = [UIAction actionWithTitle:NSLocalizedString(@"Photo Library", nil)
                                                       image:[UIImage systemImageNamed:@"photo"]
                                                  identifier:nil
                                                     handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentPhotoLibrary];
    }];

    UIAction *shareLocationAction = [UIAction actionWithTitle:NSLocalizedString(@"Location", nil)
                                                        image:[UIImage systemImageNamed:@"location"]
                                                   identifier:nil
                                                      handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentShareLocation];
    }];

    UIAction *contactShareAction = [UIAction actionWithTitle:NSLocalizedString(@"Contacts", nil)
                                                       image:[UIImage systemImageNamed:@"person"]
                                                  identifier:nil
                                                     handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentShareContact];
    }];

    UIAction *filesAction = [UIAction actionWithTitle:NSLocalizedString(@"Files", nil)
                                                image:[UIImage systemImageNamed:@"doc"]
                                           identifier:nil
                                              handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentDocumentPicker];
    }];

    UIAction *ncFilesAction = [UIAction actionWithTitle:filesAppName
                                                image:[[UIImage imageNamed:@"logo-action"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                           identifier:nil
                                              handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentNextcloudFilesBrowser];
    }];

    UIAction *pollAction = [UIAction actionWithTitle:NSLocalizedString(@"Poll", nil)
                                               image:[UIImage systemImageNamed:@"chart.bar"]
                                          identifier:nil
                                             handler:^(UIAction *action) {
        [weakSelf.textView resignFirstResponder];
        [weakSelf presentPollCreation];
    }];

    // Add actions (inverted)
    [items addObject:ncFilesAction];
    [items addObject:filesAction];
    [items addObject:contactShareAction];

    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityLocationSharing]) {
        [items addObject:shareLocationAction];
    }

    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityTalkPolls] && _room.type != kNCRoomTypeOneToOne) {
        [items addObject:pollAction];
    }

    [items addObject:photoLibraryAction];

    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        [items addObject:cameraAction];
    }

    self.leftButton.menu = [UIMenu menuWithTitle:@"" children:items];
    self.leftButton.showsMenuAsPrimaryAction = YES;
}

- (void)presentNextcloudFilesBrowser
{
    DirectoryTableViewController *directoryVC = [[DirectoryTableViewController alloc] initWithPath:@"" inRoom:_room.token];
    NCNavigationController *fileSharingNC = [[NCNavigationController alloc] initWithRootViewController:directoryVC];
    [self presentViewController:fileSharingNC animated:YES completion:nil];
}

- (void)checkAndPresentCamera
{
    // https://stackoverflow.com/a/20464727/2512312
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    
    if(authStatus == AVAuthorizationStatusAuthorized) {
        [self presentCamera];
        return;
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            if(granted){
                [self presentCamera];
            }
        }];
        return;
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Could not access camera", nil)
                                 message:NSLocalizedString(@"Camera access is not allowed. Check your settings.", nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:nil];
    
    [alert addAction:okButton];
    [[NCUserInterfaceController sharedInstance] presentAlertViewController:alert];
}

- (void)presentCamera
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_imagePicker = [[UIImagePickerController alloc] init];
        self->_imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        self->_imagePicker.cameraFlashMode = [NCUserDefaults preferredCameraFlashMode];
        self->_imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:self->_imagePicker.sourceType];
        self->_imagePicker.delegate = self;
        [self presentViewController:self->_imagePicker animated:YES completion:nil];
    });
}

- (void)presentPhotoLibrary
{
    dispatch_async(dispatch_get_main_queue(), ^{
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 5;

        PHPickerFilter *filter = [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
        config.filter = filter;

        self->_photoPicker = [[PHPickerViewController alloc] initWithConfiguration:config];
        self->_photoPicker .delegate = self;
        [self presentViewController:self->_photoPicker animated:YES completion:nil];
    });
}

- (void)presentPollCreation
{
    PollCreationViewController *pollCreationVC = [[PollCreationViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    pollCreationVC.pollCreationDelegate = self;
    NCNavigationController *pollCreationNC = [[NCNavigationController alloc] initWithRootViewController:pollCreationVC];
    [self presentViewController:pollCreationNC animated:YES completion:nil];
}

- (void)presentShareLocation
{
    ShareLocationViewController *shareLocationVC = [[ShareLocationViewController alloc] init];
    shareLocationVC.delegate = self;
    NCNavigationController *shareLocationNC = [[NCNavigationController alloc] initWithRootViewController:shareLocationVC];
    [self presentViewController:shareLocationNC animated:YES completion:nil];
}

- (void)presentShareContact
{
    CNContactPickerViewController *contactPicker = [[CNContactPickerViewController alloc] init];
    contactPicker.delegate = self;
    [self presentViewController:contactPicker animated:YES completion:nil];
}

- (void)presentDocumentPicker
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
        documentPicker.delegate = self;
        [self presentViewController:documentPicker animated:YES completion:nil];
    });
}

- (void)didPressReply:(NCChatMessage *)message {
    // Make sure we get a smooth animation after dismissing the context menu
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL isAtBottom = [self shouldScrollOnNewMessages];
        
        TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
        self.replyMessageView = (ReplyMessageView *)self.replyProxyView;
        [self.replyMessageView presentReplyViewWithMessage:message withUserId:activeAccount.userId];
        [self presentKeyboard:YES];

        // Make sure we're really at the bottom after showing the replyMessageView
        if (isAtBottom) {
            [self.tableView slk_scrollToBottomAnimated:NO];
            [self updateToolbar:NO];
        }
    });
}

- (void)didPressReplyPrivately:(NCChatMessage *)message {
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:message.actorId forKey:@"actorId"];
    [[NSNotificationCenter defaultCenter] postNotificationName:NCChatViewControllerReplyPrivatelyNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)didPressAddReaction:(NCChatMessage *)message atIndexPath:(NSIndexPath *)indexPath {
    // Hide the keyboard because we are going to present the emoji keyboard
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView resignFirstResponder];
    });

    // Present emoji keyboard
    dispatch_async(dispatch_get_main_queue(), ^{
        self.interactingMessage = message;
        self.lastMessageBeforeInteraction = [[self.tableView indexPathsForVisibleRows] lastObject];

        if ([NCUtils isiOSAppOnMac]) {
            // Move the emojiTextField to the position of the cell
            CGRect rowRect = [self.tableView rectForRowAtIndexPath:indexPath];
            CGRect convertedRowRect = [self.tableView convertRect:rowRect toView:self.view];

            // Show the emoji picker at the textView location of the cell
            convertedRowRect.origin.y += convertedRowRect.size.height - 16;
            convertedRowRect.origin.x += 54;

            // We don't want to have a clickable textField floating around
            convertedRowRect.size.width = 0;
            convertedRowRect.size.height = 0;

            // Remove and add the emojiTextField to the view, so the Mac OS emoji picker is always at the right location
            [self.emojiTextField removeFromSuperview];
            [self.emojiTextField setFrame:convertedRowRect];
            [self.view addSubview:self.emojiTextField];
        }

        [self.emojiTextField becomeFirstResponder];
    });
}

- (void)didPressForward:(NCChatMessage *)message {
    ShareViewController *shareViewController;
    
    if (message.isObjectShare) {
        shareViewController = [[ShareViewController alloc] initToForwardObjectShareMessage:message fromChatViewController:self];
    } else {
        shareViewController = [[ShareViewController alloc] initToForwardMessage:message.parsedMessage.string fromChatViewController:self];
    }
    shareViewController.delegate = self;
    NCNavigationController *forwardMessageNC = [[NCNavigationController alloc] initWithRootViewController:shareViewController];
    [self presentViewController:forwardMessageNC animated:YES completion:nil];
}

- (void)didPressResend:(NCChatMessage *)message {
    // Make sure there's no unread message separator, as the indexpath could be invalid after removing a message
    [self removeUnreadMessagesSeparator];
    
    [self removePermanentlyTemporaryMessage:message];
    NSString *originalMessage = [self replaceMessageMentionsKeysWithMentionsDisplayNames:message.message usingMessageParameters:message.messageParametersJSONString];
    [self sendChatMessage:originalMessage withParentMessage:message.parent messageParameters:message.messageParametersJSONString silently:message.isSilent];
}

- (void)didPressCopy:(NCChatMessage *)message {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = message.parsedMessage.string;
    [self.view makeToast:NSLocalizedString(@"Message copied", nil) duration:1.5 position:CSToastPositionCenter];
}

- (void)didPressTranslate:(NCChatMessage *)message {
    MessageTranslationViewController *translateMessageVC = [[MessageTranslationViewController alloc] initWithMessage:message.parsedMessage.string availableTranslations:[[NCSettingsController sharedInstance] availableTranslations]];
    NCNavigationController *translateMessageNC = [[NCNavigationController alloc] initWithRootViewController:translateMessageVC];
    [self presentViewController:translateMessageNC animated:YES completion:nil];
}

- (void) didPressTranscribeVoiceMessage:(NCChatMessage *) message {
    NCChatFileController *downloader = [[NCChatFileController alloc] init];
    downloader.delegate = self;
    downloader.messageType = kMessageTypeVoiceMessage;
    downloader.actionType = kActionTypeTranscribeVoiceMessage;
    [downloader downloadFileFromMessage:message.file];
}

- (void)didPressDelete:(NCChatMessage *)message {
    if (message.sendingFailed || message.isOfflineMessage) {
        [self removePermanentlyTemporaryMessage:message];
    } else {
        // Set deleting state
        NCChatMessage *deletingMessage = [message copy];
        deletingMessage.message = NSLocalizedString(@"Deleting message", nil);
        deletingMessage.isDeleting = YES;
        [self updateMessageWithMessageId:deletingMessage.messageId withMessage:deletingMessage];
        // Delete message
        TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
        [[NCAPIController sharedInstance] deleteChatMessageInRoom:self->_room.token withMessageId:message.messageId forAccount:activeAccount withCompletionBlock:^(NSDictionary *messageDict, NSError *error, NSInteger statusCode) {
            if (!error && messageDict) {
                if (statusCode == 202) {
                    [self.view makeToast:NSLocalizedString(@"Message deleted successfully, but Matterbridge is configured and the message might already be distributed to other services", nil) duration:5 position:CSToastPositionCenter];
                } else if (statusCode == 200) {
                    [self.view makeToast:NSLocalizedString(@"Message deleted successfully", nil) duration:3 position:CSToastPositionCenter];
                }
                NCChatMessage *deleteMessage = [NCChatMessage messageWithDictionary:[messageDict objectForKey:@"parent"] andAccountId:activeAccount.accountId];
                if (deleteMessage) {
                    [self updateMessageWithMessageId:deleteMessage.messageId withMessage:deleteMessage];
                }
            } else if (error) {
                if (statusCode == 400) {
                    [self.view makeToast:NSLocalizedString(@"Message could not be deleted because it is too old", nil) duration:5 position:CSToastPositionCenter];
                } else if (statusCode == 405) {
                    [self.view makeToast:NSLocalizedString(@"Only normal chat messages can be deleted", nil) duration:5 position:CSToastPositionCenter];
                } else {
                    [self.view makeToast:NSLocalizedString(@"An error occurred while deleting the message", nil) duration:5 position:CSToastPositionCenter];
                }
                // Set back original message on failure
                [self updateMessageWithMessageId:message.messageId withMessage:message];
            }
        }];
    }
}

- (void)didPressOpenInNextcloud:(NCChatMessage *)message {
    if (message.file) {
        [NCUtils openFileInNextcloudAppOrBrowser:message.file.path withFileLink:message.file.link];
    }
}

- (void)highlightMessageAtIndexPath:(NSIndexPath *)indexPath withScrollPosition:(UITableViewScrollPosition)scrollPosition
{
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:scrollPosition];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    });
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _emojiTextField && _interactingMessage) {
        _interactingMessage = nil;
        [textField resignFirstResponder];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _emojiTextField && string.isSingleEmoji && _interactingMessage) {
        [self addReaction:string toChatMessage:_interactingMessage];
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == _emojiTextField && _interactingMessage) {
        _interactingMessage = nil;
    }
}


#pragma mark UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [self startTyping];
}

#pragma mark TypingIndicator support

- (void)sendStartedTypingMessageToSessionId:(NSString *)sessionId
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];

    if (serverCapabilities.typingPrivacy) {
        return;
    }

    NCExternalSignalingController *signalingController = [[NCSettingsController sharedInstance] externalSignalingControllerForAccountId:_room.accountId];

    if (signalingController) {
        NSString *mySessionId = [signalingController sessionId];
        NCStartedTypingMessage *message = [[NCStartedTypingMessage alloc] initWithFrom:mySessionId
                                                                                sendTo:sessionId
                                                                           withPayload:@{}
                                                                           forRoomType:@""];

        [signalingController sendCallMessage:message];

    }
}

- (void)sendStartedTypingMessageToAll
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];

    if (serverCapabilities.typingPrivacy) {
        return;
    }

    NCExternalSignalingController *signalingController = [[NCSettingsController sharedInstance] externalSignalingControllerForAccountId:_room.accountId];

    if (signalingController) {
        NSString *mySessionId = [signalingController sessionId];
        NSMutableDictionary *participantMap = [signalingController getParticipantMap];

        for(id sessionId in participantMap) {
            NCStartedTypingMessage *message = [[NCStartedTypingMessage alloc] initWithFrom:mySessionId
                                                                                    sendTo:sessionId
                                                                               withPayload:@{}
                                                                               forRoomType:@""];

            [signalingController sendCallMessage:message];
        }
    }
}

- (void)sendStoppedTypingMessageToAll
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];

    if (serverCapabilities.typingPrivacy) {
        return;
    }

    NCExternalSignalingController *signalingController = [[NCSettingsController sharedInstance] externalSignalingControllerForAccountId:_room.accountId];

    if (signalingController) {
        NSString *mySessionId = [signalingController sessionId];
        NSMutableDictionary *participantMap = [signalingController getParticipantMap];

        for(id sessionId in participantMap) {
            NCStoppedTypingMessage *message = [[NCStoppedTypingMessage alloc] initWithFrom:mySessionId
                                                                                    sendTo:sessionId
                                                                               withPayload:@{}
                                                                               forRoomType:@""];

            [signalingController sendCallMessage:message];
        }
    }
}

- (void)startTyping
{
    if (!_isTyping) {
        _isTyping = YES;

        [self sendStartedTypingMessageToAll];
        [self setTypingTimer];
    }

    [self setStopTypingTimer];
}

- (void)stopTyping:(BOOL)force
{
    if (_isTyping || force) {
        _isTyping = NO;
        [self sendStoppedTypingMessageToAll];
        [self invalidateStopTypingTimer];
        [self invalidateTypingTimer];
    }
}

- (void)stopTypingDetected
{
    if (_isTyping) {
        _isTyping = NO;
        [self invalidateStopTypingTimer];
    }
}

// TypingTimer is used to continously send "startedTyping" messages, while we are typing
- (void)setTypingTimer
{
    [self invalidateTypingTimer];
    _typingTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(checkTypingTimer) userInfo:nil repeats:NO];
}

- (void)invalidateTypingTimer
{
    [_typingTimer invalidate];
    _typingTimer = nil;
}

- (void)checkTypingTimer {
    if (_isTyping) {
        // We're still typing, send signaling messsage again to all participants
        [self sendStartedTypingMessageToAll];
        [self setTypingTimer];
    } else {
        // We stopped typing, we don't send anything to the participants, we just remove our timer
        [self invalidateTypingTimer];
    }
}

// StopTypingTimer is used to detect when we stop typing (locally)
- (void)setStopTypingTimer
{
    [self invalidateStopTypingTimer];
    _stopTypingTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(stopTypingDetected) userInfo:nil repeats:NO];
}

- (void)invalidateStopTypingTimer
{
    [_stopTypingTimer invalidate];
    _stopTypingTimer = nil;
}


- (void)addTypingIndicatorWithUserIdentifier:(NSString *)userIdentifier withDisplayName:(NSString *)displayName
{
    dispatch_async(dispatch_get_main_queue(), ^{
        TypingIndicatorView *view = (TypingIndicatorView *)self.textInputbar.typingView;
        [view addTypingWithUserIdentifier:userIdentifier displayName:displayName];
    });

        // Make sure we're really at the bottom after showing the replyMessageView
        if (isAtBottom) {
            [self.tableView slk_scrollToBottomAnimated:NO];
        }
    });
}

- (void)removeTypingIndicatorWithUserIdentifier:(NSString *)userIdentifier
{
    dispatch_async(dispatch_get_main_queue(), ^{
        TypingIndicatorView *view = (TypingIndicatorView *)self.textInputbar.typingView;
        [view removeTypingWithUserIdentifier:userIdentifier];
    });

}

- (void)didPressResend:(NCChatMessage *)message {
    // Make sure there's no unread message separator, as the indexpath could be invalid after removing a message
    [self removeUnreadMessagesSeparator];
    
    [self removePermanentlyTemporaryMessage:message];
    [self sendChatMessage:message.message fromInputField:NO];
}

- (void)didPressCopy:(NCChatMessage *)message {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = message.parsedMessageForChat.string;
    [self.view makeToast:NSLocalizedString(@"Message copied", nil) duration:1.5 position:CSToastPositionCenter];
}

- (void) didPressTranscribeVoiceMessage:(NCChatMessage *) message {
    NCChatFileController *downloader = [[NCChatFileController alloc] init];
    downloader.delegate = self;
    downloader.messageType = kMessageTypeVoiceMessage;
    downloader.actionType = kActionTypeTranscribeVoiceMessage;
    [downloader downloadFileFromMessage:message.file];
}

- (void)didPressDelete:(NCChatMessage *)message {
    if (message.sendingFailed || message.isOfflineMessage) {
        [self removePermanentlyTemporaryMessage:message];
    } else {
        // Set deleting state
        NCChatMessage *deletingMessage = [message copy];
        deletingMessage.message = NSLocalizedString(@"Deleting message", nil);
        deletingMessage.isDeleting = YES;
        [self updateMessageWithMessageId:deletingMessage.messageId withMessage:deletingMessage];
        // Delete message
        TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
        [[NCAPIController sharedInstance] deleteChatMessageInRoom:self->_room.token withMessageId:message.messageId forAccount:activeAccount withCompletionBlock:^(NSDictionary *messageDict, NSError *error, NSInteger statusCode) {
            if (!error && messageDict) {
                if (statusCode == 202) {
                    [self.view makeToast:NSLocalizedString(@"Message deleted successfully, but Matterbridge is configured and the message might already be distributed to other services", nil) duration:5 position:CSToastPositionCenter];
                } else if (statusCode == 200) {
                    [self.view makeToast:NSLocalizedString(@"Message deleted successfully", nil) duration:3 position:CSToastPositionCenter];
                }
                NCChatMessage *deleteMessage = [NCChatMessage messageWithDictionary:[messageDict objectForKey:@"parent"] andAccountId:activeAccount.accountId];
                if (deleteMessage) {
                    [self updateMessageWithMessageId:deleteMessage.messageId withMessage:deleteMessage];
                }
            } else if (error) {
                if (statusCode == 400) {
                    [self.view makeToast:NSLocalizedString(@"Message could not be deleted because it is too old", nil) duration:5 position:CSToastPositionCenter];
                } else if (statusCode == 405) {
                    [self.view makeToast:NSLocalizedString(@"Only normal chat messages can be deleted", nil) duration:5 position:CSToastPositionCenter];
                } else {
                    [self.view makeToast:NSLocalizedString(@"An error occurred while deleting the message", nil) duration:5 position:CSToastPositionCenter];
                }
                // Set back original message on failure
                [self updateMessageWithMessageId:message.messageId withMessage:message];
            }
        }];
    }
}

- (void)didPressOpenInNextcloud:(NCChatMessage *)message {
    if (message.file) {
        [NCUtils openFileInNextcloudAppOrBrowser:message.file.path withFileLink:message.file.link];
    }
}

- (void)presentOptionsForMessageActor:(NCChatMessage *)message fromIndexPath:(NSIndexPath *)indexPath
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] getUserActionsForUser:message.actorId usingAccount:activeAccount withCompletionBlock:^(NSDictionary *userActions, NSError *error) {
        if (!error) {
            NSArray *actions = [userActions objectForKey:@"actions"];
            if ([actions isKindOfClass:[NSArray class]]) {
                UIAlertController *optionsActionSheet = [UIAlertController alertControllerWithTitle:message.actorDisplayName
                                                                                            message:nil
                                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
                for (NSDictionary *action in actions) {
                    NSString *appId = [action objectForKey:@"appId"];
                    NSString *title = [action objectForKey:@"title"];
                    NSString *link = [action objectForKey:@"hyperlink"];
                    
                    // Talk to user action
                    if ([appId isEqualToString:@"spreed"]) {
                        UIAlertAction *talkAction = [UIAlertAction actionWithTitle:title
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^void (UIAlertAction *action) {
                            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                            NSString *userId = [userActions objectForKey:@"userId"];
                            [userInfo setObject:userId forKey:@"actorId"];
                            [[NSNotificationCenter defaultCenter] postNotificationName:NCChatViewControllerTalkToUserNotification
                                                                                object:self
                                                                              userInfo:userInfo];
                        }];
                        [talkAction setValue:[[UIImage imageNamed:@"navigationLogo"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
                        [optionsActionSheet addAction:talkAction];
                        continue;
                    }
                    
                    // Other user actions
                    UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^void (UIAlertAction *action) {
                        NSURL *actionURL = [NSURL URLWithString:[link stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
                        [[UIApplication sharedApplication] openURL:actionURL options:@{} completionHandler:nil];
                    }];
                    
                    if ([appId isEqualToString:@"profile"]) {
                        [action setValue:[[UIImage imageNamed:@"user"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
                    } else if ([appId isEqualToString:@"email"]) {
                        [action setValue:[[UIImage imageNamed:@"mail"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
                    }
                    
                    [optionsActionSheet addAction:action];
                }
                
                [optionsActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                
                // Presentation on iPads
                optionsActionSheet.popoverPresentationController.sourceView = self.tableView;
                CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
                CGFloat avatarSize = kChatCellAvatarHeight + 10;
                CGRect avatarRect = CGRectMake(cellRect.origin.x, cellRect.origin.y, avatarSize, avatarSize);
                optionsActionSheet.popoverPresentationController.sourceRect = avatarRect;
                
                [self presentViewController:optionsActionSheet animated:YES completion:nil];
            }
        }
    }];
}

- (void)highlightMessageAtIndexPath:(NSIndexPath *)indexPath withScrollPosition:(UITableViewScrollPosition)scrollPosition
{
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:scrollPosition];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    });
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _emojiTextField && _reactingMessage) {
        _reactingMessage = nil;
        [textField resignFirstResponder];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _emojiTextField && string.isSingleEmoji && _reactingMessage) {
        [self addReaction:string toChatMessage:_reactingMessage];
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == _emojiTextField && _reactingMessage) {
        _reactingMessage = nil;
    }
}

#pragma mark - UIImagePickerController Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self saveImagePickerSettings:picker];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];
    ShareConfirmationViewController *shareConfirmationVC = [[ShareConfirmationViewController alloc] initWithRoom:_room account:activeAccount serverCapabilities:serverCapabilities];
    shareConfirmationVC.delegate = self;
    shareConfirmationVC.isModal = YES;
    NCNavigationController *navigationController = [[NCNavigationController alloc] initWithRootViewController:shareConfirmationVC];
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:@"public.image"]) {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:navigationController animated:YES completion:^{
                [shareConfirmationVC.shareItemController addItemWithImage:image];
            }];
        }];
    } else if ([mediaType isEqualToString:@"public.movie"]) {
        NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
        
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:navigationController animated:YES completion:^{
                [shareConfirmationVC.shareItemController addItemWithURL:videoURL];
            }];
        }];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self saveImagePickerSettings:picker];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveImagePickerSettings:(UIImagePickerController *)picker
{
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera &&
        picker.cameraCaptureMode == UIImagePickerControllerCameraCaptureModePhoto) {
        [NCUserDefaults setPreferredCameraFlashMode:picker.cameraFlashMode];
    }
}

#pragma mark - UIDocumentPickerViewController Delegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    [self shareDocumentsWithURLs:urls fromController:controller];
}

- (void)shareDocumentsWithURLs:(NSArray<NSURL *> *)urls fromController:(UIDocumentPickerViewController *)controller {
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];
    ShareConfirmationViewController *shareConfirmationVC = [[ShareConfirmationViewController alloc] initWithRoom:_room account:activeAccount serverCapabilities:serverCapabilities];
    shareConfirmationVC.delegate = self;
    shareConfirmationVC.isModal = YES;
    NCNavigationController *navigationController = [[NCNavigationController alloc] initWithRootViewController:shareConfirmationVC];
    
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        [self presentViewController:navigationController animated:YES completion:^{
            for (NSURL* url in urls) {
                [shareConfirmationVC.shareItemController addItemWithURL:url];
            }
        }];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    
}

#pragma mark - ShareViewController Delegate

- (void)shareViewControllerDidCancel:(ShareViewController *)viewController
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (viewController.forwardingMessage) {
            [self.view makeToast:NSLocalizedString(@"Failed to forward message", nil) duration:1.5 position:CSToastPositionCenter];
        }
    }];
}

#pragma mark - ShareConfirmationViewController Delegate

- (void)shareConfirmationViewControllerDidFailed:(ShareConfirmationViewController *)viewController
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (viewController.forwardingMessage) {
            [self.view makeToast:NSLocalizedString(@"Failed to forward message", nil) duration:1.5 position:CSToastPositionCenter];
        }
    }];
}

- (void)shareConfirmationViewControllerDidFinish:(ShareConfirmationViewController *)viewController
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (viewController.forwardingMessage) {
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setObject:viewController.room.token forKey:@"token"];
            [userInfo setObject:viewController.account.accountId forKey:@"accountId"];
            [[NSNotificationCenter defaultCenter] postNotificationName:NCChatViewControllerForwardNotification
                                                                object:self
                                                              userInfo:userInfo];
        }
    }];
}

#pragma mark - ShareLocationViewController Delegate

-(void)shareLocationViewController:(ShareLocationViewController *)viewController didSelectLocationWithLatitude:(double)latitude longitude:(double)longitude andName:(NSString *)name
{
    GeoLocationRichObject *richObject = [GeoLocationRichObject geoLocationRichObjectWithLatitude:latitude longitude:longitude name:name];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] shareRichObject:richObject.richObjectDictionary inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSError *error) {
        if (error) {
            NSLog(@"Error sharing rich object: %@", error);
        }
    }];
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CNContactPickerViewController Delegate

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact
{
    [self shareContact:contact];
}

#pragma mark - Contact sharing

- (void)shareContact:(CNContact *)contact
{
    NSError* error = nil;
    NSData* vCardData = [CNContactVCardSerialization dataWithContacts:@[contact] error:&error];
    NSString* vcString = [[NSString alloc] initWithData:vCardData encoding:NSUTF8StringEncoding];
    
    if (contact.imageData) {
        NSString* base64Image = [contact.imageData base64EncodedStringWithOptions:0];
        NSString* vcardImageString = [[@"PHOTO;TYPE=JPEG;ENCODING=BASE64:" stringByAppendingString:base64Image] stringByAppendingString:@"\n"];
        vcString = [vcString stringByReplacingOccurrencesOfString:@"END:VCARD" withString:[vcardImageString stringByAppendingString:@"END:VCARD"]];
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *folderPath = [paths objectAtIndex:0];
    NSString *filePath = [folderPath stringByAppendingPathComponent:@"contact.vcf"];
    [vcString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    NSString *contactFileName = [NSString stringWithFormat:@"%@.vcf", contact.identifier];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] uniqueNameForFileUploadWithName:contactFileName originalName:YES forAccount:activeAccount withCompletionBlock:^(NSString *fileServerURL, NSString *fileServerPath, NSInteger errorCode, NSString *errorDescription) {
        if (fileServerURL && fileServerPath) {
            [self uploadFileAtPath:url.path withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:nil];
        } else {
            NSLog(@"Could not find unique name for voice message file.");
        }
    }];
}

#pragma mark - Voice messages recording

- (void)showVoiceMessageRecordHint
{
    CGPoint toastPosition = CGPointMake(self.textInputbar.center.x, self.textInputbar.center.y - self.textInputbar.frame.size.height);
    [self.view makeToast:NSLocalizedString(@"Tap and hold to record a voice message, release the button to send it.", nil) duration:3 position:@(toastPosition)];
}

- (void)showVoiceMessageRecordingView
{
    _voiceMessageRecordingView = [[VoiceMessageRecordingView alloc] init];
    _voiceMessageRecordingView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.textInputbar addSubview:_voiceMessageRecordingView];
    [self.textInputbar bringSubviewToFront:_voiceMessageRecordingView];
    
    NSDictionary *views = @{@"voiceMessageRecordingView": _voiceMessageRecordingView};
    NSDictionary *metrics = @{@"buttonWidth": @(self.rightButton.frame.size.width)};
    [self.textInputbar addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[voiceMessageRecordingView]|" options:0 metrics:nil views:views]];
    [self.textInputbar addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[voiceMessageRecordingView(>=0)]-(buttonWidth)-|" options:0 metrics:metrics views:views]];
}

- (void)hideVoiceMessageRecordingView
{
    _voiceMessageRecordingView.hidden = YES;
}

- (void)setupAudioRecorder
{
    // Set the audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"voice-message-recording.m4a",
                               nil];
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];

    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];

    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];

    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:nil];
    _recorder.delegate = self;
    _recorder.meteringEnabled = YES;
    [_recorder prepareToRecord];
}

- (void)checkPermissionAndRecordVoiceMessage
{
    NSString *mediaType = AVMediaTypeAudio;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    
    if(authStatus == AVAuthorizationStatusAuthorized) {
        [self startRecordingVoiceMessage];
        return;
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            NSLog(@"Microphone permission granted: %@", granted ? @"YES" : @"NO");
        }];
        return;
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Could not access microphone", nil)
                                 message:NSLocalizedString(@"Microphone access is not allowed. Check your settings.", nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:nil];
    
    [alert addAction:okButton];
    [[NCUserInterfaceController sharedInstance] presentAlertViewController:alert];
}

- (void)startRecordingVoiceMessage
{
    [self setupAudioRecorder];
    [self showVoiceMessageRecordingView];
    if (!_recorder.recording) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        [_recorder record];
    }
}

- (void)stopRecordingVoiceMessage
{
    [self hideVoiceMessageRecordingView];
    if (_recorder.recording) {
        [_recorder stop];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
    }
}

- (void)shareVoiceMessage
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    // Replace chars that are not allowed on the filesystem
    NSCharacterSet *notAllowedCharSet = [NSCharacterSet characterSetWithCharactersInString:@"\\/:%"];
    NSString *roomString = [[_room.displayName componentsSeparatedByCharactersInSet: notAllowedCharSet] componentsJoinedByString: @" "];
    // Replace multiple spaces with 1
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
    roomString = [regex stringByReplacingMatchesInString:roomString options:0 range:NSMakeRange(0, [roomString length]) withTemplate:@" "];
    NSString *audioFileName = [NSString stringWithFormat:@"Talk recording from %@ (%@)", dateString, roomString];
    // Trim the file name if too long
    if ([audioFileName length] > 146) {
        audioFileName = [audioFileName substringWithRange:NSMakeRange(0, 146)];
    }
    audioFileName = [audioFileName stringByAppendingString:@".mp3"];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] uniqueNameForFileUploadWithName:audioFileName originalName:YES forAccount:activeAccount withCompletionBlock:^(NSString *fileServerURL, NSString *fileServerPath, NSInteger errorCode, NSString *errorDescription) {
        if (fileServerURL && fileServerPath) {
            NSDictionary *talkMetaData = @{@"messageType" : @"voice-message"};
            [self uploadFileAtPath:self->_recorder.url.path withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:talkMetaData];
        } else {
            NSLog(@"Could not find unique name for voice message file.");
        }
    }];
}

- (void)uploadFileAtPath:(NSString *)localPath withFileServerURL:(NSString *)fileServerURL andFileServerPath:(NSString *)fileServerPath withMetaData:(NSDictionary *)talkMetaData
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] setupNCCommunicationForAccount:activeAccount];
    [[NextcloudKit shared] uploadWithServerUrlFileName:fileServerURL fileNameLocalPath:localPath dateCreationFile:nil dateModificationFile:nil customUserAgent:nil addCustomHeaders:nil queue:dispatch_get_main_queue() taskHandler:^(NSURLSessionTask *task) {
        NSLog(@"Upload task");
    } progressHandler:^(NSProgress *progress) {
        NSLog(@"Progress:%f", progress.fractionCompleted);
    } completionHandler:^(NSString *account, NSString *ocId, NSString *etag, NSDate *date, int64_t size, NSDictionary *allHeaderFields, NKError *error) {
        NSLog(@"Upload completed with error code: %ld", (long)error.errorCode);

        if (error.errorCode == 0) {
            [[NCAPIController sharedInstance] shareFileOrFolderForAccount:activeAccount atPath:fileServerPath toRoom:self->_room.token talkMetaData:talkMetaData withCompletionBlock:^(NSError *error) {
                if (error) {
                    NSLog(@"Failed to share voice message");
                }
            }];
        } else if (error.errorCode == 404 || error.errorCode == 409) {
            [[NCAPIController sharedInstance] checkOrCreateAttachmentFolderForAccount:activeAccount withCompletionBlock:^(BOOL created, NSInteger errorCode) {
                if (created) {
                    [self uploadFileAtPath:localPath withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:talkMetaData];
                } else {
                    NSLog(@"Failed to check or create attachment folder");
                }
            }];
        } else {
            NSLog(@"Failed upload voice message");
        }
    }];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if (flag && recorder == _recorder && !_recordCancelled) {
        [self shareVoiceMessage];
    }
}

#pragma mark - Voice Messages Transcribe

- (void) transcribeVoiceMessageWithAudioFileStatus:(NCChatFileStatus *)fileStatus
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *audioFileUrl = [[NSURL alloc] initFileURLWithPath:fileStatus.fileLocalPath];
        VoiceMessageTranscribeViewController *viewController = [[VoiceMessageTranscribeViewController alloc] initWithAudiofileUrl:audioFileUrl];
        NCNavigationController *navigationController = [[NCNavigationController alloc] initWithRootViewController:viewController];

        [self presentViewController:navigationController animated:YES completion:nil];
    });
}

#pragma mark - Voice Messages Player

- (void)setupVoiceMessagePlayerWithAudioFileStatus:(NCChatFileStatus *)fileStatus
{
    NSData *data = [NSData dataWithContentsOfFile:fileStatus.fileLocalPath];
    NSError *error;
    _voiceMessagesPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    _voiceMessagesPlayer.delegate = self;
    if (!error) {
        _playerAudioFileStatus = fileStatus;
        [self playVoiceMessagePlayer];
    } else {
        NSLog(@"Error: %@", error);
    }
}

- (void)playVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self setSpeakerAudioSession];
        [self enableProximitySensor];
    }
    
    [self startVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer play];
}

- (void)pauseVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self disableProximitySensor];
    }
    
    [self stopVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer pause];
    [self checkVisibleCellAudioPlayers];
}

- (void)stopVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self disableProximitySensor];
    }
    
    [self stopVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer stop];
}

- (void)enableProximitySensor
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:)
                                                 name:UIDeviceProximityStateDidChangeNotification object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
}

- (void)disableProximitySensor
{
    if ([[UIDevice currentDevice] proximityState] == NO) {
        // Only disable monitoring if proximity sensor state is not active.
        // If not proximity sensor state is cached as active and next time we enable monitoring
        // sensorStateChange won't be trigger until proximity sensor state changes to inactive.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
        [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    }
}

- (void)setSpeakerAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

- (void)setVoiceChatAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:0 error:nil];
    [session setActive:YES error:nil];
}

- (void)sensorStateChange:(NSNotificationCenter *)notification
{
    if (_presentedInCall) {
        return;
    }
    
    if ([[UIDevice currentDevice] proximityState] == YES) {
        [self setVoiceChatAudioSession];
    } else {
        [self pauseVoiceMessagePlayer];
        [self setSpeakerAudioSession];
        [self disableProximitySensor];
    }
}

- (void)checkVisibleCellAudioPlayers
{
    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
        if (message.isVoiceMessage) {
            VoiceMessageTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (message.file && [message.file.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [message.file.path isEqualToString:_playerAudioFileStatus.filePath]) {
                [cell setPlayerProgress:_voiceMessagesPlayer.currentTime isPlaying:_voiceMessagesPlayer.isPlaying maximumValue:_voiceMessagesPlayer.duration];
                continue;
            }
            [cell resetPlayer];
        }
    }
}

- (void)startVoiceMessagePlayerTimer
{
    [self stopVoiceMessagePlayerTimer];
    _playerProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(checkVisibleCellAudioPlayers) userInfo:nil repeats:YES];
}

- (void)stopVoiceMessagePlayerTimer
{
    [_playerProgressTimer invalidate];
    _playerProgressTimer = nil;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self stopVoiceMessagePlayerTimer];
    [self checkVisibleCellAudioPlayers];
    [self disableProximitySensor];
}

#pragma mark - ShareLocationViewController Delegate

-(void)shareLocationViewController:(ShareLocationViewController *)viewController didSelectLocationWithLatitude:(double)latitude longitude:(double)longitude andName:(NSString *)name
{
    GeoLocationRichObject *richObject = [GeoLocationRichObject geoLocationRichObjectWithLatitude:latitude longitude:longitude name:name];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] shareRichObject:richObject.richObjectDictionary inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSError *error) {
        if (error) {
            NSLog(@"Error sharing rich object: %@", error);
        }
    }];
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CNContactPickerViewController Delegate

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact
{
    [self shareContact:contact];
}

#pragma mark - Contact sharing

- (void)shareContact:(CNContact *)contact
{
    NSError* error = nil;
    NSData* vCardData = [CNContactVCardSerialization dataWithContacts:@[contact] error:&error];
    NSString* vcString = [[NSString alloc] initWithData:vCardData encoding:NSUTF8StringEncoding];
    
    if (contact.imageData) {
        NSString* base64Image = [contact.imageData base64EncodedStringWithOptions:0];
        NSString* vcardImageString = [[@"PHOTO;TYPE=JPEG;ENCODING=BASE64:" stringByAppendingString:base64Image] stringByAppendingString:@"\n"];
        vcString = [vcString stringByReplacingOccurrencesOfString:@"END:VCARD" withString:[vcardImageString stringByAppendingString:@"END:VCARD"]];
    }
    
    vCardData = [vcString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *folderPath = [paths objectAtIndex:0];
    NSString *filePath = [folderPath stringByAppendingPathComponent:@"contact.vcf"];
    [vcString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    NSString *contactFileName = [NSString stringWithFormat:@"%@.vcf", contact.identifier];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] uniqueNameForFileUploadWithName:contactFileName originalName:YES forAccount:activeAccount withCompletionBlock:^(NSString *fileServerURL, NSString *fileServerPath, NSInteger errorCode, NSString *errorDescription) {
        if (fileServerURL && fileServerPath) {
            [self uploadFileAtPath:url.path withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:nil];
        } else {
            NSLog(@"Could not find unique name for voice message file.");
        }
    }];
}

#pragma mark - Voice messages recording

- (void)showVoiceMessageRecordHint
{
    CGPoint toastPosition = CGPointMake(self.textInputbar.center.x, self.textInputbar.center.y - self.textInputbar.frame.size.height);
    [self.view makeToast:NSLocalizedString(@"Tap and hold to record a voice message, release the button to send it.", nil) duration:3 position:@(toastPosition)];
}

- (void)showVoiceMessageRecordingView
{
    _voiceMessageRecordingView = [[VoiceMessageRecordingView alloc] init];
    _voiceMessageRecordingView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.textInputbar addSubview:_voiceMessageRecordingView];
    [self.textInputbar bringSubviewToFront:_voiceMessageRecordingView];
    
    NSDictionary *views = @{@"voiceMessageRecordingView": _voiceMessageRecordingView};
    NSDictionary *metrics = @{@"buttonWidth": @(self.rightButton.frame.size.width)};
    [self.textInputbar addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[voiceMessageRecordingView]|" options:0 metrics:nil views:views]];
    [self.textInputbar addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[voiceMessageRecordingView(>=0)]-(buttonWidth)-|" options:0 metrics:metrics views:views]];
}

- (void)hideVoiceMessageRecordingView
{
    _voiceMessageRecordingView.hidden = YES;
}

- (void)setupAudioRecorder
{
    // Set the audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"voice-message-recording.m4a",
                               nil];
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];

    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];

    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];

    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:nil];
    _recorder.delegate = self;
    _recorder.meteringEnabled = YES;
    [_recorder prepareToRecord];
}

- (void)checkPermissionAndRecordVoiceMessage
{
    NSString *mediaType = AVMediaTypeAudio;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    
    if(authStatus == AVAuthorizationStatusAuthorized) {
        [self startRecordingVoiceMessage];
        return;
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            NSLog(@"Microphone permission granted: %@", granted ? @"YES" : @"NO");
        }];
        return;
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Could not access microphone", nil)
                                 message:NSLocalizedString(@"Microphone access is not allowed. Check your settings.", nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:nil];
    
    [alert addAction:okButton];
    [[NCUserInterfaceController sharedInstance] presentAlertViewController:alert];
}

- (void)startRecordingVoiceMessage
{
    [self setupAudioRecorder];
    [self showVoiceMessageRecordingView];
    if (!_recorder.recording) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        [_recorder record];
    }
}

- (void)stopRecordingVoiceMessage
{
    [self hideVoiceMessageRecordingView];
    if (_recorder.recording) {
        [_recorder stop];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
    }
}

- (void)shareVoiceMessage
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    // Replace chars that are not allowed on the filesystem
    NSCharacterSet *notAllowedCharSet = [NSCharacterSet characterSetWithCharactersInString:@"\\/:%"];
    NSString *roomString = [[_room.displayName componentsSeparatedByCharactersInSet: notAllowedCharSet] componentsJoinedByString: @" "];
    // Replace multiple spaces with 1
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
    roomString = [regex stringByReplacingMatchesInString:roomString options:0 range:NSMakeRange(0, [roomString length]) withTemplate:@" "];
    NSString *audioFileName = [NSString stringWithFormat:@"Talk recording from %@ (%@)", dateString, roomString];
    // Trim the file name if too long
    if ([audioFileName length] > 146) {
        audioFileName = [audioFileName substringWithRange:NSMakeRange(0, 146)];
    }
    audioFileName = [audioFileName stringByAppendingString:@".mp3"];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] uniqueNameForFileUploadWithName:audioFileName originalName:YES forAccount:activeAccount withCompletionBlock:^(NSString *fileServerURL, NSString *fileServerPath, NSInteger errorCode, NSString *errorDescription) {
        if (fileServerURL && fileServerPath) {
            NSDictionary *talkMetaData = @{@"messageType" : @"voice-message"};
            [self uploadFileAtPath:self->_recorder.url.path withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:talkMetaData];
        } else {
            NSLog(@"Could not find unique name for voice message file.");
        }
    }];
}

- (void)uploadFileAtPath:(NSString *)localPath withFileServerURL:(NSString *)fileServerURL andFileServerPath:(NSString *)fileServerPath withMetaData:(NSDictionary *)talkMetaData
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] setupNCCommunicationForAccount:activeAccount];
    [[NCCommunication shared] uploadWithServerUrlFileName:fileServerURL fileNameLocalPath:localPath dateCreationFile:nil dateModificationFile:nil customUserAgent:nil addCustomHeaders:nil queue:dispatch_get_main_queue() taskHandler:^(NSURLSessionTask *task) {
        NSLog(@"Upload task");
    } progressHandler:^(NSProgress *progress) {
        NSLog(@"Progress:%f", progress.fractionCompleted);
    } completionHandler:^(NSString *account, NSString *ocId, NSString *etag, NSDate *date, int64_t size, NSDictionary *allHeaderFields, NKError *error) {
        NSLog(@"Upload completed with error code: %ld", (long)error.errorCode);

        if (error.errorCode == 0) {
            [[NCAPIController sharedInstance] shareFileOrFolderForAccount:activeAccount atPath:fileServerPath toRoom:self->_room.token talkMetaData:talkMetaData withCompletionBlock:^(NSError *error) {
                if (error) {
                    NSLog(@"Failed to share voice message");
                }
            }];
        } else if (error.errorCode == 404 || error.errorCode == 409) {
            [[NCAPIController sharedInstance] checkOrCreateAttachmentFolderForAccount:activeAccount withCompletionBlock:^(BOOL created, NSInteger errorCode) {
                if (created) {
                    [self uploadFileAtPath:localPath withFileServerURL:fileServerURL andFileServerPath:fileServerPath withMetaData:talkMetaData];
                } else {
                    NSLog(@"Failed to check or create attachment folder");
                }
            }];
        } else {
            NSLog(@"Failed upload voice message");
        }
    }];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if (flag && recorder == _recorder && !_recordCancelled) {
        [self shareVoiceMessage];
    }
}

#pragma mark - Voice Messages Transcribe

- (void) transcribeVoiceMessageWithAudioFileStatus:(NCChatFileStatus *)fileStatus
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *audioFileUrl = [[NSURL alloc] initFileURLWithPath:fileStatus.fileLocalPath];
        VoiceMessageTranscribeViewController *viewController = [[VoiceMessageTranscribeViewController alloc] initWithAudiofileUrl:audioFileUrl];
        NCNavigationController *navigationController = [[NCNavigationController alloc] initWithRootViewController:viewController];

        [self presentViewController:navigationController animated:YES completion:nil];
    });
}

#pragma mark - Voice Messages Player

- (void)setupVoiceMessagePlayerWithAudioFileStatus:(NCChatFileStatus *)fileStatus
{
    NSData *data = [NSData dataWithContentsOfFile:fileStatus.fileLocalPath];
    NSError *error;
    _voiceMessagesPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    _voiceMessagesPlayer.delegate = self;
    if (!error) {
        _playerAudioFileStatus = fileStatus;
        [self playVoiceMessagePlayer];
    } else {
        NSLog(@"Error: %@", error);
    }
}

- (void)playVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self setSpeakerAudioSession];
        [self enableProximitySensor];
    }
    
    [self startVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer play];
}

- (void)pauseVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self disableProximitySensor];
    }
    
    [self stopVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer pause];
    [self checkVisibleCellAudioPlayers];
}

- (void)stopVoiceMessagePlayer
{
    if (!_presentedInCall) {
        [self disableProximitySensor];
    }
    
    [self stopVoiceMessagePlayerTimer];
    [_voiceMessagesPlayer stop];
}

- (void)enableProximitySensor
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:)
                                                 name:UIDeviceProximityStateDidChangeNotification object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
}

- (void)disableProximitySensor
{
    if ([[UIDevice currentDevice] proximityState] == NO) {
        // Only disable monitoring if proximity sensor state is not active.
        // If not proximity sensor state is cached as active and next time we enable monitoring
        // sensorStateChange won't be trigger until proximity sensor state changes to inactive.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
        [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    }
}

- (void)setSpeakerAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

- (void)setVoiceChatAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:0 error:nil];
    [session setActive:YES error:nil];
}

- (void)sensorStateChange:(NSNotificationCenter *)notification
{
    if (_presentedInCall) {
        return;
    }
    
    if ([[UIDevice currentDevice] proximityState] == YES) {
        [self setVoiceChatAudioSession];
    } else {
        [self pauseVoiceMessagePlayer];
        [self setSpeakerAudioSession];
        [self disableProximitySensor];
    }
}

- (void)checkVisibleCellAudioPlayers
{
    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
        if (message.isVoiceMessage) {
            VoiceMessageTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (message.file && [message.file.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [message.file.path isEqualToString:_playerAudioFileStatus.filePath]) {
                [cell setPlayerProgress:_voiceMessagesPlayer.currentTime isPlaying:_voiceMessagesPlayer.isPlaying maximumValue:_voiceMessagesPlayer.duration];
                continue;
            }
            [cell resetPlayer];
        }
    }
}

- (void)startVoiceMessagePlayerTimer
{
    [self stopVoiceMessagePlayerTimer];
    _playerProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(checkVisibleCellAudioPlayers) userInfo:nil repeats:YES];
}

- (void)stopVoiceMessagePlayerTimer
{
    [_playerProgressTimer invalidate];
    _playerProgressTimer = nil;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self stopVoiceMessagePlayerTimer];
    [self checkVisibleCellAudioPlayers];
    [self disableProximitySensor];
}

#pragma mark - Gesture recognizer

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    BOOL shouldBegin = [super gestureRecognizerShouldBegin:gestureRecognizer];
    if (gestureRecognizer == self.voiceMessageLongPressGesture) {
        return YES;
    }
    return shouldBegin;
}

- (void)handleLongPressInVoiceMessageRecordButton:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (self.rightButton.tag != k_voice_record_button_tag) {
        return;
    }
    
    CGPoint point = [gestureRecognizer locationInView:self.view];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        NSLog(@"Start recording audio message");
        // 'Pop' feedback (strong boom)
        AudioServicesPlaySystemSound(1520);
        [self checkPermissionAndRecordVoiceMessage];
        [self shouldLockInterfaceOrientation:YES];
        _recordCancelled = NO;
        _longPressStartingPoint = point;
        _cancelHintLabelInitialPositionX = _voiceMessageRecordingView.slideToCancelHintLabel.frame.origin.x;
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        NSLog(@"Stop recording audio message");
        [self shouldLockInterfaceOrientation:NO];
        [self stopRecordingVoiceMessage];
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        CGFloat slideX = _longPressStartingPoint.x - point.x;
        // Only slide view to the left
        if (slideX > 0) {
            CGFloat maxSlideX = 100;
            CGRect labelFrame = _voiceMessageRecordingView.slideToCancelHintLabel.frame;
            labelFrame = CGRectMake(_cancelHintLabelInitialPositionX - slideX, labelFrame.origin.y, labelFrame.size.width, labelFrame.size.height);
            _voiceMessageRecordingView.slideToCancelHintLabel.frame = labelFrame;
            [_voiceMessageRecordingView.slideToCancelHintLabel setAlpha:(maxSlideX - slideX) / 100];
            // Cancel recording if slided more than maxSlideX
            if (slideX > maxSlideX && !_recordCancelled) {
                NSLog(@"Cancel recording audio message");
                // 'Cancelled' feedback (three sequential weak booms)
                AudioServicesPlaySystemSound(1521);
                _recordCancelled = YES;
                [self stopRecordingVoiceMessage];
            }
        }
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateCancelled || [gestureRecognizer state] == UIGestureRecognizerStateFailed) {
        NSLog(@"Gesture cancelled or failed -> Cancel recording audio message");
        [self shouldLockInterfaceOrientation:NO];
        _recordCancelled = YES;
        [self stopRecordingVoiceMessage];
    }
}

- (void)shouldLockInterfaceOrientation:(BOOL)lock
{
    AppDelegate *appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    appDelegate.shouldLockInterfaceOrientation = lock;
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [super scrollViewDidScroll:scrollView];
    
    if ([scrollView isEqual:self.tableView] && scrollView.contentOffset.y < 0) {
        if ([self couldRetireveHistory]) {
            NCChatMessage *firstMessage = [self getFirstRealMessage];
            if (firstMessage && [_chatController hasHistoryFromMessageId:firstMessage.messageId]) {
                _retrievingHistory = YES;
                [self showLoadingHistoryView];
                if (_offlineMode) {
                    [_chatController getHistoryBatchOfflineFromMessagesId:firstMessage.messageId];
                } else {
                    [_chatController getHistoryBatchFromMessagesId:firstMessage.messageId];
                }
            }
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [super scrollViewDidEndDecelerating:scrollView];
    
    if ([scrollView isEqual:self.tableView]) {
        if (_firstUnreadMessage) {
            [self checkUnreadMessagesVisibility];
        }
        
        [self updateToolbar:YES];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    
    if ([scrollView isEqual:self.tableView]) {
        if (!decelerate && _firstUnreadMessage) {
            [self checkUnreadMessagesVisibility];
        }
        
        [self updateToolbar:YES];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if ([scrollView isEqual:self.tableView]) {
        if (_firstUnreadMessage) {
            [self checkUnreadMessagesVisibility];
        }
        
        [self updateToolbar:YES];
    }
}

#pragma mark - UITextViewDelegate Methods

- (BOOL)textView:(SLKTextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // Do not allow to type while recording
    if (_voiceMessageLongPressGesture.state != UIGestureRecognizerStatePossible) {
        return NO;
    }
    
    if ([text isEqualToString:@""]) {
        UITextRange *selectedRange = [textView selectedTextRange];
        NSInteger cursorOffset = [textView offsetFromPosition:textView.beginningOfDocument toPosition:selectedRange.start];
        NSString *text = textView.text;
        NSString *substring = [text substringToIndex:cursorOffset];
        NSMutableString *lastPossibleMention = [[[substring componentsSeparatedByString:@"@"] lastObject] mutableCopy];
        [lastPossibleMention insertString:@"@" atIndex:0];
        for (NSString *mentionKey in _mentionsDict.allKeys) {
            NCMessageParameter *mentionParameter = [_mentionsDict objectForKey:mentionKey];
            if ([lastPossibleMention isEqualToString:mentionParameter.mentionDisplayName]) {
                // Delete mention
                NSRange range = NSMakeRange(cursorOffset - lastPossibleMention.length, lastPossibleMention.length);
                textView.text = [[self.textView text] stringByReplacingCharactersInRange:range withString:@""];
                // Only delete it from mentionsDict if there are no more mentions for that user/room
                // User could have manually added the mention without selecting it from autocompletion
                // so no mention was added to the mentionsDict
                if ([textView.text rangeOfString:lastPossibleMention].location != NSNotFound) {
                    [_mentionsDict removeObjectForKey:mentionKey];
                }
                return YES;
            }
        }
    }
    
    return [super textView:textView shouldChangeTextInRange:range replacementText:text];
}

#pragma mark - Room Manager notifications

- (void)didUpdateRoom:(NSNotification *)notification
{
    NCRoom *room = [notification.userInfo objectForKey:@"room"];
    if (!room || ![room.token isEqualToString:_room.token]) {
        return;
    }
    
    _room = room;
    [self setTitleView];
    
    if (!_hasStopped) {
        [self checkLobbyState];
        [self checkRoomControlsAvailability];
    }
}

- (void)didJoinRoom:(NSNotification *)notification
{
    NSString *token = [notification.userInfo objectForKey:@"token"];
    if (![token isEqualToString:_room.token]) {
        return;
    }
    
    NSError *error = [notification.userInfo objectForKey:@"error"];
    if (error && _isVisible) {
        _offlineMode = YES;
        [self setOfflineFooterView];
        [_chatController stopReceivingNewChatMessages];
        [self presentJoinError:[notification.userInfo objectForKey:@"errorReason"]];
        [self disableRoomControls];
        [self checkRoomControlsAvailability];
        return;
    }

    NCRoom *room = [notification.userInfo objectForKey:@"room"];
    if (room) {
        _room = room;
    }
    
    _hasJoinedRoom = YES;
    [self checkRoomControlsAvailability];
    
    if (_hasStopped) {
        return;
    }
    
    if (_startReceivingMessagesAfterJoin && _hasReceiveInitialHistory) {
        _startReceivingMessagesAfterJoin = NO;
        [_chatController startReceivingNewChatMessages];
    } else if (!_hasReceiveInitialHistory && !_hasRequestedInitialHistory) {
        _hasRequestedInitialHistory = YES;
        [_chatController getInitialChatHistory];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // After we joined a room, check if there are offline messages for this particular room which need to be send
        [[NCRoomsManager sharedInstance] resendOfflineMessagesForToken:self->_room.token withCompletionBlock:nil];
    });
}

- (void)didLeaveRoom:(NSNotification *)notification
{
    _hasJoinedRoom = NO;
    
    [self disableRoomControls];
    [self checkRoomControlsAvailability];
}

#pragma mark - CallKit Manager notifications

- (void)didFailRequestingCallTransaction:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    if (![roomToken isEqualToString:_room.token]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self configureActionItems];
    });
}

- (void)didLeaveRoom:(NSNotification *)notification
{
    [self disableRoomControls];
    [self checkRoomControlsAvailability];
}

#pragma mark - CallKit Manager notifications

- (void)didFailRequestingCallTransaction:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    if (![roomToken isEqualToString:_room.token]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self configureActionItems];
    });
}

#pragma mark - Chat Controller notifications

- (void)didReceiveInitialChatHistory:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (notification.object != self->_chatController) {
            return;
        }

        if ([self shouldPresentLobbyView]) {
            self->_hasRequestedInitialHistory = NO;
            [self startObservingRoomLobbyFlag];
            
            return;
        }
        
        NSMutableArray *messages = [notification.userInfo objectForKey:@"messages"];
        if (messages.count > 0) {
            NSIndexPath *indexPathUnreadMessageSeparator;
            NCChatMessage *lastMessage = nil;

            // Find the last message we received, which is not an update message
            for (NSInteger messageIndex = ([messages count] - 1); messageIndex >= 0; messageIndex--) {
                NCChatMessage *tempMessage = messages[messageIndex];

                if (tempMessage && ![tempMessage isUpdateMessage]) {
                    lastMessage = tempMessage;
                    break;
                }
            }

            [self appendMessages:messages inDictionary:self->_messages];
            
            if (lastMessage && lastMessage.messageId > self->_lastReadMessage) {
                // Iterate backwards to find the correct location for the unread message separator
                for (NSInteger sectionIndex = (self->_dateSections.count - 1); sectionIndex >= 0; sectionIndex--) {
                    NSDate *dateSection = [self->_dateSections objectAtIndex:sectionIndex];
                    NSMutableArray *messagesInSection = [self->_messages objectForKey:dateSection];
                    
                    for (NSInteger messageIndex = (messagesInSection.count - 1); messageIndex >= 0; messageIndex--) {
                        NCChatMessage *chatMessage = [messagesInSection objectAtIndex:messageIndex];
                        
                        if (chatMessage && chatMessage.messageId <= self->_lastReadMessage) {
                            // Insert unread message separator after the current message
                            [messagesInSection insertObject:self->_unreadMessagesSeparator atIndex:(messageIndex + 1)];
                            [self->_messages setObject:messagesInSection forKey:dateSection];
                            indexPathUnreadMessageSeparator = [NSIndexPath indexPathForRow:(messageIndex + 1) inSection:sectionIndex];
                            
                            break;
                        }
                    }
                    
                    if (indexPathUnreadMessageSeparator) {
                        break;
                    }
                }
                
                // Set last received message as last read message
                self->_lastReadMessage = lastMessage.messageId;
            }
            
            NSMutableArray *storedTemporaryMessages = [self->_chatController getTemporaryMessages];
            if (storedTemporaryMessages.count > 0) {
                [self insertMessages:storedTemporaryMessages];
                
                if (indexPathUnreadMessageSeparator) {
                    // It is possible that temporary messages are added which add new sections
                    // In this case the indexPath of the unreadMessageSeparator would be invalid and could lead to a crash
                    // Therefore we need to make sure we got the correct indexPath here
                    indexPathUnreadMessageSeparator = [self getIndexPathOfUnreadMessageSeparator];
                }
            }
            
            [self.tableView reloadData];
            
            if (indexPathUnreadMessageSeparator) {
                [self.tableView scrollToRowAtIndexPath:indexPathUnreadMessageSeparator atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            } else {
                [self.tableView slk_scrollToBottomAnimated:NO];
            }
            [self updateToolbar:NO];
        } else {
            [self->_chatBackgroundView.placeholderView setHidden:NO];
        }
        
        self->_hasReceiveInitialHistory = YES;
        
        NSError *error = [notification.userInfo objectForKey:@"error"];
        if (!error) {
            [self->_chatController startReceivingNewChatMessages];
        } else {
            self->_offlineMode = YES;
            [self->_chatController getInitialChatHistoryForOfflineMode];
        }
    });
}

- (void)didReceiveInitialChatHistoryOffline:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (notification.object != self->_chatController) {
            return;
        }
        
        NSMutableArray *messages = [notification.userInfo objectForKey:@"messages"];
        if (messages.count > 0) {
            [self appendMessages:messages inDictionary:self->_messages];
            [self setOfflineFooterView];
            [self.tableView reloadData];
            [self.tableView slk_scrollToBottomAnimated:NO];
            [self updateToolbar:NO];
        } else {
            [self->_chatBackgroundView.placeholderView setHidden:NO];
        }
        
        NSMutableArray *storedTemporaryMessages = [self->_chatController getTemporaryMessages];
        if (storedTemporaryMessages.count > 0) {
            [self insertMessages:storedTemporaryMessages];
            [self.tableView reloadData];
            [self.tableView slk_scrollToBottomAnimated:NO];
            [self updateToolbar:NO];
        }
    });
}

- (void)didReceiveChatHistory:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (notification.object != self->_chatController) {
            return;
        }
        
        NSMutableArray *messages = [notification.userInfo objectForKey:@"messages"];
        BOOL shouldAddBlockSeparator = [[notification.userInfo objectForKey:@"shouldAddBlockSeparator"] boolValue];
        if (messages.count > 0) {
            NSIndexPath *lastHistoryMessageIP = [self prependMessages:messages addingBlockSeparator:shouldAddBlockSeparator];
            [self.tableView reloadData];
            
            if ([NCUtils isValidIndexPath:lastHistoryMessageIP forTableView:self.tableView]) {
                [self.tableView scrollToRowAtIndexPath:lastHistoryMessageIP atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
        }
        
        BOOL noMoreStoredHistory = [[notification.userInfo objectForKey:@"noMoreStoredHistory"] boolValue];
        if (noMoreStoredHistory) {
            self->_hasStoredHistory = NO;
        }
        self->_retrievingHistory = NO;
        [self hideLoadingHistoryView];
    });
}

- (void)didReceiveChatMessages:(NSNotification *)notification
{
    // If we receive messages in the background, we should make sure that our update here completely run
    BGTaskHelper *bgTask = [BGTaskHelper startBackgroundTaskWithName:@"NCChatViewControllerdidReceiveChatMessages" expirationHandler:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = [notification.userInfo objectForKey:@"error"];
        if (notification.object != self->_chatController || error) {
            return;
        }

        BOOL firstNewMessagesAfterHistory = [[notification.userInfo objectForKey:@"firstNewMessagesAfterHistory"] boolValue];
        
        NSMutableArray *messages = [notification.userInfo objectForKey:@"messages"];
        if (messages.count > 0) {
            // Detect if we should scroll to new messages before we issue a reloadData
            // Otherwise longer messages will prevent scrolling
            BOOL shouldScrollOnNewMessages = [self shouldScrollOnNewMessages] ;
            
            BOOL newMessagesContainVisibleMessages = [self messagesContainVisibleMessages:messages];

            NSMutableArray *insertIndexPaths = [[NSMutableArray alloc] init];
            NSMutableIndexSet *insertSectionIndexSet = [[NSMutableIndexSet alloc] init];
            NSMutableArray *reloadIndexPaths = [[NSMutableArray alloc] init];

            // Check if unread messages separator should be added (only if it's not already shown)
            __block NSIndexPath *indexPathUnreadMessageSeparator;
            if (firstNewMessagesAfterHistory && [self getLastReadMessage] > 0 && ![self getIndexPathOfUnreadMessageSeparator] && newMessagesContainVisibleMessages) {
                NSMutableArray *messagesForLastDateBeforeUpdate = [self->_messages objectForKey:[self->_dateSections lastObject]];
                [messagesForLastDateBeforeUpdate addObject:self->_unreadMessagesSeparator];
                indexPathUnreadMessageSeparator = [NSIndexPath indexPathForRow:messagesForLastDateBeforeUpdate.count - 1 inSection: self->_dateSections.count - 1];
                [self->_messages setObject:messagesForLastDateBeforeUpdate forKey:[self->_dateSections lastObject]];
                [insertIndexPaths addObject:indexPathUnreadMessageSeparator];
            }
            
            // Sort received messages
            [self appendMessages:messages inDictionary:self->_messages];
            
            NSMutableArray *messagesForLastDate = [self->_messages objectForKey:[self->_dateSections lastObject]];
            __block NSIndexPath *lastMessageIndexPath = [NSIndexPath indexPathForRow:messagesForLastDate.count - 1 inSection:self->_dateSections.count - 1];

            for (NCChatMessage *newMessage in messages) {
                NSIndexPath *indexPath = [self indexPathForMessage:newMessage];

                if (indexPath.section >= self.tableView.numberOfSections) {
                    // New section -> insert the section
                    [insertSectionIndexSet addIndex:indexPath.section];
                }

                if (indexPath.section < self.tableView.numberOfSections && indexPath.row < [self.tableView numberOfRowsInSection:indexPath.section]) {
                    // This is a already known indexPath, so we want to reload the cell
                    [reloadIndexPaths addObject:indexPath];
                } else {
                    // New indexPath -> insert it
                    [insertIndexPaths addObject:indexPath];
                }

                if ([newMessage isUpdateMessage] && newMessage.parent != nil) {
                    NSIndexPath *parentPath = [self indexPathForMessage:newMessage.parent];

                    if (parentPath != nil && parentPath.section < self.tableView.numberOfSections && parentPath.row < [self.tableView numberOfRowsInSection:parentPath.section]) {
                        // We received an update message to a message which is already part of our current data, therefore we need to reload it
                        [reloadIndexPaths addObject:parentPath];
                    }
                }
            }

            [self.tableView performBatchUpdates:^{
                if (insertSectionIndexSet.count > 0) {
                    [self.tableView insertSections:insertSectionIndexSet withRowAnimation:UITableViewRowAnimationAutomatic];
                }

                if (insertIndexPaths.count > 0) {
                    [self.tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
                }

                if (reloadIndexPaths.count > 0) {
                    [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
                }
            } completion:^(BOOL finished) {
                BOOL newMessagesContainUserMessage = [self newMessagesContainUserMessage:messages];
                // Remove unread messages separator when user writes a message
                if (newMessagesContainUserMessage) {
                    [self removeUnreadMessagesSeparator];
                    indexPathUnreadMessageSeparator = nil;
                    // Update last message index path
                    lastMessageIndexPath = [NSIndexPath indexPathForRow:messagesForLastDate.count - 1 inSection:self->_dateSections.count - 1];
                }

                NCChatMessage *firstNewMessage = [messages objectAtIndex:0];
                // This variable is needed since several calls to receiveMessages API might be needed
                // (if the number of unread messages is bigger than the "limit" in receiveMessages request)
                // to receive all the unread messages.
                BOOL areReallyNewMessages = firstNewMessage.timestamp >= self->_chatViewPresentedTimestamp;

                // Position chat view
                if (indexPathUnreadMessageSeparator) {
                    NSIndexPath *indexPath = [self getIndexPathOfUnreadMessageSeparator];
                    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                } else if (shouldScrollOnNewMessages || newMessagesContainUserMessage) {
                    [self.tableView scrollToRowAtIndexPath:lastMessageIndexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
                } else if (!self->_firstUnreadMessage && areReallyNewMessages && newMessagesContainVisibleMessages) {
                    [self showNewMessagesViewUntilMessage:firstNewMessage];
                }

                // Set last received message as last read message
                NCChatMessage *lastReceivedMessage = [messages objectAtIndex:messages.count - 1];
                self->_lastReadMessage = lastReceivedMessage.messageId;
            }];
        }
        
        if (firstNewMessagesAfterHistory) {
            [self->_chatBackgroundView.loadingView stopAnimating];
            [self->_chatBackgroundView.loadingView setHidden:YES];
        }
        
        if (self->_highlightMessageId) {
            NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:self->_highlightMessageId];
            if (indexPath) {
                [self highlightMessageAtIndexPath:indexPath withScrollPosition:UITableViewScrollPositionMiddle];
            }
            self->_highlightMessageId = 0;
        }

        [bgTask stopBackgroundTask];
    });
}

- (void)didSendChatMessage:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (notification.object != self->_chatController) {
            return;
        }
        
        NSError *error = [notification.userInfo objectForKey:@"error"];

        if (!error) {
            return;
        }

        NSString *message = [notification.userInfo objectForKey:@"message"];
        NSString *referenceId = [notification.userInfo objectForKey:@"referenceId"];

        if (!referenceId) {
            self.textView.text = message;
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"Could not send the message", nil)
                                         message:NSLocalizedString(@"An error occurred while sending the message", nil)
                                         preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"OK", nil)
                                       style:UIAlertActionStyleDefault
                                       handler:nil];

            [alert addAction:okButton];
            [[NCUserInterfaceController sharedInstance] presentAlertViewController:alert];

            return;
        }

        BOOL isOfflineMessage = [[notification.userInfo objectForKey:@"isOfflineMessage"] boolValue];

        [self modifyMessageWithReferenceId:referenceId withBlock:^(NCChatMessage *message) {
            message.sendingFailed = !isOfflineMessage;
            message.isOfflineMessage = isOfflineMessage;
        }];
    });
}

- (void)didReceiveChatBlocked:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    [self startObservingRoomLobbyFlag];
}

- (void)didReceiveNewerCommonReadMessage:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    [self checkLastCommonReadMessage];
}

- (void)didReceiveCallStartedMessage:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    _room.hasCall = YES;
    [self checkRoomControlsAvailability];
}

- (void)didReceiveCallEndedMessage:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    _room.hasCall = NO;
    [self checkRoomControlsAvailability];
}

- (void)didReceiveUpdateMessage:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    NCChatMessage *message = [notification.userInfo objectForKey:@"updateMessage"];
    NCChatMessage *deleteMessage = message.parent;
    if (deleteMessage) {
        [self updateMessageWithMessageId:deleteMessage.messageId withMessage:deleteMessage];
    }
}

- (void)didReceiveHistoryCleared:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    NCChatMessage *message = [notification.userInfo objectForKey:@"historyCleared"];
    if ([_chatController hasOlderStoredMessagesThanMessageId:message.messageId]) {
        [self cleanChat];
        [_chatController clearHistoryAndResetChatController];
        _hasRequestedInitialHistory = YES;
        [_chatController getInitialChatHistory];
    }
}

- (void)didReceiveMessagesInBackground:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }

    NSLog(@"didReceiveMessagesInBackground");
    [self checkForNewStoredMessages];
}

#pragma mark - External signaling controller Notifications

- (void)didUpdateParticipants:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    NSMutableArray *reloadCells = [NSMutableArray new];
    for (NSIndexPath *visibleIndexPath in self.tableView.indexPathsForVisibleRows) {
        NSDate *sectionDate = [_dateSections objectAtIndex:visibleIndexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:visibleIndexPath.row];
        if (message.messageId > 0 && message.messageId <= _room.lastCommonReadMessage) {
            [reloadCells addObject:visibleIndexPath];
        }
        
        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:reloadCells withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    });
}

- (void)didReceiveDeletedMessage:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    NCChatMessage *message = [notification.userInfo objectForKey:@"updateMessage"];
    NCChatMessage *deleteMessage = message.parent;
    if (deleteMessage) {
        [self updateMessageWithMessageId:deleteMessage.messageId withMessage:deleteMessage];
    }
}

- (void)didReceiveHistoryCleared:(NSNotification *)notification
{
    if (notification.object != _chatController) {
        return;
    }
    
    NCChatMessage *message = [notification.userInfo objectForKey:@"historyCleared"];
    if ([_chatController hasOlderStoredMessagesThanMessageId:message.messageId]) {
        [self cleanChat];
        [_chatController clearHistoryAndResetChatController];
        _hasRequestedInitialHistory = YES;
        [_chatController getInitialChatHistory];
    }
}

- (void)didReceiveStartedTyping:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    NSString *displayName = [notification.userInfo objectForKey:@"displayName"];
    NSString *userId = [notification.userInfo objectForKey:@"userId"];
    NSString *sessionId = [notification.userInfo objectForKey:@"sessionId"];
    
    if (![roomToken isEqualToString:_room.token] || (!userId && !sessionId)) {
        return;
    }

    // Waiting for https://github.com/nextcloud/spreed/issues/9726 to receive the correct displayname for guests
    if (!displayName) {
        displayName = NSLocalizedString(@"Guest", nil);
    }

    // Don't show a typing indicator for ourselves or if typing indicator setting is disabled
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] talkAccountForAccountId:_room.accountId];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];
    if ([userId isEqualToString:activeAccount.userId] || serverCapabilities.typingPrivacy) {
        return;
    }

    // For guests we use the sessionId as identifiert, for users we use the userId
    NSString *userIdentifier = sessionId;

    if (userId && ![userId isEqualToString:@""]) {
        userIdentifier = userId;
    }

    [self addTypingIndicatorWithUserIdentifier:userIdentifier withDisplayName:displayName];
}

- (void)didReceiveStoppedTyping:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    NSString *userId = [notification.userInfo objectForKey:@"userId"];
    NSString *sessionId = [notification.userInfo objectForKey:@"sessionId"];

    if (![roomToken isEqualToString:_room.token] || (!userId && !sessionId)) {
        return;
    }

    // Don't handle stop typing indicator from ourselves or if typing indicator setting is disabled
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] talkAccountForAccountId:_room.accountId];
    ServerCapabilities *serverCapabilities = [[NCDatabaseManager sharedInstance] serverCapabilitiesForAccountId:activeAccount.accountId];
    if ([userId isEqualToString:activeAccount.userId] || serverCapabilities.typingPrivacy) {
        return;
    }

    // For guests we use the sessionId as identifiert, for users we use the userId
    NSString *userIdentifier = sessionId;

    if (userId && ![userId isEqualToString:@""]) {
        userIdentifier = userId;
    }

    [self removeTypingIndicatorWithUserIdentifier:userIdentifier];
}

- (void)didReceiveParticipantJoin:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    NSString *sessionId = [notification.userInfo objectForKey:@"sessionId"];

    if (![roomToken isEqualToString:_room.token] || !sessionId) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_isTyping) {
            [self sendStartedTypingMessageToSessionId:sessionId];
        }
    });
}

- (void)didReceiveParticipantLeave:(NSNotification *)notification
{
    NSString *roomToken = [notification.userInfo objectForKey:@"roomToken"];
    NSString *sessionId = [notification.userInfo objectForKey:@"sessionId"];
    NSString *userId = [notification.userInfo objectForKey:@"userId"];

    if (![roomToken isEqualToString:_room.token] || !sessionId) {
        return;
    }

    // For guests we use the sessionId as identifiert, for users we use the userId
    NSString *userIdentifier = sessionId;

    if (userId && ![userId isEqualToString:@""]) {
        userIdentifier = userId;
    }

    [self removeTypingIndicatorWithUserIdentifier:userIdentifier];
}



#pragma mark - Lobby functions

- (void)startObservingRoomLobbyFlag
{
    [self updateRoomInformation];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_lobbyCheckTimer invalidate];
        self->_lobbyCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateRoomInformation) userInfo:nil repeats:YES];
    });
}

- (void)updateRoomInformation
{
    [[NCRoomsManager sharedInstance] updateRoom:_room.token withCompletionBlock:nil];
}

- (BOOL)shouldPresentLobbyView
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];

    BOOL serverSupportsConversationPermissions =
        [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityConversationPermissions forAccountId:activeAccount.accountId] ||
        [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityDirectMentionFlag forAccountId:activeAccount.accountId];

    if (serverSupportsConversationPermissions && (_room.permissions & NCPermissionCanIgnoreLobby) != 0) {
        return NO;
    }

    return _room.lobbyState == NCRoomLobbyStateModeratorsOnly && !_room.canModerate;
}

#pragma mark - Chat functions

- (NSDate *)getKeyForDate:(NSDate *)date inDictionary:(NSDictionary *)dictionary
{
    NSDate *keyDate = nil;
    for (NSDate *key in dictionary.allKeys) {
        if ([[NSCalendar currentCalendar] isDate:date inSameDayAsDate:key]) {
            keyDate = key;
        }
    }
    return keyDate;
}

- (NSIndexPath *)prependMessages:(NSMutableArray *)historyMessages addingBlockSeparator:(BOOL)shouldAddBlockSeparator
{
    NSMutableDictionary *historyDict = [[NSMutableDictionary alloc] init];
    [self appendMessages:historyMessages inDictionary:historyDict];
    
    NSDate *chatSection = nil;
    NSMutableArray *historyMessagesForSection = nil;
    // Sort history sections
    NSMutableArray *historySections = [NSMutableArray arrayWithArray:historyDict.allKeys];
    [historySections sortUsingSelector:@selector(compare:)];
    
    // Add every section in history that can't be merged with current chat messages
    for (NSDate *historySection in historySections) {
        historyMessagesForSection = [historyDict objectForKey:historySection];
        chatSection = [self getKeyForDate:historySection inDictionary:_messages];
        if (!chatSection) {
            [_messages setObject:historyMessagesForSection forKey:historySection];
        }
    }
    
    [self sortDateSections];
    
    if (shouldAddBlockSeparator) {
        // Chat block separator
        NCChatMessage *blockSeparatorMessage = [[NCChatMessage alloc] init];
        blockSeparatorMessage.messageId = kChatBlockSeparatorIdentifier;
        [historyMessagesForSection addObject:blockSeparatorMessage];
    }
    
    NSMutableArray *lastHistoryMessages = [historyDict objectForKey:[historySections lastObject]];
    NSIndexPath *lastHistoryMessageIP = [NSIndexPath indexPathForRow:lastHistoryMessages.count - 1 inSection:historySections.count - 1];
    
    // Merge last section of history messages with first section in current chat
    if (chatSection) {
        NSMutableArray *chatMessages = [_messages objectForKey:chatSection];
        NCChatMessage *lastHistoryMessage = [historyMessagesForSection lastObject];
        NCChatMessage *firstChatMessage = [chatMessages firstObject];
        firstChatMessage.isGroupMessage = [self shouldGroupMessage:firstChatMessage withMessage:lastHistoryMessage];
        [historyMessagesForSection addObjectsFromArray:chatMessages];
        [_messages setObject:historyMessagesForSection forKey:chatSection];
    }
    
    return lastHistoryMessageIP;
}

- (void)appendMessages:(NSMutableArray *)messages inDictionary:(NSMutableDictionary *)dictionary
{
    for (NCChatMessage *newMessage in messages) {
        NSDate *newMessageDate = [NSDate dateWithTimeIntervalSince1970: newMessage.timestamp];
        NSDate *keyDate = [self getKeyForDate:newMessageDate inDictionary:dictionary];
        NSMutableArray *messagesForDate = [dictionary objectForKey:keyDate];

        if (messagesForDate) {
            BOOL messageUpdated = NO;
            
            // Check if we can update the message instead of adding a new one
            for (int i = 0; i < messagesForDate.count; i++) {
                NCChatMessage *currentMessage = messagesForDate[i];
                if ((!currentMessage.isTemporary && currentMessage.messageId == newMessage.messageId) ||
                    (currentMessage.isTemporary && [currentMessage.referenceId isEqualToString:newMessage.referenceId])) {
                    // The newly received message either already exists or its temporary counterpart exists -> update
                    // If the user type a command the newMessage.actorType will be "bots", then we should not group those messages
                    // even if the original message was grouped.
                    newMessage.isGroupMessage = currentMessage.isGroupMessage && ![newMessage.actorType isEqualToString:@"bots"];
                    messagesForDate[i] = newMessage;
                    messageUpdated = YES;
                    break;
                }
            }
            
            if (!messageUpdated) {
                NCChatMessage *lastMessage = [messagesForDate lastObject];
                newMessage.isGroupMessage = [self shouldGroupMessage:newMessage withMessage:lastMessage];
                [messagesForDate addObject:newMessage];
            }
        } else {
            NSMutableArray *newMessagesInDate = [NSMutableArray new];
            [dictionary setObject:newMessagesInDate forKey:newMessageDate];
            [newMessagesInDate addObject:newMessage];
        }
    }
    
    [self sortDateSections];
}

- (void)insertMessages:(NSMutableArray *)messages
{
    for (NCChatMessage *newMessage in messages) {
        NSDate *newMessageDate = [NSDate dateWithTimeIntervalSince1970: newMessage.timestamp];
        NSDate *keyDate = [self getKeyForDate:newMessageDate inDictionary:_messages];
        NSMutableArray *messagesForDate = [_messages objectForKey:keyDate];
        if (messagesForDate) {
            for (int i = 0; i < messagesForDate.count; i++) {
                NCChatMessage *currentMessage = [messagesForDate objectAtIndex:i];
                if (currentMessage.timestamp > newMessage.timestamp) {
                    // Message inserted in between other messages
                    if (i > 0) {
                        NCChatMessage *previousMessage = [messagesForDate objectAtIndex:i-1];
                        newMessage.isGroupMessage = [self shouldGroupMessage:newMessage withMessage:previousMessage];
                    }
                    currentMessage.isGroupMessage = [self shouldGroupMessage:currentMessage withMessage:newMessage];
                    [messagesForDate insertObject:newMessage atIndex:i];
                    break;
                // Message inserted at the end of a date section
                } else if (i == messagesForDate.count - 1) {
                    newMessage.isGroupMessage = [self shouldGroupMessage:newMessage withMessage:currentMessage];
                    [messagesForDate addObject:newMessage];
                    break;
                }
            }
        } else {
            NSMutableArray *newMessagesInDate = [NSMutableArray new];
            [_messages setObject:newMessagesInDate forKey:newMessageDate];
            [newMessagesInDate addObject:newMessage];
        }
    }
    
    [self sortDateSections];
}

- (NSIndexPath *)indexPathForMessage:(NCChatMessage *)message
{
    NSDate *messageDate = [NSDate dateWithTimeIntervalSince1970: message.timestamp];
    NSDate *keyDate = [self getKeyForDate:messageDate inDictionary:_messages];
    NSInteger section = [_dateSections indexOfObject:keyDate];
    if (NSNotFound != section) {
        NSMutableArray *messages = [_messages objectForKey:keyDate];
        for (int i = 0; i < messages.count; i++) {
            NCChatMessage *currentMessage = messages[i];
            if ((!currentMessage.isTemporary && currentMessage.messageId == message.messageId) ||
                (currentMessage.isTemporary && [currentMessage.referenceId isEqualToString:message.referenceId])) {
                return [NSIndexPath indexPathForRow:i inSection:section];
            }
        }
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForMessageWithMessageId:(NSInteger)messageId
{
    for (NSInteger i = _dateSections.count - 1; i >= 0; i--) {
        NSDate *keyDate = [_dateSections objectAtIndex:i];
        NSMutableArray *messages = [_messages objectForKey:keyDate];
        NCChatMessage *firstMessage = messages.firstObject;
        if (firstMessage.messageId > messageId) continue;
        for (NSInteger j = messages.count - 1; j >= 0; j--) {
            NCChatMessage *currentMessage = messages[j];
            if (currentMessage.messageId == messageId) {
                return [NSIndexPath indexPathForRow:j inSection:i];
            }
        }
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForMessageWithReferenceId:(NSString *)referenceId
{
    for (NSInteger i = _dateSections.count - 1; i >= 0; i--) {
        NSDate *keyDate = [_dateSections objectAtIndex:i];
        NSMutableArray *messages = [_messages objectForKey:keyDate];
        for (int j = 0; j < messages.count; j++) {
            NCChatMessage *currentMessage = messages[j];
            if ([currentMessage.referenceId isEqualToString:referenceId]) {
                return [NSIndexPath indexPathForRow:j inSection:i];
            }
        }
    }
    
    return nil;
}

- (NSIndexPath *)removeMessageAtIndexPath:(NSIndexPath *)indexPath
{
    NSDate *sectionKey = [_dateSections objectAtIndex:indexPath.section];
    if (sectionKey) {
        NSMutableArray *messages = [_messages objectForKey:sectionKey];
        if (indexPath.row < messages.count) {
            if (messages.count == 1) {
                // Remove section
                [_messages removeObjectForKey:sectionKey];
                [self sortDateSections];
                [self.tableView beginUpdates];
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];
                [self.tableView endUpdates];
            } else {
                // Remove message
                BOOL isLastMessage = indexPath.row == messages.count - 1;
                [messages removeObjectAtIndex:indexPath.row];
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                [self.tableView endUpdates];
                if (!isLastMessage) {
                    // Update the message next to removed message
                    NCChatMessage *nextMessage = [messages objectAtIndex:indexPath.row];
                    nextMessage.isGroupMessage = NO;
                    if (indexPath.row > 0) {
                        NCChatMessage *previousMessage = [messages objectAtIndex:indexPath.row - 1];
                        nextMessage.isGroupMessage = [self shouldGroupMessage:nextMessage withMessage:previousMessage];
                    }
                    [self.tableView beginUpdates];
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    [self.tableView endUpdates];
                }
            }
        }
    }
    
    return nil;
}

- (void)sortDateSections
{
    _dateSections = [NSMutableArray arrayWithArray:_messages.allKeys];
    [_dateSections sortUsingSelector:@selector(compare:)];
}

- (BOOL)shouldGroupMessage:(NCChatMessage *)newMessage withMessage:(NCChatMessage *)lastMessage
{
    BOOL sameActor = [newMessage.actorId isEqualToString:lastMessage.actorId];
    BOOL sameType = ([newMessage isSystemMessage] == [lastMessage isSystemMessage]);
    BOOL timeDiff = (newMessage.timestamp - lastMessage.timestamp) < kChatMessageGroupTimeDifference;

    // Try to collapse system messages if the new message is not already collapsing some messages
    if ([newMessage isSystemMessage] && [lastMessage isSystemMessage] && newMessage.collapsedMessages.count == 0) {
        [self tryToGroupSystemMessage:newMessage withMessage:lastMessage];
    }
    
    return sameActor & sameType & timeDiff;
}

- (void)tryToGroupSystemMessage:(NCChatMessage *)newMessage withMessage:(NCChatMessage *)lastMessage
{
    if ([newMessage.systemMessage isEqualToString:lastMessage.systemMessage]) {
        // Same action and actor
        if ([newMessage.actorId isEqualToString:lastMessage.actorId]) {
            if ([newMessage.systemMessage isEqualToString:@"user_added"] ||
                [newMessage.systemMessage isEqualToString:@"user_removed"] ||
                [newMessage.systemMessage isEqualToString:@"moderator_promoted"] ||
                [newMessage.systemMessage isEqualToString:@"moderator_demoted"]) {
                [self collapseSystemMessage:newMessage andMessage:lastMessage withAction:newMessage.systemMessage];
            }
        }
        // Same action different actors
        else {
            if ([newMessage.systemMessage isEqualToString:@"call_joined"] ||
                [newMessage.systemMessage isEqualToString:@"call_left"]) {
                [self collapseSystemMessage:newMessage andMessage:lastMessage withAction:newMessage.systemMessage];
            }
        }
    } else if ([newMessage.actorId isEqualToString:lastMessage.actorId]) {
        // Call reconnection
        if ([newMessage.systemMessage isEqualToString:@"call_joined"] &&
            [lastMessage.systemMessage isEqualToString:@"call_left"]) {
            [self collapseSystemMessage:newMessage andMessage:lastMessage withAction:@"call_reconnected"];
        }
    }
}

- (void)collapseSystemMessage:(NCChatMessage *)newMessage andMessage:(NCChatMessage *)lastMessage withAction:(NSString *)action
{
    NCChatMessage *collapseByMessage = lastMessage;
    if (lastMessage.collapsedBy) {
        collapseByMessage = lastMessage.collapsedBy;
        collapseByMessage.collapsedBy = nil;

        [self tryToGroupSystemMessage:newMessage withMessage:collapseByMessage];
        return;
    }

    newMessage.collapsedBy = collapseByMessage;
    newMessage.isCollapsed = YES;

    [collapseByMessage.collapsedMessages addObject:@(newMessage.messageId)];
    collapseByMessage.isCollapsed = YES;

    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];

    NSString *user0 = [[collapseByMessage.messageParameters objectForKey:@"user"] objectForKey:@"name"];
    NSString *user1 = [[newMessage.messageParameters objectForKey:@"user"] objectForKey:@"name"];
    BOOL isUser0Self = [[[collapseByMessage.messageParameters objectForKey:@"user"] objectForKey:@"id"] isEqualToString:activeAccount.userId] &&
                        [[[collapseByMessage.messageParameters objectForKey:@"user"] objectForKey:@"type"] isEqualToString:@"user"];
    BOOL isUser1Self = [[[newMessage.messageParameters objectForKey:@"user"] objectForKey:@"id"] isEqualToString:activeAccount.userId] &&
                        [[[newMessage.messageParameters objectForKey:@"user"] objectForKey:@"type"] isEqualToString:@"user"];
    NSString *actor0 = collapseByMessage.actorDisplayName;
    NSString *actor1 = newMessage.actorDisplayName;
    BOOL isActor0Self = [collapseByMessage.actorId isEqualToString:activeAccount.userId] && [collapseByMessage.actorType isEqualToString:@"users"];
    BOOL isActor1Self = [newMessage.actorId isEqualToString:activeAccount.userId] && [newMessage.actorType isEqualToString:@"users"];
    BOOL isActor0Admin = [collapseByMessage.actorId isEqualToString:@"cli"] && [collapseByMessage.actorType isEqualToString:@"guests"];

    if (isUser0Self || isUser1Self) {
        collapseByMessage.collapsedIncludesUserSelf = YES;
    }

    if (isActor0Self || isActor1Self) {
        collapseByMessage.collapsedIncludesActorSelf = YES;
    }

    if ([action isEqualToString:@"user_added"]) {

        if (isActor0Self) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You added %@ and %@", nil), user0, user1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You added %@ and %ld more participants", nil), user0, collapseByMessage.collapsedMessages.count];
            }
        } else if (isActor0Admin) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator added you and %@", nil), isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator added %@ and %@", nil), user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator added you and %ld more participants", nil), collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator added %@ and %ld more participants", nil), user0, collapseByMessage.collapsedMessages.count];
                }
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ added you and %@", nil), actor0, isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ added %@ and %@", nil), actor0, user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ added you and %ld more participants", nil), actor0, collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ added %@ and %ld more participants", nil), actor0, user0, collapseByMessage.collapsedMessages.count];
                }
            }
        }

    } else if ([action isEqualToString:@"user_removed"]) {

        if (isActor0Self) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You removed %@ and %@", nil), user0, user1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You removed %@ and %ld more participants", nil), user0, collapseByMessage.collapsedMessages.count];
            }
        } else if (isActor0Admin) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator removed you and %@", nil), isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator removed %@ and %@", nil), user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator removed you and %ld more participants", nil), collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator removed %@ and %ld more participants", nil), user0, collapseByMessage.collapsedMessages.count];
                }
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ removed you and %@", nil), actor0, isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ removed %@ and %@", nil), actor0, user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ removed you and %ld more participants", nil), actor0, collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ removed %@ and %ld more participants", nil), actor0, user0, collapseByMessage.collapsedMessages.count];
                }
            }
        }

    } else if ([action isEqualToString:@"moderator_promoted"]) {

        if (isActor0Self) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You promoted %@ and %@ to moderators", nil), user0, user1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You promoted %@ and %ld more participants to moderators", nil), user0, collapseByMessage.collapsedMessages.count];
            }
        } else if (isActor0Admin) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator promoted you and %@ to moderators", nil), isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator promoted %@ and %@ to moderators", nil), user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator promoted you and %ld more participants to moderators", nil), collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator promoted %@ and %ld more participants to moderators", nil), user0, collapseByMessage.collapsedMessages.count];
                }
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ promoted you and %@ to moderators", nil), actor0, isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ promoted %@ and %@ to moderators", nil), actor0, user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ promoted you and %ld more participants to moderators", nil), actor0, collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ promoted %@ and %ld more participants to moderators", nil), actor0, user0, collapseByMessage.collapsedMessages.count];
                }
            }
        }

    } else if ([action isEqualToString:@"moderator_demoted"]) {

        if (isActor0Self) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You demoted %@ and %@ from moderators", nil), user0, user1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You demoted %@ and %ld more participants from moderators", nil), user0, collapseByMessage.collapsedMessages.count];
            }
        } else if (isActor0Admin) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator demoted you and %@ from moderators", nil), isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator demoted %@ and %@ from moderators", nil), user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator demoted you and %ld more participants from moderators", nil), collapseByMessage.collapsedMessages.count];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"An administrator demoted %@ and %ld more participants from moderators", nil), user0, collapseByMessage.collapsedMessages.count];
                }
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ demoted you and %@ from moderators", nil), actor0, isUser0Self ? user1 : user0];
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ demoted %@ and %@ from moderators", nil), actor0, user0, user1];
                }
            } else {
                if (collapseByMessage.collapsedIncludesUserSelf) {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ demoted you and %ld more participants from moderators", nil), actor0, collapseByMessage.collapsedMessages.count];;
                } else {
                    collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ demoted %@ and %ld more participants from moderators", nil), actor0, user0, collapseByMessage.collapsedMessages.count];
                }
            }
        }

    } else if ([action isEqualToString:@"call_joined"]) {

        if (collapseByMessage.collapsedIncludesActorSelf) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You and %@ joined the call", nil), isActor0Self ? actor1 : actor0];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You and %ld more participants joined the call", nil), collapseByMessage.collapsedMessages.count];
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ and %@ joined the call", nil), actor0, actor1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ and %ld more participants joined the call", nil), actor0, collapseByMessage.collapsedMessages.count];
            }
        }

    } else if ([action isEqualToString:@"call_left"]) {

        if (collapseByMessage.collapsedIncludesActorSelf) {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You and %@ left the call", nil), isActor0Self ? actor1 : actor0];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You and %ld more participants left the call", nil), collapseByMessage.collapsedMessages.count];
            }
        } else {
            if (collapseByMessage.collapsedMessages.count == 1) {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ and %@ left the call", nil), actor0, actor1];
            } else {
                collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ and %ld more participants left the call", nil), actor0, collapseByMessage.collapsedMessages.count];
            }
        }
    } else if ([action isEqualToString:@"call_reconnected"]) {
        if (collapseByMessage.collapsedIncludesActorSelf) {
            collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"You reconnected to the call", nil)];
        } else {
            collapseByMessage.collapsedMessage = [NSString stringWithFormat:NSLocalizedString(@"%@ reconnected to the call", nil), actor0];
        }
    }

    // Reload collapsedBy message if it's already laoded in the chat
    NSMutableArray *reloadIndexPaths = [NSMutableArray new];
    NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:collapseByMessage.messageId];
    if (indexPath) {
        [reloadIndexPaths addObject:indexPath];

        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
}

- (BOOL)couldRetireveHistory
{
    return _hasReceiveInitialHistory && !_retrievingHistory && _dateSections.count > 0 && _hasStoredHistory;
}

- (void)showLoadingHistoryView
{
    _loadingHistoryView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    _loadingHistoryView.color = [UIColor darkGrayColor];
    [_loadingHistoryView startAnimating];
    self.tableView.tableHeaderView = _loadingHistoryView;
}

- (void)hideLoadingHistoryView
{
    _loadingHistoryView = nil;
    self.tableView.tableHeaderView = nil;
}

- (BOOL)shouldScrollOnNewMessages
{
    if (_isVisible) {
        // Scroll if table view is at the bottom (or 80px up)
        CGFloat minimumOffset = (self.tableView.contentSize.height - self.tableView.frame.size.height) - 80;
        if (self.tableView.contentOffset.y >= minimumOffset) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)newMessagesContainUserMessage:(NSMutableArray *)messages
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    for (NCChatMessage *message in messages) {
        if ([message.actorId isEqualToString:activeAccount.userId] && !message.isSystemMessage) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)messagesContainVisibleMessages:(NSMutableArray *)messages
{
    for (NCChatMessage *message in messages) {
        if (![message isUpdateMessage]) {
            return YES;
        }
    }
    return NO;
}

- (void)showNewMessagesViewUntilMessage:(NCChatMessage *)message
{
    _firstUnreadMessage = message;
    _unreadMessageButton.hidden = NO;
    // Check if unread messages are already visible
    [self checkUnreadMessagesVisibility];
}

- (void)hideNewMessagesView
{
    _firstUnreadMessage = nil;
    _unreadMessageButton.hidden = YES;
}

- (NSIndexPath *)getIndexPathOfUnreadMessageSeparator
{
    // Most likely the unreadMessageSeparator is somewhere near the bottom of the chat, so we look for it from bottom up
    for (NSInteger sectionIndex = (self->_dateSections.count - 1); sectionIndex >= 0; sectionIndex--) {
        NSDate *dateSection = [self->_dateSections objectAtIndex:sectionIndex];
        NSMutableArray *messagesInSection = [self->_messages objectForKey:dateSection];
        
        for (NSInteger messageIndex = (messagesInSection.count - 1); messageIndex >= 0; messageIndex--) {
            NCChatMessage *chatMessage = [messagesInSection objectAtIndex:messageIndex];
            
            if (chatMessage && chatMessage.messageId == kUnreadMessagesSeparatorIdentifier) {
                return [NSIndexPath indexPathForRow:messageIndex inSection:sectionIndex];
            }
        }
    }
    
    return nil;
}

- (void)removeUnreadMessagesSeparator
{
    NSIndexPath *indexPath = [self getIndexPathOfUnreadMessageSeparator];
    
    if (indexPath) {
        NSDate *separatorDate = [_dateSections objectAtIndex:indexPath.section];
        NSMutableArray *messages = [_messages objectForKey:separatorDate];
        [messages removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)checkUnreadMessagesVisibility
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [self indexPathForMessage:self->_firstUnreadMessage];
        NSArray* visibleCellsIPs = [self.tableView indexPathsForVisibleRows];
        if ([visibleCellsIPs containsObject:indexPath]) {
            [self hideNewMessagesView];
        }
    });
}

- (void)checkLastCommonReadMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *reloadCells = [NSMutableArray new];
        for (NSIndexPath *visibleIndexPath in self.tableView.indexPathsForVisibleRows) {
            NSDate *sectionDate = [self->_dateSections objectAtIndex:visibleIndexPath.section];
            NCChatMessage *message = [[self->_messages objectForKey:sectionDate] objectAtIndex:visibleIndexPath.row];
            if (message.messageId > 0 && message.messageId <= self->_room.lastCommonReadMessage) {
                [reloadCells addObject:visibleIndexPath];
            }
        }
        
        if (reloadCells.count > 0) {
            [self.tableView beginUpdates];
            [self.tableView reloadRowsAtIndexPaths:reloadCells withRowAnimation:UITableViewRowAnimationNone];
            [self.tableView endUpdates];
        }
    });
}

- (void)checkForNewStoredMessages
{
    // Get the last "real" message. For temporary messages the messageId would be 0
    // which would load all stored messages of the current conversation
    NCChatMessage *lastMessage = [self getLastRealMessage];

    if (lastMessage) {
        [self.chatController checkForNewMessagesFromMessageId:lastMessage.messageId];
        [self checkLastCommonReadMessage];
    }
}

- (void)cleanChat
{
    _messages = [[NSMutableDictionary alloc] init];
    _dateSections = [[NSMutableArray alloc] init];
    _hasReceiveInitialHistory = NO;
    _hasRequestedInitialHistory = NO;
    self.chatController.hasReceivedMessagesFromServer = NO;
    [self hideNewMessagesView];
    [self.tableView reloadData];
}

- (void)savePendingMessage
{
    _room.pendingMessage = self.textView.text;
    [[NCRoomsManager sharedInstance] updatePendingMessage:_room.pendingMessage forRoom:_room];
}

- (void)clearPendingMessage
{
    _room.pendingMessage = @"";
    [[NCRoomsManager sharedInstance] updatePendingMessage:_room.pendingMessage forRoom:_room];
}

- (void)saveLastReadMessage
{
    [[NCRoomsManager sharedInstance] updateLastReadMessage:_lastReadMessage forRoom:_room];
}

#pragma mark - Reactions

- (void)addReaction:(NSString *)reaction toChatMessage:(NCChatMessage *)message
{
    for (NCChatReaction *existingReaction in message.reactionsArray) {
        if ([existingReaction.reaction isEqualToString:reaction] && existingReaction.userReacted) {
            // We can't add the same reaction twice
            return;
        }
    }

    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [self setTemporaryReaction:reaction withState:NCChatReactionStateAdding toMessage:message];
    [[NCAPIController sharedInstance] addReaction:reaction toMessage:message.messageId inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSDictionary *reactionsDict, NSError *error, NSInteger statusCode) {
        if (error) {
            [self.view makeToast:NSLocalizedString(@"An error occurred while adding a reaction to message", nil) duration:5 position:CSToastPositionCenter];
            [self removeTemporaryReaction:reaction forMessageId:message.messageId];
        }
    }];
}

- (void)removeReaction:(NSString *)reaction fromChatMessage:(NCChatMessage *)message
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [self setTemporaryReaction:reaction withState:NCChatReactionStateRemoving toMessage:message];
    [[NCAPIController sharedInstance] removeReaction:reaction fromMessage:message.messageId inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSDictionary *reactionsDict, NSError *error, NSInteger statusCode) {
        if (error) {
            [self.view makeToast:NSLocalizedString(@"An error occurred while removing a reaction from message", nil) duration:5 position:CSToastPositionCenter];
            [self removeTemporaryReaction:reaction forMessageId:message.messageId];
        }
    }];
}

- (void)addOrRemoveReaction:(NCChatReaction *)reaction inChatMessage:(NCChatMessage *)message
{
    if ([message isReactionBeingModified:reaction.reaction]) {return;}
    
    if (reaction.userReacted) {
        [self removeReaction:reaction.reaction fromChatMessage:message];
    } else {
        [self addReaction:reaction.reaction toChatMessage:message];
    }
}

- (void)removeTemporaryReaction:(NSString *)reaction forMessageId:(NSInteger)messageId
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *reloadIndexPaths = [NSMutableArray new];
        NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:messageId];
        if (indexPath) {
            [reloadIndexPaths addObject:indexPath];
            NSDate *keyDate = [self->_dateSections objectAtIndex:indexPath.section];
            NSMutableArray *messages = [self->_messages objectForKey:keyDate];
            NCChatMessage *currentMessage = messages[indexPath.row];
            //Remove temporary reaction
            [currentMessage removeReactionFromTemporayReactions:reaction];
        }
        
        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    });
}

- (void)setTemporaryReaction:(NSString *)reaction withState:(NCChatReactionState)state toMessage:(NCChatMessage *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isAtBottom = [self shouldScrollOnNewMessages];
        
        NSMutableArray *reloadIndexPaths = [NSMutableArray new];
        NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:message.messageId];
        if (indexPath) {
            [reloadIndexPaths addObject:indexPath];
            NSDate *keyDate = [self->_dateSections objectAtIndex:indexPath.section];
            NSMutableArray *messages = [self->_messages objectForKey:keyDate];
            NCChatMessage *currentMessage = messages[indexPath.row];
            // Add temporary reaction
            if (state == NCChatReactionStateAdding) {
                [currentMessage addTemporaryReaction:reaction];
            }
            // Remove reaction temporarily
            else if (state == NCChatReactionStateRemoving) {
                [currentMessage removeReactionTemporarily:reaction];
            }
        }

        [self.tableView performBatchUpdates:^{
            [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        } completion:^(BOOL finished) {
            if (!isAtBottom) {
                return;
            }

            NCChatMessage *lastNonUpdateMessage = [self getLastNonUpdateMessage];

            if (lastNonUpdateMessage) {
                NSIndexPath *indexPath = [self indexPathForMessage:lastNonUpdateMessage];

                if (indexPath) {
                    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                }
            }
        }];
    });
}



- (void)showReactionsSummaryOfMessage:(NCChatMessage *)message
{
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);

    ReactionsSummaryView *reactionsVC = [[ReactionsSummaryView alloc] initWithStyle:UITableViewStyleInsetGrouped];
    NCNavigationController *reactionsNC = [[NCNavigationController alloc] initWithRootViewController:reactionsVC];
    [self presentViewController:reactionsNC animated:YES completion:nil];
    
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] getReactions:nil fromMessage:message.messageId inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSDictionary *reactionsDict, NSError *error, NSInteger statusCode) {
        if (!error) {
            [reactionsVC updateReactionsWithReactions:reactionsDict];
        }
    }];
}



- (void)showReactionsSummaryOfMessage:(NCChatMessage *)message
{
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);
    
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }
    ReactionsSummaryView *reactionsVC = [[ReactionsSummaryView alloc] initWithStyle:style];
    NCNavigationController *reactionsNC = [[NCNavigationController alloc] initWithRootViewController:reactionsVC];
    [self presentViewController:reactionsNC animated:YES completion:nil];
    
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] getReactions:nil fromMessage:message.messageId inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NSDictionary *reactionsDict, NSError *error, NSInteger statusCode) {
        if (!error) {
            [reactionsVC updateReactionsWithReactions:reactionsDict];
        }
    }];
}

#pragma mark - Autocompletion

- (void)didChangeAutoCompletionPrefix:(NSString *)prefix andWord:(NSString *)word
{
    if ([prefix isEqualToString:@"@"]) {
        [self showSuggestionsForString:word];
    }
}

- (CGFloat)heightForAutoCompletionView
{
    return kChatMessageCellMinimumHeight * self.autocompletionUsers.count;
}

- (void)showSuggestionsForString:(NSString *)string
{
    self.autocompletionUsers = nil;
    [[NCAPIController sharedInstance] getMentionSuggestionsInRoom:_room.token forString:string forAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:^(NSMutableArray *mentions, NSError *error) {
        if (!error) {
            self.autocompletionUsers = [[NSMutableArray alloc] initWithArray:mentions];
            BOOL show = (self.autocompletionUsers.count > 0);
            // Check if the '@' is still there
            [self.textView lookForPrefixes:self.registeredPrefixes completion:^(NSString *prefix, NSString *word, NSRange wordRange) {
                if (prefix.length > 0 && word.length > 0) {
                    [self showAutoCompletionView:show];
                } else {
                    [self cancelAutoCompletion];
                }
            }];
        }
    }];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return 1;
    }
    
    if ([tableView isEqual:self.tableView] && _dateSections.count > 0) {
        self.tableView.backgroundView = nil;
    } else {
        self.tableView.backgroundView = _chatBackgroundView;
    }
    
    return _dateSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return _autocompletionUsers.count;
    }
    
    NSDate *date = [_dateSections objectAtIndex:section];
    NSMutableArray *messages = [_messages objectForKey:date];
    
    return messages.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return nil;
    }
    
    NSDate *date = [_dateSections objectAtIndex:section];
    return [self getHeaderStringFromDate:date];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return 0;
    }

    NSDate *date = [_dateSections objectAtIndex:section];
    NSMutableArray *messages = [_messages objectForKey:date];

    if (![self messagesContainVisibleMessages:messages]) {
        // No visible message found -> hide section
        return 0.0;
    }
    
    return kDateHeaderViewHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return nil;
    }
    
    DateHeaderView *headerView = [[DateHeaderView alloc] init];
    headerView.dateLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    headerView.dateLabel.layer.cornerRadius = 12;
    headerView.dateLabel.clipsToBounds = YES;
    
    DateLabelCustom *headerLabel = (DateLabelCustom*)headerView.dateLabel;
    headerLabel.tableView = self.tableView;
    return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView isEqual:self.autoCompletionView]) {
        if (!_autocompletionUsers || indexPath.row >= [_autocompletionUsers count] || !_autocompletionUsers[indexPath.row]) {
            return [self.autoCompletionView dequeueReusableCellWithIdentifier:AutoCompletionCellIdentifier];
        }

        NSDictionary *suggestion = [_autocompletionUsers objectAtIndex:indexPath.row];
        NSString *suggestionId = [suggestion objectForKey:@"id"];
        NSString *suggestionName = [suggestion objectForKey:@"label"];
        NSString *suggestionSource = [suggestion objectForKey:@"source"];
        NSString *suggestionUserStatus = [suggestion objectForKey:@"status"];
        ChatMessageTableViewCell *suggestionCell = (ChatMessageTableViewCell *)[self.autoCompletionView dequeueReusableCellWithIdentifier:AutoCompletionCellIdentifier];
        suggestionCell.titleLabel.text = suggestionName;
        [suggestionCell setUserStatus:suggestionUserStatus];
        if ([suggestionId isEqualToString:@"all"]) {
            [suggestionCell.avatarButton setAvatarFor:_room with:self.traitCollection.userInterfaceStyle];
        } else if ([suggestionSource isEqualToString:@"guests"]) {
            UIColor *guestAvatarColor = [NCAppBranding placeholderColor];
            NSString *name = ([suggestionName isEqualToString:@"Guest"]) ? @"?" : suggestionName;

            UIImage *image = [NCUtils getImageWithString:name withBackgroundColor:guestAvatarColor withBounds:suggestionCell.avatarButton.bounds isCircular:YES];
            [suggestionCell.avatarButton setImage:image forState:UIControlStateNormal];
        } else if ([suggestionSource isEqualToString:@"groups"]) {
            [suggestionCell.avatarButton setGroupAvatarWith:self.traitCollection.userInterfaceStyle];
        } else {
            [suggestionCell.avatarButton setUserAvatarFor:suggestionId with:self.traitCollection.userInterfaceStyle];
        }
        return suggestionCell;
    }
    
    NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
    NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
    
    return [self getCellForMessage:message];
}

- (UITableViewCell *)getCellForMessage:(NCChatMessage *) message
{
    UITableViewCell *cell;
    if (message.messageId == kUnreadMessagesSeparatorIdentifier) {
        MessageSeparatorTableViewCell *separatorCell = (MessageSeparatorTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:MessageSeparatorCellIdentifier];
        separatorCell.messageId = message.messageId;
        separatorCell.separatorLabel.text = NSLocalizedString(@"Unread messages", nil);
        return separatorCell;
    }
    if (message.messageId == kChatBlockSeparatorIdentifier) {
        MessageSeparatorTableViewCell *separatorCell = (MessageSeparatorTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:MessageSeparatorCellIdentifier];
        separatorCell.messageId = message.messageId;
        separatorCell.separatorLabel.text = NSLocalizedString(@"Some messages not shown, will be downloaded when online", nil);
        return separatorCell;
    }
    if (message.isSystemMessage) {
        if ([message isUpdateMessage]) {
            return (SystemMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:InvisibleSystemMessageCellIdentifier];
        }
        SystemMessageTableViewCell *systemCell = (SystemMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:SystemMessageCellIdentifier];
        systemCell.delegate = self;
        [systemCell setupForMessage:message];
        return systemCell;
    }
    if (message.file) {
        if (message.isVoiceMessage) {
            NSString *voiceMessageCellIdentifier = (message.isGroupMessage) ? GroupedVoiceMessageCellIdentifier : VoiceMessageCellIdentifier;
            VoiceMessageTableViewCell *voiceMessageCell = (VoiceMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:voiceMessageCellIdentifier];
            voiceMessageCell.delegate = self;
            [voiceMessageCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];
            if ([message.file.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [message.file.path isEqualToString:_playerAudioFileStatus.filePath]) {
                [voiceMessageCell setPlayerProgress:_voiceMessagesPlayer.currentTime isPlaying:_voiceMessagesPlayer.isPlaying maximumValue:_voiceMessagesPlayer.duration];
            } else {
                [voiceMessageCell resetPlayer];
            }
            return voiceMessageCell;
        }
        NSString *fileCellIdentifier = (message.isGroupMessage) ? GroupedFileMessageCellIdentifier : FileMessageCellIdentifier;
        FileMessageTableViewCell *fileCell = (FileMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:fileCellIdentifier];
        fileCell.delegate = self;
        
        [fileCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];

        return fileCell;
    }
    if (message.geoLocation) {
        NSString *locationCellIdentifier = (message.isGroupMessage) ? GroupedLocationMessageCellIdentifier : LocationMessageCellIdentifier;
        LocationMessageTableViewCell *locationCell = (LocationMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:locationCellIdentifier];
        locationCell.delegatse = self;
        
        [locationCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];

        return locationCell;
    }
    if (message.poll) {
        NSString *pollCellIdentifier = (message.isGroupMessage) ? GroupedObjectShareMessageCellIdentifier : ObjectShareMessageCellIdentifier;
        ObjectShareMessageTableViewCell *pollCell = (ObjectShareMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:pollCellIdentifier];
        pollCell.delegate = self;
        
        [pollCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];

        return pollCell;
    }
    if (message.parent) {
        ChatMessageTableViewCell *replyCell = (ChatMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:ReplyMessageCellIdentifier];
        replyCell.delegate = self;
        
        [replyCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];
        
        return replyCell;
    }
    if (message.isGroupMessage) {
        GroupedChatMessageTableViewCell *groupedCell = (GroupedChatMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:GroupedChatMessageCellIdentifier];
        groupedCell.delegate = self;
        [groupedCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];
        
        return groupedCell;
    } else {
        ChatMessageTableViewCell *normalCell = (ChatMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:ChatMessageCellIdentifier];
        normalCell.delegate = self;
        [normalCell setupForMessage:message withLastCommonReadMessage:_room.lastCommonReadMessage];
        
        return normalCell;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView isEqual:self.tableView]) {
        NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
        
        CGFloat width = CGRectGetWidth(tableView.frame) - kChatCellAvatarHeight;
        width -= tableView.safeAreaInsets.left + tableView.safeAreaInsets.right;
        
        return [self getCellHeightForMessage:message withWidth:width];
    }
    else {
        return kChatMessageCellMinimumHeight;
    }
}

- (CGFloat)getCellHeightForMessage:(NCChatMessage *)message withWidth:(CGFloat)width
{
    // Chat separators
    if (message.messageId == kUnreadMessagesSeparatorIdentifier ||
        message.messageId == kChatBlockSeparatorIdentifier) {
        return kMessageSeparatorCellHeight;
    }
    
    // Update messages (the ones that notify about an update in one message, they should not be displayed)
    if (message.message.length == 0 || [message isUpdateMessage] || ([message isCollapsed] && message.collapsedBy > 0)) {
        return 0.0;
    }
    
    // Chat messages
    NSMutableAttributedString *messageString = message.parsedMarkdownForChat;
    width -= (message.isSystemMessage)? 80.0 : 30.0; // 4*right(10) + dateLabel(40) : 3*right(10)
    if (message.poll) {
        messageString = [[NSMutableAttributedString alloc] initWithString:message.poll.name];
        [messageString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:[ObjectShareMessageTableViewCell defaultFontSize]] range:NSMakeRange(0,messageString.length)];
        width -= kObjectShareMessageCellObjectTypeImageSize + 25; // 2*right(10) + left(5)
    }
    if (message.collapsedMessage && message.isCollapsed) {
        messageString = [[NSMutableAttributedString alloc] initWithString:message.collapsedMessage];
        [messageString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:[SystemMessageTableViewCell defaultFontSize]] range:NSMakeRange(0,messageString.length)];
    }

    // Calculate the height of the message. "boundingRectWithSize" does not work correctly with markdown, so we use this
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:messageString];
    CGRect targetBounding = CGRectMake(0, 0, width, CGFLOAT_MAX);
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:targetBounding.size];
    container.lineFragmentPadding = 0;

    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    [manager addTextContainer:container];
    [textStorage addLayoutManager:manager];

    [manager glyphRangeForBoundingRect:targetBounding inTextContainer:container];
    CGRect bodyBounds = [manager usedRectForTextContainer:container];
    
    CGFloat height = kChatCellAvatarHeight;
    height += ceil(CGRectGetHeight(bodyBounds));
    height += 20.0; // right(10) + 2*left(5)
    
    if (height < kChatMessageCellMinimumHeight) {
        height = kChatMessageCellMinimumHeight;
    }
    
    if (message.reactionsArray.count > 0) {
        height += 40; // reactionsView(40)
    }

    if (message.containsURL) {
        height += 105;
    }
    
    if (message.parent) {
        height += 55; // left(5) + quoteView(50)
        return height;
    }
    
    if (message.isGroupMessage || message.isSystemMessage) {
        height = ceil(CGRectGetHeight(bodyBounds)) + 10; // 2*left(5)
        
        if (height < kGroupedChatMessageCellMinimumHeight) {
            height = kGroupedChatMessageCellMinimumHeight;
        }
        
        if (message.reactionsArray.count > 0) {
            height += 40; // reactionsView(40)
        }

        if (message.containsURL) {
            height += 105;
        }
    }
    
    // Voice message should be before message.file check since it contains a file
    if (message.isVoiceMessage) {
        height -= ceil(CGRectGetHeight(bodyBounds));
        return height += kVoiceMessageCellPlayerHeight + 10; // right(10)
    }
    
    // Voice message should be before message.file check since it contains a file
    if (message.isVoiceMessage) {
        height -= ceil(CGRectGetHeight(bodyBounds));
        return height += kVoiceMessageCellPlayerHeight + 10; // right(10)
    }
    
    if (message.file) {
        height += message.file.previewImageHeight == 0 ? kFileMessageCellFileMaxPreviewHeight + 10 : message.file.previewImageHeight + 10; // right(10)
        
        // if the message is a media file, reduce the message height by the bodyTextView height to hide it since it usually just contains an autogenerated file name (e.g. IMG_1234.jpg)
        if ([NCUtils isImageFileType:message.file.mimetype] || [NCUtils isVideoFileType:message.file.mimetype]) {
            // Only hide the filename if there's a preview available
            if (message.file.previewAvailable) {
                height -= ceil(CGRectGetHeight(bodyBounds));
            }
        }
        
        return height;
    }
    
    if (message.geoLocation) {
        return height += kLocationMessageCellPreviewHeight + 10; // right(10)
    }
    
    if (message.poll) {
        return height += 20; // 2*right(10)
    }
    
    if (message.geoLocation) {
        return height += kLocationMessageCellPreviewHeight + 10; // right(10)
    }
    
    if (message.poll) {
        return height += 20; // 2*right(10)
    }
    
    return height;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView isEqual:self.autoCompletionView]) {
        if (!_autocompletionUsers || indexPath.row >= [_autocompletionUsers count] || !_autocompletionUsers[indexPath.row]) {
            return;
        }

        NCMessageParameter *mention = [[NCMessageParameter alloc] init];
        mention.parameterId = [self.autocompletionUsers[indexPath.row] objectForKey:@"id"];
        mention.name = [self.autocompletionUsers[indexPath.row] objectForKey:@"label"];
        mention.mentionDisplayName = [NSString stringWithFormat:@"@%@", mention.name];
        mention.mentionId = [NSString stringWithFormat:@"@%@", [self.autocompletionUsers[indexPath.row] objectForKey:@"id"]];
        // Guest mentions are wrapped with double quotes @"guest/<sha1(webrtc session id)>"
        if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"guests"]) {
            mention.mentionId = [NSString stringWithFormat:@"@\"%@\"", mention.parameterId];
        }
        // Group mentions are wrapped with double quotes @"group/groupId"
        if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"groups"]) {
            mention.mentionId = [NSString stringWithFormat:@"@\"%@\"", mention.parameterId];
        }
        // User-ids with a space should be wrapped in double quoutes
        NSRange whiteSpaceRange = [mention.parameterId rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
        if (whiteSpaceRange.location != NSNotFound) {
            mention.mentionId = [NSString stringWithFormat:@"@\"%@\"", mention.parameterId];
        }
        // Set parameter type
        if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"calls"]) {
            mention.type = @"call";
        } else if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"users"]) {
            mention.type = @"user";
        } else if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"guests"]) {
            mention.type = @"guest";
        } else if ([[self.autocompletionUsers[indexPath.row] objectForKey:@"source"] isEqualToString:@"groups"]) {
            mention.type = @"user-group";
        }
        
        NSString *mentionKey = [NSString stringWithFormat:@"mention-%ld", _mentionsDict.allKeys.count];
        [_mentionsDict setObject:mention forKey:mentionKey];
        
        NSString *mentionWithWhiteSpace = [NSString stringWithFormat:@"%@ ", mention.name];
        [self acceptAutoCompletionWithString:mentionWithWhiteSpace keepPrefix:YES];
    } else {
        [self.emojiTextField resignFirstResponder];
        [self.datePickerTextField resignFirstResponder];

        NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
        if (message.collapsedMessages.count > 0) {
            [self cellWantsToCollapseMessagesWithMessage:message];
        }

        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - iOS >=13 message long press menu

- (BOOL)isMessageReplyable:(NCChatMessage *)message
{
    return message.isReplyable && !message.isDeleting;
}

- (BOOL)isMessageReactable:(NCChatMessage *)message
{
    BOOL isReactable = [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityReactions];
    isReactable &= !_offlineMode;
    isReactable &= _room.readOnlyState != NCRoomReadOnlyStateReadOnly;
    isReactable &= !message.isDeletedMessage && !message.isCommandMessage && !message.sendingFailed && !message.isTemporary;
    
    return isReactable;
}

- (NSArray *)getSetReminderOptionsForMessage:(NCChatMessage *)message
{
    NSMutableArray *reminderOptions = [[NSMutableArray alloc] init];
    NSDate *now = [NSDate date];

    NSInteger sunday = 1;
    NSInteger monday = 2;
    NSInteger saturday = 7;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"EEE"];

    void (^setReminderCompletion)(NSError * error) = ^void(NSError *error) {
        if (error) {
            [[JDStatusBarNotificationPresenter sharedPresenter] presentWithText:NSLocalizedString(@"Error occurred when creating a reminder", @"") dismissAfterDelay:5.0 includedStyle:JDStatusBarNotificationIncludedStyleError];
        } else {
            [[JDStatusBarNotificationPresenter sharedPresenter] presentWithText:NSLocalizedString(@"Reminder was successfully set", @"") dismissAfterDelay:5.0 includedStyle:JDStatusBarNotificationIncludedStyleSuccess];
        }
    };

    // Remind me later today
    NSDate *reminderTime = [NCUtils todayWithHour:18 withMinute:0 withSecond:0];
    UIAction *laterToday = [UIAction actionWithTitle:NSLocalizedString(@"Later today", @"Remind me later today about that message") image:nil identifier:nil handler:^(UIAction *action) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [reminderTime timeIntervalSince1970]];

        [[NCAPIController sharedInstance] setReminderForMessage:message withTimestamp:timestamp withCompletionBlock:setReminderCompletion];
    }];
    laterToday.subtitle = [NCUtils getTimeFromDate:reminderTime];

    // Remind me tomorrow
    reminderTime = [[NCUtils todayWithHour:8 withMinute:0 withSecond:0] dateByAddingDays:1];
    UIAction *tomorrow = [UIAction actionWithTitle:NSLocalizedString(@"Tomorrow", @"Remind me tomorrow about that message") image:nil identifier:nil handler:^(UIAction *action) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [reminderTime timeIntervalSince1970]];

        [[NCAPIController sharedInstance] setReminderForMessage:message withTimestamp:timestamp withCompletionBlock:setReminderCompletion];
    }];
    tomorrow.subtitle = [NSString stringWithFormat:@"%@, %@", [formatter stringFromDate:reminderTime], [NCUtils getTimeFromDate:reminderTime]];

    // Remind me next saturday
    reminderTime = [NCUtils todayWithHour:8 withMinute:0 withSecond:0];
    reminderTime = [NCUtils setWeekday:saturday withDate:reminderTime];
    UIAction *thisWeekend = [UIAction actionWithTitle:NSLocalizedString(@"This weekend", @"Remind me this weekend about that message") image:nil identifier:nil handler:^(UIAction *action) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [reminderTime timeIntervalSince1970]];

        [[NCAPIController sharedInstance] setReminderForMessage:message withTimestamp:timestamp withCompletionBlock:setReminderCompletion];
    }];
    thisWeekend.subtitle = [NSString stringWithFormat:@"%@, %@", [formatter stringFromDate:reminderTime], [NCUtils getTimeFromDate:reminderTime]];

    // Remind me next monday
    reminderTime = [[NCUtils todayWithHour:8 withMinute:0 withSecond:0] dateByAddingWeeks:1];
    reminderTime = [NCUtils setWeekday:monday withDate:reminderTime];
    UIAction *nextWeek = [UIAction actionWithTitle:NSLocalizedString(@"Next week", @"Remind me next week about that message") image:nil identifier:nil handler:^(UIAction *action) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [reminderTime timeIntervalSince1970]];

        [[NCAPIController sharedInstance] setReminderForMessage:message withTimestamp:timestamp withCompletionBlock:setReminderCompletion];
    }];
    nextWeek.subtitle = [NSString stringWithFormat:@"%@, %@", [formatter stringFromDate:reminderTime], [NCUtils getTimeFromDate:reminderTime]];

    // Custom reminder
    __weak typeof(self) weakSelf = self;
    UIAction *customReminderAction = [UIAction actionWithTitle:NSLocalizedString(@"Pick date & time", @"") image:[UIImage systemImageNamed:@"calendar.badge.clock"] identifier:nil handler:^(UIAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.interactingMessage = message;
            weakSelf.lastMessageBeforeInteraction = [[weakSelf.tableView indexPathsForVisibleRows] lastObject];

            NSDate *startingDate = [now dateByAddingHours:1];
            NSDate *minimumDate = [now dateByAddingMinutes:15];
            [weakSelf.datePickerTextField getDateWithStartingDate:startingDate minimumDate:minimumDate completion:^(NSDate * _Nonnull selectedDate) {
                NSString *timestamp = [NSString stringWithFormat:@"%.0f", [selectedDate timeIntervalSince1970]];

                [[NCAPIController sharedInstance] setReminderForMessage:message withTimestamp:timestamp withCompletionBlock:setReminderCompletion];
            }];
        });
    }];

    // Show custom reminder with a separator -> use inline menu
    UIMenu *customReminder = [UIMenu menuWithTitle:@""
                                             image:nil
                                        identifier:nil
                                           options:UIMenuOptionsDisplayInline
                                          children:@[customReminderAction]];

    if (now.hour < 18) {
        [reminderOptions addObject:laterToday];
    }

    [reminderOptions addObject:tomorrow];

    if (now.weekday != sunday && now.weekday != saturday) {
        [reminderOptions addObject:thisWeekend];
    }

    [reminderOptions addObject:nextWeek];
    [reminderOptions addObject:customReminder];

    return reminderOptions;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    if ([tableView isEqual:self.autoCompletionView]) {
        return nil;
    }
    
    // Do not show context menu if long pressing in reactions view
    ChatTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    CGPoint pointInCell = [tableView convertPoint:point toView:cell];
    for (UIView *subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:ReactionsView.class] && CGRectContainsPoint(subview.frame, pointInCell)) {
            [self showReactionsSummaryOfMessage:cell.message];
            return nil;
        }
    }
    
    NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
    NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
    
    if (message.isSystemMessage || message.messageId == kUnreadMessagesSeparatorIdentifier) {
        return nil;
    }
        
    NSMutableArray *actions = [[NSMutableArray alloc] init];

    BOOL hasChatPermission = ![[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityChatPermission] || (_room.permissions & NCPermissionChat) != 0;

    // Reply option
    if ([self isMessageReplyable:message] && hasChatPermission) {
        UIImage *replyImage = [UIImage systemImageNamed:@"arrowshape.turn.up.left"];
        UIAction *replyAction = [UIAction actionWithTitle:NSLocalizedString(@"Reply", nil) image:replyImage identifier:nil handler:^(UIAction *action){
            
            [self didPressReply:message];
        }];
        
        [actions addObject:replyAction];
    }

    // Reply-privately option (only to other users and not in one-to-one)
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    if ([self isMessageReplyable:message] && _room.type != kNCRoomTypeOneToOne && [message.actorType isEqualToString:@"users"] && ![message.actorId isEqualToString:activeAccount.userId] )
    {
        UIImage *replyPrivateImage = [UIImage systemImageNamed:@"person"];
        UIAction *replyPrivateAction = [UIAction actionWithTitle:NSLocalizedString(@"Reply privately", nil) image:replyPrivateImage identifier:nil handler:^(UIAction *action){
            
            [self didPressReplyPrivately:message];
        }];
        
        [actions addObject:replyPrivateAction];
    }
    
    // Forward option (only normal messages for now)
    if (!message.file && !message.poll && !message.isDeletedMessage) {
        UIImage *forwardImage = [UIImage systemImageNamed:@"arrowshape.turn.up.right"];
        UIAction *forwardAction = [UIAction actionWithTitle:NSLocalizedString(@"Forward", nil) image:forwardImage identifier:nil handler:^(UIAction *action){
            
            [self didPressForward:message];
        }];
        
        [actions addObject:forwardAction];
    }
    
    // Add reaction option
    if ([[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityReactions] && !_offlineMode) {
        UIImage *reactionImage = [[UIImage imageNamed:@"emoji"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIAction *reactionAction = [UIAction actionWithTitle:NSLocalizedString(@"Add reaction", nil) image:reactionImage identifier:nil handler:^(UIAction *action){
            
            [self didPressAddReaction:message atIndexPath:indexPath];
        }];
        
        [actions addObject:reactionAction];
    }
    
    // Reply-privately option (only to other users and not in one-to-one)
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    if ([self isMessageReplyable:message] && _room.type != kNCRoomTypeOneToOne && [message.actorType isEqualToString:@"users"] && ![message.actorId isEqualToString:activeAccount.userId] )
    {
        UIImage *replyPrivateImage = [[UIImage imageNamed:@"user"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIAction *replyPrivateAction = [UIAction actionWithTitle:NSLocalizedString(@"Reply privately", nil) image:replyPrivateImage identifier:nil handler:^(UIAction *action){
            
            [self didPressReplyPrivately:message];
        }];
        
        [actions addObject:replyPrivateAction];
    }
    
    // Forward option (only normal messages for now)
    if (!message.file && !message.poll && !message.isDeletedMessage) {
        UIImage *forwardImage = [[UIImage imageNamed:@"forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIAction *forwardAction = [UIAction actionWithTitle:NSLocalizedString(@"Forward", nil) image:forwardImage identifier:nil handler:^(UIAction *action){
            
            [self didPressForward:message];
        }];
        
        [actions addObject:forwardAction];
    }

    // Remind me later
    if (!message.sendingFailed && !message.isOfflineMessage && !message.isDeletedMessage && [[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityRemindMeLater]) {
        UIImage *remindMeLaterImage = [UIImage systemImageNamed:@"alarm"];

        __weak typeof(self) weakSelf = self;
        UIDeferredMenuElement *deferredMenuElement = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^ _Nonnull completion)(NSArray<UIMenuElement *> * _Nonnull)) {
            [[NCAPIController sharedInstance] getReminderForMessage:message withCompletionBlock:^(NSDictionary *responseDict, NSError *error) {
                NSMutableArray *menuOptions = [[NSMutableArray alloc] init];

                [menuOptions addObjectsFromArray:[weakSelf getSetReminderOptionsForMessage:message]];

                if (responseDict && !error) {
                    // There's already an existing reminder set for this message
                    // -> offer a delete option
                    NSInteger timestamp = [[responseDict objectForKey:@"timestamp"] intValue];
                    NSDate *timestampDate = [NSDate dateWithTimeIntervalSince1970:timestamp];

                    UIAction *clearAction = [UIAction actionWithTitle:NSLocalizedString(@"Clear reminder", @"") image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *action){
                        [[NCAPIController sharedInstance] deleteReminderForMessage:message withCompletionBlock:^(NSError *error) {
                            [[JDStatusBarNotificationPresenter sharedPresenter] presentWithText:NSLocalizedString(@"Reminder was successfully cleared", @"") dismissAfterDelay:5.0 includedStyle:JDStatusBarNotificationIncludedStyleSuccess];
                        }];
                    }];
                    clearAction.subtitle = [NCUtils readableDateTimeFromDate:timestampDate];
                    clearAction.attributes = UIMenuElementAttributesDestructive;

                    UIMenu *clearReminder = [UIMenu menuWithTitle:@""
                                                            image:nil
                                                       identifier:nil
                                                          options:UIMenuOptionsDisplayInline
                                                         children:@[clearAction]];

                    [menuOptions addObject:clearReminder];
                }

                completion(menuOptions);
            }];
        }];

        UIMenu *remindeMeLaterMenu = [UIMenu menuWithTitle:NSLocalizedString(@"Set reminder", @"Remind me later about that message")
                                                     image:remindMeLaterImage
                                                identifier:nil
                                                   options:0
                                                  children:@[deferredMenuElement]];

        [actions addObject:remindeMeLaterMenu];
    }

    // Re-send option
    if ((message.sendingFailed || message.isOfflineMessage) && hasChatPermission) {
        UIImage *resendImage = [UIImage systemImageNamed:@"arrow.clockwise"];
        UIAction *resendAction = [UIAction actionWithTitle:NSLocalizedString(@"Resend", nil) image:resendImage identifier:nil handler:^(UIAction *action){
            
            [self didPressResend:message];
        }];
        
        [actions addObject:resendAction];
    }
    
    // Copy option
    UIImage *copyImage = [UIImage systemImageNamed:@"square.on.square"];
    UIAction *copyAction = [UIAction actionWithTitle:NSLocalizedString(@"Copy", nil) image:copyImage identifier:nil handler:^(UIAction *action){
        
        [self didPressCopy:message];
    }];
    
    [actions addObject:copyAction];
    
    // Translate
    if (!message.isDeletedMessage && !_offlineMode && [[NCSettingsController sharedInstance] availableTranslations].count > 0) {
        UIImage *translateImage = [UIImage systemImageNamed:@"character.book.closed"];
        UIAction *translateAction = [UIAction actionWithTitle:NSLocalizedString(@"Translate", nil) image:translateImage identifier:nil handler:^(UIAction *action){

            [self didPressTranslate:message];
        }];

        [actions addObject:translateAction];
    }

    // Open in nextcloud option
    if (message.file && !_offlineMode) {
        NSString *openInNextcloudTitle = [NSString stringWithFormat:NSLocalizedString(@"Open in %@", nil), filesAppName];
        UIImage *nextcloudActionImage = [[UIImage imageNamed:@"logo-action"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIAction *openInNextcloudAction = [UIAction actionWithTitle:openInNextcloudTitle image:nextcloudActionImage identifier:nil handler:^(UIAction *action){
            
            [self didPressOpenInNextcloud:message];
        }];

        [actions addObject:openInNextcloudAction];
    }
    
    // Transcribe voice-message
    if ([message.messageType isEqualToString:kMessageTypeVoiceMessage]) {
        UIImage *transcribeActionImage = [UIImage systemImageNamed:@"text.bubble"];
        UIAction *transcribeAction = [UIAction actionWithTitle:NSLocalizedString(@"Transcribe", @"TRANSLATORS this is for transcribing a voice message to text") image:transcribeActionImage identifier:nil handler:^(UIAction *action){
            
            [self didPressTranscribeVoiceMessage:message];
        }];

        [actions addObject:transcribeAction];
    }
    

    // Delete option
    if (message.sendingFailed || message.isOfflineMessage || ([message isDeletableForAccount:[[NCDatabaseManager sharedInstance] activeAccount] andParticipantType:_room.participantType] && hasChatPermission)) {
        UIImage *deleteImage = [UIImage systemImageNamed:@"trash"];
        UIAction *deleteAction = [UIAction actionWithTitle:NSLocalizedString(@"Delete", nil) image:deleteImage identifier:nil handler:^(UIAction *action){
            
            [self didPressDelete:message];
        }];
    
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:deleteAction];
    }
    
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:actions];

    UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
        return nil;
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return menu;
    }];

    return configuration;
}

- (void)tableView:(UITableView *)tableView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [animator addAnimations:^{
        // Only set these, when the context menu is fully visible
        self->_contextMenuReactionView.alpha = 1;
        self->_contextMenuMessageView.layer.cornerRadius = 10;
        self->_contextMenuMessageView.layer.mask = nil;
    }];
}

- (void)tableView:(UITableView *)tableView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [animator addCompletion:^{
        // Wait until the context menu is completely hidden before we execut any method
        if (self->_contextMenuActionBlock) {
            self->_contextMenuActionBlock();
            self->_contextMenuActionBlock = nil;
        }
    }];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    NSIndexPath *indexPath = (NSIndexPath *)configuration.identifier;
    NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
    NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];

    CGFloat maxPreviewWidth = self.view.bounds.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right;
    CGFloat maxPreviewHeight = self.view.bounds.size.height * 0.6;

    // TODO: Take padding into account
    CGFloat maxTextWidth = maxPreviewWidth - kChatCellAvatarHeight;

    // We need to get the height of the original cell to center the preview correctly (as the preview is always non-grouped)
    CGFloat heightOfOriginalCell = [self getCellHeightForMessage:message withWidth:maxTextWidth];

    // Remember grouped-status -> Create a previewView which always is a non-grouped-message
    BOOL isGroupMessage = message.isGroupMessage;
    message.isGroupMessage = NO;

    UITableViewCell *previewTableViewCell = [self getCellForMessage:message];
    CGFloat cellHeight = [self getCellHeightForMessage:message withWidth:maxTextWidth];

    // Cut the height if bigger than max height
    if (cellHeight > maxPreviewHeight) {
        cellHeight = maxPreviewHeight;
    }

    // Use the contentView of the UITableViewCell as a preview view
    UIView *previewMessageView = previewTableViewCell.contentView;
    previewMessageView.frame = CGRectMake(0, 0, maxPreviewWidth, cellHeight);
    previewMessageView.layer.masksToBounds = YES;

    // Create a mask to not show the avatar part when showing a grouped messages while animating
    // The mask will be reset in willDisplayContextMenuWithConfiguration so the avatar is visible when the context menu is shown
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect maskRect = CGRectMake(0, previewMessageView.frame.size.height - heightOfOriginalCell, previewMessageView.frame.size.width, heightOfOriginalCell);
    CGPathRef path = CGPathCreateWithRect(maskRect, NULL);
    maskLayer.path = path;
    CGPathRelease(path);

    previewMessageView.layer.mask = maskLayer;
    [previewMessageView setBackgroundColor:UIColor.systemBackgroundColor];
    self.contextMenuMessageView = previewMessageView;

    // Restore grouped-status
    message.isGroupMessage = isGroupMessage;

    UIView *containerView;
    CGPoint cellCenter;

    BOOL hasChatPermission = ![[NCDatabaseManager sharedInstance] serverHasTalkCapability:kCapabilityChatPermission] || (_room.permissions & NCPermissionChat) != 0;

    if ([self isMessageReactable:message] && hasChatPermission) {
        NSInteger reactionViewPadding = 10;
        NSInteger emojiButtonPadding = 10;
        NSInteger emojiButtonSize = 48;
        NSArray *frequentlyUsedEmojis = [[NSArray alloc] initWithObjects:@"👍", @"❤️", @"😂", @"😅", nil];

        NSInteger totalEmojiButtonWidth = [frequentlyUsedEmojis count] * emojiButtonSize;
        NSInteger totalEmojiButtonPadding = [frequentlyUsedEmojis count] * emojiButtonPadding;
        NSInteger addButtonWidth = emojiButtonSize + emojiButtonPadding;

        // We need to add an extra padding to the right so the buttons are correctly padded
        NSInteger reactionViewWidth = totalEmojiButtonWidth + totalEmojiButtonPadding + addButtonWidth + emojiButtonPadding;
        UIView *reactionView = [[UIView alloc] initWithFrame:CGRectMake(0, cellHeight + reactionViewPadding, reactionViewWidth, emojiButtonSize)];
        self->_contextMenuReactionView = reactionView;

        NSInteger positionX = emojiButtonPadding;
        __weak typeof(self) weakSelf = self;

        for (NSString *emoji in frequentlyUsedEmojis) {
            UIAction *reactionShortcut = [UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(UIAction *action) {
                [self.tableView.contextMenuInteraction dismissMenu];

                // Since we want to set the emoji only after the context menu disappeared, we store a block to execute afterwards
                self->_contextMenuActionBlock = ^void() {
                    [weakSelf addReaction:emoji toChatMessage:message];
                };
            }];

            UIButton *emojiShortcutButton = [UIButton buttonWithType:UIButtonTypeSystem];
            emojiShortcutButton.frame = CGRectMake(positionX, 0, emojiButtonSize, emojiButtonSize);
            emojiShortcutButton.layer.cornerRadius = emojiButtonSize / 2;

            [emojiShortcutButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
            [emojiShortcutButton addAction:reactionShortcut forControlEvents:UIControlEventTouchUpInside];
            [emojiShortcutButton setTitle:emoji forState:UIControlStateNormal];
            [emojiShortcutButton setBackgroundColor:UIColor.systemBackgroundColor];

            // Disable shortcuts, if we already reacted with that emoji
            for (NCChatReaction *reaction in message.reactionsArray) {
                if ([reaction.reaction isEqualToString:emoji] && reaction.userReacted) {
                    [emojiShortcutButton setEnabled:NO];
                    emojiShortcutButton.alpha = 0.4;
                }
            }

            [reactionView addSubview:emojiShortcutButton];

            positionX += emojiButtonSize + emojiButtonPadding;
        }

        UIAction *addReactionAction = [UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(UIAction *action) {
            [self.tableView.contextMenuInteraction dismissMenu];

            // Since we want to set the emoji only after the context menu disappeared, we store a block to execute afterwards
            self->_contextMenuActionBlock = ^void() {
                [weakSelf didPressAddReaction:message atIndexPath:indexPath];
            };
        }];

        UIButton *addReactionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        addReactionButton.frame = CGRectMake(positionX, 0, emojiButtonSize, emojiButtonSize);
        addReactionButton.layer.cornerRadius = emojiButtonSize / 2;

        [addReactionButton.titleLabel setFont:[UIFont systemFontOfSize:22]];
        [addReactionButton addAction:addReactionAction forControlEvents:UIControlEventTouchUpInside];
        [addReactionButton setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
        [addReactionButton setTintColor:UIColor.labelColor];
        [addReactionButton setBackgroundColor:UIColor.systemBackgroundColor];

        [reactionView addSubview:addReactionButton];

        // The reactionView will be shown after the animation finishes, otherwise we see the view already when animating and this looks odd
        reactionView.alpha = 0;
        reactionView.layer.cornerRadius = emojiButtonSize / 2;
        [reactionView setBackgroundColor:UIColor.systemBackgroundColor];

        containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maxPreviewWidth, cellHeight + emojiButtonSize + reactionViewPadding)];
        containerView.backgroundColor = UIColor.clearColor;
        [containerView addSubview:previewMessageView];
        [containerView addSubview:reactionView];

        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

        // On large iPhones (with regular landscape size, like iPhone X) we need to take the safe area into account when calculating the center
        CGFloat cellCenterX = cell.center.x + self.view.safeAreaInsets.left / 2 - self.view.safeAreaInsets.right / 2;
        cellCenter = CGPointMake(cellCenterX, cell.center.y + (emojiButtonSize + reactionViewPadding) / 2 - (cellHeight - heightOfOriginalCell) / 2);
    } else {
        containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maxPreviewWidth, cellHeight)];
        containerView.backgroundColor = UIColor.clearColor;
        [containerView addSubview:previewMessageView];

        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        // On large iPhones (with regular landscape size, like iPhone X) we need to take the safe area into account when calculating the center
        CGFloat cellCenterX = cell.center.x + self.view.safeAreaInsets.left / 2 - self.view.safeAreaInsets.right / 2;
        cellCenter = CGPointMake(cellCenterX, cell.center.y - (cellHeight - heightOfOriginalCell) / 2);
    }

    // Create a preview target which allows us to have a transparent background
    UIPreviewTarget *previewTarget = [[UIPreviewTarget alloc] initWithContainer:self.tableView center:cellCenter];
    UIPreviewParameters *previewParameter = [[UIPreviewParameters alloc] init];

    // Remove the background and the drop shadow from our custom preview view
    previewParameter.backgroundColor = UIColor.clearColor;
    previewParameter.shadowPath = [[UIBezierPath alloc] init];

    return [[UITargetedPreview alloc] initWithView:containerView parameters:previewParameter target:previewTarget];
}

#pragma mark - FileMessageTableViewCellDelegate

- (void)cellWantsToDownloadFile:(NCMessageFileParameter *)fileParameter
{
    if (fileParameter.fileStatus && fileParameter.fileStatus.isDownloading) {
        NSLog(@"File already downloading -> skipping new download");
        return;
    }
    
    NCChatFileController *downloader = [[NCChatFileController alloc] init];
    downloader.delegate = self;
    [downloader downloadFileFromMessage:fileParameter];
}

- (void)cellHasDownloadedImagePreviewWithHeight:(CGFloat)height forMessage:(NCChatMessage *)message
{
    if (message.file.previewImageHeight == height) {
        return;
    }
    
    BOOL isAtBottom = [self shouldScrollOnNewMessages];

    [message setPreviewImageHeight:height];

    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            // make sure we're really at the bottom after updating a message since the file previews could grow in size if they contain a media file preview, thus giving the effect of not being at the bottom of the chat
            if (isAtBottom && !self.tableView.isDecelerating) {
                [self.tableView slk_scrollToBottomAnimated:YES];
                [self updateToolbar:YES];
            }
        });
    }];

    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    
    [CATransaction commit];
}
#pragma mark - VoiceMessageTableViewCellDelegate

- (void)cellWantsToPlayAudioFile:(NCMessageFileParameter *)fileParameter
{
    if (fileParameter.fileStatus && fileParameter.fileStatus.isDownloading) {
        NSLog(@"File already downloading -> skipping new download");
        return;
    }
    
    if (!_voiceMessagesPlayer.isPlaying && [fileParameter.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [fileParameter.path isEqualToString:_playerAudioFileStatus.filePath]) {
        [self playVoiceMessagePlayer];
        return;
    }
    
    NCChatFileController *downloader = [[NCChatFileController alloc] init];
    downloader.delegate = self;
    downloader.messageType = kMessageTypeVoiceMessage;
    [downloader downloadFileFromMessage:fileParameter];
}

- (void)cellWantsToPauseAudioFile:(NCMessageFileParameter *)fileParameter
{
    if (_voiceMessagesPlayer.isPlaying && [fileParameter.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [fileParameter.path isEqualToString:_playerAudioFileStatus.filePath]) {
        [self pauseVoiceMessagePlayer];
    }
}

- (void)cellWantsToChangeProgress:(CGFloat)progress fromAudioFile:(NCMessageFileParameter *)fileParameter
{
    if ([fileParameter.parameterId isEqualToString:_playerAudioFileStatus.fileId] && [fileParameter.path isEqualToString:_playerAudioFileStatus.filePath]) {
        [self pauseVoiceMessagePlayer];
        [_voiceMessagesPlayer setCurrentTime:progress];
        [self checkVisibleCellAudioPlayers];
    }
}

#pragma mark - LocationMessageTableViewCellDelegate

- (void)cellWantsToOpenLocation:(GeoLocationRichObject *)geoLocationRichObject
{
    MapViewController *mapVC = [[MapViewController alloc] initWithGeoLocationRichObject:geoLocationRichObject];
    NCNavigationController *mapNC = [[NCNavigationController alloc] initWithRootViewController:mapVC];
    [self presentViewController:mapNC animated:YES completion:nil];
}

#pragma mark - ObjectShareMessageTableViewCellDelegate

- (void)cellWantsToOpenPoll:(NCMessageParameter *)poll
{
    PollVotingView *pollVC = [[PollVotingView alloc] initWithStyle:UITableViewStyleInsetGrouped];
    pollVC.room = _room;
    NCNavigationController *pollNC = [[NCNavigationController alloc] initWithRootViewController:pollVC];
    [self presentViewController:pollNC animated:YES completion:nil];
    
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] getPollWithId:poll.parameterId.integerValue inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NCPoll *poll, NSError *error, NSInteger statusCode) {
        if (!error) {
            [pollVC updatePollWithPoll:poll];
        }
    }];
}

#pragma mark - PollCreationViewControllerDelegate

- (void)pollCreationViewControllerWantsToCreatePollWithPollCreationViewController:(PollCreationViewController *)pollCreationViewController question:(NSString *)question options:(NSArray<NSString *> *)options resultMode:(NCPollResultMode)resultMode maxVotes:(NSInteger)maxVotes
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] createPollWithQuestion:question options:options resultMode:resultMode maxVotes:maxVotes inRoom:_room.token forAccount:activeAccount withCompletionBlock:^(NCPoll *poll, NSError *error, NSInteger statusCode) {
        if (error) {
            [pollCreationViewController showCreationError];
        } else {
            [pollCreationViewController close];
        }
    }];
}

#pragma mark - SystemMessageTableViewCellDelegate

- (void)cellWantsToCollapseMessagesWithMessage:(NCChatMessage *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{

        BOOL collapse = !message.isCollapsed;
        NSArray *messageIds = [message.collapsedMessages valueForKey:@"self"];
        NSMutableArray *reloadIndexPaths = [NSMutableArray new];

        NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:message.messageId];
        if (indexPath) {
            [reloadIndexPaths addObject:indexPath];
            message.isCollapsed = collapse;
        }

        for (NSNumber *messageId in messageIds) {
            NSIndexPath *indexPath = [self indexPathForMessageWithMessageId:messageId.intValue];
            if (indexPath) {
                [reloadIndexPaths addObject:indexPath];
                NSDate *keyDate = [self->_dateSections objectAtIndex:indexPath.section];
                NSMutableArray *messages = [self->_messages objectForKey:keyDate];
                NCChatMessage *message = messages[indexPath.row];
                message.isCollapsed = collapse;
            }
        }

        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    });
}

#pragma mark - ChatMessageTableViewCellDelegate

- (void)cellWantsToScrollToMessage:(NCChatMessage *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [self indexPathForMessage:message];
        if (indexPath) {
            [self highlightMessageAtIndexPath:indexPath withScrollPosition:UITableViewScrollPositionTop];
        }
    });
}

- (void)cellDidSelectedReaction:(NCChatReaction *)reaction forMessage:(NCChatMessage *)message
{
    [self addOrRemoveReaction:reaction inChatMessage:message];
}

- (void)cellWantsToDisplayOptionsForMessageActor:(NCChatMessage *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [self indexPathForMessage:message];
        TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
        if (indexPath && [message.actorType isEqualToString:@"users"] && ![message.actorId isEqualToString:activeAccount.userId]) {
            [self presentOptionsForMessageActor:message fromIndexPath:indexPath];
        }
    });
}

- (void)cellDidSelectedReaction:(NCChatReaction *)reaction forMessage:(NCChatMessage *)message
{
    [self addOrRemoveReaction:reaction inChatMessage:message];
}

#pragma mark - NCChatFileControllerDelegate

- (void)fileControllerDidLoadFile:(NCChatFileController *)fileController withFileStatus:(NCChatFileStatus *)fileStatus
{
    if ([fileController.messageType isEqualToString:kMessageTypeVoiceMessage]) {
        if ([fileController.actionType isEqualToString:kActionTypeTranscribeVoiceMessage]) {
            [self transcribeVoiceMessageWithAudioFileStatus:fileStatus];
        } else {
            [self setupVoiceMessagePlayerWithAudioFileStatus:fileStatus];
        }
        
        return;
    }
    
    if (_isPreviewControllerShown) {
        // We are showing a file already, no need to open another one
        return;
    }
    
    BOOL isFileCellStillVisible = NO;
    
    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        NSDate *sectionDate = [_dateSections objectAtIndex:indexPath.section];
        NCChatMessage *message = [[_messages objectForKey:sectionDate] objectAtIndex:indexPath.row];
        
        if (message.file && [message.file.parameterId isEqualToString:fileStatus.fileId] && [message.file.path isEqualToString:fileStatus.filePath]) {
            isFileCellStillVisible = YES;
            break;
        }
    }
    
    if (!isFileCellStillVisible) {
        // Only open file when the corresponding cell is still visible on the screen
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_isPreviewControllerShown = YES;
        self->_previewControllerFilePath = fileStatus.fileLocalPath;

        // When the keyboard is not dismissed, dismissing the previewController might result in a corrupted keyboardView
        [self dismissKeyboard:NO];

        // When the keyboard is not dismissed, dismissing the previewController might result in a corrupted keyboardView
        [self dismissKeyboard:NO];

        NSString *extension = [[NSURL fileURLWithPath:fileStatus.fileLocalPath].pathExtension lowercaseString];

        // For WebM we use the VLCKitVideoViewController because the native PreviewController does not support WebM
        if ([extension isEqualToString:@"webm"]) {
            VLCKitVideoViewController *vlcKitViewController = [[VLCKitVideoViewController alloc] initWithFilePath:fileStatus.fileLocalPath];
            vlcKitViewController.delegate = self;
            vlcKitViewController.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:vlcKitViewController animated:YES completion:nil];

            return;
        }

        QLPreviewController * preview = [[QLPreviewController alloc] init];
        UIColor *themeColor = [NCAppBranding themeColor];
        
        preview.dataSource = self;
        preview.delegate = self;

        preview.navigationController.navigationBar.tintColor = [NCAppBranding themeTextColor];
        preview.navigationController.navigationBar.barTintColor = themeColor;
        preview.tabBarController.tabBar.tintColor = themeColor;

        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = themeColor;
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName:[NCAppBranding themeTextColor]};
        preview.navigationItem.standardAppearance = appearance;
        preview.navigationItem.compactAppearance = appearance;
        preview.navigationItem.scrollEdgeAppearance = appearance;

        [self presentViewController:preview animated:YES completion:nil];
    });
}

- (void)fileControllerDidFailLoadingFile:(NCChatFileController *)fileController withErrorDescription:(NSString *)errorDescription
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Unable to load file", nil)
                                 message:errorDescription
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:nil];
    
    [alert addAction:okButton];
    
    [[NCUserInterfaceController sharedInstance] presentAlertViewController:alert];
}

#pragma mark - QLPreviewControllerDelegate/DataSource

- (NSInteger)numberOfPreviewItemsInPreviewController:(nonnull QLPreviewController *)controller {
    return 1;
}

- (nonnull id<QLPreviewItem>)previewController:(nonnull QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [NSURL fileURLWithPath:_previewControllerFilePath];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller
{
    _isPreviewControllerShown = NO;
}

#pragma mark - VLCVideoViewControllerDelegate

- (void)vlckitVideoViewControllerDismissed:(VLCKitVideoViewController *)controller
{
    _isPreviewControllerShown = NO;
}

#pragma mark - NCChatTitleViewDelegate

- (void)chatTitleViewTapped:(NCChatTitleView *)titleView
{
    RoomInfoTableViewController *roomInfoVC = [[RoomInfoTableViewController alloc] initForRoom:_room fromChatViewController:self];
    roomInfoVC.hideDestructiveActions = _presentedInCall;
    NCSplitViewController *splitViewController = [NCUserInterfaceController sharedInstance].mainViewController;

    if (splitViewController != nil && !splitViewController.isCollapsed) {
        roomInfoVC.modalPresentationStyle = UIModalPresentationPageSheet;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:roomInfoVC];
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        [self.navigationController pushViewController:roomInfoVC animated:YES];
    }

    // When returning from RoomInfoTableViewController the default keyboard will be shown, so the height might be wrong -> make sure the keyboard is hidden
    [self dismissKeyboard:YES];
}

@end
