SonyCameraRemoteAPI
===================

iOS Sony Camera Remote API Client Library For QX10/100 and more..

- find device SSDP
- Live Preview support


## Install

    pod 'SonyCameraRemoteAPI'
   

## Usage

### Discover and connect device and capture live view

    SonyCameraRemoteAPIClient *client = [[SonyCameraRemoteAPIClient alloc] init];
    
    [client discoverDevices:^(NSDictionary * result, NSError *error) {
        [client captureLiveview:[result objectForKey:@"liveviewstream"] captured:^(NSData *result, NSError *error) {
            UIImage *image = [UIImage imageWithData:result];
        }];
    }];


### Shoot picture

    [client request:@"camera" method:@"actTakePicture" params:@[] completion:^(NSDictionary *result, NSError *error) {
        NSArray *urls = [result objectForKey:@"result"];
        [self.shootImage setImageWithURL:[NSURL URLWithString:[[urls objectAtIndex:0]objectAtIndex:0]]];
    }];


### more API command
check sony Camera Remote API reference https://developer.sony.com/develop/cameras/
    
