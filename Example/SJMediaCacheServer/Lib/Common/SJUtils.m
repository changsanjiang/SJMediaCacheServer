//
//  SJUtils.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/5.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJUtils.h"

SJResponseContentRange
SJGetResponseContentRange(NSHTTPURLResponse *response) {
    NSDictionary *responseHeaders = response.allHeaderFields;
    NSString *bytes = responseHeaders[@"Content-Range"];
    if ( bytes.length == 0 )
        return (SJResponseContentRange){NSNotFound, NSNotFound, NSNotFound};
    
    NSString *prefix = @"bytes ";
    NSString *rangeString = [bytes substringWithRange:NSMakeRange(prefix.length, bytes.length - prefix.length)];
    NSArray<NSString *> *components = [rangeString componentsSeparatedByString:@"-"];
    NSUInteger start = (NSUInteger)[components.firstObject longLongValue];
    NSUInteger end = (NSUInteger)[components.lastObject longLongValue];
    NSUInteger totalLength = (NSUInteger)[components.lastObject.lastPathComponent longLongValue];
    return (SJResponseContentRange){start, end, totalLength};
}

NSRange
SJGetResponseNSRange(SJResponseContentRange responseRange) {
    return NSMakeRange(responseRange.start, responseRange.end + 1 - responseRange.start);
}

NSString *
SJGetResponseServer(NSHTTPURLResponse *response) {
    NSDictionary *responseHeaders = response.allHeaderFields;
    return responseHeaders[@"Server"];
}

NSString *
SJGetResponseContentType(NSHTTPURLResponse *response) {
    NSDictionary *responseHeaders = response.allHeaderFields;
    return responseHeaders[@"Content-Type"];
}

NSUInteger
SJGetResponseContentLength(NSHTTPURLResponse *response) {
    NSDictionary *responseHeaders = response.allHeaderFields;
    return [responseHeaders[@"Content-Length"] longLongValue];
}

SJRequestContentRange
SJGetRequestContentRange(NSDictionary *requestHeaders) {
    /*
     https://tools.ietf.org/html/rfc7233#section-2.1
     
     2.1.  Byte Ranges

        Since representation data is transferred in payloads as a sequence of
        octets, a byte range is a meaningful substructure for any
        representation transferable over HTTP (Section 3 of [RFC7231]).  The
        "bytes" range unit is defined for expressing subranges of the data's
        octet sequence.

          bytes-unit       = "bytes"

        A byte-range request can specify a single range of bytes or a set of
        ranges within a single representation.

          byte-ranges-specifier = bytes-unit "=" byte-range-set
          byte-range-set  = 1#( byte-range-spec / suffix-byte-range-spec )
          byte-range-spec = first-byte-pos "-" [ last-byte-pos ]
          first-byte-pos  = 1*DIGIT
          last-byte-pos   = 1*DIGIT

        The first-byte-pos value in a byte-range-spec gives the byte-offset
        of the first byte in a range.  The last-byte-pos value gives the
        byte-offset of the last byte in the range; that is, the byte
        positions specified are inclusive.  Byte offsets start at zero.

        Examples of byte-ranges-specifier values:

        o  The first 500 bytes (byte offsets 0-499, inclusive):

             bytes=0-499

        o  The second 500 bytes (byte offsets 500-999, inclusive):

             bytes=500-999

        A byte-range-spec is invalid if the last-byte-pos value is present
        and less than the first-byte-pos.

        A client can limit the number of bytes requested without knowing the
        size of the selected representation.  If the last-byte-pos value is
        absent, or if the value is greater than or equal to the current
        length of the representation data, the byte range is interpreted as
        the remainder of the representation (i.e., the server replaces the
        value of last-byte-pos with a value that is one less than the current
        length of the selected representation).

        A client can request the last N bytes of the selected representation
        using a suffix-byte-range-spec.

          suffix-byte-range-spec = "-" suffix-length
          suffix-length = 1*DIGIT

        If the selected representation is shorter than the specified
        suffix-length, the entire representation is used.

        Additional examples, assuming a representation of length 10000:

        o  The final 500 bytes (byte offsets 9500-9999, inclusive):

             bytes=-500

        Or:

             bytes=9500-

        o  The first and last bytes only (bytes 0 and 9999):

             bytes=0-0,-1

        o  Other valid (but not canonical) specifications of the second 500
           bytes (byte offsets 500-999, inclusive):

             bytes=500-600,601-999
             bytes=500-700,601-999

        If a valid byte-range-set includes at least one byte-range-spec with
        a first-byte-pos that is less than the current length of the
        representation, or at least one suffix-byte-range-spec with a
        non-zero suffix-length, then the byte-range-set is satisfiable.
        Otherwise, the byte-range-set is unsatisfiable.

        In the byte-range syntax, first-byte-pos, last-byte-pos, and
        suffix-length are expressed as decimal number of octets.  Since there
        is no predefined limit to the length of a payload, recipients MUST
        anticipate potentially large decimal numerals and prevent parsing
        errors due to integer conversion overflows.
     */
    NSString *bytes = requestHeaders[@"Range"];
    NSString *prefix = @"bytes=";
    NSString *rangeString = [bytes substringWithRange:NSMakeRange(prefix.length, bytes.length - prefix.length)];
    NSArray<NSString *> *components = [rangeString componentsSeparatedByString:@"-"];
    NSUInteger start = NSNotFound;
    if ( components.firstObject.length != 0 )
        start = (NSUInteger)[components.firstObject longLongValue];
    
    NSUInteger end = NSNotFound;
    if ( components.lastObject.length != 0 )
        end = (NSUInteger)[components.lastObject longLongValue];
    
    return (SJRequestContentRange){start, end};
}

NSRange
SJGetRequestNSRange(SJRequestContentRange requestRange) {
    NSUInteger length = 0;
    if ( requestRange.start == NSNotFound || requestRange.end == NSNotFound )
        length = NSNotFound;
    else
        length = requestRange.end + 1 - requestRange.start;
    
    return NSMakeRange(requestRange.start, length);
}

BOOL
SJNSRangeIsUndefined(NSRange range) {
    return range.location == NSNotFound || range.length == NSNotFound;
}
