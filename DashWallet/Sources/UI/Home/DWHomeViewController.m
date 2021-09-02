//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DWHomeViewController.h"

#import "DWBalanceDisplayOptionsProtocol.h"
#import "DWEnvironment.h"
#import "DWHomeView.h"
#import "DWHomeViewController+DWBackupReminder.h"
#import "DWHomeViewController+DWJailbreakCheck.h"
#import "DWHomeViewController+DWShortcuts.h"
#import "DWModalUserProfileViewController.h"
#import "DWNavigationController.h"
#import "DWNotificationsViewController.h"
#import "DWShortcutAction.h"
#import "DWSyncingAlertViewController.h"
#import "DWTxDetailPopupViewController.h"
#import "DWWindow.h"
#import "UIViewController+DWTxFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWHomeViewController () <DWHomeViewDelegate, DWShortcutsActionDelegate>

@property (strong, nonatomic) DWHomeView *view;

@end

@implementation DWHomeViewController

@dynamic view;
@synthesize model = _model;

- (void)dealloc {
    DSLog(@"☠️ %@", NSStringFromClass(self.class));
}

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].bounds;
    self.view = [[DWHomeView alloc] initWithFrame:frame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.delegate = self;
    self.view.shortcutsDelegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSParameterAssert(self.model);

    [self setupView];
    [self performJailbreakCheck];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL upgrading = [self.model performOnSetupUpgrades];
    if (!upgrading) {
        // since these both methods might display modals, don't allow running them simultaneously
        [self showWalletBackupReminderIfNeeded];
    }

    [self.model registerForPushNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.model.balanceDisplayOptions hideBalanceIfNeeded];
}

#pragma mark - DWHomeViewDelegate

- (void)homeView:(DWHomeView *)homeView showTxFilter:(UIView *)sender {
    [self showTxFilterWithSender:sender displayModeProvider:self.model shouldShowRewards:YES];
}

- (void)homeView:(DWHomeView *)homeView showSyncingStatus:(UIView *)sender {
    DWSyncingAlertViewController *controller = [[DWSyncingAlertViewController alloc] init];
    controller.model = self.model;
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)homeView:(DWHomeView *)homeView profileButtonAction:(UIControl *)sender {
    DWNotificationsViewController *controller = [[DWNotificationsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)homeView:(DWHomeView *)homeView didSelectTransaction:(DSTransaction *)transaction {
    id<DWTransactionListDataProviderProtocol> dataProvider = [self.model getDataProvider];
    DWTxDetailPopupViewController *controller =
        [[DWTxDetailPopupViewController alloc] initWithTransaction:transaction
                                                      dataProvider:dataProvider];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)homeViewShowDashPayRegistrationFlow:(DWHomeView *)homeView {
    DWShortcutAction *action = [DWShortcutAction action:DWShortcutActionType_CreateUsername];
    [self performActionForShortcut:action sender:homeView];
}

#pragma mark - DWShortcutsActionDelegate

- (void)shortcutsView:(UIView *)view didSelectAction:(DWShortcutAction *)action sender:(UIView *)sender {
    [self performActionForShortcut:action sender:sender];
}

#pragma mark - Private

- (void)payViewControllerDidHidePaymentResultToContact:(nullable id<DWDPBasicUserItem>)contact {
    if (!contact) {
        return;
    }

    DWModalUserProfileViewController *profile =
        [[DWModalUserProfileViewController alloc] initWithItem:contact
                                                      payModel:self.payModel
                                                  dataProvider:self.dataProvider];
    [self presentViewController:profile animated:YES completion:nil];
}

- (id<DWPayModelProtocol>)payModel {
    return self.model.payModel;
}

- (id<DWTransactionListDataProviderProtocol>)dataProvider {
    return [self.model getDataProvider];
}

- (void)setupView {
    UIImage *logoImage = nil;
    CGFloat logoHeight;
    if ([DWEnvironment sharedInstance].currentChain.chainType == DSChainType_TestNet) {
        logoImage = [UIImage imageNamed:@"wei_logo_testnet"];
        logoHeight = 40.0;
    }
    else {
        logoImage = [UIImage imageNamed:@"wei_logo_bar"];
        logoHeight = 23.0;
    }
    NSParameterAssert(logoImage);
    UIImageView *imageView = [[UIImageView alloc] initWithImage:logoImage];
    imageView.tintColor = [UIColor whiteColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    const CGRect frame = CGRectMake(0.0, 0.0, 89.0, logoHeight);
    imageView.frame = frame;

    UIView *contentView = [[UIView alloc] initWithFrame:frame];
    [contentView addSubview:imageView];

    self.navigationItem.titleView = contentView;

    self.view.model = self.model;
}

@end

NS_ASSUME_NONNULL_END
