//
//  ProductCard_TableView.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-11.
//  Copyright (c) 2016 Ernest Bruce.
//

#import <UIKit/UIKit.h>

@interface ProductCard_TableView : UITableView

@property (readonly) UIImage* product_image; 

- (void) setProductImage:(UIImage*) image;

@end
