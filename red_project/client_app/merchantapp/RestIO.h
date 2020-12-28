//
//  RestIO.h
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-11.
//  Copyright (c) 2016 Ernest Bruce.
//

@import Foundation;

typedef void (^RestAPICompletion)(NSURLResponse* response, NSData* data);
typedef void (^RestDownloadCompletion)(NSURL* destination_url);

@interface RestIO : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>
+ (instancetype) sharedRestIO;

- (void) downloadResourceWithURI:(NSString*)         resoruce_uri
                      completion:(RestDownloadCompletion) completion;

- (void) getResourceAtURI:(NSString*)                uri
               completion:(RestAPICompletion)        completion;

- (void) postResourceAtURI:(NSString*)               uri
                      body:(NSData*)                 body
                completion:(RestAPICompletion)       completion;

@end
