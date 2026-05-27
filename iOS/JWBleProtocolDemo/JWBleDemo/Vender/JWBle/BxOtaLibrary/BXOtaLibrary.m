//
//  BXOtaLibrary.m
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
// 

#import "BXOtaLibrary.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "YFXBluetoothManager.h"
#import "WristBandCmd_lrw.h"
#import "NSData+CRC32.h"

@interface BXOtaLibrary()

@property (nonatomic, assign) otaType otaType;
@property (nonatomic, strong) NSData *otaData;//用于接收表盘 词典的升级文件
@property (nonatomic, assign) CGPoint selfPoint;
@property (nonatomic, strong) CBPeripheral *peripheral;//连接的设备信息
@property (nonatomic, strong) UIImage *customImage;//连接的设备信息
@property (nonatomic, copy ) NSString * urlPath;
@property (strong, nonatomic) NSTimer *timer;
@end

@implementation BXOtaLibrary

static BXOtaLibrary *_manager = nil;
static BOOL isAutomaticOTA = YES;

+ (instancetype)shareBXOtaLibrary{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[BXOtaLibrary alloc]init];
        [YFXBluetoothManager shareBLEManager];
    });
    return _manager;
}

-(void)setAutoOTA:(BOOL)isAuto{
    isAutomaticOTA = isAuto;
}

-(BOOL)getisAutomaticOTA{
    return isAutomaticOTA;
}


-(void)startOtaWithPeripheral:(CBPeripheral *) cp AndOtaType:(otaType)type AndMac:(NSString *)mac{
    isFindJson = NO;
    isFindCustomJson = NO;
    _peripheral = cp;
    _otaType = type;
    [[YFXBluetoothManager shareBLEManager] setMac:mac];
    [self OtaStart];
}

-(void)OtaStart{
    totalFile = 0.0;
    totalRate = 0.0;
    otaNumber = 0;
    otaTime = 0;
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        otaTime += 1;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[YFXBluetoothManager shareBLEManager] bleCentralManager].state != CBManagerStatePoweredOn ){
            JWNSLog(@"Bluetooth not ready，Please wait centralMamager state to poweredOn and retry");
            return;
        }
        [[YFXBluetoothManager shareBLEManager] connectDeviceWithCBPeripheral:self->_peripheral];
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1.0*NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[WristBandCmd_lrw getShareInstance] checkRecoveryMode];
        });
    });
}

-(otaType)getOtaType{
    return _otaType;  
}

-(void)getFile{
    switch (_otaType) {
        case Firmware:
            {
                NSString *temp = NSTemporaryDirectory();
                [self getUrlWithURL:temp];
            }
            break;
        case Material:
            {
                [self otaWithFile:_otaData AndType:1];
            }
            break;
        case wordBook:
            {
                [self otaWithFile:_otaData AndType:2];
            }
            break;
        case customDial:
            {
                NSString *temp = NSTemporaryDirectory();
                [self getCustomDialParamWithURL:temp];
            }
            break;
        default:
            break;
    }
}

-(void)getData:(NSData *)data{
    _otaData = data;
}

//设置自定义表盘文字位置
-(void)setCustomDialDigitalClockPosition:(CGPoint)point{
    _selfPoint = point;
}

//获取自定义表盘的image 和参数

-(void)getImage:(UIImage *)image AndParams:(NSDictionary *) params{
    _customImage = image;
    _customDialDic = params;
}


-(void)analysisForListJson:(NSString *) url{
    
    NSData *jsonData = [NSData dataWithContentsOfFile:url];
//    [self deleteTempData];
    //解析json数据
    NSError *error;
    if (jsonData){
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            JWNSLog(@"解析失败");
        } else {
            JWNSLog(@"解析成功：%@", jsonDict);
            switch (_otaType) {
                case Firmware:
                    _jsonDic = jsonDict;
                    [self getTotalFileSize];
                    [self startOTAWithJsonDict];
                    break;
                case customDial:
                    _customDialDic = jsonDict;
                    
                    break;
                default:
                    break;
            }
        }
    }else{
        
    }
}
static int otaTime = 0;
static int otaNumber = 0;
static float totalFile = 0.0;
static float totalRate = 0.0;
-(void)setMaxWithoutResponse:(int)maxNumber{
    if (totalFile != 0.0){
        return;
    }
    totalFile = 0.0;
    for (int i = 0 ; i<_jsonDic.allKeys.count; i++) {
        NSString * fileName = [_jsonDic objectForKey:[NSString stringWithFormat:@"%d",i]];
        NSString * url =  [_urlPath stringByAppendingPathComponent:fileName];
        NSData *binData = [NSData dataWithContentsOfFile:url];
        if (binData){
            float binSize = ceilf(binData.length/maxNumber);
            totalFile = totalFile + binSize;
        }
    }
}
-(void)setTotalFileSize:(int)totalSize{
    totalFile = 0;
    for (int i = 0 ; i<_jsonDic.allKeys.count; i++) {
        NSString * fileName = [_jsonDic objectForKey:[NSString stringWithFormat:@"%d",i]];
        NSString * url =  [_urlPath stringByAppendingPathComponent:fileName];
        NSData *binData = [NSData dataWithContentsOfFile:url];
        if (binData){
            float binSize = ceilf(binData.length/totalSize);
            totalFile = totalFile + binSize;
        }
    }
}
-(void)getTotalFileSize{
    int maxWithoutResponse = (int) [_manager.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
//    maxWithoutResponse = 248;// 根据设备写死先。。。2024-01-09 16:47:26
    JWNSLog(@"getTotalFileSize maxWithoutResponse : %d", maxWithoutResponse);
    for (int i = 0 ; i<_jsonDic.allKeys.count; i++) {
        NSString * fileName = [_jsonDic objectForKey:[NSString stringWithFormat:@"%d",i]];
        NSString * url =  [_urlPath stringByAppendingPathComponent:fileName];
        NSData *binData = [NSData dataWithContentsOfFile:url];
        if (binData){
            float binSize = ceilf(binData.length/maxWithoutResponse);
            JWNSLog(@"logloglog \t fileName:%@ \t binData size : %ld", fileName, binData.length);
            totalFile = totalFile + binSize;
        }
    }
}

-(void)startOtaWithBin{
    switch (_otaType) {
        case Firmware:
            {
                //解析json数据
                NSString * fileName = [_jsonDic objectForKey:[NSString stringWithFormat:@"%d",otaNumber]];
                otaNumber++;
                NSString * url =  [_urlPath stringByAppendingPathComponent:fileName];
                NSData *binData = [NSData dataWithContentsOfFile:url];
                [[YFXBluetoothManager shareBLEManager] sendMsgWithoutResponse:binData];
            }
            break;
        case Material:
            {
                [[YFXBluetoothManager shareBLEManager] sendMsgWithoutResponse:_otaData];
            }
            break;
        case wordBook:
            {
                [[YFXBluetoothManager shareBLEManager] sendMsgWithoutResponse:_otaData];
            }
            break;
        case customDial:
            {
                [[YFXBluetoothManager shareBLEManager] sendMsgWithoutResponse:_otaData];
            }
            break;
        default:
            break;
    }
    
}
-(int)getUInt16:(char *) p AndOfs:(int) ofs{
    return (p[ofs] << 8) | (p[ofs + 1]);
}

-(void) setUint16:(char *)p Index:(int) ofs AndInt:(int)v{
    do {
        p[ofs] = v >> 8;
        p[ofs + 1] = v & 0xff;
    } while (0);
}

-(NSData *)dealCustomDial{
    NSData * imageData = [self BMPRepresentationWithImagezz:_customImage];

    NSMutableData * data = [_otaData  mutableCopy];
    int startIndex = [[_customDialDic objectForKey:@"backgroundStartIndex"] intValue];
    
    [data replaceBytesInRange:NSMakeRange(startIndex,imageData.length) withBytes:imageData.bytes length:imageData.length];
    
    
    NSMutableData * StrData = [NSMutableData dataWithData:[self dealWithImage:data Ofsx:_selfPoint.x Ofsy:_selfPoint.y]];
    NSData*subData = [StrData subdataWithRange:NSMakeRange(12,StrData.length-12)];
    UInt32 crc32 = [subData crc32];
    
    NSData * crc32Data = [self bytesFromUInt32:crc32];
    [StrData replaceBytesInRange:NSMakeRange(4, 4) withBytes:crc32Data.bytes length:4];
 
    _otaData = StrData;

    return StrData;
}
//处理时间位置，如不需要，可不处理
-(NSData *)dealWithImage:(NSData *)mData Ofsx:(int)ofsx Ofsy:(int)ofsy {

    int startIndex; // 日期相关的区域的起始坐标
    int len; // 日期相关数据的长度
    len = [[_customDialDic objectForKey:@"scriptLen"] intValue];
    startIndex = [[_customDialDic objectForKey:@"scriptStartIndex"] intValue];
    NSData * subData = [mData subdataWithRange:NSMakeRange(startIndex, len)];
    char * script = (char *)subData.bytes;
    int cmd_len[20]={
        0+1,
           3+1,
           7+1,
           6+1,
           6+1,
           10+1,
           14+1,
           11+1,
           12+1,
           14+1,
           7+1,
           2+1,
           3+1,
           4+1,
           6+1,
           18+1,
           8+1,
           14+1,
           16+1,
           8+1
    };
    
    int ofs=0;
    bool stop = NO;
    
    do {
        switch (script[ofs]) {
            case 0:
                ofs +=cmd_len[0];
                stop = YES;
              
                break;
            case 1:
                
                ofs +=cmd_len[1];
               
                break;
            case 2:
            {
                
                ofs +=cmd_len[2];
                
            }
                break;
            case 3:
            {
               
                ofs +=cmd_len[3];
               
            }
                break;
            case 4:
               
                ofs +=cmd_len[4];
                
                break;
            case 5:
            {
          
                int pic_id = [self getUInt16:script AndOfs: ofs+1];
                int x = [self getUInt16:script AndOfs: ofs+2+1];
                int y = [self getUInt16:script AndOfs: ofs+4+1];
        
                // 开始坐标运算
                x += ofsx;
                y += ofsy;
                // 把运算结果保存会原数据里
                [self setUint16:script Index:ofs+2+1 AndInt:x];
                [self setUint16:script Index:ofs+4+1 AndInt:y];
                
                // 再读一次,检查有没写入正确
                x = [self getUInt16:script AndOfs: ofs+2+1];
                y = [self getUInt16:script AndOfs: ofs+4+1];

                ofs +=cmd_len[5];
                
            }
                break;
            case 6:
               
                ofs +=cmd_len[6];
                
                break;
            case 7:
               
                ofs +=cmd_len[7];
               
                break;
            case 8:
                
                ofs +=cmd_len[8];
               
                break;
            case 9:
               
                ofs +=cmd_len[9];
                
                break;
            case 10:
               
                ofs +=cmd_len[10];
                
                break;
            case 11:
                
                ofs +=cmd_len[11];
               
                break;
            case 12:
                
                ofs +=cmd_len[12];
                
                break;
            case 13:
                
                ofs +=cmd_len[13];
               
                break;
            case 14:
                
                ofs +=cmd_len[14];
                
                break;
            case 15:
               
                ofs +=cmd_len[15];
                
                break;
            case 16:
               
                ofs +=cmd_len[16];
               
                break;
            case 17:
               
                ofs +=cmd_len[17];
               
                break;
            case 18:
               
                ofs +=cmd_len[18];
              
                break;
            case 19:
               
                ofs +=cmd_len[19];
               
                break;
            default:
               
                stop = YES;
                break;
        }

    } while (!stop && ofs < len);   //len == 54 满足条件就会一直执行（ofs<54 且 stop 为 NO）
    NSData * ss = [NSData dataWithBytes:script length:len];
  
    NSMutableData * data = [[NSMutableData  alloc]initWithData:mData];
  
    [data replaceBytesInRange:NSMakeRange(startIndex, len) withBytes:script length:len];
    return data;
 
}

- (NSData *)BMPRepresentationWithImagezz:(UIImage *)image
{
    CGImageRef imImage = image.CGImage;
    int width = (int)CGImageGetWidth(imImage);
    int height = (int)CGImageGetHeight(imImage);

    CGRect rect = CGRectMake(0, 0, width, height);
    CGContextRef context = [self newBitmapRGBA8ContextFromImage:imImage];
    CGContextDrawImage(context, rect, imImage);
    unsigned char *bitmapData = (unsigned char *)CGBitmapContextGetData(context);
    
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);
    size_t bufferLength = bytesPerRow * height;
    
    unsigned char *newBitmap = NULL;
    unsigned long idx = 0;
    
    NSMutableData *valData = [[NSMutableData alloc] init];

    if(bitmapData) {
        size_t newBytesPerRow = 4 * width ;
        newBitmap = (unsigned char *)malloc(sizeof(unsigned char) * newBytesPerRow * height);
        if(newBitmap) {
            for (int x=0; x<height; x++) {
                for (int y=0; y<width; y++) {
                    int offset = 4*(x*width+y);
                    int r = bitmapData[offset];
                    int g = bitmapData[offset+1];
                    int b = bitmapData[offset+2];
                    int a = bitmapData[offset+3];

                    int _b = (b >> 3) & 0x1F;
                    int _g = ((g >> 2) & 0x3F) << 5;
                    int _r = ((r >> 3) & 0x1F) << 11;
                    int color = _r | _g | _b;

                    unsigned char valChar[2];
                    valChar[0] = 0xff & color ;
                    valChar[1] = ((0xff00 & color) >> 8);
                    [valData appendBytes:valChar length:2];
                }
            }
        }
        free(bitmapData);
    }else{
    
    }
    CGContextRelease(context);
    return valData;
}

-(CGContextRef) CreateARGBBitmapContext :(CGImageRef) inImage
{
    CGContextRef    context = NULL;
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;

    size_t pixelsWide = CGImageGetWidth(inImage);
    size_t pixelsHigh = CGImageGetHeight(inImage);

    bitmapBytesPerRow   = (pixelsWide * 4);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    bitmapData = malloc( bitmapByteCount );
    
    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedFirst);
    if (context == NULL)
        {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        }

    CGColorSpaceRelease( colorSpace );
    
    return context;
}

-(CGContextRef) newBitmapRGBA8ContextFromImage:(CGImageRef) image {
    CGContextRef context = NULL;
    CGColorSpaceRef colorSpace;
    uint32_t *bitmapData;
    
    size_t bitsPerPixel = 32;
    size_t bitsPerComponent = 8;
    size_t bytesPerPixel = bitsPerPixel / bitsPerComponent;
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    size_t bytesPerRow = width * bytesPerPixel;
    size_t bufferLength = bytesPerRow * height;
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if(!colorSpace) {
        JWNSLog(@"Error allocating color space RGB\n");
        return NULL;
    }
    
    // Allocate memory for image data
    bitmapData = (uint32_t *)malloc(bufferLength);
    
    if(!bitmapData) {
        JWNSLog(@"Error allocating memory for bitmap\n");
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }
    
    //Create bitmap context
    context = CGBitmapContextCreate(bitmapData,
                                    width,
                                    height,
                                    bitsPerComponent,
                                    bytesPerRow,
                                    colorSpace,
                                    kCGImageAlphaPremultipliedLast);    // RGBA
    
    if(!context) {
        free(bitmapData);
        JWNSLog(@"Bitmap context not created");
    }
    
    CGColorSpaceRelease(colorSpace);
    
    return context;
}

- (void)startOTAWithJsonDict{
    NSString * fileName = [_jsonDic objectForKey:[NSString stringWithFormat:@"%d",otaNumber]];
    NSString * url = [_urlPath stringByAppendingPathComponent:fileName];
    NSData *binData = [NSData dataWithContentsOfFile:url];
    [self otaWithFile:binData AndId:otaNumber];
}

- (void)otaWithFile:(NSData *) data AndId:(int) fileId {
    UInt32 crc = [data crc32];
    [[WristBandCmd_lrw getShareInstance]transferStartWithId:fileId fileSize:(UInt32)data.length crc32:crc];
}

- (void)otaWithFile:(NSData *)data AndType:(int) type {
    UInt32 crc = [data crc32];
    [[WristBandCmd_lrw getShareInstance]assetUpdateReqWithType:type fileSize:(UInt32)data.length crc32:crc];
}

-(void)transferEnd{
    switch (_otaType) {
        case Firmware:
            {
                [[WristBandCmd_lrw getShareInstance] transferEnd];
            }
            break;
        case Material:
            {
                [[WristBandCmd_lrw getShareInstance] assetUpdateEnd];
            }
            break;
        case wordBook:
            {
                [[WristBandCmd_lrw getShareInstance] assetUpdateEnd];
            }
            break;
        case customDial:
            {
                [[WristBandCmd_lrw getShareInstance] assetUpdateEnd];
            }
            break;
        default:
            break;
    }
}

//判断
-(void)judgeCompleted{
    if (otaNumber == _jsonDic.count){
        [self otaFinish];
    }else{
        [self startOTAWithJsonDict];
    }
}
-(void)exitWithType:(exitType)exitType{
    [[WristBandCmd_lrw getShareInstance]exitWithType:exitType];
}

// OTA成功
-(void)otaFinish{
    [_timer invalidate];
//    _otaData = nil;
    [self.delegate onFinishWithTime:otaTime];
}

//失败原因
-(void)FailErrer:(NSString *) err{
    [self.delegate onInitialError:err];
}

//进度
- (void)otaWithFileSize:(float)filesize AndRate:(float)rate{
    totalRate = totalRate + 1;
    if (otaNumber > 0 ){
        [self.delegate otaWithIndex:otaNumber-1 AndFileSize:filesize AndRate:rate];
    }else{
        [self.delegate otaWithIndex:otaNumber AndFileSize:filesize AndRate:rate];
    }
    [self otaTotalRateWithFileSize:filesize AndRate:rate];
}

//总进度
- (void)otaTotalRateWithFileSize:(float)filesize AndRate:(float)rate{
    switch (_otaType) {
        case Firmware:
            {
//                if (totalRate <= totalFile){
                    [self.delegate otaWithTotalFileSize:totalFile AndRate:totalRate];
//                }
            }
            break;
        case Material:
            {
                [self.delegate otaWithTotalFileSize:filesize AndRate:rate];
            }
            break;
        case wordBook:
            {
                [self.delegate otaWithTotalFileSize:filesize AndRate:rate];
            }
            break;
        case customDial:
            {
                [self.delegate otaWithTotalFileSize:filesize AndRate:rate];
            }
            break;
        default:
            break;
    }
}

//非自动模式进入OTA，launchRecoverySuccess需要用户自己断开连接。
- (void)nonautomaticOTALaunchRecoverySuccess{
    if(!isAutomaticOTA){
        [self.delegate launchRecoverySuccess];
    }
}
static BOOL isFindJson = NO;
static BOOL isFindCustomJson = NO;
//递归，直到找到List.json
-(void)getUrlWithURL:(NSString *)url{
    if (!isFindJson){
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:url error:&error];
        if([cacheFiles containsObject:@"list.json"]){
            isFindJson = !isFindJson;
            _urlPath = url;
            [self analysisForListJson:[url stringByAppendingPathComponent:@"list.json"]];
            return;
        }else{
            for (NSString *file in cacheFiles) {
                [self getUrlWithURL:[url stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/",file]]];
            }
        }
    }
    return;
}

//递归，直到找到List.json
-(void)getCustomDialParamWithURL:(NSString *)url{
    if (!isFindCustomJson){
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:url error:&error];
        if([cacheFiles containsObject:@"params.json"]){
            isFindCustomJson = !isFindCustomJson;
            [self analysisForListJson:[url stringByAppendingPathComponent:@"params.json"]];
            for (int i = 0;i < cacheFiles.count; i++) {
                NSString * s = cacheFiles[i];
                if ([s containsString:@".bin"] || [s containsString:@".bxface"]){
                    _otaData = [NSData dataWithContentsOfFile:[url stringByAppendingPathComponent:s]];
                }
            }
            NSData * data = [self dealCustomDial];
            [self otaWithFile:data AndType:1];
            return;
        }else{
            for (NSString *file in cacheFiles) {
                [self getCustomDialParamWithURL:[url stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/",file]]];
            }
        }
    }
    return;
}


-(NSData *)bytesFromUInt32:(uint32_t)val
{
    NSMutableData *valData = [[NSMutableData alloc] init];
    unsigned char valChar[4];
    valChar[3] = 0xff & val;
    valChar[2] = (0xff00 & val) >> 8;
    valChar[1] = (0xff0000 & val) >> 16;
    valChar[0] = (0xff000000 & val) >> 24;
    [valData appendBytes:valChar length:4];
    return [self dataWithReverse:valData];
}

- (NSData *)dataWithReverse:(NSData *)srcData
{
    NSUInteger byteCount = srcData.length;
    NSMutableData *dstData = [[NSMutableData alloc] initWithData:srcData];
    NSUInteger halfLength = byteCount / 2;
    for (NSUInteger i=0; i<halfLength; i++) {
        NSRange begin = NSMakeRange(i, 1);
        NSRange end = NSMakeRange(byteCount - i - 1, 1);
        NSData *beginData = [srcData subdataWithRange:begin];
        NSData *endData = [srcData subdataWithRange:end];
        [dstData replaceBytesInRange:begin withBytes:endData.bytes];
        [dstData replaceBytesInRange:end withBytes:beginData.bytes];
    }
    return dstData;
}

@end
