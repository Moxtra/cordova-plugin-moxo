//
//  MXDelegateMapper.m
//  HelloCordova
//
//  Created by John on 2020/4/13.
//

#import "MXDelegateMapper.h"

@implementation MXDelegateMapper
+ (instancetype)sharedMapper {
    static MXDelegateMapper *_mapper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mapper = [[MXDelegateMapper alloc] initPrivate];
    });
    return _mapper;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        
    }
    return self;
}

- (instancetype)init {
    return [[self class] sharedMapper];
}

- (NSMutableDictionary *)delegateMapper {
    if (!_delegateMapper) {
        _delegateMapper = [[NSMutableDictionary alloc] init];
    }
    return _delegateMapper
    ;
}

@end
