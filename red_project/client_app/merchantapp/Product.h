//
//  Product.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

#import <Foundation/Foundation.h>

@interface Product : NSObject
@property NSString*  name;
@property NSString*  description;
@property NSString*  image_uri;
@property NSUInteger quantity_on_hand;
@property NSString*  price;
@end
