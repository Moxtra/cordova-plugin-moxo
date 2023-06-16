//
//  MXDelegateMapper.h
//  HelloCordova
//
//  Created by John on 2020/4/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MXDelegateMapper : NSObject
@property (nonatomic, strong) NSMutableDictionary *delegateMapper;
+ (instancetype)sharedMapper;
@end

NS_ASSUME_NONNULL_END
