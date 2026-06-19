//
//  AppDelegate.m
//  Examples
//
//  Created by Victor Zhu on 2019/3/5.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <AffirmSDK/AffirmSDK.h>

static NSString *const AffirmPromoMockModeArgument = @"-AffirmPromoMockMode";
static NSString *const AffirmPromoFixtureEnvironmentKey = @"AFFIRM_PROMO_FIXTURE";

@interface AffirmPromoMockURLProtocol : NSURLProtocol
@end

@implementation AffirmPromoMockURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    BOOL mockModeEnabled = [[[NSProcessInfo processInfo] arguments] containsObject:AffirmPromoMockModeArgument];
    return mockModeEnabled && [request.URL.path hasPrefix:@"/api/promos/v2/"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSString *fixture = [[[NSProcessInfo processInfo] environment] objectForKey:AffirmPromoFixtureEnvironmentKey] ?: @"adaptive";
    NSInteger statusCode = [fixture isEqualToString:@"error"] ? 500 : 200;
    NSString *body = [self responseBodyForFixture:fixture];
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                               statusCode:statusCode
                                                              HTTPVersion:@"HTTP/1.1"
                                                             headerFields:@{@"Content-Type": @"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

- (NSString *)responseBodyForFixture:(NSString *)fixture
{
    if ([fixture isEqualToString:@"empty"]) {
        return @"{\"promo\":{\"ala\":\"\",\"html_ala\":\"\",\"config\":{\"promo_prequal_enabled\":true,\"promo_style\":\"adaptive\",\"loan_type\":\"installment\",\"toast_enabled\":false}}}";
    }
    if ([fixture isEqualToString:@"error"]) {
        return @"{\"message\":\"Promo fixture error\",\"code\":\"promo_fixture_error\",\"field\":\"\",\"type\":\"api_error\",\"status_code\":500}";
    }
    if ([fixture isEqualToString:@"fast"]) {
        return @"{\"promo\":{\"ala\":\"As low as $60/month at 0% APR. Learn more\",\"html_ala\":\"As low as <span class=\\\"affirm-ala-price\\\">$60</span>/month at 0% APR. <a class=\\\"affirm-modal-trigger\\\">Learn more</a>\",\"config\":{\"promo_prequal_enabled\":false,\"promo_style\":\"fast\",\"loan_type\":\"installment\",\"toast_enabled\":false}}}";
    }
    return @"{\"promo\":{\"ala\":\"As low as $60/month at 0% APR. Learn more\",\"html_ala\":\"As low as <span class=\\\"affirm-ala-price\\\">$60</span>/month at 0% APR. <a class=\\\"affirm-modal-trigger\\\">Learn more</a>\",\"config\":{\"promo_prequal_enabled\":true,\"promo_style\":\"adaptive\",\"loan_type\":\"installment\",\"toast_enabled\":false}}}";
}

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if ([[[NSProcessInfo processInfo] arguments] containsObject:AffirmPromoMockModeArgument]) {
        [NSURLProtocol registerClass:AffirmPromoMockURLProtocol.class];
    }
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"3HCWTVU5BYWZB9RK"
                                                     environment:AffirmEnvironmentSandbox
                                                          locale:@"en_GB"
                                                     countryCode:@"GBR"
                                                        currency:@"GBP"
                                                    merchantName:@"Affirm Example"];
    [AffirmConfiguration sharedInstance].cardTip = @"We've added these card details to Rakuten Autofill for quick, easy checkout.";
    return YES;
}

@end
