//
//  FirstViewController.m
//  Demo
//
//  Created by John Scott on 17/03/2016.
//  Copyright © 2016 John Scott. All rights reserved.
//

#import "FirstViewController.h"

#import "JJRSObjectDescription.h"

@interface FirstViewController ()

@property (nonatomic, weak) IBOutlet UITextView * textView;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.textView.attributedText = nil;
    self.textView.attributedText = [JJRSObjectDescription attributedDescriptionForObject:self.view.window];
}

@end
