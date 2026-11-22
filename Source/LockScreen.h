#import <Cocoa/Cocoa.h>

// Uses private SkyLight APIs, loaded at runtime
BOOL LockScreenOverlaySupported(void);
BOOL MoveWindowsAboveLockScreen(NSArray<NSWindow*>* windows);
