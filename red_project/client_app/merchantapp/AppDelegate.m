//
//  AppDelegate.m
//  red
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

#import "AppDelegate.h"
#import "Stripe.h"
#import "RestIO.h"
#import "private_keys.h"


@interface AppDelegate ()
@property (readwrite) NSArray<ShippingMethod*>* shipping_methods;
@end


@implementation AppDelegate
- (BOOL)          application:(UIApplication*) app
didFinishLaunchingWithOptions:(NSDictionary*)  options
{
   _ApplePay_merchant_identifier= ApplePay_merchant_identifier;    // from private_keys.h
   _ApplePay_supported_networks=  @[PKPaymentNetworkVisa, PKPaymentNetworkAmex, PKPaymentNetworkDiscover, PKPaymentNetworkPrivateLabel];
   
   [Stripe setDefaultPublishableKey:StripePublishableKey];         // from private_keys.h
   
   _rest_io_host= @"http://red:12345";
   
   // get shipping methods from server
   {
      NSString* shipping_methods_uri= [NSString stringWithFormat:@"%@%@",_rest_io_host, @"/shipping_methods"];
      
      RestIO* rest_io= [RestIO sharedRestIO];
      [rest_io getResourceAtURI:shipping_methods_uri completion:^(NSURLResponse* response, NSData* data) {
         if ([response.MIMEType isEqualToString:@"application/json"])
         {
            NSError* error;
            NSDictionary*   json_data=        [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSMutableArray* shipping_methods= [NSMutableArray array];
            for (NSDictionary* json_shipping_method in json_data)
            {
               ShippingMethod* shipping_method= [ShippingMethod new];
               {
                  shipping_method.name=         json_shipping_method[@"name"];
                  shipping_method.detail=       json_shipping_method[@"description"];
                  shipping_method.transit_days= [NSNumber numberWithShort:[(NSString*)json_shipping_method[@"transit_days"]
                                                                           integerValue]];
                  shipping_method.price=        json_shipping_method[@"price"];
               }
               
               [shipping_methods addObject:shipping_method];
            }
            _shipping_methods= shipping_methods.copy;
         }
      }];
   }
   return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
   // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
   // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
   // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
   // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
   // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
   // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
   // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
