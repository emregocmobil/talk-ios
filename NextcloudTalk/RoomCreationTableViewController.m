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

#import "RoomCreationTableViewController.h"

#import "UIImageView+AFNetworking.h"

#import "NCAPIController.h"
#import "NCAppBranding.h"
#import "NCDatabaseManager.h"
#import "NCUtils.h"
#import "PlaceholderView.h"
#import "ResultMultiSelectionTableViewController.h"
#import "RoomCreation2TableViewController.h"

@interface RoomCreationTableViewController () <UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>
{
    NSMutableDictionary *_participants;
    NSArray *_indexes;
    UISearchController *_searchController;
    ResultMultiSelectionTableViewController *_resultTableViewController;
    NSMutableArray *_selectedParticipants;
    PlaceholderView *_roomCreationBackgroundView;
    NSTimer *_searchTimer;
    NSURLSessionTask *_searchParticipantsTask;
}
@end

@implementation RoomCreationTableViewController

- (instancetype)init
{
    return [self initWithParticipants:nil andIndexes:nil];
}

- (instancetype)initWithParticipants:(NSMutableDictionary *)participants andIndexes:(NSMutableArray *)indexes
{
    self = [super init];
    if (self) {
        _participants = participants ? participants : [[NSMutableDictionary alloc] init];
        _indexes = indexes ? indexes : [[NSArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _selectedParticipants = [[NSMutableArray alloc] init];
    
    [self.tableView registerNib:[UINib nibWithNibName:kContactsTableCellNibName bundle:nil] forCellReuseIdentifier:kContactCellIdentifier];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72, 0, 0);
    self.tableView.sectionIndexBackgroundColor = [UIColor clearColor];
    
    _resultTableViewController = [[ResultMultiSelectionTableViewController alloc] init];
    _searchController = [[UISearchController alloc] initWithSearchResultsController:_resultTableViewController];
    _searchController.searchResultsUpdater = self;
    [_searchController.searchBar sizeToFit];

    UIColor *themeColor = [NCAppBranding themeColor];
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = themeColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName:[NCAppBranding themeTextColor]};
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    
    self.navigationItem.searchController = _searchController;
    self.navigationItem.searchController.searchBar.searchTextField.backgroundColor = [NCUtils searchbarBGColorForColor:themeColor];

    if (@available(iOS 16.0, *)) {
        self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
    }
    
    _searchController.searchBar.tintColor = [NCAppBranding themeTextColor];
    UITextField *searchTextField = [_searchController.searchBar valueForKey:@"searchField"];
    UIButton *clearButton = [searchTextField valueForKey:@"_clearButton"];
    searchTextField.tintColor = [NCAppBranding themeTextColor];
    searchTextField.textColor = [NCAppBranding themeTextColor];
    dispatch_async(dispatch_get_main_queue(), ^{
        // Search bar placeholder
        searchTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Search", nil)
        attributes:@{NSForegroundColorAttributeName:[[NCAppBranding themeTextColor] colorWithAlphaComponent:0.5]}];
        // Search bar search icon
        UIImageView *searchImageView = (UIImageView *)searchTextField.leftView;
        searchImageView.image = [searchImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [searchImageView setTintColor:[[NCAppBranding themeTextColor] colorWithAlphaComponent:0.5]];
        // Search bar search clear button
        UIImage *clearButtonImage = [clearButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [clearButton setImage:clearButtonImage forState:UIControlStateNormal];
        [clearButton setImage:clearButtonImage forState:UIControlStateHighlighted];
        [clearButton setTintColor:[NCAppBranding themeTextColor]];
    });
    
    // We want ourselves to be the delegate for the result table so didSelectRowAtIndexPath is called for both tables.
    _resultTableViewController.tableView.delegate = self;
    _searchController.delegate = self;
    _searchController.searchBar.delegate = self;
    _searchController.hidesNavigationBarDuringPresentation = NO;
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Room creation placeholder view
    _roomCreationBackgroundView = [[PlaceholderView alloc] init];
    [_roomCreationBackgroundView setImage:[UIImage imageNamed:@"contacts-placeholder"]];
    [_roomCreationBackgroundView.placeholderTextView setText:NSLocalizedString(@"No participants found", nil)];
    [_roomCreationBackgroundView.placeholderView setHidden:YES];
    [_roomCreationBackgroundView.loadingView startAnimating];
    self.tableView.backgroundView = _roomCreationBackgroundView;
    
    self.definesPresentationContext = YES;
    
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", nil) style:UIBarButtonItemStylePlain
                                                                  target:self action:@selector(nextButtonPressed)];
    self.navigationItem.rightBarButtonItem = nextButton;
    self.navigationItem.rightBarButtonItem.accessibilityHint = NSLocalizedString(@"Continue to next step of conversation creation", nil);
    self.navigationController.navigationBar.tintColor = [NCAppBranding themeTextColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.barTintColor = [NCAppBranding themeColor];
    
    [self updateCounter];
    
    // Fix uisearchcontroller animation
    self.extendedLayoutIncludesOpaqueBars = YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    
    [self getPossibleParticipants];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View controller actions

- (void)cancelButtonPressed
{
    [self close];
}

- (void)close
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)nextButtonPressed
{
    RoomCreation2TableViewController *rc2VC = [[RoomCreation2TableViewController alloc] initForGroupRoomWithParticipants:_selectedParticipants];
    [self.navigationController pushViewController:rc2VC animated:YES];
}

- (void)updateCounter
{
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [NCAppBranding themeTextColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.text = NSLocalizedString(@"New group conversation", nil);
    titleLabel.accessibilityLabel = NSLocalizedString(@"Add participants to new group conversation", nil);
    [titleLabel sizeToFit];
    
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 18, 0, 0)];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.textColor = [NCAppBranding themeTextColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12];
    subTitleLabel.text = [NSString localizedStringWithFormat:NSLocalizedString(@"%ld participants", nil), _selectedParticipants.count];
    subTitleLabel.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@ added to this new group conversation", nil), subTitleLabel.text];
    [subTitleLabel sizeToFit];
    
    UIView *twoLineTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MAX(subTitleLabel.frame.size.width, titleLabel.frame.size.width), 30)];
    [twoLineTitleView addSubview:titleLabel];
    [twoLineTitleView addSubview:subTitleLabel];
    
    float widthDiff = subTitleLabel.frame.size.width - titleLabel.frame.size.width;
    
    if (widthDiff > 0) {
        CGRect frame = titleLabel.frame;
        frame.origin.x = widthDiff / 2;
        titleLabel.frame = CGRectIntegral(frame);
    }else{
        CGRect frame = subTitleLabel.frame;
        frame.origin.x = fabsf(widthDiff) / 2;
        subTitleLabel.frame = CGRectIntegral(frame);
    }
    
    self.navigationItem.titleView = twoLineTitleView;
}

#pragma mark - Participants actions

- (void)getPossibleParticipants
{
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    [[NCAPIController sharedInstance] getContactsForAccount:activeAccount forRoom:nil groupRoom:YES withSearchParam:nil andCompletionBlock:^(NSArray *indexes, NSMutableDictionary *contacts, NSMutableArray *contactList, NSError *error) {
        if (!error) {
            NSMutableArray *storedContacts = [NCContact contactsForAccountId:activeAccount.accountId contains:nil];
            NSMutableArray *combinedContactList = [NCUser combineUsersArray:storedContacts withUsersArray:contactList];
            NSMutableDictionary *participants = [NCUser indexedUsersFromUsersArray:combinedContactList];
            self->_participants = participants;
            self->_indexes = [[participants allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            [self->_roomCreationBackgroundView.loadingView stopAnimating];
            [self->_roomCreationBackgroundView.loadingView setHidden:YES];
            [self->_roomCreationBackgroundView.placeholderView setHidden:(contacts.count > 0)];
            [self.tableView reloadData];
        } else {
            NSLog(@"Error while trying to get participants: %@", error);
        }
    }];
}

- (void)searchForParticipantsWithString:(NSString *)searchString
{
    [_searchParticipantsTask cancel];
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    _searchParticipantsTask = [[NCAPIController sharedInstance] getContactsForAccount:activeAccount forRoom:nil groupRoom:YES withSearchParam:searchString andCompletionBlock:^(NSArray *indexes, NSMutableDictionary *contacts, NSMutableArray *contactList, NSError *error) {
        if (!error) {
            NSMutableArray *storedContacts = [NCContact contactsForAccountId:activeAccount.accountId contains:searchString];
            NSMutableArray *combinedContactList = [NCUser combineUsersArray:storedContacts withUsersArray:contactList];
            NSMutableDictionary *combinedContacts = [NCUser indexedUsersFromUsersArray:combinedContactList];
            NSMutableArray *combinedIndexes = [NSMutableArray arrayWithArray:[[combinedContacts allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
            [self->_resultTableViewController setSearchResultContacts:combinedContacts withIndexes:combinedIndexes];
        } else {
            if (error.code != -999) {
                NSLog(@"Error while searching for participants: %@", error);
            }
        }
    }];
}

- (BOOL)isParticipantAlreadySelected:(NCUser *)participant
{
    for (NCUser *user in _selectedParticipants) {
        if ([user.userId isEqualToString:participant.userId] &&
            [user.source isEqualToString:participant.source]) {
            return YES;
        }
    }
    return NO;
}

- (void)removeSelectedParticipant:(NCUser *)participant
{
    NCUser *userToDelete = nil;
    for (NCUser *user in _selectedParticipants) {
        if ([user.userId isEqualToString:participant.userId] &&
            [user.source isEqualToString:participant.source]) {
            userToDelete = user;
        }
    }
    
    if (userToDelete) {
        [_selectedParticipants removeObject:userToDelete];
    }
}

#pragma mark - Search controller

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    [_searchTimer invalidate];
    _searchTimer = nil;
    [_resultTableViewController showSearchingUI];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_searchTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(searchForParticipants) userInfo:nil repeats:NO];
    });
}

- (void)searchForParticipants
{
    NSString *searchString = _searchController.searchBar.text;
    if (![searchString isEqualToString:@""]) {
        [self searchForParticipantsWithString:searchString];
    }
}

- (void)didDismissSearchController:(UISearchController *)searchController
{
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _indexes.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *index = [_indexes objectAtIndex:section];
    NSArray *participants = [_participants objectForKey:index];
    return participants.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kContactsTableCellHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_indexes objectAtIndex:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return _indexes;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *index = [_indexes objectAtIndex:indexPath.section];
    NSArray *participants = [_participants objectForKey:index];
    NCUser *participant = [participants objectAtIndex:indexPath.row];
    ContactsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kContactCellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[ContactsTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kContactCellIdentifier];
    }
    
    cell.labelTitle.text = participant.name;
    
    if ([participant.source isEqualToString:kParticipantTypeUser]) {
        [cell.contactImage setImageWithURLRequest:[[NCAPIController sharedInstance] createAvatarRequestForUser:participant.userId withStyle:self.traitCollection.userInterfaceStyle andSize:96 usingAccount:[[NCDatabaseManager sharedInstance] activeAccount]]
                                 placeholderImage:nil success:nil failure:nil];
        [cell.contactImage setContentMode:UIViewContentModeScaleToFill];
    } else if ([participant.source isEqualToString:kParticipantTypeEmail]) {
        [cell.contactImage setImage:[UIImage imageNamed:@"mail"]];
    } else {
        [cell.contactImage setImage:[UIImage imageNamed:@"group"]];
    }

    UIImage *selectionImage = [UIImage systemImageNamed:@"circle"];
    UIColor *selectionImageColor = [UIColor tertiaryLabelColor];
    if ([self isParticipantAlreadySelected:participant]) {
        selectionImage = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        selectionImageColor = [NCAppBranding elementColor];
    }
    UIImageView *selectionImageView = [[UIImageView alloc] initWithImage:selectionImage];
    selectionImageView.tintColor = selectionImageColor;
    cell.accessoryView = selectionImageView;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *index = nil;
    NSArray *participants = nil;
    
    if (_searchController.active && _resultTableViewController.contacts.count > 0) {
        index = [_resultTableViewController.indexes objectAtIndex:indexPath.section];
        participants = [_resultTableViewController.contacts objectForKey:index];
    } else {
        index = [_indexes objectAtIndex:indexPath.section];
        participants = [_participants objectForKey:index];
    }
    
    NCUser *participant = [participants objectAtIndex:indexPath.row];
    if (![self isParticipantAlreadySelected:participant]) {
        [_selectedParticipants addObject:participant];
    } else {
        [self removeSelectedParticipant:participant];
    }
    
    _resultTableViewController.selectedParticipants = _selectedParticipants;
    
    [tableView beginUpdates];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [tableView endUpdates];
    
    [self updateCounter];
}

@end
