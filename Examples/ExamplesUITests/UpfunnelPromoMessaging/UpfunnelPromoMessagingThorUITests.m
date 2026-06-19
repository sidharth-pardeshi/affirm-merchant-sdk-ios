//
//  UpfunnelPromoMessagingThorUITests.m
//  ExamplesUITests
//

#import <XCTest/XCTest.h>
#import "../XCTestCase+Utils.h"

@interface UpfunnelPromoMessagingThorUITests : XCTestCase

@property (nonatomic, strong) XCUIApplication *app;

@end

@implementation UpfunnelPromoMessagingThorUITests

static NSString *const AffirmPromoBaseURLEnvironmentKey = @"AFFIRM_PROMO_BASE_URL";
static NSString *const AffirmPublicKeyEnvironmentKey = @"AFFIRM_PUBLIC_KEY";
static NSString *const AffirmPromoExternalIDEnvironmentKey = @"AFFIRM_PROMO_EXTERNAL_ID";
static NSString *const AffirmExpectedPromoTextEnvironmentKey = @"AFFIRM_EXPECTED_PROMO_TEXT";
static NSString *const AffirmCountryCodeEnvironmentKey = @"AFFIRM_COUNTRY_CODE";
static NSString *const AffirmLocaleEnvironmentKey = @"AFFIRM_LOCALE";
static NSString *const AffirmCurrencyEnvironmentKey = @"AFFIRM_CURRENCY";

- (void)setUp
{
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
}

- (void)testPromoButtonRendersAlaFromThorService
{
    NSDictionary<NSString *, NSString *> *environment = [[NSProcessInfo processInfo] environment];
    NSString *promoBaseURL = environment[AffirmPromoBaseURLEnvironmentKey];
    NSString *publicKey = environment[AffirmPublicKeyEnvironmentKey];
    if (promoBaseURL.length == 0 || publicKey.length == 0) {
        XCTSkip(@"Thor promo messaging test requires AFFIRM_PROMO_BASE_URL and AFFIRM_PUBLIC_KEY.");
        return;
    }

    NSString *expectedPromoText = environment[AffirmExpectedPromoTextEnvironmentKey] ?: @"Affirm";
    self.app.launchEnvironment = @{
        AffirmPromoBaseURLEnvironmentKey: promoBaseURL,
        AffirmPublicKeyEnvironmentKey: publicKey,
        AffirmPromoExternalIDEnvironmentKey: environment[AffirmPromoExternalIDEnvironmentKey] ?: @"test_external_id",
        AffirmCountryCodeEnvironmentKey: environment[AffirmCountryCodeEnvironmentKey] ?: @"USA",
        AffirmLocaleEnvironmentKey: environment[AffirmLocaleEnvironmentKey] ?: @"en_US",
        AffirmCurrencyEnvironmentKey: environment[AffirmCurrencyEnvironmentKey] ?: @"USD",
    };
    [self.app launch];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElement:alaElement duration:15];
    XCTAssertTrue(alaElement.exists);
    XCTAssertTrue([alaElement.label containsString:expectedPromoText],
                  @"Expected '%@' to contain '%@'", alaElement.label, expectedPromoText);
    [self attachScreenshotWithName:@"thor-native-ala-rendered"];
}

- (void)attachScreenshotWithName:(NSString *)name
{
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:[self.app screenshot]];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

@end
