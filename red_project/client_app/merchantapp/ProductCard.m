//
//  ProductCard.m
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-10.
//  Copyright (c) 2016 Ernest Bruce.
//

@import  PassKit;
#import "ProductCard.h"
#import "ProductCard_DescriptionCell.h"
#import "ProductCard_TableView.h"
#import "ProductCard_ImageCell.h"
#import "ProductCard_BuyCell.h"
#import "RestIO.h"
#import "AppDelegate.h"
#import "Stripe.h"
#import "ShippingMethod.h"

static const int ApplePay_button_tag= 100;
static const int Buy_button_tag=      101;

typedef NS_ENUM (NSUInteger, ProductCardCell)
{
   ProductDescription,
   ProductImage,
   ProductBuy
};

typedef struct
{
   CGFloat         cell_row_height;
   ProductCardCell cell_type;
} ProductCardSection;
static ProductCardSection sections[3];

static NSString* Default_shipping_method_name= @"shipping_method_name";

NSDecimalNumber* decimal_number_sum(NSArray<NSDecimalNumber*>* decimal_numbers);


@interface ProductCard()
@property NSInteger                         section_count;
@property NSNumberFormatter*                currency_formatter;
@property PKPaymentRequest*                 payment_request;
@property NSArray<PKShippingMethod*>*       pk_shipping_methods;
@property NSData*                           order_info;                    // hashed in payment_request.applicationData
@property PKPaymentMethod*                  payment_method;
@property PKShippingMethod*                 selected_shipping_method;
@property NSString*                         shipping_method_name;
@end


@implementation ProductCard

# pragma mark Core Functionality
// tally the summary items’ cost and the grand total
- (NSArray<PKPaymentSummaryItem*>*) computeSummaryItems
{
   NSDecimalNumber* product_price=
      [NSDecimalNumber decimalNumberWithString:_product.price];
   NSDecimalNumber* shipping= _selected_shipping_method?
                                 _selected_shipping_method.amount :
                                 [NSDecimalNumber zero];
   NSDecimalNumber* tax=      [product_price decimalNumberByMultiplyingBy:
                                 [NSDecimalNumber decimalNumberWithString:@"0.08"]];
   NSDecimalNumber* total=    decimal_number_sum(@[product_price, shipping, tax]);
   
   // specify summary items
   NSMutableArray<PKPaymentSummaryItem*>* summary_items=
      [NSMutableArray arrayWithArray: 
       @[
         [PKPaymentSummaryItem summaryItemWithLabel:_product.name amount:product_price],
         [PKPaymentSummaryItem summaryItemWithLabel:@"Shipping"   amount:shipping],
         [PKPaymentSummaryItem summaryItemWithLabel:@"Tax"        amount:tax],
         [PKPaymentSummaryItem summaryItemWithLabel:@"Acme"       amount:total]
         ]];
   
   return summary_items.copy;
}

- (void) process_ApplePay_payment_request
{
   /* ApplePay payment workflow */
   
   // create payment request
   AppDelegate* app_delegate= [UIApplication sharedApplication].delegate;
   _payment_request=
      [Stripe paymentRequestWithMerchantIdentifier:app_delegate.ApplePay_merchant_identifier];
   {
      {
         // set the essential properties
         _payment_request.merchantIdentifier=   app_delegate.ApplePay_merchant_identifier;
         _payment_request.countryCode=          @"US";
         _payment_request.currencyCode=         @"USD";
         _payment_request.merchantCapabilities= PKMerchantCapability3DS;
         _payment_request.supportedNetworks=    app_delegate.ApplePay_supported_networks;
         
         // compute the default shipping method, 
         // and set it asthe first shipping method in the list of shipping methods
         _selected_shipping_method= nil;
         if (_shipping_method_name)
         {
            NSIndexSet* index_set=
            [_pk_shipping_methods indexesOfObjectsWithOptions: NSEnumerationConcurrent
                                                  passingTest: ^
             BOOL (PKShippingMethod* pk_shipping_method, NSUInteger index, BOOL* stop)
             {
                BOOL found= false;
                if ([pk_shipping_method.identifier isEqual:_shipping_method_name])
                {
                   found= true;
                   *stop= true;
                }
                return found;
             }];
            
            NSUInteger index= [index_set firstIndex];
            if (index > 0 && index < _pk_shipping_methods.count)
            {
               NSMutableArray<PKShippingMethod*>* pk_shipping_methods=
                  [NSMutableArray arrayWithArray:_pk_shipping_methods];
               [pk_shipping_methods exchangeObjectAtIndex:index withObjectAtIndex:0];
               _pk_shipping_methods=       pk_shipping_methods.copy;
               _selected_shipping_method= _pk_shipping_methods[0];
            }
         }
         
         // set the shipping methods
         _payment_request.shippingMethods= _pk_shipping_methods;
      }
      
      // require shipping address and billing email
      _payment_request.requiredShippingAddressFields=
         PKAddressFieldPostalAddress | PKAddressFieldEmail;
      _payment_request.requiredBillingAddressFields=
         PKAddressFieldEmail;
      
      // specify a particular shipping address
      /*{
         PKContact*              contact= [PKContact new];
         CNMutablePostalAddress* address= [CNMutablePostalAddress new];
         
         address.street=          @"123 Fern Road";
         address.city=            @"San Jose";
         address.postalCode=      @"95123";
         address.country=         @"USA";
         address.ISOCountryCode=  @"US";
         contact.postalAddress=   [address copy];
         
         _payment_request.shippingContact= contact;
      }*/
   }
   
   // compute summary items and assign them to the payment request
   _payment_request.paymentSummaryItems= [self computeSummaryItems];
   
   
   static NSDateFormatter* date_formatter= nil;
   if (date_formatter == nil) {
      date_formatter= [NSDateFormatter new];
      NSLocale *locale= [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
      
      date_formatter.locale= locale;
      date_formatter.dateFormat= @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
      date_formatter.timeZone= [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
   }
   
   // add order information
   {
      NSDictionary* order_info_dictionary= @
      {
         @"product"    : _product.name,
         @"local_date" : [date_formatter stringFromDate:[NSDate date]],
      };
      
      NSError* error;
      _order_info= [NSJSONSerialization dataWithJSONObject: order_info_dictionary
                                                   options: 0
                                                     error: &error];
      NSAssert(!error, @"error converting %@ to JSON", error);
      NSLog(@"  (process_ApplePay_payment_request) order_info_dictionary == %@", order_info_dictionary);
      _payment_request.applicationData= (NSData*)_order_info;
   }
   
   // this payment gateway’s API provides a payment request–based check for ApplePay availability
   if ([Stripe canSubmitPaymentRequest:_payment_request])
   {
      PKPaymentAuthorizationViewController* payment_sheet= 
      [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:_payment_request];
      payment_sheet.delegate= self;
      [self presentViewController:payment_sheet animated:true completion:nil];      
   }
   else
   {
      [self process_Card_payment];
   }
}

- (void) process_ApplePay_payment_with_Stripe:(PKPayment*)                             payment_info 
                                   completion:(void (^)(PKPaymentAuthorizationStatus)) payment_completion
{   
   [[STPAPIClient sharedClient] createTokenWithPayment: payment_info
                                            completion: ^
    (STPToken* charge_token, NSError* error)
    {
       if (error)
       {
          NSLog(@"  (process_ApplePay_payment:completion:) error");
          payment_completion(PKPaymentAuthorizationStatusFailure);
       }
       else
          [self backend_process_payment_info:payment_info gateway:@"stripe" charge_token:charge_token completion:payment_completion];
    }];
}

/* 
 * throws JSONDeserializationException
 */
- (void) backend_process_payment_info:(PKPayment*)                             payment_info
                              gateway:(NSString*)                              gateway
                         charge_token:(id)                                     charge_token
                           completion:(void (^)(PKPaymentAuthorizationStatus)) payment_completion
{
   NSLog(@"ProductCard: backend_process_payment_info:charge_token:");
   
   RestIO* rest_io= [RestIO sharedRestIO];
   {
      AppDelegate* app_delegate=    [UIApplication sharedApplication].delegate;
      NSString* payment_charge_uri= [NSString stringWithFormat:@"%@%@",
                                     app_delegate.rest_io_host,
                                     @"/payment"];
      
      NSNumber* total_in_cents= (NSNumber*)
      [_payment_request.paymentSummaryItems[_payment_request.paymentSummaryItems.count - 1].amount
       decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithString:@"100"]];
      NSString* currency= _payment_request.currencyCode;
      
      NSString* contact_name=
      [payment_info.shippingContact.name.givenName stringByAppendingString:
       [@" " stringByAppendingString:payment_info.shippingContact.name.familyName]];
      
      // collect info required by order procesing webapp
      NSDictionary* order_info_package_dictionary= @
      {
         @"gateway"              : gateway,
         @"source"               : ((STPToken*)charge_token).tokenId,
         @"amount"               : total_in_cents,
         @"currency"             : currency,
         @"description"          : _payment_request.paymentSummaryItems[0].label,
         @"shipping_contact"     : contact_name,
         @"shipping_email"       : payment_info.shippingContact.emailAddress,
         @"shipping_street"      : payment_info.shippingContact.postalAddress.street,
         @"shipping_city"        : payment_info.shippingContact.postalAddress.city,
         @"shipping_state"       : payment_info.shippingContact.postalAddress.state,
         @"shipping_zip"         : payment_info.shippingContact.postalAddress.postalCode,
         @"shipping_method_name" : payment_info.shippingMethod.identifier
      };
      
      NSData* order_info_package_json;
      {
         NSError* error;
         order_info_package_json=
         [NSJSONSerialization dataWithJSONObject: order_info_package_dictionary
                                         options: NSJSONWritingPrettyPrinted 
                                           error: &error];
         NSAssert(!error, @"error converting %@ to JSON", error);
      }
      
      // send order information to order processing web app
      [rest_io postResourceAtURI: payment_charge_uri
                            body: order_info_package_json
                      completion: ^
      (NSURLResponse* response, NSData* data)
      {
         NSLog(@"  (backend_process_StripeToken:): completion");
         NSLog(@"    response == %@", response);
          
         if (((NSHTTPURLResponse*)response).statusCode == 200)
         {
            NSDictionary* result;
            {
               NSError* error;
               result= [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
               if (error)
                  [NSException raise:@"JSONDeserializationException"
                              format:@"error deserializing JSON"];
            }
            
            NSLog(@"    result     == %@", result);
             
            NSString* status= (NSString*)result[@"status"];
             
            payment_completion([status isEqual: @"succeeded"]?
                               PKPaymentAuthorizationStatusSuccess : 
                               PKPaymentAuthorizationStatusFailure);
         }
         else
            payment_completion(PKPaymentAuthorizationStatusFailure);
      }];
   }
}

- (void) process_Card_payment
{
   /* non-ApplePay payment workflow */
}


#pragma mark PKPaymentAuthorizationViewControllerDelegate Protocol

/* user changed payment method
 */
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController* _Nonnull)                               controller
                     didSelectPaymentMethod:(PKPaymentMethod* _Nonnull)                                                    payment_method
                                 completion:(void (^ _Nonnull)(NSArray<PKPaymentSummaryItem*>* _Nonnull summary_items))    completion
{
   NSLog(@"paymentAuthorizationViewController:didSelectPaymentMethod:completion:");   
   NSLog(@"  payment_method.type == %lu",       (unsigned long)payment_method.type);
   NSLog(@"  payment_method.displayName == %@", payment_method.displayName);
   
   completion([self computeSummaryItems]);
}

/* user changes shipping information
 */
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController* _Nonnull)             controller
                   didSelectShippingContact:(PKContact* _Nonnull)                                        shipping_contact
                                 completion:(void (^ _Nonnull)
                                             (PKPaymentAuthorizationStatus status,
                                              NSArray<PKShippingMethod*>* _Nonnull     shipping_methods,
                                              NSArray<PKPaymentSummaryItem*>* _Nonnull summary_items))   completion
{
   NSLog(@"paymentAuthorizationViewController:didSelectShippingContact:completion:");
   
   // validate address in shipping_contact
   // if the address is not valid, set the status argument of
   // the completion block to an appropriate value,
   // such as PKPaymentAuthorizationStatusInvalidShippingPostalAddress
   
   completion(PKPaymentAuthorizationStatusSuccess, _pk_shipping_methods, [self computeSummaryItems]);
}

/* user changea shipping method
 */
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController* _Nonnull)            controller
                    didSelectShippingMethod:(PKShippingMethod* _Nonnull)                                pk_shipping_method
                                 completion:(void (^ _Nonnull)
                                             (PKPaymentAuthorizationStatus             status,
                                              NSArray<PKPaymentSummaryItem*>* _Nonnull summary_items))  completion
{
   NSLog(@"paymentAuthorizationViewController:didSelectShippingMethod:completion:");
   
   _selected_shipping_method= pk_shipping_method;
   _shipping_method_name=     pk_shipping_method.identifier;
   
   completion(PKPaymentAuthorizationStatusSuccess, [self computeSummaryItems]);
}

/* user authorizing payment request
 *
 */
- (void) paymentAuthorizationViewControllerWillAuthorizePayment:(PKPaymentAuthorizationViewController*) controller
{
   NSLog(@"paymentAuthorizationViewControllerWillAuthorizePayment:");
   
   [[NSUserDefaults standardUserDefaults] setObject:_shipping_method_name 
                                             forKey:Default_shipping_method_name];
}

/* user authorizes payment request
 */
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController*)  controller
                        didAuthorizePayment:(PKPayment*)                             payment_info
                                 completion:(void (^)(PKPaymentAuthorizationStatus)) payment_completion
{
   NSLog(@"paymentAuthorizationViewController:didAuthorizePayment:");
   
   [self process_ApplePay_payment_with_Stripe:payment_info completion:payment_completion];
}

/* payment sheet is done
 */
- (void) paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController*) controller
{
   [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark View Management
- (void) viewDidLoad 
{
   [super viewDidLoad];
   
   _currency_formatter=             [NSNumberFormatter new];
   _currency_formatter.numberStyle= NSNumberFormatterCurrencyStyle;
   
   // get last-used shipping method
   _shipping_method_name= [[NSUserDefaults standardUserDefaults] objectForKey:Default_shipping_method_name];
   
   // define table sections
   {
      short   i= 0;
      sections[  i].cell_row_height=   44; sections[i].cell_type= ProductDescription;
      sections[++i].cell_row_height=  400; sections[i].cell_type= ProductImage;
      sections[++i].cell_row_height=   44; sections[i].cell_type= ProductBuy;
      _section_count= ++i;
   }
   
   // download product image
   RestIO* rest_io= [RestIO sharedRestIO];
   [rest_io downloadResourceWithURI: _product.image_uri 
                         completion: ^
    (NSURL* destination_url)
    {
       dispatch_async(dispatch_get_main_queue(), ^
          {
             UIImage *image= [UIImage imageWithContentsOfFile:[destination_url path]];
             [((ProductCard_TableView*)self.view) setProductImage:image];
          }
       );
    }];
   
   // get the ShippingMethod objects in the app delegate,
   // and convert them to PKShippingMethod objects
   {
      AppDelegate* app_delegate= [UIApplication sharedApplication].delegate;
      NSMutableArray<PKShippingMethod*>* pk_shipping_methods= [NSMutableArray new];
      for (ShippingMethod* shipping_method in app_delegate.shipping_methods)
      {
         PKShippingMethod* pk_shipping_method=
         [PKShippingMethod 
          summaryItemWithLabel:[@"Shipping " stringByAppendingString:shipping_method.name]
          amount:[NSDecimalNumber decimalNumberWithString:shipping_method.price]];
         pk_shipping_method.identifier= shipping_method.name;
         pk_shipping_method.detail=     shipping_method.detail;
         [pk_shipping_methods addObject:pk_shipping_method];
      }
      _pk_shipping_methods= pk_shipping_methods.copy;
   }
}


# pragma mark Action Methods
- (IBAction) purchaseAction:(UIButton*) sender
{
   if (sender.tag == ApplePay_button_tag)
      [self process_ApplePay_payment_request];
   else
      [self process_Card_payment];
}


# pragma mark UITableViewDataSource & UITableViewDelegate Methods
- (NSInteger)  tableView:(UITableView *) table_view
   numberOfRowsInSection:(NSInteger)     section 
{
   return 1;
}

- (NSInteger) numberOfSectionsInTableView: (UITableView*) table_view
{
   return _section_count;
}

- (CGFloat)    tableView:(UITableView*) table_view
 heightForRowAtIndexPath:(NSIndexPath*) index_path
{
   return (CGFloat)sections[index_path.section].cell_row_height;;
}

- (UITableViewCell*) tableView:(UITableView*) table_view 
         cellForRowAtIndexPath:(NSIndexPath*) index_path 
{
   if (index_path.section >= _section_count)
      @throw [NSException exceptionWithName:@"InconsistentStateException"
                                     reason:@"invalid index_path.section"
                                   userInfo:@{ @"index_path.section" : [NSNumber numberWithLong:index_path.section] }];
   
   switch (sections[index_path.section].cell_type)
   {
      case ProductDescription:
         return [self description_cell];
         
      case ProductImage:
         return [self image_cell];
         
      case ProductBuy:
         return [self buy_cell];
   }
}


#pragma mark Table Cell Dequeuing
- (ProductCard_DescriptionCell*) description_cell
{
   ProductCard_DescriptionCell* cell= 
   (ProductCard_DescriptionCell*)[(UITableView*)self.view dequeueReusableCellWithIdentifier:@"description"];
   
   cell.description_label.text= _product.description;
   
   return cell;
}

- (ProductCard_ImageCell*) image_cell
{
   ProductCard_ImageCell* cell= 
   (ProductCard_ImageCell*)[(ProductCard_TableView*)self.view dequeueReusableCellWithIdentifier:@"image"];
   
   cell.image_view.image= ((ProductCard_TableView*)self.view).product_image;
   
   return cell;
}

- (ProductCard_BuyCell*) buy_cell
{
   // deque the buy cell (contains the “Price:” and price_label labels)
   ProductCard_BuyCell* cell= 
      (ProductCard_BuyCell*)[(ProductCard_TableView*)self.view dequeueReusableCellWithIdentifier:@"buy"];
   
   // set the value for the price_label label
   NSNumber* product_price_as_number= [NSNumber numberWithDouble:[_product.price doubleValue]];      
   cell.price_label.text=             [_currency_formatter stringFromNumber:product_price_as_number];
   
   // determine whether ApplePay is available on this device and is configured with the accepted payment networks
   BOOL can_use_ApplePay;
   {
      AppDelegate* app_delegate= [UIApplication sharedApplication].delegate;
      if ((can_use_ApplePay= [PKPaymentAuthorizationViewController canMakePayments]))
         can_use_ApplePay= [PKPaymentAuthorizationViewController
                            canMakePaymentsUsingNetworks:app_delegate.ApplePay_supported_networks];
   }
   
   // instantiate the purchase button
   UIButton* purchase_button;
   if (can_use_ApplePay)
   {
      // configure a PKPaymentButton (Pay button)
      purchase_button= [PKPaymentButton buttonWithType:PKPaymentButtonTypePlain 
                                                 style:PKPaymentButtonStyleWhiteOutline];
      purchase_button.tag= ApplePay_button_tag;
   }
   else
   {
      // configure a UIButton
      purchase_button= [UIButton buttonWithType:UIButtonTypeSystem];
      [purchase_button setTitle:@"Buy" forState:UIControlStateNormal];
      purchase_button.tag= Buy_button_tag;
   }
   
   // define the layout of the purchase button
   {
      NSArray* purchase_button_layout=
      @[[NSLayoutConstraint constraintWithItem:purchase_button                   // flush to the right side of container
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:cell.contentView
                                     attribute:NSLayoutAttributeTrailingMargin
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:purchase_button                   // center vertically within container
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:cell.contentView
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0]];
      [purchase_button setTranslatesAutoresizingMaskIntoConstraints:false];      // unburden the button from its autoresizing-mask–based layout constraints
      
      // tapping the purchase button results in a call to the purchase_action: method
      [purchase_button addTarget:self action:@selector(purchaseAction:) forControlEvents:UIControlEventTouchDown];
      
      [cell.contentView addSubview:purchase_button];
      [cell.contentView addConstraints:purchase_button_layout];
      [cell.contentView layoutIfNeeded];
   }
   
   return cell;
}

@end


NSDecimalNumber* decimal_number_sum(NSArray<NSDecimalNumber*>* decimal_numbers)
{
   NSDecimalNumber* sum= [NSDecimalNumber decimalNumberWithString:@"0.00"];
   for (NSDecimalNumber* number in decimal_numbers)
   {
      sum= [sum decimalNumberByAdding:number];
   }
   return sum;
}
