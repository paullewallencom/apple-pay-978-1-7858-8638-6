//
//  ProductCard.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

@import  UIKit;
@import  PassKit;
#import "Product.h"


@interface ProductCard : UITableViewController <PKPaymentAuthorizationViewControllerDelegate>
@property (weak) IBOutlet UINavigationItem*  navigation;
@property                 Product*           product;
@end
