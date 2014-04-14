    //
//  QXAPIClient.m
//  SonyQXAPITest
//
//  Created by masafumi yoshida on 2014/04/12.
//  Copyright (c) 2014年 masafumi yoshida. All rights reserved.
//

#import "SonyCameraRemoteAPIClient.h"
#import <AFNetworking.h>
#import <KissXML/DDXML.h>

typedef struct {
    unsigned char start_byte;
    unsigned char payload_type;
    unsigned char sequence_number[2];
    unsigned char timestamp[4];
} liveview_common_header;

typedef struct {
    unsigned char start_code[4];
    unsigned char image_size[3];
    unsigned char padding_size;
    unsigned char reserved1[4];
    unsigned char flag;
    unsigned char reserved2[115];
} liveview_payload_header;

@interface SonyCameraRemoteAPIClient ()
@property (strong, nonatomic) SonyCameraRemoteAPIClientCompleteBlocks discoverComplete;
@property (strong, nonatomic) SonyCameraRemoteAPIClientCompleteBlocks captured;
@property (strong, nonatomic) NSString* descriptionUrl;
@property (strong, nonatomic) NSMutableDictionary* serviceUrls;
@property (nonatomic) int packetSize;
@property (nonatomic) int paddingSize;
@property (nonatomic) int currentPacketSize;
@property (strong,nonatomic) NSMutableData *packet;

@property(nonatomic,strong) AsyncUdpSocket *ssdpSock;
@end

@implementation SonyCameraRemoteAPIClient

-(void)request:(NSString*)service
        method:(NSString*)method
        params:(id)params
    completion:(SonyCameraRemoteAPIClientCompleteBlocks)completion{

    NSString *serviceUrl = [self.serviceUrls objectForKey:service];
    if(serviceUrl){
        AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        payload[@"version"] = @"1.0";
        payload[@"method"] = method;
        payload[@"params"] = params;
        payload[@"id"] = [NSNumber numberWithInt:1];
        
        
        [manager POST:serviceUrl
           parameters:payload
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                             completion(responseObject,nil);
                                         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                             completion(nil,error);
                                         }];
        
    
        
    }
    else{
        completion(nil,nil);
    }
}


-(void)captureLiveview:(NSString*)liveviewUrl
    captured:(SonyCameraRemoteAPIClientCompleteBlocks)captured{
    self.captured = captured;
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    
    
    NSURL *url = [NSURL URLWithString:liveviewUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];

    self.packetSize = 0;
    self.currentPacketSize = 0;
    
    [task resume];
    
}


- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
//    NSLog(@"DATA:\n%d\nEND DATA\n",data.length);
    if(!self.packet){
        [self receiveFromHeader:data];
    
    }
    else{
        if(self.packetSize > data.length + self.packet.length){
            [self.packet appendData:data];
      //      NSLog(@"IMAGE DATA:\n%d/%d\n",self.packet.length,self.packetSize);
        }
        else {
            int appendSize = self.packetSize - self.packet.length;
            [self.packet appendData:[ data subdataWithRange:NSMakeRange(0,appendSize)]];
        //    NSLog(@"IMAGE DATA:\n%d/%d\n",self.packet.length,self.packetSize);
            NSData *packet = self.packet;
            self.packet = nil;
            self.captured(packet,nil);
            
            if(data.length > self.packetSize + self.packet.length + self.paddingSize){
                [self receiveFromHeader:[data subdataWithRange:NSMakeRange(appendSize + self.paddingSize,data.length - appendSize -self.paddingSize)]];
                
            }
            
        }
    }
    
    
}

-(void)receiveFromHeader:(NSData*)data{
    unsigned char commonHeader[8];
    unsigned char payloadHeader[128];
    
    if(!data || data.length < 8){
        return;
    }
    [data getBytes:commonHeader length:8];
    if(commonHeader[0] == 0xFF){
        liveview_common_header *liveviewCommonHeader =(liveview_common_header*)commonHeader;
        int sequenseNumber = (int)*(unsigned short*)liveviewCommonHeader->sequence_number;
        int timestamp = (int)*(unsigned short*)liveviewCommonHeader->timestamp;
        //NSLog(@"%c %c %d %d",liveviewCommonHeader->start_byte,liveviewCommonHeader->payload_type,sequenseNumber,timestamp);
        [data getBytes:payloadHeader range:NSMakeRange(8,127)];
        liveview_payload_header *liveviewPayloadHeader =(liveview_payload_header*)payloadHeader;
        int imageSize = (int)*(unsigned short*)liveviewPayloadHeader->image_size;
        int paddingSize = (int)liveviewPayloadHeader->padding_size;
       // NSLog(@"%s %d %d",liveviewPayloadHeader->start_code,imageSize,paddingSize);
        self.packetSize = imageSize;
        self.paddingSize = paddingSize;
        
        if(self.packetSize < data.length - 136){
            self.packet = [[NSMutableData alloc] initWithData:[data subdataWithRange:NSMakeRange(136,self.packetSize)]];
            NSData *packet = self.packet;
            self.packet = nil;
            self.captured(packet,nil);
            [self receiveFromHeader:[data subdataWithRange:NSMakeRange(136 + self.packetSize, data.length - 136 - self.packetSize)]];
        }
        else{
            self.packet = [[NSMutableData alloc] initWithData:[data subdataWithRange:NSMakeRange(136, data.length - 136)]];
            
        }
       // NSLog(@"IMAGE DATA:\n%d\n",self.packet.length);
    }
    
}


-(void)discoverDevices:(SonyCameraRemoteAPIClientCompleteBlocks)completion{
    self.discoverComplete = completion;
    NSError *socketError = nil;
    
    self.ssdpSock = [[AsyncUdpSocket alloc] initIPv4];
    self.ssdpSock.delegate = self;
    
    NSString *str = @"M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMan: \"ssdp:discover\"\r\nST: urn:schemas-sony-com:service:ScalarWebAPI:1\r\n\r\n";
    
    if (![ self.ssdpSock bindToPort:1900 error:&socketError]) {
        NSLog(@"Failed binding socket: %@", [socketError localizedDescription]);
        return ;
    }
    
    if(![ self.ssdpSock joinMulticastGroup:@"239.255.255.250" error:&socketError]){
        NSLog(@"Failed joining multicast group: %@", [socketError localizedDescription]);
        return ;
    }
    
    if (![ self.ssdpSock enableBroadcast:TRUE error:&socketError]){
        NSLog(@"Failed enabling broadcast: %@", [socketError localizedDescription]);
        return ;
    }
    
    [self.ssdpSock sendData:[str dataUsingEncoding:NSUTF8StringEncoding]
                     toHost: @"239.255.255.250" port: 1900 withTimeout:2 tag:1];
    [self.ssdpSock receiveWithTimeout: 2 tag:1];
    [NSTimer scheduledTimerWithTimeInterval: 5 target: self
                                   selector:@selector(completeSearch:) userInfo: self repeats: NO];
    [self.ssdpSock closeAfterSendingAndReceiving];
}


-(void) completeSearch: (NSTimer *)t {
    NSLog(@"%s",__FUNCTION__);
    [self.ssdpSock close];
    self.ssdpSock = nil;
    
    if(self.descriptionUrl){
        [self getDeviceDescription:self.descriptionUrl completion:self.discoverComplete];
    }
    else{
        // retry
        [self discoverDevices:self.discoverComplete];
    }
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port{
    NSLog(@"%s %d %@ %d",__FUNCTION__,tag,host,port);
    NSString *aStr = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSLog(@"%@",aStr);
    
    NSString *url = [self parseDeviceDescriptionUrl:aStr];
    
        
    if(url){
        self.descriptionUrl = url;
    }
    
    return NO;
}


-(NSString*) parseDeviceDescriptionUrl:(NSString*)response{
    NSError *error;
    NSRegularExpression *regexp =
    [NSRegularExpression regularExpressionWithPattern:@"LOCATION: (.*)"
                                              options:0
                                                error:&error];
    
    NSTextCheckingResult *match = [regexp firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
    if(match){
        return [response substringWithRange:[match rangeAtIndex:1]];
    }
    return nil;
}



-(void)getDeviceDescription:(NSString*)deviceDescriptionURL
    completion:(SonyCameraRemoteAPIClientCompleteBlocks)completion{
    self.serviceUrls = [NSMutableDictionary dictionary];
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFXMLParserResponseSerializer new];
    [manager GET:deviceDescriptionURL
      parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
          NSError *error;
          
          DDXMLDocument *doc = [[DDXMLDocument alloc] initWithData:operation.responseData options:0 error:&error];
          if (!error) {
              NSArray *services = [doc nodesForXPath:@"//av:X_ScalarWebAPI_Service" error:nil];
              
              for(DDXMLNode *node in services){
                  DDXMLNode *typeNode =node.children.firstObject;
                  DDXMLNode *actionListNode =[node.children objectAtIndex:1];
                  
                  [self.serviceUrls setObject: [NSString stringWithFormat:@"%@/%@" ,actionListNode.stringValue,typeNode.stringValue] forKey:typeNode.stringValue];
              }
              
              NSArray *liveUrls = [doc nodesForXPath:@"//av:X_ScalarWebAPI_LiveView_URL" error:nil];
              NSString*liveViewImage;
              for(DDXMLNode *node in liveUrls){
                  liveViewImage = node.stringValue;
              }
              completion(@{@"liveviewstream":liveViewImage},nil);
              
          } else {
              NSLog(@"%@ %@", [error localizedDescription], [error userInfo]);
          }
          
      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
          NSLog(@"Error: %@", error);
          completion(nil,error);
      }];
    
    
    
}

@end
