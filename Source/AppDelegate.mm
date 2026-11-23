#import "AppDelegate.h"
#import "LockScreen.h"
#import <QuartzCore/QuartzCore.h>

// Radius of the rounded corners drawn below the bar
static const CGFloat kCornerRadius = 15.0;

// NSUserDefaults keys for the menu options
static NSString* const kRoundedCornersKey = @"RoundedCorners";
static NSString* const kAnimateTransitionsKey = @"AnimateTransitions";
static NSString* const kShowOnLockScreenKey = @"ShowOnLockScreen";

static CGPathRef CreateOverlayPath(CGSize size, CGFloat radius)
{
    CGFloat w = size.width;
    CGFloat h = size.height;

    if (radius <= 0) {
        return CGPathCreateWithRect(CGRectMake(0, 0, w, h), NULL);
    }

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, h);
    CGPathAddLineToPoint(path, NULL, 0, 0);
    CGPathAddArcToPoint(path, NULL, 0, radius, radius, radius, radius);
    CGPathAddLineToPoint(path, NULL, w - radius, radius);
    CGPathAddArcToPoint(path, NULL, w, radius, w, 0, radius);
    CGPathAddLineToPoint(path, NULL, w, h);
    CGPathCloseSubpath(path);
    return path;
}

@interface AppDelegate () {
    NSArray<NSWindow*>* m_overlayWindows;
    BOOL m_screenLocked;
}
@property (strong, nonatomic) NSStatusItem* statusItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kRoundedCornersKey : @YES,
        kAnimateTransitionsKey : @NO,
        kShowOnLockScreenKey : @NO,
    }];

    // Add a menu bar icon with the options and a way to quit the app
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"menubar.rectangle"
                                             accessibilityDescription:@"HideNotch"];

    NSMenu* menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    [self addToggleToMenu:menu title:@"Rounded Corners" key:kRoundedCornersKey];
    [self addToggleToMenu:menu title:@"Animate Transitions" key:kAnimateTransitionsKey];

    NSMenuItem* lockScreenItem = [self addToggleToMenu:menu title:@"Show on Lock Screen" key:kShowOnLockScreenKey];
    if (!LockScreenOverlaySupported()) {
        lockScreenItem.enabled = NO;
        lockScreenItem.toolTip = @"Not supported on this version of macOS";
    }

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    self.statusItem.menu = menu;

    // Draw the black overlays that hide the notch
    [self setupOverlays];

    // Recalculate if displays connect/disconnect, or if resolution changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setupOverlays)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];

    // Track locking so the overlays can be moved above the lock screen
    NSDistributedNotificationCenter* distributedCenter = [NSDistributedNotificationCenter defaultCenter];
    [distributedCenter addObserver:self
                          selector:@selector(screenDidLock:)
                              name:@"com.apple.screenIsLocked"
                            object:nil];
    [distributedCenter addObserver:self
                          selector:@selector(screenDidUnlock:)
                              name:@"com.apple.screenIsUnlocked"
                            object:nil];
}

- (NSMenuItem*)addToggleToMenu:(NSMenu*)menu title:(NSString*)title key:(NSString*)key
{
    NSMenuItem* item = [menu addItemWithTitle:title action:@selector(toggleOption:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = key;
    item.state = [self optionEnabled:key] ? NSControlStateValueOn : NSControlStateValueOff;
    return item;
}

- (BOOL)optionEnabled:(NSString*)key
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)toggleOption:(NSMenuItem*)sender
{
    NSString* key = sender.representedObject;
    BOOL enabled = ![self optionEnabled:key];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
    sender.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;

    // Only the corner shape changes what's on screen right now; the other
    // options take effect on the next transition or lock
    if ([key isEqualToString:kRoundedCornersKey]) {
        [self setupOverlays];
    }
}

- (void)screenDidLock:(NSNotification*)notification
{
    m_screenLocked = YES;
    [self moveOverlaysAboveLockScreenIfEnabled];
}

- (void)screenDidUnlock:(NSNotification*)notification
{
    m_screenLocked = NO;

    // Rebuild so the overlays are back in the normal desktop Spaces
    if ([self optionEnabled:kShowOnLockScreenKey]) {
        [self setupOverlays];
    }
}

- (void)moveOverlaysAboveLockScreenIfEnabled
{
    if (!m_screenLocked || ![self optionEnabled:kShowOnLockScreenKey]) {
        return;
    }

    MoveWindowsAboveLockScreen(m_overlayWindows);
}

- (void)setupOverlays
{
    CGFloat cornerRadius = [self optionEnabled:kRoundedCornersKey] ? kCornerRadius : 0;
    BOOL animate = [self optionEnabled:kAnimateTransitionsKey];
    // Fade in/out like a normal window, or appear and disappear instantly
    NSWindowAnimationBehavior animationBehavior = animate ? NSWindowAnimationBehaviorDefault : NSWindowAnimationBehaviorNone;

    // Unless animating, swap overlays as an instant cut with no implicit layer
    // animations. The new windows go up before the old ones come down either
    // way, so there's never a gap where the notch shows.
    [CATransaction begin];
    [CATransaction setDisableActions:!animate];

    NSMutableArray<NSWindow*>* newWindows = [NSMutableArray array];

    for (NSScreen* screen in [NSScreen screens]) {
        // Only apply to screens with a notch
        if (screen.safeAreaInsets.top <= 0) {
            continue;
        }

        NSRect screenFrame = screen.frame;
        CGFloat menuBarHeight = screen.safeAreaInsets.top;

        // Cover the menu bar area, plus room below it for the rounded corners
        CGFloat overlayHeight = menuBarHeight + cornerRadius;
        NSRect overlayRect = NSMakeRect(
            screenFrame.origin.x,
            NSMaxY(screenFrame) - overlayHeight,
            screenFrame.size.width,
            overlayHeight);

        NSWindow* window = [[NSWindow alloc] initWithContentRect:overlayRect
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];

        // ARC owns the window via m_overlayWindows; don't let -close release it too
        window.releasedWhenClosed = NO;

        window.animationBehavior = animationBehavior;

        // Transparent window; the shape layer draws the black bar and corners
        window.backgroundColor = [NSColor clearColor];
        window.opaque = NO;
        window.hasShadow = NO;

        NSView* contentView = window.contentView;
        contentView.wantsLayer = YES;

        CAShapeLayer* shapeLayer = [CAShapeLayer layer];
        shapeLayer.frame = contentView.bounds;
        shapeLayer.contentsScale = screen.backingScaleFactor;
        shapeLayer.fillColor = [NSColor blackColor].CGColor;

        CGPathRef path = CreateOverlayPath(contentView.bounds.size, cornerRadius);
        shapeLayer.path = path;
        CGPathRelease(path);

        [contentView.layer addSublayer:shapeLayer];

        window.level = CGWindowLevelForKey(kCGStatusWindowLevelKey) - 1;
        // Let clicks pass through to the menu bar
        window.ignoresMouseEvents = YES;
        // Show on every Space (not over fullscreen apps), stay put during Mission Control,
        // and stay out of the Cmd-` window cycle
        window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;

        [window orderFrontRegardless];
        [newWindows addObject:window];
    }

    for (NSWindow* win in m_overlayWindows) {
        // Use the current setting, not the one from when the window was created
        win.animationBehavior = animationBehavior;
        [win close];
    }
    m_overlayWindows = [newWindows copy];

    [CATransaction commit];

    // Displays can change while locked (e.g. waking); keep new overlays above the lock screen
    [self moveOverlaysAboveLockScreenIfEnabled];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
