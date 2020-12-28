//
//  ShippingMethod.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-12.
//  Copyright (c) 2016 Ernest Bruce.
//

#import <Foundation/Foundation.h>

@interface ShippingMethod : NSObject
@property NSString*  name;
@property NSString*  detail;
@property NSNumber*  transit_days;
@property NSString*  price;
@end
