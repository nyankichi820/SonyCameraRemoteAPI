//
//  ViewController.h
//  SonyCameraRemoteAPI
//
//  Created by masafumi yoshida on 2014/04/14.
//  Copyright (c) 2014年 masafumi yoshida. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView* shootImage;
@property (strong, nonatomic) IBOutlet UIView* imageCanvas;
@property (strong, nonatomic) IBOutlet CALayer* imageLayer;
@property (strong, nonatomic) IBOutlet UILabel* statusLabel;
@property (strong, nonatomic) IBOutlet UIButton* shootButton;
@end
