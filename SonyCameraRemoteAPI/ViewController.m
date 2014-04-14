//
//  ViewController.m
//  SonyCameraRemoteAPI
//
//  Created by masafumi yoshida on 2014/04/14.
//  Copyright (c) 2014年 masafumi yoshida. All rights reserved.
//

#import "ViewController.h"
#import "SonyCameraRemoteAPIClient.h"
#import <UIImageView+WebCache.h>
#import <GPUImage.h>
#import <FrameAccessor/FrameAccessor.h>

@interface ViewController ()
@property(nonatomic,strong) SonyCameraRemoteAPIClient * client;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self roundView:self.imageCanvas];
    [self roundView:self.shootImage];
    [self roundView:self.shootButton];
    
   
    self.imageLayer = [CALayer layer];
    self.imageLayer.frame = CGRectMake(0,0,self.imageCanvas.width,self.imageCanvas.height);
    
    [self.imageCanvas.layer addSublayer:self.imageLayer];
    
    self.client = [[SonyCameraRemoteAPIClient alloc] init];
    
    
     __weak __typeof(self)weakSelf = self;
    [self.client discoverDevices:^(NSDictionary * result, NSError *error) {
        weakSelf.shootButton.enabled = YES;
        weakSelf.statusLabel.hidden = YES;
        [weakSelf.client captureLiveview:[result objectForKey:@"liveviewstream"] captured:^(NSData *result, NSError *error) {
            UIImage *image = [UIImage imageWithData:result];
            if(!image){
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                
                GPUImageSwirlFilter *filter = [[GPUImageSwirlFilter alloc] init];
                [filter setAngle:0.3];
                UIImage *filteredImage = [filter imageByFilteringImage:image];
                weakSelf.imageLayer.contents = (id)filteredImage.CGImage;
                
            });
        }];
        
        
    }];
    
	// Do any additional setup after loading the view, typically from a nib.
}

-(void)roundView:(UIView*)view{
    view.layer.cornerRadius = 2;
    view.layer.shadowColor = [[UIColor grayColor] CGColor];
    view.layer.shadowOffset = CGSizeMake(2.0, 2.0);
    view.layer.shadowRadius = 0.0f;
    view.layer.shadowOpacity = 0.5;
    
}
-(IBAction)shotPicture:(id)sender{
    
    
    self.statusLabel.hidden = NO;
    self.statusLabel.text   = @"Shoot Picture";
    
     __weak __typeof(self)weakSelf = self;
    [self.client request:@"camera" method:@"actTakePicture" params:@[] completion:^(NSDictionary *result, NSError *error) {
        NSArray *urls = [result objectForKey:@"result"];
        NSArray *errors = [result objectForKey:@"error"];
        NSLog(@"%@ %@",errors.firstObject,errors.lastObject);
        
        [self.shootImage setImageWithURL:[NSURL URLWithString:[[urls objectAtIndex:0]objectAtIndex:0]]
         completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
             GPUImageSwirlFilter *filter = [[GPUImageSwirlFilter alloc] init];
             [filter setAngle:0.3];
             UIImage *filteredImage = [filter imageByFilteringImage:image];
             weakSelf.shootImage.image = filteredImage;
             weakSelf.statusLabel.hidden = YES;
         }];
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
