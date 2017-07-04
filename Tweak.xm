#import <UIKit/UIKit.h>
#import <UIKit/UIColor+Private.h>
#import <UIKit/_UILegibilitySettings.h>
#import <objc/runtime.h>
#import "../PS.h"

@interface SBIconLabelImageParameters : NSObject
@end

@interface SBFolderIconBackgroundView : UIView
@end

@interface SBIconModel : NSObject
- (NSArray *)leafIcons;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (BOOL)hasOpenFolder;
- (SBIconModel *)model;
@end

@interface SBIcon : NSObject
@end

@interface SBIconImageView : UIView
+ (CGFloat)cornerRadius;
- (SBIcon *)icon;
@end

@interface SBIconView : UIView
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
- (BOOL)isInDock;
- (SBIconLabelImageParameters *)_labelImageParameters;
- (_UILegibilitySettings *)_legibilitySettingsWithParameters:(SBIconLabelImageParameters *)param;
- (_UILegibilitySettings *)_legibilitySettingsWithPrimaryColor:(UIColor *)color;
- (SBIconImageView *)_iconImageView;
- (void)_updateLabel;
- (void)_updateIconImageViewAnimated:(BOOL)animated;
@end

@interface SBFolderBackgroundView : UIView
+ (CGFloat)cornerRadiusToInsetContent;
- (void)_updateAccessibilityBackground; // Addition
@end

@interface SBFolderIconImageView : SBIconImageView
- (void)_updateAccessibilityBackgroundContrast; // Addition
@end

@interface SBIconViewMap : NSObject
+ (SBIconViewMap *)homescreenMap;
- (SBIconView *)iconViewForIcon:(SBIcon *)icon;
- (SBIconView *)mappedIconViewForIcon:(SBIcon *)icon;
@end

@interface SBIconListView : UIView
- (NSArray *)icons;
@end

@interface SBDockIconListView : SBIconListView
@end

@interface SBDockView : UIView
// Addition
- (void)_backgroundContrastDidChange:(id)change;
- (void)contrast70_updateTextColor;
@end

@interface SBWallpaperEffectView : UIView
@end

@interface UIView (Addition)
- (void)sb_setBoundsAndPositionFromFrame:(CGRect)frame;
@end

extern "C" BOOL _UIAccessibilityEnhanceBackgroundContrast();
extern "C" CGPoint UIRectGetCenter(CGRect);
extern "C" NSString *UIAccessibilityEnhanceBackgroundContrastChangedNotification;

%hook SBFolderIconImageView

static UIView *_accessibilityFolderIconBackgroundView;

%new
- (void)_updateAccessibilityBackgroundContrast {
    BOOL contrast = _UIAccessibilityEnhanceBackgroundContrast();
    SBFolderIconBackgroundView *backgroundView = MSHookIvar<SBFolderIconBackgroundView *>(self, "_backgroundView");
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderIconBackgroundView);
    if (!contrast) {
        if (accessibilityBackgroundView != nil) {
            [accessibilityBackgroundView removeFromSuperview];
            [accessibilityBackgroundView release];
            accessibilityBackgroundView = nil;
        }
    } else {
        if (accessibilityBackgroundView == nil) {
            CGRect frame = backgroundView != nil ? CGRectMake(1, 1, backgroundView.frame.size.width, backgroundView.frame.size.height) : CGRectZero;
            accessibilityBackgroundView = [[UIView alloc] initWithFrame:frame];
            accessibilityBackgroundView.layer.cornerRadius = [%c(SBIconImageView) cornerRadius];
            accessibilityBackgroundView.layer.masksToBounds = YES;
            [self insertSubview:accessibilityBackgroundView aboveSubview:backgroundView];
        }
    }
    [backgroundView setHidden:contrast];
    [accessibilityBackgroundView setHidden:!contrast];
    SBIconViewMap *homescreenMap = [%c(SBIconViewMap) homescreenMap];
    SBIconView *iconView = [homescreenMap mappedIconViewForIcon:[self icon]];
    BOOL iconIsInDock = [iconView isInDock];
    if (!iconIsInDock)
        [accessibilityBackgroundView setBackgroundColor:[UIColor systemGrayColor]];
    else
        [accessibilityBackgroundView setBackgroundColor:[UIColor colorWithRed:169/255.0f green:169/255.0f blue:174/255.0f alpha:1]];
    objc_setAssociatedObject(self, &_accessibilityFolderIconBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setBackgroundScale:(CGFloat)scale {
    %orig;
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderIconBackgroundView);
    [accessibilityBackgroundView setTransform:CGAffineTransformMakeScale(scale, scale)];
    objc_setAssociatedObject(self, &_accessibilityFolderIconBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
}

// Hooked in -[SBFolderIconImageView prepareToCrossfadeWithFloatyFolderView:allowFolderInteraction:]
- (void)insertSubview:(id)view1 aboveSubview:(id)view2 {
    if (view1 == MSHookIvar<UIView *>(self, "_crossfadeScalingView")) {
        UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderIconBackgroundView);
        %orig(view1, accessibilityBackgroundView == nil ? view2 : accessibilityBackgroundView);
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderIconBackgroundView);
    if (accessibilityBackgroundView != nil) {
        [accessibilityBackgroundView setCenter:UIRectGetCenter(self != nil ? self.bounds : CGRectZero)];
        objc_setAssociatedObject(self, &_accessibilityFolderIconBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
    }
}

- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        [self _updateAccessibilityBackgroundContrast];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateAccessibilityBackgroundContrast) name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    %orig;
}

%end

%hook SBIconView

- (void)setLocation: (NSInteger)location {
    BOOL shouldHook = MSHookIvar<NSInteger>(self, "_location") != location;
    %orig;
    if (shouldHook)
        [self _updateIconImageViewAnimated:NO];
}

- (void)_setIcon:(SBIcon *)icon animated:(BOOL)animated {
    BOOL shouldHook = MSHookIvar<SBIcon *>(self, "_icon") != icon;
    %orig;
    if (shouldHook) {
        if (icon != nil)
            [self _updateIconImageViewAnimated:NO];
    }
}

- (void)_updateIconImageViewAnimated:(BOOL)animated {
    %orig;
    if (MSHookIvar<SBIcon *>(self, "_icon") != nil) {
        SBFolderIconImageView *folderIconImageView = (SBFolderIconImageView *)[self _iconImageView];
        if ([folderIconImageView respondsToSelector:@selector(_updateAccessibilityBackgroundContrast)]) {
            [folderIconImageView _updateAccessibilityBackgroundContrast];
            //[self _updateLabel];
        }
    }
}

%end

%hook SBFolderBackgroundView

static UIView *_accessibilityFolderBackgroundView;

- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateAccessibilityBackground) name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    }
    return self;
}

- (void)layoutSubviews {
    %orig;
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderBackgroundView);
    accessibilityBackgroundView.frame = self ? self.frame : CGRectZero;
    objc_setAssociatedObject(self, &_accessibilityFolderBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
}

- (void)_configureBackground {
    %orig;
    [self _updateAccessibilityBackground];
}

%new
- (void)_updateAccessibilityBackground {
    BOOL contrast = _UIAccessibilityEnhanceBackgroundContrast();
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityFolderBackgroundView);
    SBWallpaperEffectView *backdropView = MSHookIvar<SBWallpaperEffectView *>(self, "_backdropView");
    if (!contrast) {
        if (accessibilityBackgroundView) {
            [accessibilityBackgroundView removeFromSuperview];
            [accessibilityBackgroundView release];
            accessibilityBackgroundView = nil;
        }
    } else {
        CGRect frame = CGRectMake(0, 0, 300, 300);
        accessibilityBackgroundView = [[UIView alloc] initWithFrame:frame];
        accessibilityBackgroundView.layer.cornerRadius = [%c(SBFolderBackgroundView) cornerRadiusToInsetContent];
        accessibilityBackgroundView.layer.masksToBounds = YES;
        accessibilityBackgroundView.backgroundColor = [UIColor systemGrayColor];
        [self insertSubview:accessibilityBackgroundView atIndex:0];
    }
    [backdropView setHidden:contrast];
    [accessibilityBackgroundView setHidden:!contrast];
    objc_setAssociatedObject(self, &_accessibilityFolderBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    %orig;
}

%end

%hook SBDockView

static UIView *_accessibilityDockBackgroundView;

- (id)initWithDockListView:(id)view forSnapshot:(BOOL)snapshot {
    self = %orig;
    if (self) {
        [self _backgroundContrastDidChange:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_backgroundContrastDidChange:) name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    }
    return self;
}

%new
- (void)_backgroundContrastDidChange: (id)change {
    BOOL contrast = _UIAccessibilityEnhanceBackgroundContrast();
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityDockBackgroundView);
    UIView *backgroundView = MSHookIvar<SBWallpaperEffectView *>(self, "_backgroundView") ? : MSHookIvar<UIImageView *>(self, "_backgroundImageView");
    if (contrast) {
        if (accessibilityBackgroundView == nil) {
            CGRect frame = backgroundView != nil ? backgroundView.frame : CGRectZero;
            accessibilityBackgroundView = [[UIView alloc] initWithFrame:frame];
            accessibilityBackgroundView.backgroundColor = [UIColor systemGrayColor];
            [self insertSubview:accessibilityBackgroundView aboveSubview:backgroundView];
            //[backgroundView removeFromSuperview];
        }
    } else {
        if (accessibilityBackgroundView) {
            [self insertSubview:accessibilityBackgroundView aboveSubview:backgroundView];
            [accessibilityBackgroundView removeFromSuperview];
            [accessibilityBackgroundView release];
            accessibilityBackgroundView = nil;
        }
    }
    [backgroundView setHidden:contrast];
    [accessibilityBackgroundView setHidden:!contrast];
    //[self contrast70_updateTextColor];
    objc_setAssociatedObject(self, &_accessibilityDockBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
}

- (void)layoutSubviews {
    %orig;
    UIView *backgroundView = MSHookIvar<SBWallpaperEffectView *>(self, "_backgroundView") ? : MSHookIvar<UIImageView *>(self, "_backgroundImageView");
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityDockBackgroundView);
    if (accessibilityBackgroundView) {
        [accessibilityBackgroundView sb_setBoundsAndPositionFromFrame:backgroundView.frame];
        objc_setAssociatedObject(self, &_accessibilityDockBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
    }
}

- (void)setBackgroundAlpha:(CGFloat)alpha {
    %orig;
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityDockBackgroundView);
    if (accessibilityBackgroundView) {
        accessibilityBackgroundView.alpha = alpha;
        objc_setAssociatedObject(self, &_accessibilityDockBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
    }
}

- (void)setVerticalBackgroundStretch:(CGFloat)stretch {
    %orig;
    UIView *backgroundView = MSHookIvar<SBWallpaperEffectView *>(self, "_backgroundView") ? : MSHookIvar<UIImageView *>(self, "_backgroundImageView");
    UIView *accessibilityBackgroundView = objc_getAssociatedObject(self, &_accessibilityDockBackgroundView);
    if (accessibilityBackgroundView) {
        [accessibilityBackgroundView setTransform:backgroundView.transform];
        objc_setAssociatedObject(self, &_accessibilityDockBackgroundView, accessibilityBackgroundView, OBJC_ASSOCIATION_ASSIGN);
    }
}

/*%new
   - (void)contrast70_updateTextColor {
        SBDockIconListView *iconListView = MSHookIvar<SBDockIconListView *>(self, "_iconListView");
        for (SBIcon *icon in [iconListView icons]) {
                SBIconView *iconView = [[%c(SBIconViewMap) homescreenMap] mappedIconViewForIcon:icon];
                [iconView _updateLabel];
        }
   }*/

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIAccessibilityEnhanceBackgroundContrastChangedNotification object:nil];
    %orig;
}

%end

/*%hook SBIconView

   - (_UILegibilitySettings *)_legibilitySettingsWithParameters:(id)param {
        BOOL contrast = _UIAccessibilityEnhanceBackgroundContrast();
        if (contrast) {
                if ([self isInDock])
                        return [self _legibilitySettingsWithPrimaryColor:[UIColor blackColor]];
        }
        return %orig;
   }

   %end*/
