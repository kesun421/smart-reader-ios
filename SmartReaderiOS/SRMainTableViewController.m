//
//  SRMainTableViewController.m
//  SmartReaderiOS
//
//  Created by Ke Sun on 11/25/13.
//  Copyright (c) 2013 Ke Sun. All rights reserved.
//

#import "SRMainTableViewController.h"
#import "SRFileUtility.h"
#import "SRSecondaryTableViewController.h"
#import "SRAddSourceViewController.h"
#import "SRSource.h"
#import "MWFeedInfo.h"
#import "UIImageView+AFNetworking.h"
#import "MWFeedParser.h"
#import "MWFeedInfo.h"
#import "MWFeedItem.h"
#import "SRSourceManager.h"
#import "SRTextFilteringManager.h"
#import "UIImage+Extensions.h"
#import "SRMessageViewController.h"

#define IMAGE_SIZE CGSizeMake(25.0, 25.0)

@interface SRMainTableViewController () <SRAddSourceViewControllerDelegate, SRSourceManagerDelegate, SRTextFilteringManagerDelegate, SRSecondaryTableViewControllerDelegate>
{
    BOOL _refreshingSourcesTableCellAnimationSwitch;
}

@end

@implementation SRMainTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    [[SRSourceManager sharedManager] loadSources];
    [SRSourceManager sharedManager].mainDelegate = self;
    
    [self refreshSources];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    self.tableView.separatorColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.leftBarButtonItems = @[
                                               [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"book-7.png"] resizeImageToSize:IMAGE_SIZE]
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(showBookmarks)],
                                               [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"plus-circle-7.png"] resizeImageToSize:IMAGE_SIZE]
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(add)]
                                               ];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"more-list-7.png"] resizeImageToSize:IMAGE_SIZE]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(menu)],
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refreshSources) forControlEvents:UIControlEventValueChanged];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [SRTextFilteringManager sharedManager].interestingFeedItems.count ? [SRSourceManager sharedManager].sources.count + 1 : [SRSourceManager sharedManager].sources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // Set back to default.
    float titleFontSize = 18.0;
    cell.textLabel.font = [UIFont systemFontOfSize:titleFontSize];
    cell.backgroundColor = [UIColor whiteColor];
    
    // Add rounded corner to favicons.
    cell.imageView.layer.cornerRadius = 5.0;
    cell.imageView.clipsToBounds = YES;
    
    CGSize newImageSize = CGSizeMake(30.0, 30.0);
    
    if ([SRTextFilteringManager sharedManager].interestingFeedItems.count && indexPath.row == 0) {
        int count = 0;
        for (MWFeedItem *feedItem in [SRTextFilteringManager sharedManager].interestingFeedItems) {
            if (!feedItem.read) {
                count++;
            }
        }
        
        cell.imageView.image = [[[UIImage imageNamed:@"star-7.png"] resizeImageToSize:newImageSize] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.textLabel.text = @"Interesting Articles...";
        cell.textLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d unread", count];
        cell.backgroundColor = [UIColor colorWithRed:238.0f/255.0f green:247.0f/255.0f blue:255.0f/255.0f alpha:1.0];
        
        if (_refreshingSourcesTableCellAnimationSwitch) {
            CABasicAnimation* rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
            rotationAnimation.duration = 1.0;
            [cell.imageView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
            
            _refreshingSourcesTableCellAnimationSwitch = NO;
        }
    }
    else {
        long index = [SRTextFilteringManager sharedManager].interestingFeedItems.count ? indexPath.row - 1 : indexPath.row;
        SRSource *source = [SRSourceManager sharedManager].sources[index];
        
        int count = 0;
        for (MWFeedItem *feedItem in source.feedItems) {
            if (!feedItem.read) {
                count++;
            }
        }
        
        __weak UITableViewCell *weakCell = cell;
        UIImage *placeholderImage = [[[UIImage imageNamed:@"rss-7.png"] resizeImageToSize:newImageSize] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        [cell.imageView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:source.faviconLink]]
                              placeholderImage:placeholderImage
                                       success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                           weakCell.imageView.image = [image resizeImageToSize:newImageSize];
                                       }
                                       failure:nil];

        cell.textLabel.text = source.feedInfo.title;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d unread", count];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    if ([SRTextFilteringManager sharedManager].interestingFeedItems.count && indexPath.row == 0) {
        return NO;
    }
    else {
        return YES;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        NSInteger index = [SRTextFilteringManager sharedManager].interestingFeedItems.count ? indexPath.row - 1 : indexPath.row;
        [[SRSourceManager sharedManager] deleteSourceAtIndex:index];
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        
        [tableView reloadData];
    }
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Stop the refresh control from continued spinning.  If we don't do this, it's possible that we navigated to another view controller
    // while the refresh control was spinning, when we navigate back to the main cview controller, there will be a gap left in the UI that
    // used to hold the refresh control.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
    
    SRSource *source = nil;
    if ([SRTextFilteringManager sharedManager].interestingFeedItems.count && indexPath.row == 0) {
        source = [SRSource new];
        source.feedItems = [SRTextFilteringManager sharedManager].interestingFeedItems;
        source.sourceForInterestingItems = YES;
    }
    else {
        long index = [SRTextFilteringManager sharedManager].interestingFeedItems.count ? indexPath.row - 1 : indexPath.row;
        source = [SRSourceManager sharedManager].sources[index];
    }
    
    SRSecondaryTableViewController *secondaryViewController = [[SRSecondaryTableViewController alloc] initWithSource:source];
    secondaryViewController.delegate = self;
    
    [self.navigationController pushViewController:secondaryViewController animated:YES];
}

#pragma mark - SRAddSourceViewControllerDelegate methods

- (void)addSourceViewController:(SRAddSourceViewController *)controller didRetrieveSource:(SRSource *)source
{
    [[SRSourceManager sharedManager] addSource:source];
    [[SRSourceManager sharedManager] saveSources];
    
    [self.tableView reloadData];
}

- (void)addSourceViewControllerDidFinishAddingAllSources:(SRAddSourceViewController *)controller
{
    SRMessageViewController *msgController = [[SRMessageViewController alloc] initWithMessage:@"News source added"];
    [self.navigationController.view addSubview:msgController.view];
    [msgController animate];
}

#pragma mark - UI related

- (void)add
{
    SRAddSourceViewController *addSourceViewController = [SRAddSourceViewController new];
    addSourceViewController.delegate = self;
    
    [self.navigationController presentViewController:addSourceViewController animated:YES completion:nil];
}

- (void)refreshSources
{
    _refreshingSourcesTableCellAnimationSwitch = YES;
    
    [[SRSourceManager sharedManager] refreshSources];
}

- (void)showBookmarks
{
    SRSource *source = [SRSource new];
    source.sourceForBookmarkedItems = YES;
    NSMutableArray *bookmarkedItems = [NSMutableArray new];
    
    for (SRSource *src in [SRSourceManager sharedManager].sources) {
        for (MWFeedItem *feedItem in src.feedItems) {
            if (feedItem.bookmarked) {
                feedItem.source = src;
                [bookmarkedItems addObject:feedItem];
            }
        }
    }
    
    [bookmarkedItems sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        MWFeedItem *feedItem1 = (MWFeedItem *)obj1;
        MWFeedItem *feedItem2 = (MWFeedItem *)obj2;
        
        return [feedItem2.bookmarkedDate compare:feedItem1.bookmarkedDate];
    }];
    
    source.feedItems = [bookmarkedItems copy];
    
    SRSecondaryTableViewController *secondaryViewController = [[SRSecondaryTableViewController alloc] initWithSource:source];
    secondaryViewController.delegate = self;
    
    [self.navigationController pushViewController:secondaryViewController animated:YES];
}

- (void)menu
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Menu" message:@"What's a menu gotta do these days to get some function assigned!?" delegate:nil cancelButtonTitle:@"Okay..." otherButtonTitles:nil];
    [alert show];
}

#pragma mark - SRSourceManagerDelegate methods

- (void)didFinishRefreshingAllSourcesWithError:(NSError *)error
{
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
    
    [SRTextFilteringManager sharedManager].delegate = self;
    [[SRTextFilteringManager sharedManager] findInterestingFeedItemsFromSources:[SRSourceManager sharedManager].sources];
}

#pragma mark - SRTextFilteringManagerDelegate methods

- (void)didFinishFindinglikableFeedItems
{
    DebugLog(@"Found these likable items: %@", [SRTextFilteringManager sharedManager].interestingFeedItems);
    
    if ([SRTextFilteringManager sharedManager].interestingFeedItems.count) {
        SRMessageViewController *msgController = [[SRMessageViewController alloc] initWithMessage:[NSString stringWithFormat:@"Found %lu interesting items",(unsigned long)[SRTextFilteringManager sharedManager].interestingFeedItems.count]];
        [self.navigationController.view addSubview:msgController.view];
        [msgController animate];
    }
    else {
        SRMessageViewController *msgController = [[SRMessageViewController alloc] initWithMessage:@"Train me to suggest articles"];
        [self.navigationController.view addSubview:msgController.view];
        [msgController animate];
    }
    
    [self.tableView reloadData];
}

#pragma mark - SRSecondaryTableViewControllerDelegate methods

- (void)refresh:(id)sender
{
    [self.tableView reloadData];
}

@end
