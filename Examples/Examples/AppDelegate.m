//
//  AppDelegate.m
//  Examples
//
//  Created by Victor Zhu on 2019/3/5.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <AffirmSDK/AffirmSDK.h>

static NSString *const AffirmPromoBaseURLEnvironmentKey = @"AFFIRM_PROMO_BASE_URL";
static NSString *const AffirmPublicKeyEnvironmentKey = @"AFFIRM_PUBLIC_KEY";
static NSString *const AffirmCountryCodeEnvironmentKey = @"AFFIRM_COUNTRY_CODE";
static NSString *const AffirmLocaleEnvironmentKey = @"AFFIRM_LOCALE";
static NSString *const AffirmCurrencyEnvironmentKey = @"AFFIRM_CURRENCY";

@interface AffirmConfiguration (UpfunnelPromoUITesting)
@property (nonatomic, copy, nullable) NSString *promosURLOverride;
@end

static NSString *AffirmEnvironmentValueOrDefault(NSDictionary<NSString *, NSString *> *environment,
                                                 NSString *key,
                                                 NSString *defaultValue)
{
    NSString *value = environment[key];
    return value.length > 0 ? value : defaultValue;
}

static NSString *AffirmURLByTrimmingTrailingSlashes(NSString *url)
{
    NSString *trimmedURL = [url copy];
    while ([trimmedURL hasSuffix:@"/"]) {
        trimmedURL = [trimmedURL substringToIndex:trimmedURL.length - 1];
    }
    return trimmedURL;
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSDictionary<NSString *, NSString *> *environment = [[NSProcessInfo processInfo] environment];
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:AffirmEnvironmentValueOrDefault(environment, AffirmPublicKeyEnvironmentKey, @"3HCWTVU5BYWZB9RK")
                                                     environment:AffirmEnvironmentSandbox
                                                          locale:AffirmEnvironmentValueOrDefault(environment, AffirmLocaleEnvironmentKey, @"en_GB")
                                                     countryCode:AffirmEnvironmentValueOrDefault(environment, AffirmCountryCodeEnvironmentKey, @"GBR")
                                                        currency:AffirmEnvironmentValueOrDefault(environment, AffirmCurrencyEnvironmentKey, @"GBP")
                                                    merchantName:@"Affirm Example"];
    NSString *promoBaseURL = environment[AffirmPromoBaseURLEnvironmentKey];
    if (promoBaseURL.length > 0) {
        [AffirmConfiguration sharedInstance].promosURLOverride = AffirmURLByTrimmingTrailingSlashes(promoBaseURL);
    }
    [AffirmConfiguration sharedInstance].cardTip = @"We've added these card details to Rakuten Autofill for quick, easy checkout.";
    return YES;
}

@end
