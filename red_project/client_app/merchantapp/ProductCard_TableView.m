//
//  ProductCard_TableView.m
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-11.
//  Copyright (c) 2016 Ernest Bruce.
//

#import "ProductCard_TableView.h"

@interface ProductCard_TableView()
@property (nonatomic) UIImage* product_image; 
@end

@implementation ProductCard_TableView

- (void) setProductImage:(UIImage*) product_image
{
   NSLog(@"ProductCard_TableView setProductImage:");
   _product_image= product_image;
   [self reloadData];
}
@end
