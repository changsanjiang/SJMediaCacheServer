#  分层


- Assets       共享部分
- Contents   写入和读取数据
- Reader      处理请求, 持有content写入数据

共享数据的写入操作
    - 共享数据的初始化由Assets内部进行

Contents 的创建工作
    - 


@protocol Asset
@property NSString *name;
@property AssetType type;
- (void)registerObserver:(id<AssetObserver>)observer;
- (void)removeObserver:(id<AssetObserver>)observer;
- (void)prepare;
@end

@protocol AssetObserver
- (void)asset:(id<Asset>)asset didCompletePrepareWithError:(NSError *)error;
@end

@protocol FILEAsset <Asset>
@property NSString *contentType;
@property UInt64 totalLength;
@property NSString *extname;
@end

@protocol HLSAsset <Asset>
@property NSString *tsContentType; // 本地
@property HLSParser *parser; 
@end 

@protocol HLSParser
@end

@protocol Content

@end

@protocol Reader

@end
