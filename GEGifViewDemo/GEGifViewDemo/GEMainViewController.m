//
//  GEMainViewController.m
//  GEGifViewDemo
//
//  Created by sunyanliang on 13-10-11.
//  Copyright (c) 2013年 SunYanLiang. All rights reserved.
//

#import "GEMainViewController.h"
#import "GEGifView.h"

@interface GEMainViewController ()

@end

@implementation GEMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    GEGifView* gifView1 = [[GEGifView alloc] initWithFileName:@"cat_justAImage.gif"]; // one picture named *.gif
    gifView1.frame = CGRectMake(0, 0+20, 160, 160);
    gifView1.backgroundColor = [UIColor grayColor];
    [self.view addSubview:gifView1];
    [gifView1 start];
    
    GEGifView* gifView2 = [[GEGifView alloc] initWithFileName:@"heart_oneFrame.gif"]; // gif which has one frame
    gifView2.frame = CGRectMake(160, 0+20, 160, 160);
    gifView2.backgroundColor = [UIColor magentaColor];
    [self.view addSubview:gifView2];
    [gifView2 start];
    
    GEGifView* gifView3 = [[GEGifView alloc] initWithFileName:@"cat_jiaFei.gif"]; // gif which has many frames
    gifView3.frame = CGRectMake(0, 160+20, 320, 320);
    gifView3.backgroundColor = [UIColor brownColor];
    [self.view addSubview:gifView3];
    [gifView3 start];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
