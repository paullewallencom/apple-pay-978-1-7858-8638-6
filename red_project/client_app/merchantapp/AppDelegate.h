//
//  AppDelegate.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

#import <UIKit/UIKit.h>
#import "ShippingMethod.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow*                  window;
@property (readonly, copy)    NSString*                  ApplePay_merchant_identifier;
@property (readonly, copy)    NSArray*                   ApplePay_supported_networks;
@property (readonly, copy)    NSArray<ShippingMethod*>*  shipping_methods;
@property (readonly)          NSString*                  rest_io_host;
@end

