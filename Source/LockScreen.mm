#import "LockScreen.h"
#include <dlfcn.h>

namespace {

// Lock screen is 300
constexpr int kAboveLockScreenSpaceLevel = 400;
constexpr int kMoveWindowsFlags = 7;

using SLSMainConnectionIDFn = int (*)(void);
using SLSSpaceCreateFn = uint64_t (*)(int cid, int one, int zero);
using SLSSpaceSetAbsoluteLevelFn = CGError (*)(int cid, uint64_t space, int level);
using SLSShowSpacesFn = CGError (*)(int cid, CFArrayRef spaces);
using SLSSpaceAddWindowsAndRemoveFromSpacesFn = CGError (*)(int cid, uint64_t space, CFArrayRef windows, int flags);

struct SkyLight {
    SLSMainConnectionIDFn mainConnectionID = nullptr;
    SLSSpaceCreateFn spaceCreate = nullptr;
    SLSSpaceSetAbsoluteLevelFn spaceSetAbsoluteLevel = nullptr;
    SLSShowSpacesFn showSpaces = nullptr;
    SLSSpaceAddWindowsAndRemoveFromSpacesFn spaceAddWindowsAndRemoveFromSpaces = nullptr;

    bool loaded() const
    {
        return mainConnectionID && spaceCreate && spaceSetAbsoluteLevel && showSpaces
            && spaceAddWindowsAndRemoveFromSpaces;
    }
};

const SkyLight& LoadSkyLight()
{
    static const SkyLight skyLight = [] {
        SkyLight sl;
        void* handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        if (!handle) {
            return sl;
        }
        sl.mainConnectionID = (SLSMainConnectionIDFn)dlsym(handle, "SLSMainConnectionID");
        sl.spaceCreate = (SLSSpaceCreateFn)dlsym(handle, "SLSSpaceCreate");
        sl.spaceSetAbsoluteLevel = (SLSSpaceSetAbsoluteLevelFn)dlsym(handle, "SLSSpaceSetAbsoluteLevel");
        sl.showSpaces = (SLSShowSpacesFn)dlsym(handle, "SLSShowSpaces");
        sl.spaceAddWindowsAndRemoveFromSpaces = (SLSSpaceAddWindowsAndRemoveFromSpacesFn)dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces");
        return sl;
    }();
    return skyLight;
}

// Created once, kept for the app's lifetime
uint64_t AboveLockScreenSpace()
{
    static uint64_t space = 0;
    if (space != 0) {
        return space;
    }

    const SkyLight& sl = LoadSkyLight();
    int cid = sl.mainConnectionID();
    uint64_t newSpace = sl.spaceCreate(cid, 1, 0);
    if (newSpace == 0) {
        return 0;
    }
    sl.spaceSetAbsoluteLevel(cid, newSpace, kAboveLockScreenSpaceLevel);
    sl.showSpaces(cid, (__bridge CFArrayRef) @[ @(newSpace) ]);

    space = newSpace;
    return space;
}

} // namespace

BOOL LockScreenOverlaySupported(void)
{
    return LoadSkyLight().loaded();
}

BOOL MoveWindowsAboveLockScreen(NSArray<NSWindow*>* windows)
{
    if (!LockScreenOverlaySupported() || windows.count == 0) {
        return NO;
    }

    uint64_t space = AboveLockScreenSpace();
    if (space == 0) {
        return NO;
    }

    NSMutableArray<NSNumber*>* windowNumbers = [NSMutableArray array];
    for (NSWindow* window in windows) {
        [windowNumbers addObject:@(window.windowNumber)];
    }

    const SkyLight& sl = LoadSkyLight();
    CGError err = sl.spaceAddWindowsAndRemoveFromSpaces(
        sl.mainConnectionID(), space, (__bridge CFArrayRef)windowNumbers, kMoveWindowsFlags);
    return err == kCGErrorSuccess;
}
