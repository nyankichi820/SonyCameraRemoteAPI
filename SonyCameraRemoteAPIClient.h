//
//  QXAPIClient.h
//  SonyQXAPITest
//
//  Created by masafumi yoshida on 2014/04/12.
//  Copyright (c) 2014年 masafumi yoshida. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CocoaAsyncSocket/AsyncUdpSocket.h>


typedef void (^SonyCameraRemoteAPIClientCompleteBlocks)(id result,NSError *error);



@interface SonyCameraRemoteAPIClient : NSObject<AsyncUdpSocketDelegate>

-(void)discoverDevices:(SonyCameraRemoteAPIClientCompleteBlocks)completion;

-(void)request:(NSString*)service
        method:(NSString*)method
        params:(id)params
    completion:(SonyCameraRemoteAPIClientCompleteBlocks)completion;

-(void)captureLiveview:(NSString*)liveviewUrl
               captured:(SonyCameraRemoteAPIClientCompleteBlocks)captured;
@end
