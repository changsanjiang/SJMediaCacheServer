//
//  MCSDefines.h
//  Pods
//
//  Created by BlueDancer on 2020/7/6.
//

#ifndef MCSDefines_h
#define MCSDefines_h

typedef NS_ENUM(NSUInteger, MCSResourceType) {
    MCSResourceTypeVOD,
    MCSResourceTypeHLS
};

typedef NS_OPTIONS(NSUInteger, MCSDataType) {
    MCSDataTypeHLSMask      = 0xFF,
    MCSDataTypeHLSPlaylist  = 1,
    MCSDataTypeHLSAESKey    = 2,
    MCSDataTypeHLSTs        = 3,
    MCSDataTypeHLS          = 1 << MCSDataTypeHLSPlaylist | 1 << MCSDataTypeHLSAESKey | 1 << MCSDataTypeHLSTs,

    MCSDataTypeVODMask      = 0xFF00,
    MCSDataTypeVOD          = 1 << 8,
};


typedef NS_OPTIONS(NSUInteger, MCSLogOptions) {
    MCSLogOptionPrefetcher          = 1 << 0,
    MCSLogOptionResourceReader      = 1 << 1,
    MCSLogOptionDataReader          = 1 << 2,
    MCSLogOptionDownload            = 1 << 3,
    MCSLogOptionHTTPConnection      = 1 << 4,
    MCSLogOptionSQLite              = 1 << 5,
    MCSLogOptionSessionTask         = 1 << 6,
    MCSLogOptionDefault = MCSLogOptionPrefetcher | MCSLogOptionResourceReader | MCSLogOptionDataReader | MCSLogOptionHTTPConnection,
    MCSLogOptionAll = MCSLogOptionDefault | MCSLogOptionDownload | MCSLogOptionSQLite | MCSLogOptionSessionTask,
};

#endif /* MCSDefines_h */
