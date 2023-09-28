//
//  ResultMultiSelectionTableViewController.h
//  VideoCalls
//
//  Created by Ivan Sein on 18.06.18.
//  Copyright © 2018 struktur AG. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ContactsTableViewCell.h"

@interface ResultMultiSelectionTableViewController : UITableViewController

@property (nonatomic, strong) NSMutableDictionary *contacts;
@property (nonatomic, strong) NSArray *indexes;
@property (nonatomic, strong) NSMutableArray *selectedParticipants;

- (void)setSearchResultContacts:(NSMutableDictionary *)contacts withIndexes:(NSArray *)indexes;
- (void)showSearchingUI;

@end
