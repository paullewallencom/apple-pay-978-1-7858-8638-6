//
//  RestIO.m
//  MerchantApp
//
//  Created by Ernest Bruce on 2015-09-11.
//  Copyright (c) 2016 Ernest Bruce.
//

@import Foundation;
#import "RestIO.h"


@interface RestIO()
@property (nonatomic) NSMutableDictionary* tasks;
@end


@implementation RestIO

+ (instancetype) sharedRestIO
{
   static RestIO* shared_io;
   @synchronized(self) {
      if (!shared_io) {
         shared_io= [RestIO new];
      }
      return shared_io;
   }
}

- (instancetype) init
{
   self=   [super init];
   _tasks= [NSMutableDictionary new];
   return self;
}

- (void) downloadResourceWithURI:(NSString*)              uri
                      completion:(RestDownloadCompletion) completion
{
   NSURL*        url=     [NSURL URLWithString:uri];
   NSURLRequest* request= [NSURLRequest requestWithURL:url];
   
   // add download task to download-task dictionary
   NSURLSessionDownloadTask* 
   download_task= [self.ephemeral_session downloadTaskWithRequest:request];
   
   NSMutableDictionary*
   download_task_data= [NSMutableDictionary dictionaryWithDictionary:
                        @{ 
                          @"request"    : request,
                          @"completion" : completion
                          }
                        ];
   
   [_tasks setObject:download_task_data forKey:download_task];
   
   [download_task resume];
}

- (void) getResourceAtURI:(NSString*)        uri
               completion:(RestAPICompletion) completion
{
   NSURLSessionDataTask* data_task= [self.api_session dataTaskWithURL:[NSURL URLWithString:uri]];
   
   // add task to data-task dictionary
   {
      NSMutableData*       empty_data= [NSMutableData dataWithCapacity:50];
      NSMutableDictionary* task_data=  [NSMutableDictionary dictionaryWithDictionary:
                                        @{ @"data":         empty_data,
                                           @"completion":   completion
                                           }
                                        ];
      [_tasks setObject:task_data forKey:data_task];
   }
   
   [data_task resume];
}

- (void) postResourceAtURI:(NSString*)         uri
                      body:(NSData*)           body
                completion:(RestAPICompletion) completion
{
   NSMutableURLRequest* request= [NSMutableURLRequest requestWithURL:[NSURL URLWithString:uri]];
   {
      request.HTTPMethod= @"post";
      request.HTTPBody=   body;
   }   
   
   // add task to tasks dictionary
   NSURLSessionDataTask* data_task= [self.api_session dataTaskWithRequest:request];
   {
      NSMutableData*       empty_data= [NSMutableData dataWithCapacity:50];
      NSMutableDictionary* task_data=  [NSMutableDictionary dictionaryWithDictionary:
                                        @{ 
                                          @"data"       : empty_data,
                                          @"completion" : completion
                                          }
                                        ];
      [_tasks setObject:task_data forKey:data_task];
   }
   
   [data_task resume];
}


#pragma mark Private Methods
- (NSURLSession*) api_session
{
   static NSURLSession* api_session= nil;
   {
      NSURLSessionConfiguration* 
      configuration= [NSURLSessionConfiguration defaultSessionConfiguration];
      configuration.URLCache= nil;
      
      api_session= [NSURLSession sessionWithConfiguration:configuration
                                                 delegate:self 
                                            delegateQueue:nil];
   }
   return api_session;
}

- (NSURLSession*) download_session
{
   static NSURLSession*   download_session= nil;
   {
      download_session= 
      [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                    delegate:self 
                               delegateQueue:nil];
   }
   
   return download_session;
}

- (NSURLSession*) ephemeral_session
{
   static NSURLSession* ephemeral_session= nil;
   {
      ephemeral_session= 
      [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                    delegate:self 
                               delegateQueue:nil];
   }
   return ephemeral_session;
}


#pragma mark NSURLSessionDownloadDelegate Protocol
- (void)          URLSession:(NSURLSession*)             session
                downloadTask:(NSURLSessionDownloadTask*) download_task
   didFinishDownloadingToURL:(NSURL*)                    download_url
{
   NSFileManager* file_manager= [NSFileManager defaultManager];
   NSArray* urls= [file_manager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
   NSURL* documents_directory= urls[0];
   
   NSURL* original_url=    [[download_task originalRequest] URL];
   NSURL* destination_url= [documents_directory URLByAppendingPathComponent:[original_url lastPathComponent]];
   NSError* error;
   
   // remove existing file at destination
   [file_manager removeItemAtURL:destination_url error:NULL];
   
   BOOL success= [file_manager copyItemAtURL:download_url toURL:destination_url error:&error];
   if (success)
   {
      NSMutableDictionary* download_task_data= _tasks[download_task];
      {
         NSAssert(download_task_data, @"download_task_data must not be nil");
         [download_task_data setObject:destination_url forKey:@"destination_url"];
      }
   }
   else
      NSLog(@"Error during the copy: %@", [error localizedDescription]);
}

- (void)     URLSession:(NSURLSession*)     session
                   task:(NSURLSessionTask*) task
   didCompleteWithError:(NSError*)          error
{
   if (error)
      NSLog(@"  (URLSession:task:didCompleteWithError:): task %@ completed with error: %@",
            task, [error localizedDescription]);
   else
   {
      NSDictionary* task_data= _tasks[task];
      {
         NSAssert(task_data, @"task_data must not be nil");
         
         if ([task isKindOfClass:[NSURLSessionDownloadTask class]])
         {
            NSURL* destination_url=     task_data[@"destination_url"];
            void (^completion)(NSURL*)= task_data[@"completion"];
            completion(destination_url);      
         }
         else if ([task isKindOfClass:[NSURLSessionDataTask class]])
         {
            NSURLResponse* response=                     task_data[@"response"];
            NSData*        data=                         task_data[@"data"];
            void (^completion)(NSURLResponse*, NSData*)= task_data[@"completion"];
            completion(response, data);
         }
         
         [_tasks removeObjectForKey:task];
      }
   }
}


#pragma mark NSURLSessionDataDelegate Protocol
/* NSURLSessionDataDelegate_protocol
 *    the data task received the initial reply (headers) from the server.
 *    implement only if you need to support the (relatively obscure) multipart/x-mixed-replace content type
 */
- (void)   URLSession:(NSURLSession*)                                        session 
             dataTask:(NSURLSessionDataTask*)                                data_task
   didReceiveResponse:(NSURLResponse*)                                       response
    completionHandler:(void(^)(NSURLSessionResponseDisposition disposition)) completion_handler
{
   NSMutableDictionary* task_data= _tasks[data_task];
   {
      NSAssert(task_data, @"task_data must not be nil");
      
      task_data[@"response"]= response;   
      completion_handler(NSURLSessionResponseAllow);      
   }
}

/* NSURLSessionDataDelegate_protocol
 *   tells the delegate that a data task has received some of the expected data.
 *
 *   because data (NSData*) is often pieced together from a number of segments, whenever possible,
 *   use enumerateByteRangeUsingBlock: (NSData) to iterate through data rather than bytes (NSData),
 *   which flattens the data into a single memory block.
 */
- (void) URLSession:(NSURLSession*)         session
           dataTask:(NSURLSessionDataTask*) data_task
     didReceiveData:(NSData*)               received_data
{
   NSMutableDictionary* task_data= _tasks[data_task];
   {
      NSAssert(task_data, @"task_data must not be nil");
      
      NSMutableData* data= task_data[@"data"];
      [data appendData:received_data];
   }
}

@end
