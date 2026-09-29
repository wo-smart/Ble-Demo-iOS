# JWBle SDK API 文档

> 🌐 语言 / Language: **中文** ｜ [English](SDK_API_Reference_EN.md)

> 本文档完整整理 **当前 SDK 实际公开**的 API、参数、返回值、回调、数据模型、枚举与状态码。
> 公开 API 范围的判定依据：`JWBle/JWBle/JWBle.h` 伞形头文件 + `.xcodeproj` Headers 阶段导出的头文件 + 交付 `JWBle.framework/Headers`。
> 内部实现类（`WristBand`、`BleCore`、`JWBleCommandHelp`、`JWBleCommunicationManager`、`JWBlePrivateAction`、`FMDB` 等）**不属于公开 API**，不写入本文档作为可调用接口。
> 本文档与交付的 `JWBle.framework`（1.3.2）公开头文件逐项核对；标 **⚠️** 的行为提示均来自实现代码，可直接作为集成依据。

---

## 第 0 章 阅读约定

### 0.1 公开 API 范围

| 类别 | 文件 | 说明 |
| --- | --- | --- |
| 伞形头 | `JWBle.h` | 对外统一入口，`#import <JWBle/JWBle.h>` |
| 核心类 | `JWBleManager.h`、`JWBleAction.h`、`JWBleDataAction.h` | 初始化/状态、设备与功能指令、数据读写 |
| 扩展类 | `JWBleOTAAction.h`、`JWBleCustomizeMainInterfaceAction.h`、`JWBleMyMainInterfaceAction.h` | OTA、表盘自定义 |
| 工具类 | `JWBlePublicHelp.h`、`JWLogAction.h`、`JWLogModel.h`、`JWBleDBModel.h` | 换算、日志、数据库基类 |
| 定义 | `JWBlePublicDefine.h`、`JWBlePublicModelDefine.h` | 枚举、Block 定义 |
| 模型 | `JWBleDeviceModel.h`、`JWBleAlarmClockModel.h` 等 | 见第 6 章 |

### 0.2 统计（基于公开头文件）

| 项目 | 数量 |
| --- | --- |
| 公开类 | 23（其中功能/工具类 8，Model 15） |
| 公开方法 | 238 |
| Block 回调定义 | 66 |
| `JWBleManager` 回调属性 | 29 |
| 公开枚举 | 44 |
| 公开错误码 | **45 个**（`JWBleErrorCode`）+ 错误域与 NSError 工具函数（见第 12 章） |

本文档的覆盖方式：**第 2~7 章**对核心/流程类 API 给出完整格式（含示例）；**第 13 章**对剩余对外 API 按同一模板补齐；**13.4 附录**单独列出生产/产测专用接口（不建议第三方使用）。全部 238 个公开方法均已收录。

> 2026-09-29 新增公开 API：`jwStartScanDeviceWithTimeout:callBack:`（带超时扫描）、`jwGetDeviceCurrentBatteryWithCallBack:`（电量带回调）、类方法 `jwSetHealthFunctionWithBloodGlucoseOpen:bloodFatOpen:uricAcidOpen:withCallBack:`。
>
> 2026-09-29 新增错误码能力：`JWBleErrorCode`（45 个）、`JWBleErrorDomain`、`JWBleErrorMessageForCode()`、`JWBleMakeError()`、`JWBleMakeErrorWithUnderlyingError()`、4 个状态映射函数、`JWBleManager.lastErrorCode`、`JWBleOTAAction.lastErrorCode/lastErrorMessage/lastUnderlyingError/lastError`（见第 12 章）。

### 0.3 回调返回方式

SDK **不使用 Delegate 协议，也不使用对外 Notification**（内部 `NSNotification` 全部为私有实现细节）。对外统一为：

1. **方法内 Block（一次性结果）**：绝大多数 `JWBleAction` / `JWBleDataAction` 方法；
2. **`JWBleManager` 属性 Block（持续/异步事件）**：实时数据、连接状态、电量变化等。

> “调用某个 API 后去哪里拿结果”：优先看方法签名里的 `callBack`；实时性与状态类事件看 `JWBleManager` 对应属性 Block。完整对应关系见第 7 章。

---

## 第 1 章 JWBleManager（初始化与全局状态）

### 1.1 `+ (JWBleManager *)shareInstance`

**功能说明**：获取 SDK 单例。首次调用会初始化默认属性（`isAutoShowPair = YES`、`checkUserBinding = YES`、`cacheLogCount = 30`）并注册全部内部回调转发。

**方法定义**
```objc
+ (JWBleManager *)shareInstance;
```

**参数**：无

**返回值**：`JWBleManager` 单例（非空）

**回调**：无

**前置条件**：无

**调用示例**
```objc
JWBleManager *manager = [JWBleManager shareInstance];
```

**注意事项**：线程安全（`dispatch_once`）；建议在 App 启动阶段调用一次。

---

### 1.2 `- (void)setUpWithUid:(NSString *)uid`

**功能说明**：SDK 初始化入口。绑定“App 侧账号标识”，用于设备绑定关系校验与自动重连。

**方法定义**
```objc
- (void)setUpWithUid:(NSString *)uid;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `uid` | `NSString *` | 是 | App 侧用户唯一标识。同一账号在不同手机登录可连接同一设备；不同账号未解绑时无法连接 |

**返回值**：无

**回调**：无（内部会触发自动重连，重连结果通过 `connectStateChangeCallBack` 上报）

**前置条件**：无（可在未连接时调用）

**调用示例**
```objc
[[JWBleManager shareInstance] setUpWithUid:@"user_123456"];
```

**注意事项**

- 与上次相同的 `uid` 会被直接忽略（不重复初始化）。
- 更换 `uid` 时会取消所有等待重连的外设。
- `isProduce == NO` 时会尝试基于本地绑定记录自动回连设备。

---

### 1.3 `- (NSString *)sdkInfo` / `- (NSDictionary *)sdkInfoDic`

**功能说明**：获取 SDK 自报的厂商与版本信息。

**方法定义**
```objc
- (NSString *)sdkInfo;
- (NSDictionary *)sdkInfoDic;
```

**返回值**

- `sdkInfo`：形如 `Manufacturer Information: Wo-Smart Technologies\nPlatform: iOS\nVersion: 1.3.2`
- `sdkInfoDic`：`@{@"Manufacturer Information": @"Wo-Smart Technologies", @"Platform": @"iOS", @"Version": @"1.3.2"}`

**注意事项**：该版本号（1.3.2）与打包 Info.plist（1.0.2）、`Version Description.md`（1.0.2）**不一致**，对外发布前需统一。

---

### 1.4 属性清单

#### 状态类

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `isConnected` | `BOOL` | 是否已连接（`deviceConnectStatus != DisConnect`）。**只有 getter 实现，禁止赋值** |
| `isConnecing` | `BOOL` | 是否正在连接 |
| `deviceConnectStatus` | `JWBleDeviceConnectStatus` | 最近一次连接状态 |
| `connectionModel` | `JWBleDeviceModel *` | 当前已连接设备（未连接为 `nil`） |
| `lastErrorCode` | `JWBleErrorCode`（只读） | 最近一次**连接类失败**的错误码；连接/绑定/同步成功后自动清零（2026-09-29 新增） |

#### 配置类

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `showLog` | `BOOL` | `NO` | 输出日志 |
| `saveLog` | `BOOL` | `NO` | 持久化日志（需 `showLog == YES`；影响性能；通过 `[JWLogModel getLog]` 读取） |
| `cacheLogCount` | `int` | `30` | 日志批量落盘阈值 |
| `isProduce` | `BOOL` | `NO` | 生产/产测模式；`YES` 时关闭自动重连与 60s 连接超时保护 |
| `isSNQR` | `BOOL` | `NO` | SN 快速扫描模式：跳过登录/绑定流程，同步完成条件改为 SN 快速条件（不全量获取设备信息） |
| `isSupportAnonymousUse` | `BOOL` | `NO` | 匿名使用：跳过登录/绑定流程，直接进入绑定成功状态 |
| `isAutoShowPair` | `BOOL` | `YES` | 连接后是否弹出系统配对窗口 |
| `checkUserBinding` | `BOOL` | `YES` | 是否校验用户绑定 |
| `checkSpecialOtaShutdown` | `BOOL` | `NO` | 置 `YES` 时，收到设备“OTA 结束查询”响应后会向设备下发“特殊 OTA 关机”指令 |
| `cacheLogArr` | `NSMutableArray *` | 懒加载空数组 | 日志缓存数组（内部使用，不建议三方操作） |

#### 回调类（28 个）

见第 7 章完整回调清单。

---

## 第 2 章 JWBleAction — 设备管理与用户设置

### 2.1 `+ (void)jwStartScanDeviceWithCallBack:`

**功能说明**：开始扫描周边手环设备。

**方法定义**
```objc
+ (void)jwStartScanDeviceWithCallBack:(JWBleReceiveScanningDeviceCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `callBack` | `JWBleReceiveScanningDeviceCallBack` | 是 | `void (^)(JWBleDeviceModel *deviceModel)`，每发现一个新设备回调一次 |

**返回值**：无

**回调**：`JWBleReceiveScanningDeviceCallBack`（主线程，每个外设仅回调一次）

**前置条件**：系统蓝牙已开启（`PoweredOn`）

**调用示例**
```objc
[JWBleAction jwStartScanDeviceWithCallBack:^(JWBleDeviceModel *deviceModel) {
    NSLog(@"%@ %@ %@", deviceModel.deviceName, deviceModel.macAddress, deviceModel.rssi);
}];
```

**注意事项**：不自动停止、无超时；需自行 `jwStopScanDevice`。同一 `CBPeripheral` 只回调一次，RSSI 不会刷新。

---

### 2.1.1 `+ (void)jwStartScanDeviceWithTimeout:callBack:`（2026-09-29 新增）

**功能说明**：开始扫描，并在指定时间后自动停止，避免忘记 `jwStopScanDevice` 造成长时间扫描耗电。

**方法定义**
```objc
+ (void)jwStartScanDeviceWithTimeout:(NSTimeInterval)timeout callBack:(JWBleReceiveScanningDeviceCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `timeout` | `NSTimeInterval` | 是 | 超时秒数，建议 10~30；`<= 0` 表示不超时（等价于 `jwStartScanDeviceWithCallBack:`） |
| `callBack` | `JWBleReceiveScanningDeviceCallBack` | 是 | 扫描回调，与 2.1 相同 |

**返回值**：无

**回调**：`JWBleReceiveScanningDeviceCallBack`（主线程）

**前置条件**：系统蓝牙已开启

**调用示例**
```objc
[JWBleAction jwStartScanDeviceWithTimeout:15 callBack:^(JWBleDeviceModel *deviceModel) {
    NSLog(@"%@", deviceModel.deviceName);
}];
```

**注意事项**：超时后 SDK 自动停止扫描并清理扫描回调（此后不再有回调）；超时前调用 `jwStopScanDevice` 会同时取消该定时器。

---

### 2.2 `+ (void)jwStopScanDevice`

**功能说明**：停止扫描。

**方法定义**
```objc
+ (void)jwStopScanDevice;
```

**参数**：无。**返回值**：无。**回调**：无。**前置条件**：无。

**调用示例**
```objc
[JWBleAction jwStopScanDevice];
```

**注意事项**：可重复调用；会清理内部扫描定时器。

---

### 2.3 `+ (void)jwConnectDevice:`

**功能说明**：连接指定设备。

**方法定义**
```objc
+ (void)jwConnectDevice:(JWBleDeviceModel *)deviceModel;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `deviceModel` | `JWBleDeviceModel *` | 是 | 扫描回调返回的设备模型；如已有 MAC，也可自行 `new` 一个并只设置 `macAddress` |

**返回值**：无

**回调**：`JWBleManager.connectStateChangeCallBack`（`Connect` → `BondSuccess` → `SyncSuccess`）

**前置条件**：该设备已扫描到（`per` 有效）；系统蓝牙开启

**调用示例**
```objc
[JWBleAction jwConnectDevice:deviceModel];
```

**注意事项**

- `deviceModel == nil` 且当前已连接时直接返回。
- 连接/同步 60 秒超时（`isProduce == NO` 生效）→ `TimeOutDisconnect` 并主动断开。
- 建议连接前先 `jwStopScanDevice`。

---

### 2.4 `+ (void)jwDisConnect`

**功能说明**：断开连接并**解绑**（会清空本地设备信息表与血压配置表）。

**方法定义**
```objc
+ (void)jwDisConnect;
```

**参数/返回值**：无

**回调**：`connectStateChangeCallBack(DisConnect)`

**注意事项**：解绑后不会自动重连；再次使用需重新扫描 + 连接。

---

### 2.5 `+ (void)jwDisConnectNotUnBond`

**功能说明**：断开连接但**保留绑定关系**。

**方法定义**
```objc
+ (void)jwDisConnectNotUnBond;
```

**参数/返回值**：无

**回调**：`connectStateChangeCallBack(DisConnect)`

**注意事项**：内部会标记 `activeDisconnect`，因此**不会**触发自动重连。

---

### 2.6 `+ (void)jwRemoveConnectRecord:`

**功能说明**：删除本地连接记录（会导致无法自动重连）。

**方法定义**
```objc
+ (void)jwRemoveConnectRecord:(NSString *)deviceUUID;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `deviceUUID` | `NSString *` | 是 | 与最后一次连接设备 UUID 一致时删除；传 `@""` 直接删除 |

**回调**：无

---

### 2.7 `+ (void)sysDeviceFuncAction`

**功能说明**：主动刷新设备功能列表。

**方法定义**
```objc
+ (void)sysDeviceFuncAction;
```

**回调**：无（结果体现在 `JWBleManager.connectionModel.functionData` / `functionDataV2`）

**前置条件**：设备已连接

**注意事项**：该接口无回调；如需确认写入结果，请用对应查询接口回读（如 `jwCheckControlSwitchStates:`、`jwCheckFunctionStates:`）。

---

### 2.8 用户信息与目标设置

#### 2.8.1 `+ (void)jwSynchronizePersonalInformation:isMan:height:weight:callBack:`

**功能说明**：同步用户个人信息到设备（用于卡路里/距离等换算基准）。

**方法定义**
```objc
+ (void)jwSynchronizePersonalInformation:(int)age
                                 isMan:(BOOL)isMan
                                height:(float)height
                                weight:(float)weight
                              callBack:(JWBleCommunicationCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `age` | `int` | 是 | 年龄，有效范围 0~127 |
| `isMan` | `BOOL` | 是 | 是否男性 |
| `height` | `float` | 是 | 身高 cm，0.0~256，精确到 0.5（实现内以 `height * 2` 下发） |
| `weight` | `float` | 是 | 体重 kg，0.0~512，精确到 0.5（实现内以 `weight * 2` 下发） |
| `callBack` | `JWBleCommunicationCallBack` | 是 | `void (^)(JWBleCommunicationStatus status)` |

**返回值**：无

**回调**：方法内 Block；实现中指令下发后立即回调 `JWBleCommunicationStatus_Success`（“已下发”语义）

**前置条件**：设备已连接

**调用示例**
```objc
[JWBleAction jwSynchronizePersonalInformation:28 isMan:YES height:175.0 weight:68.0
                                     callBack:^(JWBleCommunicationStatus status) { }];
```

**注意事项**：会同时写入本地血压配置表的年龄字段；`Success` 不代表设备已生效。允许重复调用（后一次覆盖前一次）。

#### 2.8.2 目标设置

| API | 方法定义 | 参数（有效范围） | 回调 | 注意事项 |
| --- | --- | --- | --- | --- |
| 计步目标 | `+ (void)jwSetStepTargetAction:(int)step callBack:(JWBleCommunicationCallBack)callBack;` | `step` 1000~65000（越界自动收敛） | `JWBleCommunicationCallBack` | “已下发”语义 |
| 卡路里目标 | `+ (void)jwSetCalorieTargetAction:(int)calorie callBack:(JWBleCommunicationCallBack)callBack;` | `calorie` 100~9999 千卡 | `JWBleCommunicationCallBack` | 实现中**未做范围收敛**，越界值直接下发 |
| 睡眠目标 | `+ (void)jwSetSleepTargetAction:(int)minute callBack:(JWBleCommunicationCallBack)callBack;` | `minute` 90~900（越界自动收敛） | `JWBleCommunicationCallBack` | “已下发”语义 |

---

### 2.9 查找设备与遥控拍照

| 功能 | 方法定义 | 参数 | 回调 | 注意事项 |
| --- | --- | --- | --- | --- |
| 查找手环 | `+ (void)jwFindDeviceWithCallBack:(JWBleCommunicationCallBack)callBack;` | `callBack` 必填 | `JWBleCommunicationCallBack` | 设备已连接；“已下发”语义 |
| 遥控拍照开关 | `+ (void)jwRemotePhotography:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | `open` 开/关 | `JWBleCommunicationCallBack` | 需支持 `JWBleFunctionEnum_RemotePhotography` |
| 设备摇晃拍照事件 | 无公开调用 API | — | `JWBleManager.remotePhotographyCallBack` → `JWBleRemotePhotographyStatus_TakePhoto` | 需先打开遥控拍照 |

---

### 2.10 能力查询接口（**推荐优先使用**）

#### 2.10.1 `+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:`

**功能说明**：查询设备是否支持某功能，以及该功能当前是否开启。这是三方判断“设备能力差异”的**首选接口**。

**方法定义**
```objc
+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:(JWBleFunctionEnum)functionEnum;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `functionEnum` | `JWBleFunctionEnum` | 是 | 功能枚举（见第 8 章） |

**返回值**：同步返回 `JWBleFunctionStatesEnum`

| 返回值 | 含义 |
| --- | --- |
| `JWBleFunctionStateEnum_NotSupport`（值为 `0 \| 2` = 2） | 不支持 |
| `JWBleFunctionStateEnum_Close`（1） | 支持但关闭 |
| `JWBleFunctionStateEnum_Open`（3） | 支持且开启 |

**回调**：无（同步返回）

**前置条件**：**设备已完成同步**（依赖 `connectionModel.functionData` / `functionDataV2`）；未连接时统一返回“不支持”

**调用示例**
```objc
if ([JWBleAction jwCheckFunctionStates:JWBleFunctionEnum_ECG] == JWBleFunctionStateEnum_Open) {
    [JWBleAction jwECGAction:YES callBack:^(JWBleCommunicationStatus status, int ecgStatus) { }];
}
```

**注意事项**

- 该接口**只读缓存**，不会发起通信；必须在 `SyncSuccess` 之后调用。
- 功能号 > 10000 的走 `functionDataV2`（设备功能 2 组），其余走 `functionData`。
- **`functionData` 有两种编码，接口按长度自动切换**（`JWBleAction.m` 第 854~960 行）：

| 分支 | 条件 | 解码 | 可能返回值 |
| --- | --- | --- | --- |
| 位图模式 | `functionData.length <= 8` | 内置 `switch` 表映射为 `(byteIndex, bitIndex)`，取 `(byte >> bit) & 0x01` | **只有 `Open`(3) 或 `NotSupport`(2)**，不会返回 `Close` |
| 字节下标模式 | `functionData.length > 8` | `NSMakeRange(functionEnum, 1)`，枚举值即字节下标 | `0`/`2` → `NotSupport`；`1` → `Close`；其他 → `Open` |

- 位图模式是**白名单**（58 项，见 11.3 节）：未列入 `switch` 的功能（含全部 `10001~10016`）直接返回 `NotSupport`；字节下标模式下功能号必须 `< functionData.length`。
- 因此判定请统一用 `!= NotSupport`（支持）与 `== Open`（开启），**不要**用 `== 0` 或 `== Close`。

#### 2.10.2 其余能力查询

| API | 返回值含义 | 依赖数据 |
| --- | --- | --- |
| `+ (int)jwCheckControlSwitchStates:(JWBleDeviceSwitchFunctionEnum)functionEnum;` | 返回对应开关的当前值（如 0/1）；**`-1` 表示设备不支持该设置** | `connectionModel.deviceSwitchData` |
| `+ (JWBleHideFunctionStatesEnum)jwCheckHideFunctionStates:(JWBleFunctionEnum)functionEnum;` | `NotSupport` / `Show` / `Hidden`；仅支持 `StopwatchTiming`、`FindPhone`、`AutomaticLockScreen`、`TwoButtonSliding`、`VoiceAssistant` | `connectionModel.hideFunctionMenu` |
| `+ (JWBleFunctionStatesEnum)jwCheckCustomFunctionStates:(JWBleCustomFunctionEnum)functionEnum;` | 客户定制功能（脉冲/辅助睡眠/桑拿）支持状态 | `connectionModel.customizedFunctionDic` |

---

## 第 3 章 JWBleAction — 设备设置

> 本章接口多为“读/写二合一”：`isGet == YES` 读取（等待设备回包，`status` 为真实结果），`isGet == NO` 下发（“已下发”语义）。

### 3.1 时间

```objc
+ (void)jwSetTimeWithYear:(UInt8)year andMonth:(UInt8)month andDay:(UInt8)day
                 andHour:(UInt8)hour andMinute:(UInt8)minute andSecond:(UInt8)second
                 callBack:(void (^)(JWBleCommunicationStatus status))callBack;
```

| 参数 | 说明 |
| --- | --- |
| `year` | 年（**相对 2000 年的偏移**：2026 年传 `26`，取值 0~63；与 `JWBleAlarmClockModel.year` 一致） |
| `month` / `day` / `hour` / `minute` / `second` | 月 / 日 / 时 / 分 / 秒 |

**回调**：方法内 Block（`status`）

**注意事项**：`JWBleWeatherModel` 的注释要求天气的年月日与设备日期一致，因此建议先设置时间再同步天气。

---

### 3.2 `+ (void)jwCommonFunction:functionsState:callBack:`

**功能说明**：读写通用功能开关（当前公开支持“公英制”与“12/24 小时制”）。

**方法定义**
```objc
+ (void)jwCommonFunction:(JWBleFunctionEnum)functionEnum
           functionsState:(JWBleCommonFunctionsStatus)functionsState
                 callBack:(JWBleCommonFuctionReceiveCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `functionEnum` | `JWBleFunctionEnum` | 是 | 目前支持 `JWBleFunctionEnum_Unit`（公英制，开 = 公制）、`JWBleFunctionEnum_TimeSystem`（开 = 12 小时制） |
| `functionsState` | `JWBleCommonFunctionsStatus` | 是 | `_Read` / `_Open` / `_Close` |
| `callBack` | `JWBleCommonFuctionReceiveCallBack` | 是 | `void (^)(JWBleCommunicationStatus, JWBleCommonFunctionsStatus)` |

**返回值**：无

**回调**：方法内 Block，返回通信状态 + 读取到的功能状态

**前置条件**：设备已连接

**调用示例**
```objc
[JWBleAction jwCommonFunction:JWBleFunctionEnum_Unit
               functionsState:JWBleCommonFunctionsStatus_Open
                     callBack:^(JWBleCommunicationStatus status, JWBleCommonFunctionsStatus state) { }];
```

---

### 3.3 语言：`+ (void)jwLanguageAction:languageEnum:callBack:`

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `isGet` | `BOOL` | 是否读取 |
| `languageEnum` | `JWBleLanguageEnum` | 语言枚举（18 种，见第 8 章） |
| `callBack` | `JWBleLanguageCallBack` | `void (^)(JWBleCommunicationStatus, JWBleLanguageEnum)` |

**注意事项**：需设备支持 `JWBleFunctionEnum_MoreLanguage`。

---

### 3.4 屏幕相关

| 功能 | 方法定义 | 参数 | 回调 |
| --- | --- | --- | --- |
| 亮屏时长 | `+ (void)jwbBrightScreenDuration:(BOOL)isGet timeLength:(int)timeLength callBack:(JWBleBrightScreenDurationCallBack)callBack;` | `timeLength` 3~30 秒（注释） | `JWBleBrightScreenDurationCallBack` → `(status, timeLength, defalut)` |
| 亮度调节 | `+ (void)jwbBrightnessAdjustment:(BOOL)isGet value:(int)value callBack:(void (^)(JWBleCommunicationStatus status,int value,int defalutValue))callBack;` | `value` 20~100 | 方法内 Block |
| 转腕/抬腕亮屏 | `+ (void)jwTurnWristCreenActionWithIsGet:(BOOL)isGet open:(BOOL)open sensitivity:(int)sensitivity startMinute:(int)startMinute endMinute:(int)endMinute callBack:(JWBleTurnWristCreenActionCallBack)callBack;` | `sensitivity` 灵敏度；`startMinute` / `endMinute` 时间窗（分钟） | `JWBleTurnWristCreenActionCallBack` → `(status, open, sensitivity, startMinute, endMinute)` |
| 自动锁屏 | `+ (void)jwAutomaticLockScreenAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;` | `open` | 方法内 Block |
| 主界面颜色 | `+ (void)jwUpdateInterfaceColor:(int)colorIndex callBack:(void (^)(JWBleCommunicationStatus status))callBack;` | `colorIndex` 1~7 | 方法内 Block |

**注意事项**

- 亮屏时长上限在不同固件上不同（提交历史显示部分设备由 30s 提高到 60s），而头文件注释仍写 3~30s，**代码与文档不一致**。
- 自动锁屏属“隐藏功能菜单”，需先查询 `jwCheckHideFunctionStates:`。
- 主界面颜色“仅支持特殊手环固件”。

---

### 3.5 勿扰模式：`+ (void)jwNotDisturbAction:model:callBack:`

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `isGet` | `BOOL` | 是否读取 |
| `model` | `JWNotDisturbModel *` | 设置时必填；读取时可传空对象 |
| `callBack` | `JWBleNotDisturbActionCallBack` | `void (^)(JWBleCommunicationStatus, JWNotDisturbModel *)` |

`JWNotDisturbModel` 字段：`open`、`enumType`（`JWBleNotDisturbEnum`：全天 / 未佩戴 / 定时）、`startHour`、`startMinute`、`endHour`、`endMinute`。

---

### 3.6 久坐提醒：`+ (void)jwSedentaryReminder:open:startH:endH:span:threshold:dayFlagArr:callBack:`

| 参数 | 类型 | 有效范围 | 说明 |
| --- | --- | --- | --- |
| `isGet` | `BOOL` | — | 是否读取 |
| `open` | `BOOL` | — | 开关 |
| `startH` / `endH` | `int` | 0~23 | 开始 / 结束小时 |
| `span` | `int` | 30~240 | 提醒间隔（分钟） |
| `threshold` | `int` | 0~65535 | 区间内步数低于该值即提醒 |
| `dayFlagArr` | `NSArray *` | 7 元素 | 周重复，周一起 7 位，`true` / `false` |
| `callBack` | `JWBleSedentaryReminderActionCallBack` | — | `(status, open, startH, endH, span, threshold, dayFlagArr)` |

---

### 3.7 闹钟

| API | 方法定义 | 说明 |
| --- | --- | --- |
| 旧版闹钟 | `+ (void)jwAlarmAction:(BOOL)get alarmArr:(NSArray<JWBleAlarmClockModel *> *)alarmArr callBack:(JWBleAlarmActionCallBack)callBack;` | 全量设置，只需传“开启的闹钟”；读取时 `alarmArr` 传 `nil` |
| 闹钟 2.0 | `+ (void)jwAlarmV2Action:(BOOL)get alarmModel:(JWBleAlarmClockModel *)alarmModel callBack:(JWBleAlarmActionCallBack)callBack;` | 单个闹钟操作；`month` 与 `day` 同时为 0 表示删除 |

**回调**：`JWBleAlarmActionCallBack` → `(JWBleCommunicationStatus status, NSArray<JWBleAlarmClockModel *> *alarmArr)`

**注意事项**：旧版为全量覆盖、V2 为单条操作，**两者不可混用**；读取会等待设备回包。

---

### 3.8 消息通知

| 功能 | 方法定义 | 说明 |
| --- | --- | --- |
| 单个通知开关 | `+ (void)jwUpdateNotiStatus:(JWBleNotiEnum)enumType open:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | 设置单个 App 通知开关 |
| 批量通知开关 | `+ (void)jwOneTimeUpdateNotiStatus:(NSDictionary *)dic callBack:(JWBleCommunicationCallBack)callBack;` | `dic` 形如 `@{@(JWBleNotiEnum_Call):@(YES), @(JWBleNotiEnum_QQ):@(NO)}` |
| 读取通知开关 | `+ (void)jwGetNotiStatusWithCallBack:(JWBleGetNoticeCallBack)callBack;` | 返回 `NSDictionary`，key 为**字符串**（`"Call"`、`"QQ"`、`"WeChat"`…），value 为 `true` / `false` |
| 隐藏功能开关 | `+ (void)jwUpdateHideFunction:(JWBleFunctionEnum)enumType open:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | 隐藏/显示功能菜单 |
| 功能显示隐藏批量操作 | `+ (void)jwDeviceFunctionShowOrHiddenAction:(BOOL)isGet setDic:(NSDictionary *)setDic callBack:(void (^)(JWBleCommunicationStatus status, NSDictionary *dic))callBack;` | `setDic` 形如 `@{@"findPhone":@(YES), @"stopWatch":@(YES)}` |

**注意事项**：读取接口返回的字典 **key 为字符串名称**，与 `JWBleNotiEnum` 数值枚举是两套标识，接入时不要混用。

---

### 3.9 倒计时 / 查找手机

| 功能 | 方法定义 | 参数与回调 |
| --- | --- | --- |
| 倒计时操作 | `+ (void)jwCountDownAction:(BOOL)isGet model:(JWCountDownModel *)countDownModel callBack:(JWBleCountDownActionCallBack)callBack;` | `JWCountDownModel`：`seconds`(1~86400)、`optionEnum`（设置/开始/停止）、`open`（是否显示在设备 UI）；读取且状态为“开始”时 `seconds` 为剩余秒数；回调 `JWBleCountDownActionCallBack` |
| 停止倒计时回调 | `+ (void)jwStopCountDownCallBack;` | 无参数、无回调（清空内部回调） |
| 查找手机 | 无公开调用 API（设备侧触发） | `JWBleManager.findPhoneCallBack`（无参）/ `findPhoneV2CallBack(BOOL start)` |

---

### 3.10 温度相关设置

| 功能 | 方法定义 | 参数 | 回调 |
| --- | --- | --- | --- |
| 温度开关 | `+ (void)jwTemperatureSwitchAction:(BOOL)isGet unit:(BOOL)unit compensate:(BOOL)compensate monitor:(BOOL)monitor callBack:...` | `unit`：`YES` 摄氏度 / `NO` 华氏度；`compensate` 补偿开关；`monitor` 界面显示开关 | `(status, unit, compensate, monitor)` |
| 体温提醒 | `+ (void)jwTemperatureReminderAction:(BOOL)isGet value:(int)value callBack:...` | `value` 38.0~41.9（摄氏度），`0` 表示关闭提醒 | `(status, value)` |
| 设定温度 | `+ (void)jwSetTemperature:(int)value callBack:...` | `365` 表示 36.5℃ | `(status, BOOL success)` |
| 温度标定查询 | `+ (void)jwGetTemperatureWithCallBack:...` | 无 | `(status, BOOL already, NSInteger frequency, NSInteger temperatureInital)` |

---

### 3.11 其余设备设置（汇总表）

| 功能 | API | 参数 | 回调 |
| --- | --- | --- | --- |
| 血压 2.0（连续血压） | `+ jwBPV2Action:open:callBack:` | `isGet`、`open` | `(status, BOOL open)` |
| 私人血压 | `+ jwBPPrivateSet:h:l:callBack:` / `+ jwBPPrivateGetWithcallBack:` | `h` 高压、`l` 低压 | `(status)` / `(status, open, h, l)` |
| 血压自动检测 | `+ jwBPAutomaticDetectionAction_V3:open:timeSpan:callBack:` | `timeSpan`：5 / 30 / 60 / 120 分钟 | `JWBleAutomaticDetectionActionCallBack` |
| 心率自动检测 | `+ jwHrAutomaticDetectionAction:open:timeSpan:callBack:` | 同上 | `JWBleAutomaticDetectionActionCallBack` |
| 心率自动检测类型查询 | `+ jwGetHRAutomaticDetectionType:` | 无 | `(status, NSDictionary *)`，key 为 `"0"/"5"/"30"/"60"/"120"`，value 为是否支持 |
| 心率上限提醒 | `+ jwHighHeartRateReminderAction:open:maxValue:callBack:` | `maxValue` 40~220 | `(status, open, maxValue)` |
| 低氧提醒 | `+ jwLowOxygenReminderAction:open:callBack:` | `isGet`、`open` | `(status, open)` |
| 连续血氧 | `+ jwContinuousBloodOxygenAction:open:callBack:` | `isGet`、`open` | `(status, open)` |
| 全天睡眠 | `+ jwSleepAllDayAction:open:callBack:` | `isGet`、`open` | `(status, open)` |
| 表盘日期格式 | `+ jwDialDateFormatAction:open:callBack:` | `open == false` → MM-DD；`true` → DD-MM | `(status, open)` |
| 喝水提醒 | `+ jwDrinkWaterReminderAction:open:startHour:startMinute:endHour:endMinute:span:callBack:` | `span` 30~480 分钟 | `(status, open, startHour, startMinute, endHour, endMinute, span)` |
| 女性健康 | `+ jwFemaleAction:mode:cycleDay:menstrualDay:year:month:day:callBack:` | `mode` 为 `JWBleFemaleStatus`；周期 / 经期天数；上次月经日期 | `(status)` |
| 天气同步 | `+ jwWeatherAction:callBack:` | `JWBleWeatherModel`（当前天气 + 最多 6 天预报） | `(status)` |
| 音频操作 | `+ jwAudioAction:open:callBack:` | `isGet`、`open` | `(status, open)` |
| 用户偏好 | `+ jwUserPreferencesAction:values:callBack:` | `@[@{@"type":@(JWUserPreferenceType), @"value":@(0)}]` | `(status, NSArray *values)` |
| 关机 | `+ jwTurnOffBracelet;` | 无 | 无 |
| 恢复出厂 | `+ jwReset;` | 无 | 无 |
| 每日总量同步 | `+ jwDialyDataSyncWithSteps:andDistance:andCalory:` | 总步数 / 总距离 / 总卡路里（`UInt32`） | 无 |
| 同步睡眠给设备 | `+ jwSyncSleep2Device:deep:light:startMinuteIndex:endMinuteIndex:callBack:` | `level` 1~5；深睡 / 浅睡分钟；入睡 / 苏醒分钟下标 | `JWBleCommunicationCallBack` |
| 通讯录同步 | `+ jwSyncContacts:callBack:` | 最多 15 条，`@{@"name":…, @"phone":…}`，name ≤15 UTF8、phone ≤19 UTF8 | `(status, int index)` |
| SOS 同步 | `+ jwSyncSOSContacts:callBack:` | 最多 5 条，字段同上 | `(status, int index)` |
| 设备数据下标重置 | `+ jwDeviceDataReset;` | 无 | 无（需配合 `jwRemoveDataTimeLessThan:`） |
| 设备当前电量 | `+ jwGetDeviceCurrentBattery;` | 无 | **无方法内回调**；电量经 `connectStateChangeCallBack(BatteryUpdate)` 与 `JWBleManager.connectionModel.power` 获取 |
| 设备当前电量（带回调，2026-09-29 新增） | `+ jwGetDeviceCurrentBatteryWithCallBack:(JWBleGetPowerCallBack)callBack;` | `callBack` 必填 | `JWBleManager.getPowerCallBack` → `(status, int power, bool charging)`；注册一次后设备每次上报电量都会回调 |
| 耳机配对 | `+ jwHeadphonePairing;` / `+ jwCancelHeadphonePairing;` | 无 | 状态经 `connectStateChangeCallBack(HeadphoneDeviceStatusChanged)` 与 `connectionModel.headphoneDeviceStatus` |
| 修改设备名 | `+ jwModifyDeviceName:(NSString *)name;` | 中文 ≤4 字 / 英文数字 ≤12 位 | 无方法内回调；成功后触发 `connectStateChangeCallBack(SyncSuccess)` |
| 主界面风格 | `+ jwMainInterfaceAction:willShowIndex:callBack:` | `willShowIndex`：`count+1` 自定义表盘、`count+2` 下载表盘 | `(status, curShowIndex, count)` |
| 资源升级类型 | `+ jwUpdateResourceType:type:callBack:` | `JWUpdateResourceType` | `(status, type)` |

---

## 第 4 章 JWBleAction — 健康监测与实时数据

### 4.1 手动点测（一次性读值）

#### `+ (void)jwTestHRAction:callBack:`

**功能说明**：启动/停止手动心率测量。

**方法定义**
```objc
+ (void)jwTestHRAction:(BOOL)start callBack:(JWBleTestHRCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `start` | `BOOL` | 是 | `YES` 开始测量，`NO` 停止 |
| `callBack` | `JWBleTestHRCallBack` | 是 | `void (^)(JWBleCommunicationStatus status, JWBleTestHRStatus testStatus, int hrValue)` |

**回调**：`JWBleTestHRCallBack`，`testStatus` 会多次回调（开始 → 设备响应中 → 结束）；`hrValue` 在结束时为测量值

**前置条件**：设备已连接；需支持 `JWBleFunctionEnum_HR`；设备不繁忙

**调用示例**
```objc
[JWBleAction jwTestHRAction:YES callBack:^(JWBleCommunicationStatus status,
                                            JWBleTestHRStatus testStatus, int hrValue) {
    if (testStatus == JWBleTestHRStatus_TestEnd) {
        NSLog(@"心率：%d", hrValue);
    }
}];
```

**注意事项**：测量期间设备处于繁忙态；重复调用可能返回 `JWBleCommunicationStatus_Busy`。

---

### 4.2 血压 / 温度 / 血氧 / 血糖点测

| 功能 | 方法定义 | 参数 | 回调 |
| --- | --- | --- | --- |
| 手动血压 | `+ (void)jwTestBPAction:(BOOL)start callBack:(JWBleTestBPCallBack)callBack;` | `start` | `JWBleTestBPCallBack` → `(status, JWBleTestBPStatus testStatus, int high, int low)` |
| 温度监测开关/查询 | `+ (void)jwTestTemperatureAction:(int)actionKey callBack:(JWBleTestTemperatureCallBack)callBack;` | `actionKey`：0 关闭温度监测、1 开启、2 查询是否可开启（依赖连续心率） | `JWBleTestTemperatureCallBack` → `(status, JWBleTestTemperatureStatus)` |
| 血氧点测 | `+ (void)jwTestOxygen:(JWTestOxygenRequestType)requestType callBack:(void (^)(JWBleCommunicationStatus status, JWTestOxygenResultType resultType, JWOxygenModel *oxygenModel))callBack;` | `requestType`：`End` / `Start` / `Check` | 方法内 Block，成功时返回 `JWOxygenModel` |
| 血糖点测 | `+ (void)jwTestBloodGlucoseAction:(BOOL)start callBack:(void (^)(JWBleCommunicationStatus status, JWBleTestBPStatus testStatus, int value))callBack;` | `start` | 复用 `JWBleTestBPStatus` 状态机 |
| 私人血糖 | `+ (void)jwPrivateBloodGlucoseAction:(BOOL)isGet high:(int)high low:(int)low callBack:...` | `high` / `low` 需 **×10**（7.5 → 传 75） | `(status, high, low)` |
| 连续血糖开关 | `+ (void)jwContinuousBloodGlucoseAction:(BOOL)isGet open:(BOOL)open callBack:...` | `isGet`、`open` | `(status, open)` |
| 体脂点测 | `+ (void)jwCommonMeasurementAction:(JWBleCommonMeasurementEnum)actionEnum start:(BOOL)start;` | 目前枚举仅 `JWBleCommonMeasurementEnum_BodyFat = 5` | **无方法内回调**；数据经 `JWBleManager.bodyFatDataCallBack` 返回，结束状态经 `endMeasurementStatusCallBack` |

**注意事项**

- 点测类接口都是**异步多次回调**（开始/进行中/结束），必须按 `testStatus` 判断结束。
- 点测期间设备繁忙，其他指令可能被拒绝。
- 血氧结果模型 `JWOxygenModel` 含 `mCurValue`（当前）、`mHighValue`（最高）、`mLowValue`（最低）、`time`（时间戳）。

---

### 4.3 ECG / ECG Belt

| 功能 | 方法定义 | 回调 |
| --- | --- | --- |
| ECG 开关 | `+ (void)jwECGAction:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, int ecgStatus))callBack;` | `ecgStatus`：0 normal / 1 start / 2 end / 3 interrupt / 4 interrupt 10s after end / 999 data collection |
| ECG Belt 开关 | `+ (void)jwBeltAction:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, int beltStatus))callBack;` | `beltStatus` 语义同 `ecgStatus` |
| ECG 波形数据 | 无调用 API | `JWBleManager.ecgDataCallBack(NSArray *originalSignals, NSArray *filterSignals)` |
| ECG 原始数据 | 无调用 API | `JWBleManager.ecgOriDataCallBack(NSData *oriData)` |
| ECG 指标值 | 无调用 API | `JWBleManager.ecgValueDataCallBack(int bpm, int qt, int hrv, int rri, int progress)` |
| Belt 波形数据 | 无调用 API | `JWBleManager.beltDataCallBack(NSArray *originalSignals, NSArray *filterSignals)` |
| Belt 指标值 | 无调用 API | `JWBleManager.beltValueDataCallBack(int bpm, int qt, int hrv, int rri)` |
| 产测 ECG 数据 | 无调用 API | `JWBleManager.deviceTestECGCallBack(NSDictionary *dic)` |

**前置条件**：需 `JWBleFunctionEnum_ECG` / `JWBleFunctionEnum_Belt` 支持（`jwCheckFunctionStates:`）

---

### 4.4 健康评估类（尿酸 / 血脂 / 周期血糖 / 压力）

| 功能 | 方法定义 | 参数 | 回调 |
| --- | --- | --- | --- |
| 尿酸评估 | `+ jwUricAcidAction:open:privateValue:privateRtc:callBack:` | `open`（`get == NO` 生效）；`privateValue` 私人值（男 238~356、女 178~297 μmol/L，设备默认 0）；`privateRtc` 设置时间（秒级时间戳，默认 0） | `(status, open, privateValue, privateRtc)` |
| 血脂评估 | `+ jwBloodFatAction:open:privateValue:privateRtc:callBack:` | 同上 | 同上 |
| 周期血糖 | `+ jwBloodGlucoseCycleAction:open:privateValue:privateRtc:callBack:` | 同上 | 同上 |
| 尿酸连续监测 | `+ jwUricAcidContinuesMonitoringAction:open:callBack:` | `get`、`open` | `(status, open)` |
| 尿酸连续监测私人值 | `+ jwUricAcidContinuesMonitoringPrivateAction:open:value:callBack:` | `value` | `(status, open, value)` |
| 血脂连续监测 | `+ jwBloodFatContinuesMonitoringAction:open:callBack:` | `get`、`open` | `(status, open)` |
| 血脂连续监测私人值 | `+ jwBloodFatContinuesMonitoringPrivateAction:open:value:callBack:` | `value` | `(status, open, value)` |
| 压力连续监测 | `+ jwStressContinuesMonitoringAction:open:callBack:` | `get`、`open` | `(status, open)` |
| 压力连续监测数据 | `+ jwSyncStressContinuesMonitoringDataWithBlock:` | 无 | `(status, NSArray *resultData)` |

**状态回调（异步事件）**

| 回调 | 触发 | 数据 |
| --- | --- | --- |
| `JWBleManager.uricAcidStatusCallBack` | 尿酸状态变化 | `(BOOL open, int privateValue, int privateRtc)` |
| `JWBleManager.bloodFatStatusCallBack` | 血脂状态变化 | 同上 |
| `JWBleManager.bloodGlucoseCycleStatusCallBack` | 周期血糖状态变化 | 同上 |

**注意事项**：三个接口的 `privateValue` 单位不同——尿酸、血脂为 **μmol/L**（男性 238~356、女性 178~297），周期血糖为 **mmol/L ×10**（7.5 → 传 75）或 **mg/dL**，取决于 `JWUserPreferenceType`。

---

### 4.5 实时数据（`JWBleManager` 属性 Block）

| 功能 | 触发 API | 回调 |
| --- | --- | --- |
| 实时心率 | `+ (void)jwRealTimeHeartRateAction:(BOOL)open callBack:(JWRealTimeHeartRateActionCallBack)callBack;` | `JWBleManager.realTimeHeartRateCallBack(NSInteger hrValue)`；`hrValue == -999` 表示设备主动停止 |
| 运动实时心率 | `+ (void)jwRealTimeHeartRateAction:(BOOL)open sprotType:(int)sportType callBack:(JWRealTimeHeartRateActionCallBack)callBack;` | 同上；需支持 `JWBleFunctionEnum_APP_MOTION_HR_V2` |
| 实时体温 | `+ jwTestTemperatureAction:callBack:`（actionKey = 1） | `JWBleManager.realTimeTemperatureCallBack(float value, BOOL gradientStatus, BOOL wearingState, BOOL compensationStatus)`；`value == -999` 表示设备主动停止 |
| 实时计步 | `+ (void)jwGetRealTimeStepWithCallback:(void (^)(JWBleCommunicationStatus status, int step, int dis, int calories))callBack;` | 方法内 Block |
| 脉冲数据 | `+ jwCustomSetPulseAction:minute:level:callBack:`（客户定制） | `JWBleManager.pulseDataCallBack(int status, int length, int timestamp, int value)`；`status`：0 end / 1 start / 2 receiving |
| 脉冲结束 | — | `JWBleManager.endOfPulseCallBack(int value)` |
| 桑拿数据 | 客户定制功能 | `JWBleManager.saunaDataCallBack(int status, int length, int time, int hr, int tem, int label, int move)` |
| 心率体动数据 | — | `JWBleManager.hrMovementDataCallBack(int time, int hr, int tem, int label, int move)` |
| 体脂数据 | `+ jwCommonMeasurementAction:start:` | `JWBleManager.bodyFatDataCallBack(NSDictionary *dataDic)`，字段见第 6 章 |
| 设备开关变化 | — | `JWBleManager.deviceSwitchChangeCallBack(NSData *deviceSwitchData)`（配合 `jwGetDeviceSNIDWithBlock:` 解析） |
| 点测结束 | 任意通用点测 | `JWBleManager.endMeasurementStatusCallBack(JWBleEndMeasurementStatusType)` |
| Opus 数据 | `+ (void)jwOpenOpus:(BOOL)open;` | `JWBleManager.opusDataCallBack(NSData *responData)` |
| LANGCO 翻译 | 客户定制 | `JWBleManager.langCoTranslationCallBack(int value)` |

**注意事项**：`sprotType`（原头文件拼写如此）取值注释为 0 户外跑步 / 1 爬山 / 3 户外骑行 / 8 室内跑步 / 10 plank / 11 户外健走 / 14 徒步，与 `JWBleDeviceMotionEnum` 的取值一致，但接口类型是 `int` 而非枚举。

---

## 第 5 章 JWBleAction — 多运动（App 控制设备）

> 该组接口是最新增的“App 控制设备多运动”能力，需设备支持 `JWBleFunctionEnum_APPControlMotion`（功能号 35）。

### 5.1 查询设备当前运动状态

**功能说明**：查询设备当前的多运动状态（空闲/运行中/暂停）与运动类型。

**方法定义**
```objc
+ (void)jwQueryDeviceMotionStatus:(JWBleDeviceMotionControlCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `callBack` | `JWBleDeviceMotionControlCallBack` | 是 | `void (^)(JWBleCommunicationStatus status, JWBleMotionStatusModel * _Nullable statusModel)` |

**返回值**：无

**回调**：方法内 Block。**通信失败、超时或断连时 `statusModel` 为 `nil`**

**前置条件**：设备已连接且支持多运动功能

**调用示例**
```objc
[JWBleAction jwQueryDeviceMotionStatus:^(JWBleCommunicationStatus status,
                                         JWBleMotionStatusModel *statusModel) {
    if (statusModel) {
        NSLog(@"state=%ld type=%ld result=%ld",
              (long)statusModel.state, (long)statusModel.motionType, (long)statusModel.result);
    }
}];
```

**注意事项**：读类接口，会等待设备回包；同一时刻只允许一个待处理的多运动请求。

---

### 5.2 查询支持的运动类型

**方法定义**
```objc
+ (void)jwQuerySupportedDeviceMotionTypes:(JWBleDeviceMotionTypeListCallBack)callBack;
```

**参数**：`callBack` 类型为 `void (^)(JWBleCommunicationStatus status, NSArray<NSNumber *> * _Nonnull motionTypes)`

**回调**：返回 `JWBleDeviceMotionEnum` 对应的 `NSNumber` 数组；**设备不支持多运动功能时成功返回空数组**

**注意事项**：实现内先判断 `JWBleFunctionEnum_APPControlMotion`，不支持时直接以 `Success + 空数组` 回调。

---

### 5.3 开始 / 暂停 / 恢复 / 结束

| 功能 | 方法定义 | 说明 |
| --- | --- | --- |
| 开始 | `+ (void)jwStartDeviceMotion:(JWBleDeviceMotionEnum)motionType callBack:(JWBleDeviceMotionControlCallBack)callBack;` | 需要传具体运动类型 |
| 暂停 | `+ (void)jwPauseDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` | 无类型参数（协议下发 `0xFF`） |
| 恢复 | `+ (void)jwResumeDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` | 无类型参数 |
| 结束 | `+ (void)jwStopDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` | 无类型参数 |

**回调**：均为 `JWBleDeviceMotionControlCallBack`，结果以 `JWBleMotionStatusModel` 返回（`result` 表示设备侧执行结果）

**前置条件**：设备已连接且支持多运动

**注意事项**

- **设备响应才是权威结果**：下发指令不会直接改变 SDK 状态；`result` 为 `Success(0x00)` / `AlreadyInTargetState(0x01)` 视为成功，`0x02`~`0x04` 为协议失败。
- **超时 6 秒**，超时后回调一次通信失败；**同一时刻只允许一个待处理请求**（依据 `docs/superpowers/specs/2026-08-19-device-motion-control-design.md`）。
- 请**串行调用**，不要并发下发多个多运动控制指令。

---

### 5.4 持续状态与实时数据

| 回调 | 触发 | 数据 |
| --- | --- | --- |
| `JWBleManager.deviceMotionStatusChangeCallBack` | 设备主动上报状态变化（0x5D） | `JWBleMotionStatusModel` |
| `JWBleManager.deviceMotionRealtimeDataCallBack` | 设备实时数据（0x5E），仅当状态为 Running/Paused 时有效 | `JWBleMotionRealtimeDataModel`（`state`、`motionType`、`rawMotionType`、`duration`（秒）、`heartRate`、`steps`、`distance`、`calories`） |

---

## 第 6 章 JWBleDataAction（历史数据同步与读取）

### 6.1 同步：`+ (void)jwSyncDataWithCallBack:`

**功能说明**：从设备拉取历史数据并写入本地数据库。**所有历史数据读取接口的前置条件**。

**方法定义**
```objc
+ (void)jwSyncDataWithCallBack:(JWBleSyncCallBack)callBack;
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `callBack` | `JWBleSyncCallBack` | 是 | `void (^)(JWBleCommunicationStatus status, JWBleSyncStateEnum syncStateEnum)` |

**回调语义（实现顺序）**

1. 未连接 → `(Faild, Interrupt)`；
2. 设备处于 DFU 模式 → `(IsDFUModel, Interrupt)`；
3. 正常开始 → `(Success, Start)`；
4. 完成后按设备返回的 `status`：
   - `1` → `(Success, Complete)`（内部可能先做数据校准/同步回设备）
   - `2` → `(Faild, InconsistentTotals)`（总数不一致）
   - 其他 / 失败 → `(Faild, Interrupt)`

**前置条件**：设备已连接（`isConnected == YES`）且非 DFU

**调用示例**
```objc
[JWBleDataAction jwSyncDataWithCallBack:^(JWBleCommunicationStatus status,
                                           JWBleSyncStateEnum syncState) {
    if (syncState == JWBleSyncEnum_Complete) {
        // 可以读取本地数据了
    }
}];
```

**注意事项**

- 同步耗时较长，务必配合 `JWBleManager.synchronousDataProgressCallBack` 展示进度。
- 同步期间设备处于繁忙状态，其他指令可能返回 `Busy`。
- 重复同步不会清库，可能出现重复数据 → 需要时配合 `jwRemoveDataTimeLessThan:` / `jwFixDBData`。

---

### 6.2 数据读取接口（全部读本地数据库）

**通用说明**

- 所有接口均在**调用线程同步读本地 SQLite**，`callBack` 为同步回调；
- 日期参数统一为 `yyyyMMdd` 字符串（如 `@"20260928"`）；
- 每个 `ByYYYYMMDD` 接口都有对应的 `ByStartT:endT:` 时间戳版本；
- 数据来自上一次 `jwSyncDataWithCallBack:`。

| 数据类型 | 方法（日期版） | 时间戳版 | 返回结构 |
| --- | --- | --- | --- |
| 步数（15 分钟粒度） | `+ jwGetStepDataByYYYYMMDDStr:callBack:` | `+ jwGetStepDataByStartT:endT:callBack:` | 固定 96 条 `@{offset, steps, calory, distance}` |
| 当天步数汇总 | `+ jwGetDayStepTotalValue:callback:` | — | `(status, int step, int dis, int calories)` |
| 设置当天步数 | `+ jwSetTodayStepData:arr:` | — | 无回调（写本地库） |
| 睡眠（分钟粒度） | `+ jwGetSleepDataByYYYYMMDDStr:callBack:` | — | `@{minute, status(1 浅睡/2 深睡/3 清醒), yyyyMMdd}` |
| 过滤后睡眠 | `+ jwGetFilterSleepDataByYYYYMMDDStr:callBack:` | — | `DEEP_HOUR`、`LIGHT_HOUR`、`SLEEP_LEVEL`、`SLEEP_TIME`、`SLE_HOUR`、`SLE_MINUTE`、`WAKE_TIME`、`WakeUpTime`、`oneSleLine` |
| 睡眠质量计算（本地） | `+ (int)jwSleepQualityCalculation:deepMinute:totalMinute:wakeUpCount:` | — | 同步返回 0~5（0/1 较差、2 一般、3 好、4 很好、5 完美） |
| 睡眠原始数据解析 | `+ (NSArray *)jwTestSleepOriData:(NSString *)oriData;` | — | 同步返回数组（解析原始 hex 字符串） |
| 心率 | `+ jwGetHRDataByYYYYMMDDStr:callBack:` | `+ jwGetHRDataByStartT:endT:callBack:` | `@{time, value}`，按 `time` 升序 |
| 心率原始数据 | `+ jwGetHRRawDataWithCallBack:` | — | 全部本地心率记录 |
| 血压 | `+ jwGetBpDataByYYYYMMDDStr:callBack:` | `+ jwGetBpDataByStartT:endT:callBack:` | `@{time, high, low}` |
| 体温 | `+ jwGetTemperatureDataByYYYYMMDDStr:callBack:` | `+ jwGetTemperatureDataByStartT:endT:callBack:` | `@{time, value, wearingState, compensationStatus}` |
| 温度校准（本地计算） | `+ (float)jwTemperatureCalibration:(float)value;` | — | 同步返回校准后的温度值 |
| 血氧 | `+ jwGetOxygenDataByYYYYDDStr:callBack:` | `+ jwGetOxygenDataByStartT:endT:callBack:` | `JWOxygenModel` 数组 |
| HRV | `+ jwGetHrvDataByYYYYDDStr:callBack:` | `+ jwGetHrvDataByStartT:endT:callBack:` | `@{hrvValue, time}`，两个版本结构一致 |
| HRV-RMSSD | `+ jwGetHrvRmssdDataByYYYYDDStr:callBack:` | `+ jwGetHrvRmssdDataByStartT:endT:callBack:` | 见 6.3 |
| 血糖 | `+ jwGetBloodGlucoseDataByYYYYDDStr:callBack:` | `+ jwGetBloodGlucoseDataByStartT:endT:callBack:` | `@{value, time}` |
| 脉冲 | `+ jwGetPulseDataByYYYYDDStr:callBack:` | `+ jwGetPulseDataByStartT:endT:callBack:` | `@{value, time}` |
| 桑拿 | `+ jwGetSaunaDataByYYYYDDStr:callBack:` | `+ jwGetSaunaDataByStartT:endT:callBack:` | 数组，元素：`time`、`hr`、`tem`、`label`、`move` |
| 心率体动 | `+ jwGetHrMovementDataByYYYYDDStr:callBack:` | `+ jwGetHrMovementDataByStartT:endT:callBack:` | 数组，元素：`time`、`hr`、`tem`、`label`、`move` |
| 紫外线 | `+ jwGetUVDataByYYYYDDStr:callBack:` | `+ jwGetUVDataByStartT:endT:callBack:` | 数组，元素：`time`、`value`、`vd`、`skin`、`skinCancer` |
| 压力 | `+ jwGetStressDataByYYYYDDStr:callBack:` | `+ jwGetStressDataByStartT:endT:callBack:` | 数组，元素：`time`、`value` |
| 佩戴状态 | `+ jwGetWearStatusDataByYYYYDDStr:callBack:` | `+ jwGetWearStatusDataByStartT:endT:callBack:` | `@{time, wearingState(0 未佩戴/1 已佩戴)}` |
| 尿酸（周期） | `+ jwGetUricAcidCycleDataByYYYYDDStr:deviceMac:callBack:` | — | `cycleStartTime`、`cycleStartActionTime`、`valueTime`、`cycleEndTime`、`dayStatusList`、`evaluationResult` |
| 尿酸（连续监测） | `+ jwGetUricAcidContinuousMonitoringDataByYYYYMMDDStr:callBack:` | — | 数组，元素：`time`、`value` |
| 血脂（周期） | `+ jwGetBloodFatCycleDataByYYYYDDStr:deviceMac:callBack:` | — | 同周期结构 |
| 血脂（连续监测） | `+ jwGetBloodFatContinuousMonitoringDataByYYYYMMDDStr:callBack:` | — | 数组，元素：`time`、`value` |
| 血糖（周期） | `+ jwGetBloodGlucoseCycleDataByYYYYDDStr:deviceMac:callBack:` | — | 同周期结构 |
| 体脂 | `+ jwGetBodyFatByYYYYDDStr:deviceMac:callBack:` | — | 字段见第 10 章 `JWBleBodyFatDataCallBack` |
| 微体检 | `+ jwGetMicroPhysicalExaminationByYYYYDDStr:callBack:` | — | `time`、`hrValue`、`oxygenValue`、`stressValue`、`temperatureValue`、`skinTemperatureValue`、`bloodVesselElasticityValue`、`cardiovascularValue` |
| 运动记录 | `+ jwGetMotionDataByYYYYMMDDStr:callBack:` | — | `pk`、`year`、`month`、`day`、`minuteIndex`、`seconds`、`motionType`、`sportsMinute`、`sportsSeconds`、`pauseCount`、`pauseMinute`、`pauseSeconds`、`stepCount`、`distance`、`uid`、`calories` |
| 删除单条运动记录 | `+ (void)jwRemoveMotionDataWithPK:(int)pk;` | — | 无回调 |

**⚠️ 读取接口的返回值约定（2026-09-29 修复后）**

1. `jwGetHrvDataByStartT:endT:callBack:` 返回**HRV 数据**：`@{@"hrvValue": NSNumber, @"time": NSNumber}`，与日期版 `jwGetHrvDataByYYYYDDStr:` 结构一致（此前该接口错误地返回血氧数据，已修复）。
2. `jwGetStepDataByYYYYMMDDStr:` 补全的缺失分片与正常数据**类型一致**，`steps` / `calory` / `distance` / `offset` 全部为 `NSNumber`（此前缺失分片为字符串 `@"0"`，已修复）。
3. 所有 getter 均为**纯只读**：同一时间戳只返回第一条（去重语义保留），但**不再删除数据库记录**，重复调用结果稳定（此前会删除“重复时间戳”记录，已修复）。
4. `time <= 0` 的无效记录会被**跳过**（不返回、不删除）。
5. 需要清理历史数据时请使用显式接口：`jwRemoveDataTimeLessThan:dataType:`、`jwRemoveDataTime:dataType:`、`jwFixDBData`。

---

### 6.3 数据管理

| API | 方法定义 | 说明 |
| --- | --- | --- |
| 按时间删除 | `+ (void)jwRemoveDataTimeLessThan:(NSInteger)t;` | 删除小于 `t` 的全部数据 |
| 按类型+时间删除 | `+ (void)jwRemoveDataTimeLessThan:(NSInteger)t dataType:(JWDeleteDataType)dataType;` | `dataType` 见第 8 章 |
| 删除指定时间数据 | `+ (void)jwRemoveDataTime:(NSInteger)t dataType:(JWDeleteDataType)dataType;` | 删除等于 `t` 的数据 |
| 修复数据库 | `+ (void)jwFixDBData;` | 修复 `jwDeviceDataReset` 后重复数据问题 |

---

## 第 7 章 OTA 与表盘自定义

### 7.1 `JWBleOTAAction`

**单例**：`+ (JWBleOTAAction *)shareInstance`

#### 7.1.1 升级前检查（`JWBleAction`）

```objc
+ (void)jwCheckOTAEnableWithCallBack:(void (^)(JWBleCommunicationStatus status, int deviceStatus))callBack;
```

| `deviceStatus` | 含义（依据头文件注释） |
| --- | --- |
| `0` | 可直接开始 OTA 静默升级 |
| `1` | 手环设备正忙，需要提醒用户 |
| 其他值 | 设备未就绪（例如正在升级）；建议提示用户稍后重试，失败原因可结合 OTA 回调中的 `JWBleOTAAction.lastError*` 判断 |

#### 7.1.2 启动升级

| 方法定义 | 参数 | 调用示例 |
| --- | --- | --- |
| `- (void)startOTAV2ForWithData:(NSData *)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel andPeripheral:(CBPeripheral *)per callBack:(JWBleDFUCallBack)callBack;` | `data` 升级包；`OTAModel` 是否优先 OTA 模式；`per` 指定外设 | 见下 |
| `- (void)startOTAV2ForWithData:(NSData *)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel callBack:(JWBleDFUCallBack)callBack;` | 使用当前已连接设备 | — |
| `- (void)startOTAV2ForWithData:(NSData *)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel fsblMode:(BOOL)fsblMode versionString:(NSString *)versionString callBack:(JWBleDFUCallBack)callBack;` | `fsblMode` 是否校验 Secure Boot Loader 版本；`versionString` 目标 FSBL 版本，空字符串表示不跳过 | — |
| `- (void)cancelAllPeripheralConnections;` | 无 | 取消全部外设连接 |

**回调**：`JWBleDFUCallBack` → `void (^)(NSInteger didSend, NSInteger totalLength, JWBleDeviceDFUStatus deviceDFUStatus)`

**失败原因（2026-09-29 新增，全部为只读属性）**

| 成员 | 类型 | 说明 |
| --- | --- | --- |
| `lastErrorCode` | `JWBleErrorCode` | 最近一次升级失败的错误码；成功、跳过（版本一致）或未开始升级时为 `JWBleErrorCodeNone` |
| `lastErrorMessage` | `NSString *`（可空） | 失败描述，包含底层错误信息 |
| `lastUnderlyingError` | `NSError *`（可空） | 底层错误，OTA 场景通常来自 `RTKOTAErrorDomain` |
| `- (NSError *)lastError` | `NSError *`（可空） | 组合成 `NSError`，无失败时返回 `nil` |

**回调时序（依据实现）**

1. `data == nil` → 立即 `(0, 0, FileNotExist)`；
2. 无可用外设 → 立即 `(0, 0, PeripheralIsNull)`；
3. 开始 → `(0, 0, Start)`；
4. 传输中 → 多次 `(didSend, totalLength, Updating)`，进度 = `didSend / totalLength`；
5. FSBL 版本一致（仅第三个重载）→ `(0, 0, VersionConsistent)`；
6. 结束 → `(totalLength, totalLength, Success)` 或 `(0, 0, Failure)`。

**调用示例**
```objc
NSData *firmware = [NSData dataWithContentsOfFile:firmwarePath options:0 error:nil];
[[JWBleOTAAction shareInstance] startOTAV2ForWithData:firmware
                          prefersUpgradeUsingOTAMode:YES
                                           callBack:^(NSInteger didSend, NSInteger totalLength,
                                                      JWBleDeviceDFUStatus status) {
    if (status == JWBleDeviceDFUStatus_Updating) {
        // 进度
    } else if (status == JWBleDeviceDFUStatus_Success) {
        // 升级成功
    } else if (status == JWBleDeviceDFUStatus_Failure) {
        // 升级失败
    }
}];
```

**注意事项**：升级期间 `connectionModel.otaIng == YES`，扫描会被忽略；升级失败后建议重新连接再重试；`JWBleDeviceDFUStatus_VersionConsistent` 表示设备版本与升级包一致、无需升级。

### 7.2 表盘自定义 `JWBleCustomizeMainInterfaceAction`

| 方法定义 | 参数 | 回调 |
| --- | --- | --- |
| `+ (void)startWithImage:previewImage:configModel:actionCallBack:updateCallBack:` | 背景图、预览图、配置模型 | `actionCallBack`（制作/传输状态）、`updateCallBack`（`JWBleDFUCallBack` 传输进度） |
| `+ (void)startWithImage:previewImage:previewWidth:configModel:actionCallBack:updateCallBack:` | 额外指定预览宽度 | 同上 |
| `+ (void)startWithImage:previewImage:deviceWidth:deviceHeight:configModel:actionCallBack:updateCallBack:` | 动态指定设备宽高 | 同上 |
| `+ (void)startWithImage:previewImage:deviceWidth:deviceHeight:configModel:actionCallBack:combinedDataSuccessCallBack:updateCallBack:` | 额外返回合成数据 | 增加 `combinedDataSuccessCallBack(NSDictionary *dataDic)` |
| `+ (unsigned char *)convertUIImageToBitmapRGBRGB:(UIImage *)image;` | `UIImage` | 返回 RGB 字节流（`malloc` 分配）；**调用方使用完毕后需 `free()` 释放** |

**回调类型**

- `JWBleCustomizeMainInterfaceActionCallBack` → `void (^)(JWBleCustomizeMainInterfaceActionStatus actionStatus)`
- `JWBleCustomizeMainInterfaceCombinedDataSuccessCallBack` → `void (^)(NSDictionary *dataDic)`

**状态枚举**：`米其林资源包制作中` → `MakingResourcePack`；`PictureIsEmpty`；`FailedToParseImage`；`FailedToMakeResourcePack`；`Transmission`；`Success`；`Failure`

**配置模型**：`JWBleCustomizeMainInterfaceActionConfigModel`（`color` 白/黑、`position` 九宫格位置、`devicePositionDic` 设备坐标、`chipType`）

**相关 `JWBleAction` 方法（无方法内回调，结果体现在设备端）**

```objc
+ (void)jwCustomizeMainInterfaceAction:(BOOL)get configModel:(JWBleCustomizeMainInterfaceActionConfigModel *)configModel;
+ (void)jwCustomizeRoundMainInterfaceAction:(BOOL)get configModel:(...)configModel;
+ (void)jwCustomizeRectangleMainInterfaceAction:(BOOL)get configModel:(...)configModel;
+ (void)wbSetCustomizeV102MainInterface:(BOOL)get configModel:(...)configModel;
+ (void)jwCustomizeGT5MainInterfaceAction:(BOOL)get configModel:(...)configModel;
+ (void)jwCustomize_1_47_MainInterfaceAction:(BOOL)get configModel:(...)configModel;
+ (void)jwCustomize_238_MainInterfaceAction:(BOOL)get configModel:(...)configModel;
+ (void)jwCustomizeMainInterfacePositionWithConfigModel:(JWBleCustomizeMainInterfaceActionConfigModel *)configModel;
```

**注意事项**：以上 8 个方法对应 SDK 内部的表盘资源机型/尺寸代号（`V102`、`GT5`、`1.47`、`238` 等），**第三方不需要按型号选择**——统一调用 `JWBleCustomizeMainInterfaceAction` 的显式 `deviceWidth:deviceHeight:` 版本即可，SDK 会按连接设备的实际分辨率处理。

### 7.3 `JWBleMyMainInterfaceAction`

| 成员 | 签名 | 说明 |
| --- | --- | --- |
| 单例 | `+ (JWBleMyMainInterfaceAction *)shareInstance` | — |
| 获取配置 | `- (void)getDeviceInterfaceConf;` | 获取设备自定义表盘配置（结果经 `callBack` 属性返回 `NSData`） |
| 发送数据 | `- (void)testSendData:(NSData *)data;` | 自定义表盘数据通道的原始发送接口（`wbSendData_my:`），一般由 SDK 内部流程调用 |
| 发送图片数据 | `- (void)testSendImageData:(NSData *)data;` | 同上 |
| 设备响应入口 | `- (void)deviceRespnseData:(NSData *)data;` | 设备侧数据回调入口，由 SDK 内部转发到 `callBack`；第三方通常无需调用 |
| 回调属性 | `@property(nonatomic, copy) JWBleMyMainInterfaceActionCallBack callBack;` | `void (^)(NSData *data)` |

**注意事项**：该类包含 `test` 前缀方法且需外部“喂”设备响应数据，明显偏内部实现，建议后续从公开头文件移除或补齐语义。

---

## 第 8 章 工具类

### 8.1 `JWBlePublicHelp`

| 方法定义 | 参数 | 返回值 | 说明 |
| --- | --- | --- | --- |
| `+ (float)jw_step2DisWith:(int)height andStepCount:(int)stepCount;` | `height` cm、`stepCount` 步数 | 公里（float） | 步数换算距离 |
| `+ (float)jw_dis2CalWith:(float)weight andDis:(float)dis;` | `weight` kg、`dis` 千米 | 千卡（float） | 距离换算卡路里 |

**注意事项**：为同步计算、无回调。换算公式（与固件一致）：
`distance(km) = height(cm) × 0.0045 × steps ÷ 1000`；`calories(kcal) = weight(kg) × distance(km) × 0.8214`。

### 8.2 `JWLogAction` / `JWLogModel`

| 成员 | 签名 | 说明 |
| --- | --- | --- |
| 读取日志 | `+ (NSArray *)getLog;` | 返回日志数组（`JWLogModel`） |
| 清空日志 | `+ (void)clear;` | 清空本地日志 |
| 写日志 | `+ (void)log:(NSString *)formatStr, ...NS_FORMAT_FUNCTION(1,2);` | 格式化写日志 |
| 日志模型 | `JWLogModel`：`NSTimeInterval t`、`NSString *str` | 继承自 `JWBleDBModel` |
| 便捷宏 | `JWNSLog(...)` | 等价于 `[JWLogModel log:__VA_ARGS__]` |

**前置条件**：需 `JWBleManager.showLog = YES`；持久化需 `saveLog = YES`。

### 8.3 `JWBleDBModel`

公开的本地数据库基类（FMDB/JKDBModel 风格）：`pk`、`columeNames`、`columeTypes`，以及 `save`、`saveOrUpdate`、`update`、`deleteObject`、`findAll`、`findByPK:`、`findByCriteria:`、`createTable`、`clearTable` 等。SDK 自身的业务表模型并未全部公开，第三方一般**无需直接使用**。

---

## 第 9 章 回调总清单（API → 回调 对应关系）

### 9.1 `JWBleManager` 属性回调（28 个，全部在主线程回调）

| 回调属性 | 类型 | 触发场景 | 参数 | 对应 API / 前置条件 | 注意事项 |
| --- | --- | --- | --- | --- | --- |
| `connectStateChangeCallBack` | `JWBleConnectStatusChangeCallBack` | 连接、绑定、同步、断开、电量、充电、超时、设备状态、耳机状态等**全部连接类事件** | `JWBleDeviceConnectStatus` | 任意（初始化后即可注册） | 必接。是所有连接状态的唯一出口 |
| `getPowerCallBack` | `JWBleGetPowerCallBack` | 设备上报电量（主动查询或电量变化） | `(JWBleCommunicationStatus status, int power, bool charging)` | `jwGetDeviceCurrentBatteryWithCallBack:`（2026-09-29 新增） | 持久回调，注册一次即可 |
| `centralManagerStateChangeBlock` | `JWCentralManagerStateChangeBlock` | 手机系统蓝牙开关变化 | `JWBleCentralManagerState` | 初始化后 | 蓝牙关闭时会先回调 `DisConnect` |
| `remotePhotographyCallBack` | `JWBleRemotePhotographyCallBack` | 遥控拍照设置结果 + 设备摇晃拍照事件 | `JWBleRemotePhotographyStatus` | `jwRemotePhotography:callBack:` | `_TakePhoto` 为用户拍照动作 |
| `synchronousDataProgressCallBack` | `JWBleSynchronousDataProgressCallBack` | 历史数据同步进度 | `(int curPackageIndex, int packageCount)` | `jwSyncDataWithCallBack:` 过程中 | 用于进度条 |
| `langCoTranslationCallBack` | `JWBleLangCoTranslationCallBack` | 客户定制翻译功能返回 | `int value` | 客户定制功能 | 需定制支持 |
| `findPhoneCallBack` | `JWBleFindPhoneCallBack` | 设备触发“查找手机”（旧版） | 无 | 设备侧触发 | 无返回值 |
| `findPhoneV2CallBack` | `JWBleFindPhoneV2CallBack` | 设备触发“查找手机”V2 | `BOOL start` | 设备侧触发 | `start` 表示开始/结束 |
| `realTimeHeartRateCallBack` | `JWBleRealTimeHeartRateCallBack` | 实时心率数据 | `NSInteger hrValue` | `jwRealTimeHeartRateAction:callBack:` | `-999` 表示设备主动停止 |
| `realTimeTemperatureCallBack` | `JWBleRealTimeTemperatureCallBack` | 实时体温数据 | `(float value, BOOL gradientStatus, BOOL wearingState, BOOL compensationStatus)` | `jwTestTemperatureAction:`（actionKey = 1） | `-999` 表示设备主动停止 |
| `deviceMotionStatusChangeCallBack` | `JWBleDeviceMotionStatusChangeCallBack` | 设备多运动状态变化（0x5D 主动上报） | `JWBleMotionStatusModel` | 多运动功能 | 与请求回调可能同时触发 |
| `deviceMotionRealtimeDataCallBack` | `JWBleDeviceMotionRealtimeDataCallBack` | 设备多运动实时数据（0x5E） | `JWBleMotionRealtimeDataModel` | 需状态已进入 Running/Paused | 停止/断开后不再回调 |
| `endOfPulseCallBack` | `JWBleEndOfPulseCallBack` | 脉冲结束 | `int value` | `jwCustomSetPulseAction:minute:level:callBack:` | 客户定制 |
| `pulseDataCallBack` | `JWBlePulseDataCallBack` | 脉冲数据 | `(int status, int length, int timestamp, int value)` | 同上 | `status`：0 end / 1 start / 2 receiving |
| `saunaDataCallBack` | `JWBleSaunaDataCallBack` | 桑拿数据 | `(int status, int length, int time, int hr, int tem, int label, int move)` | 客户定制 | — |
| `hrMovementDataCallBack` | `JWBleHrMovementDataCallBack` | 心率体动监测数据 | `(int time, int hr, int tem, int label, int move)` | — | — |
| `opusDataCallBack` | `JWBleOpusDataCallBack` | Opus 数据 | `NSData *responData` | `jwOpenOpus:` | 需设备支持 |
| `ecgDataCallBack` | `JwECGDataCallBack` | ECG 波形数据 | `(NSArray *originalSignals, NSArray *filterSignals)` | `jwECGAction:callBack:` | 高频回调 |
| `ecgOriDataCallBack` | `JwECGOriDataCallBack` | ECG 原始数据 | `NSData *oriData` | 同上 | — |
| `ecgValueDataCallBack` | `JwECGValueDataCallBack` | ECG 指标值 | `(int bpm, int qt, int hrv, int rri, int progress)` | 同上 | `progress` 为进度 |
| `deviceTestECGCallBack` | `JwDeviceTestECGCallBack` | 产测 ECG 数据 | `NSDictionary *dic` | 产测模式 | 第三方通常不使用 |
| `beltValueDataCallBack` | `JwBeltValueDataCallBack` | ECG Belt 指标值 | `(int bpm, int qt, int hrv, int rri)` | `jwBeltAction:callBack:` | — |
| `beltDataCallBack` | `JwBeltDataCallBack` | ECG Belt 波形 | `(NSArray *originalSignals, NSArray *filterSignals)` | 同上 | — |
| `deviceSwitchChangeCallBack` | `JwDeviceSwitchChangeCallBack` | 设备可控开关数据变化 | `NSData *deviceSwitchData` | 连接成功后同步、或设备主动上报 | 需 `jwGetDeviceSNIDWithBlock:` 解析 |
| `uricAcidStatusCallBack` | `JWBleUricAcidStatusCallBack` | 尿酸状态变化 | `(BOOL open, int privateValue, int privateRtc)` | `jwUricAcidAction:…` | — |
| `bloodFatStatusCallBack` | `JWBleBloodFatStatusCallBack` | 血脂状态变化 | 同上 | `jwBloodFatAction:…` | — |
| `bloodGlucoseCycleStatusCallBack` | `JWBleBloodGlucoseCycleStatusCallBack` | 周期血糖状态变化 | 同上 | `jwBloodGlucoseCycleAction:…` | — |
| `endMeasurementStatusCallBack` | `JWBleEndMeasurementStatusCallBack` | 通用点测结束 | `JWBleEndMeasurementStatusType`（Cancel / Fail / Success） | 通用点测 | 判断点测是否成功 |
| `bodyFatDataCallBack` | `JWBleBodyFatDataCallBack` | 体脂数据 | `NSDictionary *dataDic` | `jwCommonMeasurementAction:start:` | 字段见 10.10 |

### 9.2 方法内 Block（按功能归类）

| 模块 | 方法 | 回调结果 |
| --- | --- | --- |
| 扫描 | `jwStartScanDeviceWithCallBack:` | `JWBleDeviceModel`（每设备一次） |
| 用户信息/目标 | `jwSynchronizePersonalInformation:…`、`jwSetStepTargetAction:` 等 | `JWBleCommunicationStatus` |
| 能力查询 | `jwCheckFunctionStates:`、`jwCheckControlSwitchStates:`、`jwCheckHideFunctionStates:`、`jwCheckCustomFunctionStates:` | **同步返回值**，无 Block |
| 时间/单位/语言/亮度/亮屏 | `jwSetTimeWithYear:…`、`jwCommonFunction:…`、`jwLanguageAction:…`、`jwbBrightnessAdjustment:…`、`jwbBrightScreenDuration:…` | `JWBleCommunicationStatus` + 读到的值 |
| 勿扰/久坐/转腕 | `jwNotDisturbAction:`、`jwSedentaryReminder:`、`jwTurnWristCreenActionWithIsGet:` | 专用 Block（见第 3 章） |
| 闹钟/吃药提醒 | `jwAlarmAction:`、`jwAlarmV2Action:`、`jwMedicationReminderAction:` | 专用 Block，返回模型数组 |
| 消息通知 | `jwUpdateNotiStatus:`、`jwOneTimeUpdateNotiStatus:`、`jwGetNotiStatusWithCallBack:` | `JWBleCommunicationStatus` / 通知字典 |
| 点测 | `jwTestHRAction:`、`jwTestBPAction:`、`jwTestOxygen:`、`jwTestTemperatureAction:`、`jwTestBloodGlucoseAction:` | 专用 Block（含测试状态机） |
| 多运动 | `jwQueryDeviceMotionStatus:`、`jwStartDeviceMotion:` 等 | `JWBleCommunicationStatus` + `JWBleMotionStatusModel` |
| 数据同步 | `jwSyncDataWithCallBack:` | `JWBleCommunicationStatus` + `JWBleSyncStateEnum` |
| 数据读取 | `JWBleDataAction` 全部 getter | 数组 / 字典（读本地库，同步回调） |
| OTA | `JWBleOTAAction` 三个 `startOTA…` | `JWBleDFUCallBack` |
| 表盘 | `JWBleCustomizeMainInterfaceAction` 四个 `startWithImage:…` | `actionCallBack` + `updateCallBack`（+ `combinedDataSuccessCallBack`） |

### 9.3 定义了但**没有任何公开 API 引用**的回调（11 个，均已标记废弃）

以下 Block 类型在公开头文件中声明，但公开 API 已不再使用，属于历史遗留；2026-09-29 已统一加 `API_DEPRECATED` 标记：

`JWBleCheckMotionSupportCallBack`、`JWBleCommunicationReceiveCallBack`、`JWBleFindPhoneActionCallBack`、`JWBleGetImmediateDataCallBack`、`JWBleHRReminderActionCallBack`、`JWBleMainInterfaceStyleBlock`、`JWBleMotionActionCallBack`、`JWBleStopwatchTimingActionCallBack`、`JWBleTimeThemeActionCallBack`、`JWBleTimerActionCallBack`、`JWBleUpdatePWDCallBack`

> 上表这些 Block 与 `JWBleMotionActionEnum` 自 1.3.2 起标记为 `API_DEPRECATED`（保留声明以兼容旧代码，请勿在新代码中使用）。`JWBleGetPowerCallBack` 已用于 `jwGetDeviceCurrentBatteryWithCallBack:`，不属于遗留回调。

---

## 第 10 章 数据模型

### 10.1 `JWBleDeviceModel`（设备模型）

| 字段 | 类型 | 单位 | 是否可能为空 | 说明 |
| --- | --- | --- | --- | --- |
| `rssi` | `NSNumber *` | dBm | 可能 | 信号强度；无广播上下文时为 `@0` |
| `systemMacAddress` | `NSString *` | — | 可能 | 原始广播字符串 / 系统 UUID |
| `macAddress` | `NSString *` | — | 可能 | 解析后的 MAC（`AA:BB:CC:DD:EE:FF`）；解析不到时为 UUID |
| `deviceName` | `NSString *` | — | 可能 | 广播名，回退到 `CBPeripheral.name` |
| `versionName` | `NSString *` | — | 同步后 | 形如 `1.2.3` 或 `1.2.3.4` |
| `versionCode` | `int` | — | 同步后 | 版本整数编码（有 buildnum 时为 7 位十进制拼接） |
| `fontVersionCode` | `int` | — | 同步后 | 字库版本号；不支持时为 `-1` |
| `fontVersionCodeStr` | `NSString *` | — | 同步后 | 如 `0.0.0.0` |
| `resourceVersionCode` | `int` | — | 同步后 | 资源版本号；不支持时为 `-1` |
| `resourceVersionCodeStr` | `NSString *` | — | 同步后 | 如 `0.0.0.0` |
| `power` | `int` | % | 同步后 | 电量 |
| `deviceNumber` | `int` | — | 同步后 | 设备号（deviceId） |
| `functionData` | `NSData *` | — | 可能 | 功能位图（能力判断依据） |
| `functionDataV2` | `NSArray *` | — | 可能 | 设备功能 2 组列表，元素为 `@{@"type":…}` |
| `hideFunctionMenu` | `NSData *` | — | 可能 | 隐藏功能菜单位图 |
| `notiData` | `NSData *` | — | 可能 | 通知开关数据 |
| `per` | `CBPeripheral *` | — | 可能 | 系统蓝牙外设对象 |
| `isDFU` | `BOOL` | — | — | 是否为 DFU 设备 |
| `otaIng` | `BOOL` | — | — | 是否正在 OTA |
| `chargIng` | `BOOL` | — | — | 是否充电中 |
| `headsetPaired` | `BOOL` | — | — | 耳机是否配对过 |
| `headphoneDeviceStatus` | `int` | — | — | 耳机状态：0 关机 / 1 配对中 / 2 准备就绪 / 3 已连接 / 4 被手机连接中 |
| `deviceStatusTypeArr` | `NSArray *` | — | 可能 | 设备状态数组（元素为 `JWDeviceStatusType`，如省电模式） |
| `chipType` | `int` | — | 可能 | 芯片类型：0 C（正常芯片）/ 1 D（VD 版本） |
| `platform` | `int` | — | 可能 | 芯片平台：0 rtk / 100 联睿微 |
| `advertisementData` | `NSDictionary *` | — | 可能 | 原始广播数据 |
| `deviceSwitchData` | `NSData *` | — | 可能 | 设备可控开关数据 |
| `customizedFunctionDic` | `NSDictionary *` | — | 可能 | 客户定制功能支持情况 |
| `DeviceInfoData` | `NSData *` | — | 可能 | RTK 原始设备信息（1.3.2 起随 framework 交付） |

### 10.2 `JWBleAlarmClockModel`

| 字段 | 类型 | 单位/范围 | 说明 |
| --- | --- | --- | --- |
| `year` | `int` | 0~63（自 2000 起算，13 = 2013） | 年 |
| `month` | `int` | 1~12 | 月（V2 中 month、day 同时为 0 表示删除） |
| `day` | `int` | 1~31 | 日 |
| `hour` | `int` | 0~23 | 时 |
| `minute` | `int` | 0~59 | 分 |
| `repeatWeekArr` | `NSArray *` | 7 元素 0/1 | 周重复（周一起）。全 0 / `nil` / 空 / 不足 7 位表示仅当次有效 |
| `idd` | `int` | — | 闹钟 V2 的 ID |
| `isOpen` | `bool` | — | 闹钟 V2 是否开启 |
| `content` | `NSString *` | — | 闹钟 V2 显示文本 |

### 10.3 `JWBleMedicationReminderModel`

字段与 `JWBleAlarmClockModel` 的前 6 项完全一致（`year`、`month`、`day`、`hour`、`minute`、`repeatWeekArr`），无 V2 字段。

### 10.4 `JWBleHeatStressReminderModel`

| 字段 | 类型 | 范围 | 说明 |
| --- | --- | --- | --- |
| `open` | `BOOL` | — | 是否开启 |
| `startHour` | `int` | 0~23 | 开始小时 |
| `startMinute` | `int` | 0~59 | 开始分钟 |
| `endHour` | `int` | 0~23 | 结束小时 |
| `endMinute` | `int` | 0~59 | 结束分钟 |

> 该模型与 `jwHeatStressReminderAction:` 均已包含在交付的 1.3.2 `JWBle.framework` 中。

### 10.5 `JWNotDisturbModel`

| 字段 | 类型 | 范围 | 说明 |
| --- | --- | --- | --- |
| `open` | `BOOL` | — | 是否开启 |
| `enumType` | `JWBleNotDisturbEnum` | 0~2 | 全天 / 未佩戴 / 定时 |
| `startHour` | `UInt32` | 0~23 | 开始小时 |
| `startMinute` | `UInt32` | 0~59 | 开始分钟 |
| `endHour` | `UInt32` | 0~23 | 结束小时 |
| `endMinute` | `UInt32` | 0~59 | 结束分钟 |

### 10.6 `JWCountDownModel`

| 字段 | 类型 | 范围 | 说明 |
| --- | --- | --- | --- |
| `seconds` | `int` | 1~86400 | 秒数；读取且状态为“开始”时为剩余秒数 |
| `optionEnum` | `JWCountDownOptionEnum` | 0~2 | Setting / Start / Stop |
| `open` | `bool` | — | 是否显示在设备 UI |

### 10.7 `JWOxygenModel`

| 字段 | 类型 | 单位 | 说明 |
| --- | --- | --- | --- |
| `mCurValue` | `int` | % | 当前血氧值 |
| `mHighValue` | `int` | % | 最高血氧值 |
| `mLowValue` | `int` | % | 最低血氧值 |
| `time` | `NSInteger` | 秒级时间戳 | 时间 |

### 10.8 天气模型

`JWBleWeatherModel`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `open` | `bool` | 是否开启天气 |
| `curWeatherModel` | `JWBleCurWeatherModel *` | 当前天气，**不能为空** |
| `futureWeatherArr` | `NSArray<JWBleFutureWeatherModel *> *` | 预报，最多 6 条 |

`JWBleCurWeatherModel`

| 字段 | 类型 | 单位/范围 | 说明 |
| --- | --- | --- | --- |
| `year` / `month` / `day` | `int` | — | **必须与设备日期一致** |
| `cityStr` | `NSString *` | ≤33 bytes | 城市名 |
| `weatherCode` | `JWBleWeatherCode` | 0~27 | 天气类型 |
| `temp` | `int` | ℃，需 > 0 | 当前温度 |
| `maxTemp` / `minTemp` | `int` | ℃，需 > 0 | 最高/最低温度 |
| `humidity` | `int` | % | 湿度，0 表示不显示 |
| `uv` | `int` | 0~5 档 | 紫外线等级：0 无效 / 1 最弱(0-2) / 2 弱(3-4) / 3 中(5-6) / 4 强(7-9) / 5 很强(≥10) |
| `pm` | `int` | — | 污染指数，0 表示不显示 |

`JWBleFutureWeatherModel`：`weatherCode`、`maxTemp`、`minTemp`（均为 `int`）。

### 10.9 `JWBleCustomizeMainInterfaceActionConfigModel`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `color` | `JWBleCustomizeMainInterfaceActionConfigModelColor` | 白 / 黑 |
| `position` | `JWBleCustomizeMainInterfaceActionConfigModelPosition` | 九宫格位置（0~8） |
| `devicePositionDic` | `NSDictionary *` | 各位置对应的设备坐标，形如 `@{@"…Top_Middle": @{@"x":@2, @"y":@5}}` |
| `chipType` | `int` | 芯片类型 |

### 10.10 `JWBleBodyFatDataCallBack` 返回字典字段

| 字段 | 说明 |
| --- | --- |
| `time` | 时间 |
| `weight` | 体重 |
| `bmi`、`bmiLevel`、`bmiMaxLevel` | BMI 及等级/最大等级 |
| `fm`、`fmLevel`、`fmMaxLevel` | 脂肪 |
| `tbw`、`tbwLevel`、`tbwMaxLevel` | 水分 |
| `pw`、`pwLevel`、`pwMaxLevel` | 蛋白质 |
| `mm`、`mmLevel`、`mmMaxLevel` | 骨盐量（BMC） |
| `slm`、`slmLevel`、`slmMaxLevel` | 肌肉量 |
| `bmr`、`bmrLevel`、`bmrMaxLevel` | 基础代谢 |

> 全部为 `NSInteger`：`weight` 为体重（kg）；`fm`（体脂）、`tbw`（水分）、`pw`（蛋白质）、`mm`（骨盐量）、`slm`（肌肉量）、`bmr`（基础代谢）为设备上报数值，`*Level` / `*MaxLevel` 为当前档位与满量程，用于绘制进度条；具体展示单位由 App 按产品需求换算。

### 10.11 多运动模型

`JWBleMotionStatusModel`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `result` | `JWBleDeviceMotionResult` | 设备执行结果（0x00 成功 / 0x01 已是目标状态 / 0x02 不支持类型 / 0x03 状态非法 / 0x04 电量低） |
| `state` | `JWBleDeviceMotionState` | 0x00 空闲 / 0x01 运行中 / 0x02 暂停 |
| `motionType` | `JWBleDeviceMotionEnum` | 已映射的运动类型 |
| `rawMotionType` | `NSInteger` | 设备原始运动类型（未映射时用于排查） |

`JWBleMotionRealtimeDataModel`

| 字段 | 类型 | 单位 | 说明 |
| --- | --- | --- | --- |
| `state` | `JWBleDeviceMotionState` | — | 运动状态 |
| `motionType` | `JWBleDeviceMotionEnum` | — | 运动类型 |
| `rawMotionType` | `NSInteger` | — | 原始类型 |
| `duration` | `uint32_t` | 秒 | 时长（头文件明确注释 Unit: seconds） |
| `heartRate` | `uint8_t` | bpm | 心率 |
| `steps` | `uint32_t` | 步 | 步数 |
| `distance` | `uint32_t` | 米 | 与设备协议运动数据字段一致（距离单位：米） |
| `calories` | `uint32_t` | 卡 | 与设备协议运动数据字段一致（卡路里单位：卡，展示为千卡需自行换算） |

### 10.12 `JWBleLogModel` / `JWBleDBModel`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `JWLogModel.t` | `NSTimeInterval` | 日志时间 |
| `JWLogModel.str` | `NSString *` | 日志内容 |
| `JWBleDBModel.pk` | `int` | 主键 |

---

## 第 11 章 公开枚举

> 枚举值已按头文件原样列出；含义取自头文件注释。

### 11.1 连接与通信（`JWBlePublicDefine.h`）

**`JWBleDeviceConnectStatus`** — 连接状态（核心）

| 枚举值 | 含义 |
| --- | --- |
| `DisConnect = 0` | 断开连接 |
| `Connect` | 已连接（BLE 链路） |
| `BondSuccess` | 绑定成功 |
| `BondFailure` | 绑定失败 |
| `SyncSuccess` | 同步信息成功（设备 Ready） |
| `SyncFailure` | 同步信息失败 |
| `DiscoverNewUpdateFirm` | 发现可升级的新固件 |
| `BatteryUpdate` | 电量变化 |
| `ChargeStatusChanged` | 充电状态改变 |
| `HeadphoneDeviceStatusChanged` | 耳机状态改变 |
| `TimeOutDisconnect` | 通信超时，已主动断开 |
| `DeviceStatusChanges` | 设备状态改变（省电模式、飞行模式等） |
| `BondConfirm_NotAllowed` | 绑定失败：用户点击不允许 |
| `BondConfirm_TimeOut` | 绑定失败：用户未操作设备 |
| `BleRemovedPairingInformation` | 系统蓝牙配对缓存被删除（通常被其他手机绑走） |
| `Temp` | 占位 |

**`JWBleCommunicationStatus`** — 通信状态（**事实上的错误码**）

| 枚举值 | 含义 |
| --- | --- |
| `Faild = 0` | 通信失败 |
| `Success = 1` | 通信成功 |
| `PWDError = 3` | 通信密码错误 |
| `IsDFUModel = 4` | 设备处于 DFU 模式 |
| `Busy = 5` | 设备正忙（同步数据中） |

**`JWBleCentralManagerState`** — 系统蓝牙状态

`Unknown = 0`、`Resetting`、`Unsupported`、`Unauthorized`、`PoweredOff`、`PoweredOn`

**`JWBleSyncStateEnum`** — 同步状态：`Start = 0`、`Interrupt`、`InconsistentTotals`、`Complete`

**`JWBleBusyStateEnum`** — 设备繁忙判断：`Busy = 2`、`Idle = 3`、`TimeOut = 4`

**`JWBleRealTimeHeartRateStateEnum`** — 实时心率状态：`Close = 0`、`Open`、`Busy`、`TimeOut`

**`JWBleDeviceDFUStatus`** — 固件升级状态

| 枚举值 | 含义 |
| --- | --- |
| `FileNotExist = 0` | 升级文件不存在 |
| `Start` | 开始升级 |
| `Updating` | 升级中 |
| `Success` | 升级成功 |
| `Failure` | 升级失败 |
| `PeripheralIsNull` | 设备为 null |
| `VersionConsistent` | 版本一致，无需升级 |

### 11.2 测试状态

| 枚举 | 取值 | 含义 |
| --- | --- | --- |
| `JWBleTestHRStatus` | `TestStart = 0`、`DeviceResponse`、`TestEnd`、`TestField` | 心率点测状态机 |
| `JWBleTestBPStatus` | `TestStart = 0`、`DeviceResponse`、`TestEnd`、`TestField`、`TestInterrupt` | 血压/血糖点测状态机 |
| `JWBleTestTemperatureStatus` | `TestEnd = 0`、`DeviceResponse = 1`、`NotOpen = 2`、`Open = 3`、`BUSY = 4`、`TestField` | 温度监测开关结果 |
| `JWBleEndMeasurementStatusType` | `Cancel = 0`、`Fail`、`Success` | 通用点测结束状态 |
| `JWTestOxygenRequestType` | `End = 0`、`Start`、`Check` | 血氧点测请求 |
| `JWTestOxygenResultType` | `End = 0`、`Start`、`Disable`、`Available` | 血氧点测返回 |

### 11.3 设备功能与设置

**`JWBleFunctionEnum`** — 功能枚举（能力判断核心），共 **100 项**，分 3 段定义：

- 基础段（`Error = -1` 起自增）、高位段（63 → 35 递减）、设备功能 2 段（10001 → 10016）。
- 下表的“值”列：基础段与 V2 段为**按 C 枚举规则推算的隐式值**（源文件未显式写值），已与实现中的解码逻辑（`NSMakeRange(functionEnum, 1)`）交叉验证一致；如需绝对确认，可用实现中的位图映射表反算。
- “位图坐标”列 = `functionData.length <= 8` 时该功能在 `functionData` 中的 `byteIndex.bitIndex`（`JWBleAction.m` 的静态 `switch` 表）。标注 `—` 表示**不在位图白名单内**，此类设备上必然返回“不支持”。

**基础段（0 ~ 33）**

| 枚举 | 值 | 含义 | 位图坐标 |
| --- | --- | --- | --- |
| `JWBleFunctionEnum_Error` | -1 | 占位符 | — |
| `JWBleFunctionEnum_HeadphoneCall` | 0 | 耳机通话 | 3.7 |
| `JWBleFunctionEnum_BloodPressureTest` | 1 | 血压测试 | 3.6 |
| `JWBleFunctionEnum_HR` | 2 | 心率监测 | 3.5 |
| `JWBleFunctionEnum_DoNotDisturbMode` | 3 | 勿扰模式 | 3.4 |
| `JWBleFunctionEnum_Step` | 4 | 计步 | 3.3 |
| `JWBleFunctionEnum_Sleep` | 5 | 睡眠监测 | 3.2 |
| `JWBleFunctionEnum_WeChatRun` | 6 | 微信运动 Airsync | 3.1 |
| `JWBleFunctionEnum_BrightScreenDuration` | 7 | 亮屏时长 | 3.0 |
| `JWBleFunctionEnum_Noti` | 8 | 消息提醒 | 2.7 |
| `JWBleFunctionEnum_MainInterfaceStyle` | 9 | 主界面风格 | 2.6 |
| `JWBleFunctionEnum_LiftTheWristScreen` | 10 | 抬手亮屏 | 2.5 |
| `JWBleFunctionEnum_MoreLanguage` | 11 | 多语言 | 2.4 |
| `JWBleFunctionEnum_TimeSystem` | 12 | 时间 12/24 进制 | 2.3 |
| `JWBleFunctionEnum_Unit` | 13 | 公英制 | 2.2 |
| `JWBleFunctionEnum_OTA` | 14 | 空中升级 | 2.1 |
| `JWBleFunctionEnum_NFC` | 15 | NFC | 2.0 |
| `JWBleFunctionEnum_ExerciseMore` | 16 | 多运动 | 1.7 |
| `JWBleFunctionEnum_StopwatchTiming` | 17 | 秒表计时（隐藏功能菜单） | 1.6 |
| `JWBleFunctionEnum_Countdown` | 18 | 倒计时 | 1.5 |
| `JWBleFunctionEnum_HeartRateReminder` | 19 | 心率提醒 | 1.4 |
| `JWBleFunctionEnum_RemotePhotography` | 20 | 遥控拍照 | 1.3 |
| `JWBleFunctionEnum_FindPhone` | 21 | 查找手机（隐藏功能菜单） | 1.2 |
| `JWBleFunctionEnum_FindBracelet` | 22 | 查找手环 | 1.1 |
| `JWBleFunctionEnum_BrightnessControl` | 23 | 亮度控制 | 1.0 |
| `JWBleFunctionEnum_MusicControl` | 24 | 音乐控制 | 0.7 |
| `JWBleFunctionEnum_VolumeControl` | 25 | 音量控制 | 0.6 |
| `JWBleFunctionEnum_SmartAlarmClock` | 26 | 智能闹钟 | 0.5 |
| `JWBleFunctionEnum_SedentaryReminder` | 27 | 久坐提醒 | 0.4 |
| `JWBleFunctionEnum_EventReminder` | 28 | 事件提醒 | 0.3 |
| `JWBleFunctionEnum_AutomaticLockScreen` | 29 | 自动锁屏（隐藏功能菜单） | 0.2 |
| `JWBleFunctionEnum_RealTimeHeartRate` | 30 | 实时心率 | 0.1 |
| `JWBleFunctionEnum_HideFunctionMenu` | 31 | 隐藏功能菜单 | 0.0 |
| `JWBleFunctionEnum_TwoButtonSliding` | 32 | 双按键滑动（隐藏功能菜单） | — |
| `JWBleFunctionEnum_VoiceAssistant` | 33 | 语音助手（隐藏功能菜单） | — |

> 注：`TwoButtonSliding`、`VoiceAssistant` 可被 `jwCheckHideFunctionStates:` 判断，但**不在** `jwCheckFunctionStates:` 的位图表中。

**高位段（63 ~ 35，递减定义；值 52 未定义）**

| 枚举 | 值 | 含义 | 位图坐标 |
| --- | --- | --- | --- |
| `JWBleFunctionEnum_DataCalibration` | 63 | 数据校准 | 4.0 |
| `JWBleFunctionEnum_SyncSleep` | 62 | 同步睡眠给手环 | 4.1 |
| `JWBleFunctionEnum_Temperature` | 61 | 温度 | 4.2 |
| `JWBleFunctionEnum_BloodPressureV2` | 60 | 血压 2.0 | 4.3 |
| `JWBleFunctionEnum_SmartAlarmClockV2` | 59 | 智能闹钟 2.0 | 4.4 |
| `JWBleFunctionEnum_MainInterfaceStyle_Customize` | 58 | 自定义主界面风格 | 4.5 |
| `JWBleFunctionEnum_MainInterfaceStyle_Download` | 57 | 下载主界面 | 4.6 |
| `JWBleFunctionEnum_Blood_Oxygen` | 56 | 血氧 | 4.7 |
| `JWBleFunctionEnum_DisplayFontUpgrade` | 55 | 显示字库升级 | 5.0 |
| `JWBleFunctionEnum_SleepQualityJudgment_V2` | 54 | 睡眠质量判断 2.0 | 5.1 |
| `JWBleFunctionEnum_APP_MOTION_HR_V2` | 53 | APP 运动心率 2.0 | 5.2 |
| （未定义） | 52 | — | 5.3（对应位未使用） |
| `JWBleFunctionEnum_ContinuousBloodOxygen` | 51 | 连续血氧检测 | 5.4 |
| `JWBleFunctionEnum_ECG` | 50 | ECG | 5.5 |
| `JWBleFunctionEnum_Status_Check` | 49 | 状态检查 | 5.6 |
| `JWBleFunctionEnum_Address_Book` | 48 | 通讯录 | 5.7 |
| `JWBleFunctionEnum_HRV` | 47 | HRV | 6.0 |
| `JWBleFunctionEnum_DeviceBPMonitoring` | 46 | 设备血压监测 | 6.1 |
| `JWBleFunctionEnum_BloodGlucose` | 45 | 血糖 | 6.2 |
| `JWBleFunctionEnum_LowOxygenReminder` | 44 | 低氧提醒 | 6.3 |
| `JWBleFunctionEnum_HighHeartRateReminder` | 43 | 心率过高提醒 | 6.4 |
| `JWBleFunctionEnum_SleepAllDay` | 42 | 全天睡眠 | 6.5 |
| `JWBleFunctionEnum_DialDateFormat` | 41 | 表盘日期格式 | 6.6 |
| `JWBleFunctionEnum_ECGHidden_HRV_QT` | 40 | ECG 不显示 QT 和 HRV | 6.7 |
| `JWBleFunctionEnum_Belt` | 39 | ECG Belt | 7.0 |
| `JWBleFunctionEnum_Health_Hidden` | 38 | 健康功能隐藏 | 7.1 |
| `JWBleFunctionEnum_Stress` | 37 | 压力自动监测 | 7.2 |
| `JWBleFunctionEnum_HeatStress` | 36 | 热应激 | 7.3 |
| `JWBleFunctionEnum_APPControlMotion` | 35 | APP 控制多运动 | 7.4 |

**设备功能 2 段（10001 ~ 10016，全部不在位图白名单）**

| 枚举 | 值 | 含义 |
| --- | --- | --- |
| `JWBleFunctionEnum_DevicePrivateBloodPressure` | 10001 | 设备私人血压 |
| `JWBleFunctionEnum_SOS` | 10002 | SOS |
| `JWBleFunctionEnum_DrinkWaterReminder` | 10003 | 喝水提醒 |
| `JWBleFunctionEnum_TemperatureReminder` | 10004 | 体温提醒 |
| `JWBleFunctionEnum_MedicationReminder` | 10005 | 吃药提醒 |
| `JWBleFunctionEnum_Female` | 10006 | 女性健康 |
| `JWBleFunctionEnum_Weather` | 10007 | 天气 |
| `JWBleFunctionEnum_WearingTime` | 10008 | 佩戴时间 |
| `JWBleFunctionEnum_UricAcid` | 10009 | 尿酸 |
| `JWBleFunctionEnum_BloodFat` | 10010 | 血脂 |
| `JWBleFunctionEnum_BloodGlucoseCycle` | 10011 | 周期血糖 |
| `JWBleFunctionEnum_UricAcid_ContinuesMonitoring_Private` | 10012 | 尿酸持续监测（私人模式） |
| `JWBleFunctionEnum_BloodFat_ContinuesMonitoring_Private` | 10013 | 血脂持续监测（私人模式） |
| `JWBleFunctionEnum_BodyFat` | 10014 | 体脂 |
| `JWBleFunctionEnum_MicroPhysicalExamination` | 10015 | 微体检 |
| `JWBleFunctionEnum_UV` | 10016 | 紫外线 |

> V2 段的判断逻辑：`functionDataV2` 中任一项的 `type == 功能号 - 10000` 即为支持（返回 `Open`），否则 `NotSupport`；列表为空也返回 `NotSupport`。

**`JWBleFunctionStatesEnum`**：`NotSupport = 0\|2`、`Close = 1`、`Open = 3`

**`JWBleHideFunctionStatesEnum`**：`NotSupport = 0`、`Show`、`Hidden`

**`JWBleDeviceSwitchFunctionEnum`** — 设备可控开关（`-1` 表示不支持）

`Time_Format`、`Language`、`Heart_Rate_Monitoring`、`Blood_Pressure_Monitoring`、`Blood_Oxygen_Monitoring`、`Temperature_Monitoring`、`Temperature_Compensation`、`Temperature_Function_Independent`、`BloodGlucose_Monitoring`、`Gesture_Bright_Screen`、`UricAcidContinuesMonitoring`、`BloodFatContinuesMonitoring`

**`JWBleCommonFunctionsStatus`**：`Read`、`Open`、`Close`

**`JWBleLanguageEnum`** — 18 种语言：`English = 0`、`ChineseSimplified = 1`、`Traditional_Chinese = 2`、`Polish = 13`、`German = 18`、`Russian = 19`、`French = 20`、`Korean = 29`、`Dutch = 31`、`Mongolian = 53`、`Portuguese = 62`、`Japanese = 65`、`Swedish = 66`、`Thai = 81`、`Turkey = 82`、`Spanish = 87`、`Italian = 96`、`Vietnamese = 102`

**`JWBleNotiEnum`** — 通知类型（步长为 2）

`Error = -1`、`Call = 1`、`QQ = 3`、`WeChat = 5`、`SMS = 7`、`Line = 9`、`Twitter = 11`、`Facebook = 14`、`Messenger = 16`、`WhatsApp = 18`、`LinkedIn = 20`、`Instagram = 22`、`Skype = 24`、`Viber = 26`、`KakaoTalk = 28`、`VKontakte = 30`、`AppleMail = 32`、`AppleCalendar = 34`、`AppleFacetime = 36`、`Tim = 38`、`Gmail = 40`、`DingTalkPlus = 42`、`WorkWechat = 44`、`APlus = 46`、`LINK = 48`、`Beike = 50`、`Lianjia = 52`、`Other = 54`

**`JWUserPreferenceType`**：`BloodGlucose_Unit = 0`（0: mmol；1: mg）

**`JWBleFemaleStatus`**：`None = 0`、`Menstrual`、`Getting_Pregnant`、`Pregnancy`、`Mom`

**`JWDeviceStatusType`**：`Power_Saving_Mode = 63`、`Temp`

**`JWUpdateResourceType`**：`Main_display_resource = 0`、`Display_font`、`Font_libraries_involved_in_the_main_interface`、`Custom_interface_resources`、`Dial_market_resources`

### 11.4 运动

**`JWBleDeviceMotionEnum`**：`Unknown = -1`、`Run = 0`、`Climb`、`Football`、`Cycle`、`Rope`、`RunOutDoor`、`RideOutDoor`、`WalkOutDoor`、`RunInDoor`、`FreeTrain`、`Plank`、`Walk`、`Pranayama`、`Yoga`、`Hiking`、`Spinning`、`Rowing`、`Stepper`、`Elliptical`、`Basketball`、`Tennis`、`Badminton`、`Baseball`、`Rugby`、`PingPong = 0x18`、`Skiing = 0x19`、`Cricket = 0x1A`、`StrengthTraining = 0x1B`

**`JWBleDeviceMotionControlAction`**：`Query = 0x00`、`Start = 0x01`、`Pause = 0x02`、`Resume = 0x03`、`Stop = 0x04`

**`JWBleDeviceMotionResult`**：`Success = 0x00`、`AlreadyInTargetState = 0x01`、`UnsupportedType = 0x02`、`InvalidState = 0x03`、`LowBattery = 0x04`

**`JWBleDeviceMotionState`**：`Idle = 0x00`、`Running = 0x01`、`Paused = 0x02`

**`JWBleMotionActionEnum`**：`Stop = 0`、`Start = 1`、`Pause = 3`（⚠️ 该枚举与 `JWBleMotionActionCallBack` 均**无公开 API 引用**）

**`JWBleImmediateDataEnum`**：`Step = 0`、`HR`

### 11.5 健康与数据

**`JWBleBusyStatus`**（设备繁忙原因，共 14 项）：`Heart_Rate_Manual_Test = 0`、`Heart_Rate_Silent_Measurement`、`Manual_Blood_Pressure_Measurement`、`Blood_Pressure_Silent_Measurement`、`Manual_Blood_Oxygen_Measurement`、`Silent_Measurement_Of_Blood_Oxygen`、`Manual_Pressure_Measurement`、`Silent_Measurement_Of_Pressure`、`In_Motion`、`ECG_Testing`、`Manual_Blood_Glucose_Measurement`、`Silent_Measurement_Of_Blood_Glucose`、`Pulsed_Magnetic_Therapy`、`BodyFat_Testing`

**`JWBleCommonMeasurementEnum`**：`BodyFat = 5`

**`JWUricAcidEvaluationResultEnum`**：`None = 0`、`Insufficient_Wearing_Time`（佩戴时间不足）、`Low_Risk`、`Medium_Risk`、`High_Risk`

> 该枚举同时用于**尿酸、血脂、周期血糖**的 `evaluationResult` 字段，取值语义一致：`0` 无、`1` 佩戴时间不足、`2` 低风险、`3` 中风险、`4` 高风险。

**`JWDeleteDataType`**：`Step = 0`、`Sleep`、`HeartRate`、`BloodPressure`、`Oxygen`、`Temperature`、`BloodGlucose`、`Hrv`、`Sports`、`BloodFat`、`UricAcid`、`BloodGlucoseCycle`、`BloodFatContinuousMonitoring`、`UricAcidContinuousMonitoring`、`BodyFat`、`MicroPhysicalExamination`、`UV`

### 11.6 状态与密码

| 枚举 | 取值 |
| --- | --- |
| `JWBleUpdatePWDStatus` | `Success = 0`、`OldPwdError`、`DeviceBusy`、`Faild` |
| `JWBleRemotePhotographyStatus` | `Success = 0`、`TakePhoto`、`DeviceBusy`、`Faild` |
| `JWBleCustomFunctionEnum` | `Error = -1`、`SetPulse = 0`、`SleepAid`、`Sauna` |

### 11.7 模型内枚举

| 枚举 | 取值 |
| --- | --- |
| `JWBleNotDisturbEnum` | `AllDay = 0`、`NotWorn`、`Timing` |
| `JWCountDownOptionEnum` | `Setting = 0`、`Start`、`Stop` |
| `JWBleWeatherCode` | `Other = 0`、`Sunny`、`Cloudy`、`Overcast`、`Rain`、`LightRain`、`ModerateRain`、`HeavyRain`、`Storm`、`ShowerRain`、`HeavyShowerRain`、`FreezingRain`、`Snow`、`LightSnow`、`ModerateSnow`、`HeavySnow`、`Sleet`、`Typhoon`、`Duststorm`、`SunnyAtNight`、`CloudyAtNight`、`Hot`、`Cold`、`Breeze`、`Gale`、`Mist`、`CloudyToClear` |
| `JWBleCustomizeMainInterfaceActionStatus` | `MakingResourcePack = 0`、`PictureIsEmpty`、`FailedToParseImage`、`FailedToMakeResourcePack`、`Transmission`、`Success`、`Failure` |
| `JWBleCustomizeMainInterfaceActionConfigModelColor` | `White = 0`、`Black` |
| `JWBleCustomizeMainInterfaceActionConfigModelPosition` | `Top_Left = 0`、`Top_Middle`、`Top_Right`、`Middle_Left`、`Middle_Middle`、`Middle_Right`、`Bottom_Left`、`Bottom_Middle`、`Bottom_Right` |

---

## 第 12 章 错误码与异常处理

### 12.1 统一错误码（2026-09-29 新增）

原状态枚举全部保留、**没有任何方法签名被修改**；在上层新增了统一错误码 `JWBleErrorCode`（45 个值）与 NSError 工具函数，属于纯增量能力：

| 能力 | 声明 | 说明 |
| --- | --- | --- |
| 错误码枚举 | `JWBleErrorCode`（`JWBlePublicDefine.h`） | 45 个值，分 5 段：1xxx 状态/参数/通信、2xxx 蓝牙与链路、3xxx 设备与协议、4xxx OTA/DFU、9xxx 未知 |
| 错误域 | `JWBleErrorDomain` | 取值 `com.wosmart.JWBle.ErrorDomain`，用于 `NSError.domain` |
| 消息 | `NSString *JWBleErrorMessageForCode(JWBleErrorCode)` | 英文技术描述（便于日志与问题追踪），面向用户的文案请自行本地化 |
| 构造 NSError | `NSError *JWBleMakeError(JWBleErrorCode)` | 直接得到带 `NSLocalizedDescriptionKey` 的 `NSError` |
| 构造带底层错误的 NSError | `NSError *JWBleMakeErrorWithUnderlyingError(JWBleErrorCode, NSError *)` | userInfo 含 `NSUnderlyingErrorKey` |
| 状态映射 | `JWBleErrorCodeFromCommunicationStatus()`<br />`JWBleErrorCodeFromConnectStatus()`<br />`JWBleErrorCodeFromCentralManagerState()`<br />`JWBleErrorCodeFromDFUStatus()` | 均为头文件 `NS_INLINE` 纯函数，不发通信；成功态返回 `JWBleErrorCodeNone` |

**错误码分段速查**

| 段 | 取值 | 覆盖 |
| --- | --- | --- |
| 无错误 | `None = 0` | 成功 / 正常态 |
| 状态与参数 | 1000~1009 | 未初始化、未连接、设备繁忙、DFU 模式、密码错误、不支持、参数非法、超时、超范围、通信失败 |
| 蓝牙与链路 | 2000~2008 | 蓝牙关闭/未授权/不支持/重置/未知、连接失败、连接超时、链路断开、系统配对被移除 |
| 设备与协议 | 3000~3006 | 设备返回失败、数据非法、同步失败、同步总数不一致、绑定失败、绑定被拒、绑定超时 |
| OTA / DFU | 4000~4016 | 文件不存在/为空、无可用设备、格式非法、解析失败、版本一致（跳过）、固件不匹配、版本过旧、电量过低、不支持该方式、启动失败、传输失败、校验失败、激活失败、超时、断开、取消、失败（未细分） |
| 未知 | 9000 | 兜底 |

**调用示例**

```objc
// 1) 把 SDK 回调里的状态枚举转成错误码 / map a status enum into an error code
JWBleErrorCode code = JWBleErrorCodeFromCommunicationStatus(status);
if (code != JWBleErrorCodeNone) {
    NSInteger httpLikeCode = code;                         // 例如 1002
    NSError *error = JWBleMakeError(code);                 // 可直接上报/打点
    NSLog(@"%@", error.localizedDescription);
}

// 2) 连接类失败：直接读 JWBleManager.lastErrorCode / connection failures
JWBleErrorCode connectError = [JWBleManager shareInstance].lastErrorCode;

// 3) OTA 失败：拿具体原因 / OTA failure reason
JWBleOTAAction *ota = [JWBleOTAAction shareInstance];
if (ota.lastErrorCode != JWBleErrorCodeNone) {
    NSLog(@"OTA failed: %ld %@ (underlying: %@)",
          (long)ota.lastErrorCode, ota.lastErrorMessage, ota.lastUnderlyingError);
}
```

**配套属性**

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `JWBleManager.lastErrorCode` | `JWBleErrorCode`（只读） | 最近一次连接类失败的原因；连接/绑定/同步成功后自动清零 |
| `JWBleOTAAction.lastErrorCode` | `JWBleErrorCode`（只读） | 最近一次升级失败的原因（成功、跳过或未开始为 `None`） |
| `JWBleOTAAction.lastErrorMessage` | `NSString *`（只读，可空） | 失败描述，包含底层错误信息 |
| `JWBleOTAAction.lastUnderlyingError` | `NSError *`（只读，可空） | 底层错误，OTA 场景通常来自 `RTKOTAErrorDomain` |
| `- (NSError *)JWBleOTAAction.lastError` | `NSError *`（可空） | 把上面三项组合成 `NSError`；无失败时返回 `nil` |

> OTA 失败原因来自 RTKOTASDK 的 `RTKOTAErrorDomain`，已做映射（例如 `RTKOTAErrorImageOld` → `JWBleErrorCodeOTAImageTooOld`、`RTKOTAErrorDeviceBatteryLevelLow` → `JWBleErrorCodeOTADeviceBatteryLow`、`RTKOTAErrorUserCancelled` → `JWBleErrorCodeOTACancelled`），无法识别的归入 `JWBleErrorCodeOTAFailed`。

### 12.2 原有状态枚举仍在使用（需要时用上面的函数转换）

| 类别 | 承载枚举 | 典型值 |
| --- | --- | --- |
| 通信状态 | `JWBleCommunicationStatus` | `Faild`、`PWDError`、`IsDFUModel`、`Busy` |
| 连接状态 | `JWBleDeviceConnectStatus` | `SyncFailure`、`TimeOutDisconnect`、`BondFailure`、`BondConfirm_NotAllowed`、`BondConfirm_TimeOut`、`BleRemovedPairingInformation` |
| 功能状态 | `JWBleFunctionStatesEnum` / `JWBleHideFunctionStatesEnum` | `NotSupport`、`Close`、`Open` |
| 测试状态 | `JWBleTestHRStatus` / `JWBleTestBPStatus` / `JWBleTestTemperatureStatus` | `TestField`、`TestInterrupt`、`NotOpen`、`BUSY` |
| 升级状态 | `JWBleDeviceDFUStatus` | `FileNotExist`、`Failure`、`PeripheralIsNull`、`VersionConsistent` |

### 12.3 异常场景与建议处理

| 场景 | 表现 | 建议处理 |
| --- | --- | --- |
| 未连接就调用业务 API | 回调 `JWBleCommunicationStatus_Faild` | 先判断 `JWBleManager.isConnected` / 等待 `SyncSuccess` |
| 设备处于 DFU 模式 | 回调 `JWBleCommunicationStatus_IsDFUModel` | 提示用户等待/重新连接 |
| 设备正在同步运动历史 | 回调 `JWBleCommunicationStatus_Busy` | 串行化调用，等待同步结束 |
| 通信密码不一致 | 回调 `JWBleCommunicationStatus_PWDError` | 提示重新绑定（解绑后重连） |
| 连接后 60 秒未完成同步 | `connectStateChangeCallBack(TimeOutDisconnect)`，SDK 主动断开 | 提示重试；检查设备是否被其他手机占用 |
| 绑定被用户拒绝 / 超时 | `BondConfirm_NotAllowed` / `BondConfirm_TimeOut` | 提示用户重新操作设备 |
| 系统配对缓存被删除 | `BleRemovedPairingInformation` | 重新绑定 |
| 功能不支持 | `jwCheckFunctionStates:` 返回 `NotSupport`（值为 2） | **不要调用该功能 API**，UI 隐藏入口 |
| 升级文件不存在 / 设备为空 | `JWBleDeviceDFUStatus_FileNotExist` / `_PeripheralIsNull` | 校验文件与连接状态后重试 |
| 升级失败 | `JWBleDeviceDFUStatus_Failure` | 读取 `JWBleOTAAction.lastErrorCode` / `lastError` 获取具体原因（2026-09-29 起），再决定重试或提示 |

### 12.4 第三方需要自行处理的状态

1. **蓝牙被关闭**：`centralManagerStateChangeBlock` 会先触发 `DisConnect`，随后 `PoweredOff`。
2. **App 退到后台**：SDK 不保证后台重连，需三方自行声明后台模式。
3. **权限被拒绝**：SDK 不弹系统权限框，`CBCentralManager` 会进入 `Unauthorized` 状态，需三方自行引导。
4. **本地数据库读写失败**：`JWBleDataAction` 的 getter 无错误回传，数据为空时返回空数组（**无法区分“无数据”和“读取失败”**，建议三方自行校验）。

---

## 第 13 章 公开 API 明细（统一格式补全）

> 第 2~7 章已给出核心 API 的完整格式（含调用示例）；本章按同一模板补齐**其余对外 API**。
> 模板字段：功能 / 签名 / 参数 / 回调 / 前置条件 / 注意事项（示例与核心 API 同构，不再重复）。
> **生产/产测专用接口不在此列**，见 13.4 附录。

### 13.1 提醒与周期性监测

#### 13.1.1 `jwHrAutomaticDetectionAction:open:timeSpan:callBack:`

- **功能**：读写“心率自动检测”开关与间隔。
- **签名**：`+ (void)jwHrAutomaticDetectionAction:(BOOL)isGet open:(BOOL)open timeSpan:(int)timeSpan callBack:(JWBleAutomaticDetectionActionCallBack)callBack;`
- **参数**：`isGet` 读取/设置；`open` 开关（设置时有效）；`timeSpan` 间隔分钟，取值 5 / 30 / 60 / 120。
- **回调**：`JWBleAutomaticDetectionActionCallBack` → `(JWBleCommunicationStatus status, BOOL open, int timeSpan)`。
- **前置**：设备已连接；需支持 `JWBleFunctionEnum_HR`；建议先 `jwGetHRAutomaticDetectionType:` 确认支持的间隔。
- **注意**：`isGet = YES` 时等待设备回包；`isGet = NO` 为“已下发”语义。

#### 13.1.2 `jwBPAutomaticDetectionAction_V3:open:timeSpan:callBack:`

- **功能**：读写“血压自动检测”开关与间隔。
- **签名**：`+ (void)jwBPAutomaticDetectionAction_V3:(BOOL)isGet open:(BOOL)open timeSpan:(int)timeSpan callBack:(JWBleAutomaticDetectionActionCallBack)callBack;`
- **参数**：同 13.1.1。
- **回调**：`(status, BOOL open, int timeSpan)`。
- **前置**：设备已连接；需支持血压功能（`JWBleFunctionEnum_BloodPressureTest` / `BloodPressureV2`）。
- **注意**：方法名带 `_V3` 后缀，是 SDK 内部版本演进痕迹，与 13.1.1 的调用方式完全对称。

#### 13.1.3 `jwTurnWristCreenActionWithIsGet:open:sensitivity:startMinute:endMinute:callBack:`

- **功能**：读写抬腕/转腕亮屏及其时间窗与灵敏度。
- **签名**：`+ (void)jwTurnWristCreenActionWithIsGet:(BOOL)isGet open:(BOOL)open sensitivity:(int)sensitivity startMinute:(int)startMinute endMinute:(int)endMinute callBack:(JWBleTurnWristCreenActionCallBack)callBack;`
- **参数**：`sensitivity` 灵敏度；`startMinute` / `endMinute` 生效时间窗（当日分钟数）。
- **回调**：`(status, open, sensitivity, startMinute, endMinute)`。
- **前置**：需支持 `JWBleFunctionEnum_LiftTheWristScreen`。
- **注意**：时间窗单位为“分钟”，不是“小时”；另可用 `jwCheckControlSwitchStates:Gesture_Bright_Screen` 读开关值。

#### 13.1.4 `jwbBrightScreenDuration:timeLength:callBack:`

- **功能**：读写亮屏时长。
- **签名**：`+ (void)jwbBrightScreenDuration:(BOOL)isGet timeLength:(int)timeLength callBack:(JWBleBrightScreenDurationCallBack)callBack;`
- **参数**：`timeLength` 秒（头文件注释 3~30，**部分固件支持到 60，请以实报为准**）。
- **回调**：`(JWBleCommunicationStatus status, int timeLength, int defalut)`。
- **前置**：需支持 `JWBleFunctionEnum_BrightScreenDuration`。
- **注意**：方法名前缀为小写 `jwb`，与 SDK 其余 `jw` 前缀不一致（历史遗留）。

#### 13.1.5 `jwbBrightnessAdjustment:value:callBack:`

- **功能**：读写屏幕亮度。
- **签名**：`+ (void)jwbBrightnessAdjustment:(BOOL)isGet value:(int)value callBack:(void (^)(JWBleCommunicationStatus status,int value,int defalutValue))callBack;`
- **参数**：`value` 亮度 20~100。
- **回调**：`(status, value, defalutValue)`。
- **前置**：需支持 `JWBleFunctionEnum_BrightnessControl`。

#### 13.1.6 `jwDialDateFormatAction:open:callBack:`

- **功能**：读写表盘日期格式。
- **签名**：`+ (void)jwDialDateFormatAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **参数**：`open`：`false` → MM-DD，`true` → DD-MM。
- **前置**：需支持 `JWBleFunctionEnum_DialDateFormat`(41)。

#### 13.1.7 `jwSleepAllDayAction:open:callBack:`

- **功能**：读写全天睡眠监测开关。
- **签名**：`+ (void)jwSleepAllDayAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **前置**：需支持 `JWBleFunctionEnum_SleepAllDay`(42)。

#### 13.1.8 `jwHighHeartRateReminderAction:open:maxValue:callBack:`

- **功能**：读写心率上限提醒。
- **签名**：`+ (void)jwHighHeartRateReminderAction:(BOOL)isGet open:(BOOL)open maxValue:(int)maxValue callBack:(void (^)(JWBleCommunicationStatus status, BOOL open, int maxValue))callBack;`
- **参数**：`maxValue` 40~220。
- **前置**：需支持 `JWBleFunctionEnum_HighHeartRateReminder`(43)。

#### 13.1.9 `jwLowOxygenReminderAction:open:callBack:`

- **功能**：读写低血氧提醒开关。
- **签名**：`+ (void)jwLowOxygenReminderAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **前置**：需支持 `JWBleFunctionEnum_LowOxygenReminder`(44)。

#### 13.1.10 `jwContinuousBloodOxygenAction:open:callBack:`

- **功能**：读写连续血氧检测开关。
- **签名**：`+ (void)jwContinuousBloodOxygenAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **前置**：需支持 `JWBleFunctionEnum_ContinuousBloodOxygen`(51)。

#### 13.1.11 `jwTemperatureReminderAction:value:callBack:`

- **功能**：读写体温过高提醒阈值。
- **签名**：`+ (void)jwTemperatureReminderAction:(BOOL)isGet value:(int)value callBack:(void (^)(JWBleCommunicationStatus status, int value))callBack;`
- **参数**：`value` 摄氏 38.0~41.9；**传 0 表示关闭提醒**。
- **前置**：需支持 `JWBleFunctionEnum_TemperatureReminder`(10004)（V2 段功能）。

#### 13.1.12 `jwDrinkWaterReminderAction:open:startHour:startMinute:endHour:endMinute:span:callBack:`

- **功能**：读写喝水提醒。
- **签名**：`+ (void)jwDrinkWaterReminderAction:(BOOL)isGet open:(bool)open startHour:(int)startHour startMinute:(int)startMinute endHour:(int)endHour endMinute:(int)endMinute span:(int)span callBack:(void (^)(JWBleCommunicationStatus status, bool open, int startHour, int startMinute, int endHour, int endMinute, int span))callBack;`
- **参数**：`span` 间隔 30~480 分钟；起止时分。
- **回调**：`(status, open, startHour, startMinute, endHour, endMinute, span)`。
- **前置**：需支持 `JWBleFunctionEnum_DrinkWaterReminder`(10003)。
- **注意**：⚠️ `isGet = YES` 时**读取的是本地缓存**（`functionDataV2` 的 `contentData`），不向设备查询；`isGet = NO` 时写入并立即回调 `Success`，不等设备确认。因此**写入后请再调用一次 `isGet = YES` 回读**，以设备返回值刷新 UI。

#### 13.1.13 `jwMedicationReminderAction:alarmArr:callBack:`

- **功能**：读写吃药提醒列表。
- **签名**：`+ (void)jwMedicationReminderAction:(BOOL)get alarmArr:(NSArray<JWBleMedicationReminderModel *> *)alarmArr callBack:(JWBleMedicationReminderActionCallBack)callBack;`
- **参数**：`alarmArr` 设置时必填（数组即全量）；模型字段同 `JWBleAlarmClockModel` 前 6 项。
- **回调**：`(status, NSArray<JWBleMedicationReminderModel *> *alarmArr)`。
- **前置**：需支持 `JWBleFunctionEnum_MedicationReminder`(10005)。
- **注意**：全量覆盖语义；读取等待设备回包。

#### 13.1.14 `jwHeatStressReminderAction:model:callBack:`

- **功能**：读写热应激提醒。
- **签名**：`+ (void)jwHeatStressReminderAction:(BOOL)get model:(JWBleHeatStressReminderModel *)model callBack:(void (^)(JWBleCommunicationStatus status, JWBleHeatStressReminderModel *model))callBack;`
- **参数**：`model` 设置时必填（`open` + 起止时分）。
- **前置**：需支持 `JWBleFunctionEnum_HeatStress`(36)。
- **说明**：该 API 与模型已包含在交付的 1.3.2 `JWBle.framework` 中，可直接调用。

#### 13.1.15 `jwFemaleAction:mode:cycleDay:menstrualDay:year:month:day:callBack:`

- **功能**：设置女性健康参数。
- **签名**：`+ (void)jwFemaleAction:(BOOL)open mode:(JWBleFemaleStatus)mode cycleDay:(int)cycleDay menstrualDay:(int)menstrualDay year:(int)year month:(int)month day:(int)day callBack:(void (^)(JWBleCommunicationStatus status))callBack;`
- **参数**：`open` 开关；`mode` 状态（无/月经期/备孕/怀孕/宝妈）；`cycleDay` 周期天数；`menstrualDay` 经期天数；`year/month/day` 上次月经日期。
- **前置**：需支持 `JWBleFunctionEnum_Female`(10006)。
- **注意**：**只有设置，没有读取**（无 `isGet` 参数）；回调为“已下发”语义。

#### 13.1.16 `jwWeatherAction:callBack:`

- **功能**：下发当前天气与预报给设备。
- **签名**：`+ (void)jwWeatherAction:(JWBleWeatherModel *)weatherModel callBack:(void (^)(JWBleCommunicationStatus status))callBack;`
- **参数**：`weatherModel` 必填；`curWeatherModel` 不能为空，`futureWeatherArr` 最多 6 条；**年/月/日必须与设备日期一致**。
- **前置**：需支持 `JWBleFunctionEnum_Weather`(10007)；建议先用 `jwSetTimeWithYear:…` 校准设备时间。
- **注意**：“已下发”语义；建议每次 App 前台或天气更新时重新下发。

#### 13.1.17 `jwUserPreferencesAction:values:callBack:`

- **功能**：读写用户偏好（当前仅血糖单位）。
- **签名**：`+ (void)jwUserPreferencesAction:(BOOL)isGet values:(NSArray *)values callBack:(void (^)(JWBleCommunicationStatus status, NSArray *values))callBack;`
- **参数**：`values` 形如 `@[@{@"type": @(JWUserPreferenceType_BloodGlucose_Unit), @"value": @(0)}]`（0 = mmol/L，1 = mg/dL）。
- **回调**：`(status, NSArray *values)`。
- **注意**：⚠️ `isGet = YES` 时若设备返回失败，**不会回调**（`if (success)` 无 `else`，见问题 29）。请自行加超时兜底。

### 13.2 数据与设置辅助接口

#### 13.2.1 `jwGetRealTimeStepWithCallback:`

- **功能**：读取实时计步（当前值）。
- **签名**：`+ (void)jwGetRealTimeStepWithCallback:(void (^)(JWBleCommunicationStatus status, int step, int dis, int calories))callBack;`
- **回调**：`(status, step, dis, calories)`，`dis` 单位米、`calories` 单位卡。
- **前置**：设备已连接。

#### 13.2.2 `jwGetHRAutomaticDetectionType:`

- **功能**：查询设备支持的自动检测间隔集合。
- **签名**：`+ (void)jwGetHRAutomaticDetectionType:(void (^)(JWBleCommunicationStatus status, NSDictionary *resultDic))callBack;`
- **回调**：字典 key 为 `"0"/"5"/"30"/"60"/"120"`，value 为 `@(YES/NO)`；`"0"` 表示支持连续检测。
- **前置**：设备已连接。
- **注意**：与 13.1.1 配合使用，避免下发不支持的间隔。

#### 13.2.3 `jwCountDownAction:model:callBack:` / `jwStopCountDownCallBack`

- **功能**：读写倒计时（设置 / 开始 / 停止）。
- **签名**：
  - `+ (void)jwCountDownAction:(BOOL)isGet model:(JWCountDownModel *)countDownModel callBack:(JWBleCountDownActionCallBack)callBack;`
  - `+ (void)jwStopCountDownCallBack;`（清除内部回调，无参数）
- **参数**：`JWCountDownModel.seconds` 1~86400；`optionEnum` 设置/开始/停止；`open` 是否显示在设备 UI。
- **回调**：`(status, JWCountDownModel *countDownModel)`；读取且状态为“开始”时 `seconds` 为剩余秒数。
- **前置**：需支持 `JWBleFunctionEnum_Countdown`。
- **注意**：`jwStopCountDownCallBack` 只是清理回调，不向设备下发停止；停止请用 `jwCountDownAction` + `JWCountDownOptionEnum_Stop`。

#### 13.2.4 `jwAutomaticLockScreenAction:open:callBack:`

- **功能**：读写自动锁屏。
- **签名**：`+ (void)jwAutomaticLockScreenAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **前置**：属隐藏功能菜单，需 `jwCheckHideFunctionStates:JWBleFunctionEnum_AutomaticLockScreen` 非 `NotSupport`。

#### 13.2.5 `jwMainInterfaceAction:willShowIndex:callBack:`

- **功能**：读写主界面（表盘）风格。
- **签名**：`+ (void)jwMainInterfaceAction:(BOOL)isGet willShowIndex:(int)willShowIndex callBack:(void (^)(JWBleCommunicationStatus status,int curShowIndex, int count))callBack;`
- **参数**：`willShowIndex` 目标风格序号；`count+1` 显示自定义表盘，`count+2` 显示下载表盘（`count` 来自回调）。
- **回调**：`(status, curShowIndex, count)`。
- **前置**：需支持 `JWBleFunctionEnum_MainInterfaceStyle`。
- **注意**：**必须先 `isGet = YES` 拿到 `count`**，再用 `count+1`/`count+2` 的约定下发。

#### 13.2.6 `jwUpdateResourceType:type:callBack:`

- **功能**：读写资源升级类型（决定后续资源 OTA 的目标）。
- **签名**：`+ (void)jwUpdateResourceType:(BOOL)isGet type:(JWUpdateResourceType)type callBack:(void (^)(JWBleCommunicationStatus status, JWUpdateResourceType type))callBack;`
- **参数**：`type` 为主显示资源 / 显示字库 / 主界面字库 / 自定义界面资源 / 表盘市场资源。
- **前置**：需支持 `JWBleFunctionEnum_DisplayFontUpgrade`(55) 等对应功能位。

#### 13.2.7 `jwDialyDataSyncWithSteps:andDistance:andCalory:`

- **功能**：把 App 统计的当日总步数/总距离/总卡路里同步给设备。
- **签名**：`+ (void)jwDialyDataSyncWithSteps:(UInt32)totalSteps andDistance:(UInt32)totalDistance andCalory:(UInt32)totalCalory;`
- **回调**：**无**（方法无回调参数）。
- **注意**：方法名中的 `Dialy` 为 `Daily` 的写法沿用（仅命名，不影响调用）；该接口无回调，结果请通过读取接口回读确认。

#### 13.2.8 `jwSyncSleep2Device:deep:light:startMinuteIndex:endMinuteIndex:callBack:`

- **功能**：把 App 计算的睡眠结果同步给设备。
- **签名**：`+ (void)jwSyncSleep2Device:(int)level deep:(int)deep light:(int)light startMinuteIndex:(int)startMinuteIndex endMinuteIndex:(int)endMinuteIndex callBack:(JWBleCommunicationCallBack)callBack;`
- **参数**：`level` 睡眠质量 1~5；`deep` / `light` 深睡/浅睡分钟；`startMinuteIndex` / `endMinuteIndex` 入睡/苏醒分钟下标。
- **前置**：需支持 `JWBleFunctionEnum_SyncSleep`(62)。

#### 13.2.9 `jwUpdateInterfaceColor:callBack:` / `jwGetDeviceStatusWithBlock:` / `jwGetMacAddressWithBlock:`

- `jwUpdateInterfaceColor:(int)colorIndex callBack:`：`colorIndex` 1~7，仅特殊固件支持。
- `jwGetDeviceStatusWithBlock:`：返回 `int status`，`0` 关闭 / `1` 匹配中 / `2` 准备就绪 / `3` 已连接。
- `jwGetMacAddressWithBlock:`：返回 `NSString *macAddr`，**无通信状态**（失败时无法区分，可能是 `nil` 或空串）。

#### 13.2.10 `jwCheckDeviceBusyWithCallBack:` / `jwCheckDeviceBusyStatusWithCallBack:`

- **功能**：查询设备是否繁忙（前者返回状态枚举，后者返回繁忙原因数组）。
- **签名**：
  - `+ (void)jwCheckDeviceBusyWithCallBack:(JwCheckDeviceBusyCallBack)callBack;` → `(status, JWBleBusyStateEnum)`（2 繁忙 / 3 空闲 / 4 超时）
  - `+ (void)jwCheckDeviceBusyStatusWithCallBack:(void (^)(JWBleCommunicationStatus status, NSArray *statusArr))callBack;` → 数组元素为 `JWBleBusyStatus`
- **前置**：设备已连接。
- **注意**：两个接口功能重叠、命名近似，建议只用其中一个并在文档中固定。

#### 13.2.11 `jwDeviceDataReset`

- **功能**：重置设备端历史数据下标。
- **签名**：`+ (void)jwDeviceDataReset;`
- **回调**：无。
- **注意**：⚠️ 头文件明确要求随后执行 `[JWBleDataAction jwRemoveDataTimeLessThan:]`，否则会出现数据重复。

#### 13.2.12 `jwSyncContacts:callBack:` / `jwSyncSOSContacts:callBack:`

- **功能**：同步通讯录 / SOS 联系人。
- **签名**：
  - `+ (void)jwSyncContacts:(NSArray<NSDictionary *> *)addressBooks callBack:(void (^)(JWBleCommunicationStatus status, int index))callBack;`（最多 15 条）
  - `+ (void)jwSyncSOSContacts:(NSArray<NSDictionary *> *)addressBooks callBack:(void (^)(JWBleCommunicationStatus status, int index))callBack;`（最多 5 条）
- **参数**：元素为 `@{@"name": …, @"phone": …}`；`name` ≤15 UTF8、`phone` ≤19 UTF8。
- **回调**：`(status, int index)`，`index` 为进度/结果下标；**传空数组表示清空，此时 `index` 为 100**。
- **前置**：通讯录需 `JWBleFunctionEnum_Address_Book`(48)，SOS 需 `SOS`(10002)。

#### 13.2.13 `jwAudioAction:open:callBack:` / `jwHeadphonePairing` / `jwCancelHeadphonePairing`

- `jwAudioAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`：音频开关读写。
- `jwHeadphonePairing` / `jwCancelHeadphonePairing`：无参数、**无回调**；结果经 `connectStateChangeCallBack(JWBleDeviceConnectStatus_HeadphoneDeviceStatusChanged)` 与 `JWBleManager.connectionModel.headphoneDeviceStatus` 获取（0 关机 / 1 配对中 / 2 就绪 / 3 已连接 / 4 被手机连接中）。

#### 13.2.14 `jwModifyDeviceName:` / `jwGetDeviceSNIDWithBlock:` / `jwGetDeviceCurrentBattery`

- `jwModifyDeviceName:(NSString *)name`：中文 ≤4 字或英文数字 ≤12 位；**无方法内回调**，成功后触发 `connectStateChangeCallBack(SyncSuccess)`（受 `infoFull` 约束）。
- `jwGetDeviceSNIDWithBlock:(void (^)(JWBleCommunicationStatus status, NSString *snID, NSData *oriContentData))callBack;`：获取设备 SN；`deviceSwitchChangeCallBack` 的原始数据需配合该接口解析。
- `jwGetDeviceCurrentBattery`：无参数、**无方法内回调**；电量经 `connectStateChangeCallBack(BatteryUpdate)` + `connectionModel.power` 获取。

#### 13.2.15 `jwShowText:content:` / `jwShowMotor:` / `jwTurnOffBracelet` / `jwReset` / `jwOpenOpus:`

- `jwShowText:(BOOL)show content:(NSString *)content;`：设备常驻显示文本（生产/调试用途）。
- `jwShowMotor:(BOOL)open;`：马达开关（生产/调试用途）。
- `jwTurnOffBracelet;` / `jwReset;`：关机 / 恢复出厂，**无回调**。
- `jwOpenOpus:(BOOL)open;`：Opus 通道开关；数据经 `JWBleManager.opusDataCallBack` 回传。

### 13.3 血压、血糖、健康评估与客户定制

#### 13.3.1 `jwBPV2Action:open:callBack:`

- **功能**：读写血压 2.0（连续血压）开关。
- **签名**：`+ (void)jwBPV2Action:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
- **前置**：需支持 `JWBleFunctionEnum_BloodPressureV2`(60)。

#### 13.3.2 `jwBPPrivateSet:h:l:callBack:` / `jwBPPrivateGetWithcallBack:`

- **功能**：设置 / 读取私人血压基准值。
- **签名**：
  - `+ (void)jwBPPrivateSet:(BOOL)open h:(NSInteger)h l:(NSInteger)l callBack:(void (^)(JWBleCommunicationStatus status))callBack;`
  - `+ (void)jwBPPrivateGetWithcallBack:(void (^)(JWBleCommunicationStatus status, BOOL open, NSInteger h, NSInteger l))callBack;`
- **前置**：需支持 `JWBleFunctionEnum_DevicePrivateBloodPressure`(10001)。

#### 13.3.3 `jwTemperatureSwitchAction:unit:compensate:monitor:callBack:`

- **功能**：读写温度单位、补偿开关、界面显示开关。
- **签名**：`+ (void)jwTemperatureSwitchAction:(BOOL)isGet unit:(BOOL)unit compensate:(BOOL)compensate monitor:(BOOL)monitor callBack:(void (^)(JWBleCommunicationStatus status, BOOL unit, BOOL compensate, BOOL monitor))callBack;`
- **参数**：`unit`：`YES` 摄氏度 / `NO` 华氏度。
- **回调**：`(status, unit, compensate, monitor)`。
- **注意**：⚠️ `isGet = YES` 时设备返回失败**不会回调**（问题 29）。

#### 13.3.4 `jwTestBloodGlucoseAction:callBack:` / `jwPrivateBloodGlucoseAction:high:low:callBack:` / `jwContinuousBloodGlucoseAction:open:callBack:`

- `jwTestBloodGlucoseAction:(BOOL)start callBack:(void (^)(JWBleCommunicationStatus status, JWBleTestBPStatus testStatus, int value))callBack;`
  血糖点测，复用血压的测试状态机；`value` 为血糖值，量纲与 `jwPrivateBloodGlucoseAction:` 一致（mmol/L ×10，例如 7.5 → 75）。
- `jwPrivateBloodGlucoseAction:(BOOL)isGet high:(int)high low:(int)low callBack:(void (^)(JWBleCommunicationStatus status, int high, int low))callBack;`
  私人血糖高低值；**传值需 ×10**（7.5 → 传 75）。
- `jwContinuousBloodGlucoseAction:(BOOL)isGet open:(BOOL)open callBack:(void (^)(JWBleCommunicationStatus status, BOOL open))callBack;`
  连续血糖开关；前置为 `JWBleFunctionEnum_BloodGlucose_Monitoring` 开关位。

#### 13.3.5 健康评估：尿酸 / 血脂 / 周期血糖

三个接口签名完全同构：

```objc
+ (void)jwUricAcidAction:(BOOL)get open:(BOOL)open privateValue:(int)privateValue privateRtc:(int)privateRtc
                callBack:(void (^)(JWBleCommunicationStatus status, BOOL open, int privateValue, int privateRtc))callBack;
+ (void)jwBloodFatAction:(BOOL)get open:(BOOL)open privateValue:(int)privateValue privateRtc:(int)privateRtc
               callBack:(...)callBack;                       // 同上
+ (void)jwBloodGlucoseCycleAction:(BOOL)get open:(BOOL)open privateValue:(int)privateValue privateRtc:(int)privateRtc
                        callBack:(...)callBack;              // 同上
```

- **参数**：`get` 读取/设置；`open` 与 `privateValue` / `privateRtc` **仅在 `get = NO` 时生效**；`privateRtc` 精确到秒（设备默认 0）。
- **回调**：`(status, open, privateValue, privateRtc)`。
- **前置**：分别需 `UricAcid`(10009) / `BloodFat`(10010) / `BloodGlucoseCycle`(10011)。
- **注意**：
  1. ⚠️ 头文件把三者的 `privateValue` 单位都写成“男 238~356 μmol/L / 女 178~297 μmol/L”，**血糖单位与此不符，属注释复制**（问题 19）；
  2. ⚠️ 错误分支会把 `JWBleTestBPStatus_TestField`(=3 → `YES`) 传给 `BOOL open`（问题 30）。

#### 13.3.6 连续监测：尿酸 / 血脂 / 压力

| API | 说明 |
| --- | --- |
| `+ jwUricAcidContinuesMonitoringAction:open:callBack:` | 尿酸连续监测开关；**读取失败不回调**（问题 29） |
| `+ jwUricAcidContinuesMonitoringPrivateAction:open:value:callBack:` | 私人值；`value` 为私人阈值 |
| `+ jwBloodFatContinuesMonitoringAction:open:callBack:` | 血脂连续监测开关 |
| `+ jwBloodFatContinuesMonitoringPrivateAction:open:value:callBack:` | 私人值 |
| `+ jwStressContinuesMonitoringAction:open:callBack:` | 压力连续监测开关 |
| `+ jwSyncStressContinuesMonitoringDataWithBlock:` | 拉取压力连续监测数据 → `(status, NSArray *resultData)` |

- **前置**：分别为 `UricAcidContinuesMonitoring` / `BloodFatContinuesMonitoring` / `Stress`(37) 开关位或功能位。
- **数据读取**：尿酸/血脂连续监测的历史数据用 `JWBleDataAction` 的 `jwGetUricAcidContinuousMonitoringDataByYYYYMMDDStr:` / `jwGetBloodFatContinuousMonitoringDataByYYYYMMDDStr:`。

#### 13.3.7 `jwCommonMeasurementAction:start:`

- **功能**：启动/停止通用点测（当前仅体脂）。
- **签名**：`+ (void)jwCommonMeasurementAction:(JWBleCommonMeasurementEnum)actionEnum start:(BOOL)start;`
- **参数**：`actionEnum` 目前仅 `JWBleCommonMeasurementEnum_BodyFat`（值 5）。
- **回调**：**无方法内回调**；数据经 `JWBleManager.bodyFatDataCallBack(NSDictionary *)`，结束状态经 `JWBleManager.endMeasurementStatusCallBack`。
- **前置**：需支持 `JWBleFunctionEnum_BodyFat`(10014)。

#### 13.3.8 消息通知与功能显示隐藏

| API | 说明与注意 |
| --- | --- |
| `+ jwUpdateNotiStatus:(JWBleNotiEnum)enumType open:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | 单个通知开关；“已下发”语义 |
| `+ jwOneTimeUpdateNotiStatus:(NSDictionary *)dic callBack:(JWBleCommunicationCallBack)callBack;` | 批量开关，`@{@(JWBleNotiEnum_Call):@(YES), …}` |
| `+ jwGetNotiStatusWithCallBack:(JWBleGetNoticeCallBack)callBack;` | 读取通知开关，返回字典 **key 为字符串**（`"Call"`、`"QQ"`…），等待设备回包 |
| `+ jwUpdateHideFunction:(JWBleFunctionEnum)enumType open:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | 隐藏/显示功能菜单；**仅 5 个功能有效**（秒表、查找手机、自动锁屏、双按键滑动、语音助手），非法枚举直接回调 `Faild` |
| `+ jwDeviceFunctionShowOrHiddenAction:setDic:callBack:` | ⚠️ **空实现：成功路径不下发指令也不回调**（问题 28），请勿使用 |

#### 13.3.9 健康功能显示开关

| API | 说明 |
| --- | --- |
| `+ jwGetHealthFunctionWithCallBack:` | 一次读取血糖/血脂/尿酸三个显示开关 → `(status, BOOL bloodGlucoseOpen, BOOL bloodFatOpen, BOOL uricAcidOpen)` |
| `+ jwGetHealthFunctionBloodGlucoseWithcallBack:` / `+ jwSetHealthFunctionBloodGlucoseOpen:withCallBack:` | 血糖显示开关读写 |
| `+ jwGetHealthFunctionBloodFatWithCallBack:` / `+ jwSetHealthFunctionBloodFatOpen:withCallBack:` | 血脂显示开关读写 |
| `+ jwGetHealthFunctionUricAcidWithCallBack:` / `+ jwSetHealthFunctionUricAcidOpen:withCallBack:` | 尿酸显示开关读写 |
| `+ jwSetHealthFunctionWithBloodGlucoseOpen:bloodFatOpen:uricAcidOpen:withCallBack:` | ✅ 2026-09-29 新增的**类方法**，推荐使用（同一签名的实例方法仍保留，仅用于兼容，因 `JWBleAction` 无单例而无法调用） |

- **语义**：注释说明“隐藏 = YES，显示 = NO”，与直觉相反，接入时务必注意。

#### 13.3.10 客户定制功能

| API | 说明 |
| --- | --- |
| `+ jwCustomCustomizationNotifyAction:open:callBack:` | 客户定制消息通知开关；需向 SDK 提供方申请对应包名 |
| `+ jwCustomSetPulseAction:minute:level:callBack:` | 脉冲：`minute` 1~15 分钟（默认 1）、`level` 1~7 档（默认 1）；数据经 `pulseDataCallBack` / `endOfPulseCallBack` |
| `+ jwCustomSleepAidAction:time:effectTime:level:callBack:` | 辅助睡眠：`time` ∈ {10,15,20,30}、`effectTime < time`、`level` 默认 1 |
| `+ jwCustomSleepAidAction_V2:mode:time:level:callBack:` | 辅助睡眠 V2，回调多返回 `int deviceStatus`（设备侧状态：`0` 可执行、`1` 设备忙，其余为设备未就绪） |
| `+ jwCustomHrvRmssdAction:timeInterval:callBack:` | HRV-RMSSD 开关与间隔：`0` 关闭 / 5 / 10 / 15 |

- **前置**：先 `jwCheckCustomFunctionStates:`（`SetPulse` / `SleepAid` / `Sauna`）。

### 13.4 附录：生产 / 产测专用接口（**不建议第三方使用**）

这些接口位于公开头文件 `JWBleAction.h` 的“生产测试方法”段落，供产线工具使用；第三方 App 不应调用。全部为“已下发”语义或无回调。

| 接口 | 用途 |
| --- | --- |
| `jwGeBATTERT_VOLTAGEWithBlock:` | 电池电压 |
| `jwGetPATCH_VERSIONWithBlock:` | PATCH 版本 |
| `jwGetGSENSOR_IDWithBlock:` | Gsensor ID |
| `jwGetHR_IC_IDWithBlock:` | 心率 IC ID（返回是否正确与 chipID） |
| `jwGetHALLWithBlock:` | HALL 状态（0 舱内 / 1 舱外） |
| `jwSendNotiWithType:andValue:` | 向设备推送测试通知 |
| `jwDefaultFunctionSettings:temperatureOpen:pressureOpen:sceneControl:alexa:light:`（及 `agingMode:`、`heatStressOpen:` 重载） | 默认功能开关下发（热应激使用反向关闭位） |
| `jwGetDefaultFunctionSettings:`（及 `WithAgingMode:`、`WithHeatStress:` 版本） | 默认功能开关读取 |
| `jwProduceEnd:` | 产测结束 |
| `jwReadConnectedRssi:` | 读取已连接设备 RSSI |
| `jwGetDeviceHeartRateLightLeakage:callBack:` | 心率漏光值 |
| `jwUpdateMacAddress:callBack:` / `jwUpdateSN:callBack:` / `jwUpdateSN_V2:callBack:` | 写入 MAC / SN |
| `jwSetTemperature:callBack:` / `jwGetTemperatureWithCallBack:` | 温度标定值写入 / 读取 |
| `jwGetHistoryAddress:` / `jwGetHistoryAddress_oriData:` | 读取历史数据地址 |
| `doLEBroadcast` / `enterDUT` | LE 广播 / 进入 DUT 模式 |
| `jwGetFactoryFunctionWithCallBack:` | 产测功能列表 |
| `jwUpdateTpModel:callBack:` / `jwGetTpInfoWithCallBack:` | TP 功能与信息 |
| `jwGetLicense:` / `jwSetLicense:key:mac:sn:callBack:` | License 读写 |
| `jwPIDAction:pid:callBack:` | PID 读写 |
| `jwGetOriSleepDataWithCallBack:` | 睡眠原始数据 |
| `jwGetDeviceTestResultWithCallBack:` | 设备测试结果 |
| `jwSteFirmwareBurningConfiguration:callBack:` / `jwGetFirmwareBurningConfigurationWithCallBack:` | 固件烧录配置 |
| `jwGetIcEuidWithCallBack:` | IC EUID |
| `jwDvtCheckAction:index:callBack:` | DVT 检查 |
| `jwGetResourceOTAStatusWithCallBack:` | 资源 OTA 状态 |
| `jwGetDebugShowWithCallBack:` | DebugShow |
| `jwSettingDeviceLaohuaWithCallBack:` | 进入老化模式 |
| `jwGetDeviceUV:callBack:` | 紫外线等级读取 |
