//
//  ProductList.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

@import Foundation;
#import "ProductList.h"
#import "Product.h"
#import "ProductCard.h"
#import "RestIO.h"
#import "AppDelegate.h"


@interface ProductList ()
@property (nonatomic) NSMutableDictionary*  data_tasks;
@property (nonatomic) NSArray<Product*>*    products;
@end

@implementation ProductList

- (void) viewDidLoad
{
   [super viewDidLoad];
   self.title= @"Products";
   NSLog(@"ProductList viewDidLoad");
   
   AppDelegate* app_delegate= [UIApplication sharedApplication].delegate;
   
   // get product list (inventory)
   {
      NSLog(@"  getting product list (inventory)");
      
      RestIO* rest_io= [RestIO sharedRestIO];
      NSString* inventory_uri=
         [NSString stringWithFormat:@"%@%@",  app_delegate.rest_io_host, @"/inventory"];
      [rest_io getResourceAtURI:inventory_uri completion:^(NSURLResponse* response, NSData* data)
       {
          if ([response.MIMEType isEqualToString:@"application/json"])
          {
             NSError* error;
             NSDictionary* json_data=  [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
             NSMutableArray<Product*>* products= [NSMutableArray new];
             for (NSDictionary* json_product in json_data)
             {            
                Product* product=    [Product new];
                product.name=        json_product[@"name"];
                product.description= json_product[@"description"];
                product.image_uri=   json_product[@"image_uri"];
                product.price=       json_product[@"price"];
                {
                   NSInteger quantity=  [(NSString*)json_product[@"quantity_on_hand"] integerValue];
                   product.quantity_on_hand= quantity > 0? quantity : 0;
                }
                [products addObject:product];
             }
             _products= products.copy;
             dispatch_async(dispatch_get_main_queue(), ^{                
                [(UITableView*)self.view reloadData];
             });
          }
      }];
   }
}

- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
}

- (NSInteger) tableView:(UITableView*) tableView
  numberOfRowsInSection:(NSInteger)    section
{
   return _products.count;
}

- (UITableViewCell*) tableView:(UITableView*) table_view cellForRowAtIndexPath:(NSIndexPath*) index_path 
{
   static NSString* identifier= @"name";
   
   UITableViewCell* cell= [table_view dequeueReusableCellWithIdentifier:identifier];
   cell.textLabel.text=   (_products[index_path.row]).name;
   
   return cell;
}

- (IBAction) showProductCard:(id) sender
{
   [self performSegueWithIdentifier:@"product" sender:[(UITableViewCell*)sender superview]];
}

- (void) prepareForSegue:(UIStoryboardSegue*) segue
                  sender:(id)                 sender
{
   ProductCard* product_card= segue.destinationViewController;
   NSIndexPath* selected=     [(UITableView*)self.view indexPathForSelectedRow];
   Product*     product=      _products[selected.row];
   NSString*    product_name= product.name;
   
   product_card.product=          product;
   product_card.navigation.title= product_name;
}

@end
