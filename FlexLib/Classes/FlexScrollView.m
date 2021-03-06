/**
 * Copyright (c) 2017-present, zhenglibao, Inc.
 * email: 798393829@qq.com
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */



#import "FlexScrollView.h"
#import "FlexRootView.h"
#import "FlexParentView.h"
#import "ViewExt/UIView+Flex.h"
#import "YogaKit/UIView+Yoga.h"
#import "FlexUtils.h"
#import "FlexTouchView.h"

static void* gObserverFrame         = (void*)1;
static void* gObserverContentOffset = (void*)2;

@interface FlexScrollView()
{
    FlexParentView* _subview;
    FlexRootView* _contentView;
    UIView* _holder;
    
    UIView* _stickingView;
    NSInteger _stickingZIndex;
    BOOL _stickingYChanged;
}
@end


@implementation FlexScrollView

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _stickingZIndex = -1;
        
        // 占位的view
        _holder = [[UIView alloc]init];
        _holder.yoga.isEnabled = YES;
        [super addSubview:_holder];
        
        // 构造view tree
        __weak FlexScrollView* weakSelf = self;
        _subview = [[FlexParentView alloc]init];
        _subview.onFrameChange = ^(CGRect rc){
            weakSelf.contentSize = rc.size ;
        };
        
        _contentView = [[FlexRootView alloc]init];
        _contentView.onWillLayout = ^{
            [weakSelf onContentViewWillLayout];
        };
        _contentView.onDidLayout = ^{
            [weakSelf onContentViewDidLayout];
        };
        [_subview addSubview:_contentView];
        [super addSubview:_subview];
        
        [self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:gObserverFrame];
        [self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:gObserverContentOffset];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"frame"];
    [self removeObserver:self forKeyPath:@"contentOffset"];
}

-(void)onContentViewWillLayout
{
    [self restoreStickView];
}

-(void)onContentViewDidLayout
{
    if(_stickingView != nil){
        _stickingView.viewAttrs.originY = _stickingView.frame.origin.y ;
        [self resetStickViews:YES];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(UIView*)object change:(NSDictionary *)change context:(void *)context
{
    if(context == gObserverFrame){
        
        CGRect rcNew = [[change objectForKey:@"new"]CGRectValue];
        
        rcNew.origin = _subview.frame.origin;
        _subview.frame = rcNew;
        [_contentView setNeedsLayout];
    
    }else if(context == gObserverContentOffset){
        [self resetStickViews:NO];
    }
}

-(void)postCreate
{
    // let child has chance to process touch event
    self.canCancelContentTouches = YES;
    self.delaysContentTouches = NO;
    
#define COPYYGVALUE(prop)           \
if(from.prop.unit==YGUnitPoint||    \
    from.prop.unit==YGUnitPercent)  \
{                                   \
    to.prop = from.prop;            \
}                                   \
    
    //同步yoga属性
    YGLayout* from = self.yoga ;
    YGLayout* to = _contentView.yoga ;
    
    to.direction = from.direction ;
    to.flexDirection = from.flexDirection;
    to.justifyContent = from.justifyContent;
    to.alignItems = from.alignItems;
    to.alignSelf = from.alignSelf;
    to.flexWrap = from.flexWrap;
    to.overflow = from.overflow;
    to.display = from.display;
    
    COPYYGVALUE(paddingLeft)
    COPYYGVALUE(paddingTop)
    COPYYGVALUE(paddingRight)
    COPYYGVALUE(paddingBottom)
    COPYYGVALUE(paddingStart)
    COPYYGVALUE(paddingEnd)
    COPYYGVALUE(paddingHorizontal)
    COPYYGVALUE(paddingVertical)
    COPYYGVALUE(padding)
    
    to.aspectRatio = from.aspectRatio;
}
-(void)addSubview:(UIView *)view
{
    if(view.viewAttrs.stickTop){
        _stickingZIndex = _contentView.subviews.count;
        _stickingView = view;
    }
    [_contentView addSubview:view];
    [_contentView registSubView:view];
}
-(void)restoreStickView
{
    if(_stickingView == nil||!_stickingYChanged)
        return;
    
    CGRect rc = _stickingView.frame ;
    rc.origin.y = _stickingView.viewAttrs.originY;
    _stickingView.frame = rc;
    [_stickingView.yoga markDirty];
    [_contentView insertSubview:_stickingView atIndex:_stickingZIndex];
    _stickingYChanged = NO;
}
-(void)resetStickViews:(BOOL)fromLayout
{
    if(_stickingView == nil)
        return;
    
    CGFloat offsetY = self.contentOffset.y ;
    CGFloat y = _stickingView.viewAttrs.originY ;
    CGFloat newY = MAX(offsetY,y);
    
    CGRect rc = _stickingView.frame ;
    
    if(rc.origin.y != newY){
        rc.origin.y = newY ;
        _stickingView.frame = rc;
        
        [_contentView bringSubviewToFront:_stickingView];
        _stickingYChanged = YES;
    }
}
FLEXSET(horzScroll)
{
    BOOL b = String2BOOL(sValue) ;
    self.horizontal = b ;
    
    _contentView.flexibleWidth = b;
}
FLEXSET(vertScroll)
{
    BOOL b = String2BOOL(sValue) ;
    self.vertical = b ;
    
    _contentView.flexibleHeight = b;
}
@end
