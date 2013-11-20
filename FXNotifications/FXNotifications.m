//
//  FXNotifications.m
//
//  Version 1.0.1
//
//  Created by Nick Lockwood on 20/11/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXNotifications
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "FXNotifications.h"
#import <objc/runtime.h>


#import <Availability.h>
#if !__has_feature(objc_arc) || !__has_feature(objc_arc_weak)
#error This class requires automatic reference counting and weak references
#endif


typedef void (^FXNotificationBlock)(NSNotification *note, __weak id observer);


@interface FXNotificationWrapper : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, weak) NSObject *object;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) FXNotificationBlock block;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, weak) NSNotificationCenter *center;

- (void)action:(NSNotification *)note;
- (BOOL)matchesName:(NSString *)name object:(id)object;

@end


@implementation NSObject (FXNotifications)

- (NSMutableArray *)FXNotifications_wrappers
{
    @synchronized(self)
    {
        NSMutableArray *wrappers = objc_getAssociatedObject(self, _cmd);
        if (!wrappers)
        {
            wrappers = [NSMutableArray array];
            objc_setAssociatedObject(self, _cmd, wrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return wrappers;
    }
}

- (void)FXNotifications_addObserverWrapper:(FXNotificationWrapper *)wrapper
{
    @synchronized(self)
    {
        NSInteger count = 0;
        for (FXNotificationWrapper *_wrapper in [self FXNotifications_wrappers])
        {
            if ([_wrapper matchesName:wrapper.name object:wrapper.object]) count ++;
        }
        if (count == 0)
        {
            [wrapper.center addObserver:self
                               selector:@selector(FXNotification_action:)
                                   name:wrapper.name
                                 object:wrapper.object];
        }
        [[self FXNotifications_wrappers] addObject:wrapper];
    }
}

- (void)FXNotifications_removeObserverWrapper:(FXNotificationWrapper *)wrapper
{
    @synchronized(self)
    {
        [[self FXNotifications_wrappers] removeObject:wrapper];
        NSInteger count = 0;
        for (FXNotificationWrapper *_wrapper in [self FXNotifications_wrappers])
        {
            if ([_wrapper matchesName:wrapper.name object:wrapper.object]) count ++;
        }
        if (count == 0)
        {
            [wrapper.center removeObserver:self];
        }
    }
}

- (void)FXNotification_action:(NSNotification *)note
{
    for (FXNotificationWrapper *wrapper in [self FXNotifications_wrappers])
    {
        if ([wrapper matchesName:note.name object:note.object])
        {
            [wrapper action:note];
        }
    }
}

@end


@implementation FXNotificationWrapper

- (void)action:(NSNotification *)note
{
    if (self.block)
    {
        if ([NSOperationQueue currentQueue] == self.queue)
        {
             self.block(note, self.observer);
        }
        else
        {
            [self.queue addOperationWithBlock:^{
                self.block(note, self.observer);
            }];
        }
    }
}

- (BOOL)matchesName:(NSString *)name object:(id)object
{
    return  (!self.name || [name isEqualToString:self.name]) && (!self.object || object == self.object);
}

- (void)dealloc
{
    [_observer FXNotifications_removeObserverWrapper:self];
}

@end


@implementation NSNotificationCenter (FXNotifications)

- (void)addObserver:(id)observer
            forName:(NSString *)name
             object:(id)object
              queue:(NSOperationQueue *)queue
         usingBlock:(FXNotificationBlock)block
{
    FXNotificationWrapper *wrapper = [[FXNotificationWrapper alloc] init];
    wrapper.observer = observer;
    wrapper.object = object;
    wrapper.name = name;
    wrapper.block = block;
    wrapper.queue = queue ?: [NSOperationQueue currentQueue];
    wrapper.center = self;
    
    [observer FXNotifications_addObserverWrapper:wrapper];
}

@end

