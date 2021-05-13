//
//  SJDemoViewModel.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoViewModel.h"
#import "SJDemoMediaModel.h"

@interface SJDemoSection : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, readonly) NSInteger numberOfRows;
- (nullable __kindof SJDemoRow *)rowAtIndex:(NSInteger)index;
- (void)addRow:(SJDemoRow *)row;
- (NSInteger)indexOfRow:(SJDemoRow *)row;
- (void)removeRowAtIndex:(NSInteger)index;
@end

@implementation SJDemoSection {
    NSMutableArray<__kindof SJDemoRow *> *_rows;
}

- (NSInteger)numberOfRows {
    return _rows.count;
}

- (nullable __kindof SJDemoRow *)rowAtIndex:(NSInteger)index {
    if ( [self _isGettingSafeIndex:index] )
        return _rows[index];
    return nil;
}

- (void)addRow:(SJDemoRow *)row {
    if ( row != nil ) {
        if ( _rows == nil ) {
            _rows = NSMutableArray.array;
        }
        [_rows addObject:row];
    }
}

- (NSInteger)indexOfRow:(SJDemoRow *)row {
    if ( row != nil )
        return [_rows indexOfObject:row];
    return NSNotFound;
}

- (void)removeRowAtIndex:(NSInteger)index {
    if ( [self _isGettingSafeIndex:index] )
        [_rows removeObjectAtIndex:index];
}

- (BOOL)_isGettingSafeIndex:(NSInteger)index {
    return index >= 0 && index < _rows.count;
}
@end

@interface SJDemoViewModel ()
@property (nonatomic, strong) SJDemoSection *mediaSection;
@property (nonatomic, strong) SJDemoSection *downloadSection;
@end

@implementation SJDemoViewModel {
    NSArray<SJDemoSection *> *_sections;
    NSMutableArray<NSString *> *_registers;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _mediaSection = SJDemoSection.alloc.init;
        _mediaSection.title = @"";
        
        _downloadSection = SJDemoSection.alloc.init;
        _downloadSection.title = @"下载队列";
        
        _sections = @[_mediaSection, _downloadSection];
    }
    return self;
}

- (nullable SJDemoMediaRow *)addMediaRowWithModel:(SJDemoMediaModel *)model {
    if ( model != nil ) {
        SJDemoMediaRow *row = [SJDemoMediaRow.alloc initWithMedia:model];
        __weak typeof(self) _self = self;
        row.selectedExecuteBlock = ^(SJDemoMediaRow * _Nonnull row, NSIndexPath *indexPath) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            if ( self.mediaRowWasTappedExecuteBlock ) self.mediaRowWasTappedExecuteBlock(row, indexPath);
        };
        [_mediaSection addRow:row];
        return row;
    }
    return nil;
}

- (nullable SJDemoDownloadRow *)addDownloadRowWithModel:(SJDemoMediaModel *)model {
    if ( model != nil ) {
        SJDemoDownloadRow *row = [SJDemoDownloadRow.alloc initWithMedia:model];
        __weak typeof(self) _self = self;
        row.selectedExecuteBlock = ^(SJDemoDownloadRow * _Nonnull row, NSIndexPath *indexPath) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            if ( self.downloadRowWasTappedExecuteBlock ) self.downloadRowWasTappedExecuteBlock(row, indexPath);
        };
        [_downloadSection addRow:row];
        return row;
    }
    return nil;
}

- (void)removeRow:(SJDemoRow *)row {
    for ( SJDemoSection *s in _sections ) {
        NSInteger idx = [s indexOfRow:row];
        if ( idx != NSNotFound ) {
            [s removeRowAtIndex:idx];
            break;
        }
    }
}

- (NSInteger)numberOfSections {
    return _sections.count;
}

- (nullable NSString *)titleForHeaderInSection:(NSInteger)section {
    return _sections[section].title;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    return _sections[section].numberOfRows;
}

- (nullable SJDemoRow *)rowAtIndexPath:(NSIndexPath *)indexPath {
    return [_sections[indexPath.section] rowAtIndex:indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( _registers == nil ) {
        _registers = NSMutableArray.new;
    }
    SJDemoRow *row = [self rowAtIndexPath:indexPath];
    NSString *identifier = NSStringFromClass(row.cellClass);
    if ( ![_registers containsObject:identifier] ) {
        [_registers addObject:identifier];
        [tableView registerNib:row.cellNib forCellReuseIdentifier:identifier];
    }
    return [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
}
@end
