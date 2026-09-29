# JWBle SDK API Reference

> 🌐 Language: [中文](SDK_API文档.md) ｜ **English**

> Complete reference of the public API: methods, parameters, callbacks, models, enums and status codes.
> Public surface = `JWBle.h` umbrella header + the headers explicitly marked `ATTRIBUTES = (Public,)` in `JWBle.xcodeproj` + the headers inside the shipped `JWBle.framework/Headers`.
> Internal classes (`WristBand`, `BleCore`, `JWBleCommandHelp`, `JWBleCommunicationManager`, `JWBlePrivateAction`, FMDB, …) are **not** part of the public API and are not documented as callable interfaces.
> This reference is verified line-by-line against the shipped `JWBle.framework` (1.3.2) public headers; every **⚠️** note comes from the implementation and can be relied on.

---

## Chapter 0 — Conventions

### 0.1 Public surface

| Layer | Files | Notes |
| --- | --- | --- |
| Umbrella header | `JWBle.h` | `#import <JWBle/JWBle.h>` |
| Core classes | `JWBleManager.h`, `JWBleAction.h`, `JWBleDataAction.h` | init/state, device commands, data access |
| Extension classes | `JWBleOTAAction.h`, `JWBleCustomizeMainInterfaceAction.h`, `JWBleMyMainInterfaceAction.h` | OTA, watch face |
| Utility classes | `JWBlePublicHelp.h`, `JWLogAction.h`, `JWLogModel.h`, `JWBleDBModel.h` | unit conversion, logging, DB base class |
| Definitions | `JWBlePublicDefine.h`, `JWBlePublicModelDefine.h` | enums and block typedefs |
| Models | 15 classes (`JWBleDeviceModel.h`, …) | see Chapter 10 |

### 0.2 Statistics

| Item | Count |
| --- | --- |
| Public classes | 23 (8 functional/utility + 15 models) |
| Public methods | 238 |
| Block typedefs | 66 |
| `JWBleManager` callback properties | 29 |
| Public enums | 44 |
| Error codes | **45** (`JWBleErrorCode`) plus an error domain and NSError helpers (Chapter 12) |

Coverage: **Chapters 2-7** give the full template (including samples) for the core/flow APIs; **Chapter 13** applies the same template to the remaining public APIs; **13.4** lists production-test-only APIs separately.

> Public APIs added on 2026-09-29: `jwStartScanDeviceWithTimeout:callBack:` (scan with timeout), `jwGetDeviceCurrentBatteryWithCallBack:` (battery with callback) and the class method `jwSetHealthFunctionWithBloodGlucoseOpen:bloodFatOpen:uricAcidOpen:withCallBack:`.
>
> Unified error handling added on 2026-09-29: `JWBleErrorCode` (45 values), `JWBleErrorDomain`, `JWBleErrorMessageForCode()`, `JWBleMakeError()`, `JWBleMakeErrorWithUnderlyingError()`, four status-mapping functions, `JWBleManager.lastErrorCode` and `JWBleOTAAction.lastErrorCode / lastErrorMessage / lastUnderlyingError / lastError` (see Chapter 12).

### 0.3 How results are delivered

The SDK uses **no delegate protocol** and exposes **no notifications** (internal `NSNotification`s are implementation details). Results arrive through:

1. **In-method blocks** — most `JWBleAction` / `JWBleDataAction` methods;
2. **`JWBleManager` property blocks** — connection state, real-time streams, battery, etc.

> To find "where do I get the result of API X", first look at the `callBack` parameter of the method; for state/stream events look at the matching `JWBleManager` property. The full mapping is in Chapter 9.

---

## Chapter 1 — JWBleManager (initialisation and global state)

### 1.1 `+ (JWBleManager *)shareInstance`

Returns the SDK singleton. The first call applies the defaults (`isAutoShowPair = YES`, `checkUserBinding = YES`, `cacheLogCount = 30`) and registers callback forwarding.

```objc
+ (JWBleManager *)shareInstance;
```

Parameters: none. Returns: the singleton (never `nil`). Callback: none. Preconditions: none.
Notes: thread-safe (`dispatch_once`); call once during app start-up.

### 1.2 `- (void)setUpWithUid:(NSString *)uid`

SDK initialisation entry point; binds the SDK to an app-side account identifier used for device binding and auto-reconnect.

```objc
- (void)setUpWithUid:(NSString *)uid;
```

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `uid` | `NSString *` | Yes | App-side unique user id. The same account may connect from another phone; a different account cannot unless the device is unbound |

Returns: none. Callback: none (auto-reconnect, if started, reports through `connectStateChangeCallBack`).
Notes: the same `uid` is ignored; changing the `uid` cancels pending reconnects; when `isProduce == NO` the SDK attempts to reconnect from the local binding record.

### 1.3 `- (NSString *)sdkInfo` / `- (NSDictionary *)sdkInfoDic`

```objc
- (NSString *)sdkInfo;      // "Manufacturer Information: Wo-Smart Technologies\nPlatform: iOS\nVersion: 1.3.2"
- (NSDictionary *)sdkInfoDic;
```

Notes: the version comes from the internal constant `kJWBleSDKVersion`, kept in sync with `Info.plist` and `Version Description.md` (both `1.3.2`).

### 1.4 Properties

**State (read-only)**

| Property | Type | Notes |
| --- | --- | --- |
| `isConnected` | `BOOL` | `deviceConnectStatus != DisConnect`. Getter only — do not assign |
| `isConnecing` | `BOOL` | Connecting/being connected |
| `deviceConnectStatus` | `JWBleDeviceConnectStatus` | Latest connection status |
| `connectionModel` | `JWBleDeviceModel *` | Connected device (`nil` when disconnected) |
| `lastErrorCode` | `JWBleErrorCode` (read-only) | Reason of the most recent **connection-class** failure; cleared after a successful connect/bind/sync (added 2026-09-29) |

**Configuration**

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `showLog` | `BOOL` | `NO` | Verbose log; may contain MAC/UID, keep off in production |
| `saveLog` | `BOOL` | `NO` | Persist logs (requires `showLog`); read via `[JWLogModel getLog]` |
| `cacheLogCount` | `int` | `30` | Batch flush threshold |
| `isProduce` | `BOOL` | `NO` | Production-test mode: no auto-reconnect, no 60 s connect timeout |
| `isSNQR` | `BOOL` | `NO` | SN fast-scan mode |
| `isSupportAnonymousUse` | `BOOL` | `NO` | Skip login/binding |
| `isAutoShowPair` | `BOOL` | `YES` | Show the system pairing dialog |
| `checkUserBinding` | `BOOL` | `YES` | Validate the binding |
| `checkSpecialOtaShutdown` | `BOOL` | `NO` | Send the special OTA shutdown command after OTA end |

**Callbacks**: 29 block properties — see Chapter 9.

---

## Chapter 2 — JWBleAction: device management and user settings

### 2.1 `+ (void)jwStartScanDeviceWithCallBack:`

Starts scanning for bands.

```objc
+ (void)jwStartScanDeviceWithCallBack:(JWBleReceiveScanningDeviceCallBack)callBack;
```

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `callBack` | `JWBleReceiveScanningDeviceCallBack` | Yes | `void (^)(JWBleDeviceModel *deviceModel)`, once per newly discovered peripheral |

Callback: main thread, one call per peripheral. Preconditions: Bluetooth powered on.
Notes: no timeout and no auto-stop; each `CBPeripheral` is reported once and RSSI is not refreshed.

### 2.1.1 `+ (void)jwStartScanDeviceWithTimeout:callBack:` (added 2026-09-29)

Starts scanning and stops automatically after `timeout` seconds.

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `timeout` | `NSTimeInterval` | Yes | Seconds (10-30 recommended); `<= 0` behaves like 2.1 |
| `callBack` | `JWBleReceiveScanningDeviceCallBack` | Yes | Same as 2.1 |

Notes: after the timeout the SDK stops scanning and clears the scan callback; calling `jwStopScanDevice` earlier also cancels the timer.

### 2.2 `+ (void)jwStopScanDevice`

Stops scanning. No parameters, no callback. Safe to call repeatedly; clears the internal timer.

### 2.3 `+ (void)jwConnectDevice:`

```objc
+ (void)jwConnectDevice:(JWBleDeviceModel *)deviceModel;
```

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `deviceModel` | `JWBleDeviceModel *` | Yes | From the scan callback; you may also create one and set only `macAddress` |

Callback: `connectStateChangeCallBack` (`Connect` → `BondSuccess` → `SyncSuccess`).
Notes: a `nil` model while connected is rejected; a 60 s timeout (when `isProduce == NO`) reports `TimeOutDisconnect` and disconnects.

### 2.4 `+ (void)jwDisConnect`

Disconnects **and unbinds** (clears the local device-info and BP-config tables). Callback: `DisConnect`. No auto-reconnect afterwards.

### 2.5 `+ (void)jwDisConnectNotUnBond`

Disconnects but keeps the binding. Callback: `DisConnect`. Marks the disconnect as deliberate, so **no** auto-reconnect.

### 2.6 `+ (void)jwRemoveConnectRecord:`

```objc
+ (void)jwRemoveConnectRecord:(NSString *)deviceUUID;   // @"" removes it unconditionally
```

Removes the stored connection record (disables auto-reconnect). No callback.

### 2.7 `+ (void)sysDeviceFuncAction`

Requests a refresh of the device feature list. No callback: the result updates `connectionModel.functionData` / `functionDataV2`; watch for `SyncSuccess` or re-query `jwCheckFunctionStates:` afterwards.

### 2.8 User profile and goals

#### 2.8.1 `jwSynchronizePersonalInformation:isMan:height:weight:callBack:`

```objc
+ (void)jwSynchronizePersonalInformation:(int)age isMan:(BOOL)isMan
                                  height:(float)height weight:(float)weight
                                callBack:(JWBleCommunicationCallBack)callBack;
```

| Parameter | Type | Range | Notes |
| --- | --- | --- | --- |
| `age` | `int` | 0-127 | Years |
| `isMan` | `BOOL` | — | Male |
| `height` | `float` | 0.0-256 | cm, 0.5 cm resolution (sent as `height * 2`) |
| `weight` | `float` | 0.0-512 | kg, 0.5 kg resolution (sent as `weight * 2`) |
| `callBack` | `JWBleCommunicationCallBack` | — | `(JWBleCommunicationStatus)` |

Callback: **"sent" semantics** — `Success` is returned as soon as the command is queued. Also writes the age into the local BP config table.

#### 2.8.2 Goals

| API | Range | Callback |
| --- | --- | --- |
| `+ jwSetStepTargetAction:callBack:` | 1000-65000 (clamped) | `JWBleCommunicationCallBack` |
| `+ jwSetCalorieTargetAction:callBack:` | 100-9999 kcal (**not** clamped) | `JWBleCommunicationCallBack` |
| `+ jwSetSleepTargetAction:callBack:` | 90-900 minutes (clamped) | `JWBleCommunicationCallBack` |

All three use "sent" semantics.

### 2.9 Find device and remote camera

| Feature | Signature | Callback | Notes |
| --- | --- | --- | --- |
| Find band | `+ (void)jwFindDeviceWithCallBack:(JWBleCommunicationCallBack)callBack;` | `JWBleCommunicationCallBack` | "Sent" semantics |
| Remote camera | `+ (void)jwRemotePhotography:(BOOL)open callBack:(JWBleCommunicationCallBack)callBack;` | `JWBleCommunicationCallBack` | Requires `JWBleFunctionEnum_RemotePhotography` |
| Shutter event | no API — device triggered | `JWBleManager.remotePhotographyCallBack` → `JWBleRemotePhotographyStatus_TakePhoto` | Enable remote camera first |

### 2.10 Capability query APIs (prefer these over hard-coded models)

#### 2.10.1 `+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:`

```objc
+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:(JWBleFunctionEnum)functionEnum;
```

Returns synchronously:

| Value | Meaning |
| --- | --- |
| `JWBleFunctionStateEnum_NotSupport` (`0 \| 2` = **2**) | Not supported |
| `JWBleFunctionStateEnum_Close` (1) | Supported but disabled |
| `JWBleFunctionStateEnum_Open` (3) | Supported and enabled |

Preconditions: **the device must have completed sync** (`SyncSuccess`); before that everything reports "not supported". This call reads cached data only and never talks to the device.

Judgement rules:

- support: `!= JWBleFunctionStateEnum_NotSupport`
- enabled: `== JWBleFunctionStateEnum_Open`
- **never** test `== 0` or `== Close` — bitmap-mode devices never return `Close`.

**`functionData` has two encodings** (`JWBleAction.m` lines 854-960):

| Branch | Condition | Decoding | Possible results |
| --- | --- | --- | --- |
| Bitmap | `functionData.length <= 8` | Built-in `switch` mapping to `(byteIndex, bitIndex)`, `(byte >> bit) & 0x01` | **Only `Open`(3) or `NotSupport`(2)** |
| Byte index | `functionData.length > 8` | `NSMakeRange(functionEnum, 1)` — the enum value *is* the byte index | `0`/`2` → NotSupport; `1` → Close; else → Open |

Consequences: the bitmap branch is a 58-entry whitelist (all `10001-10016` V2 features return "not supported" there); in the byte-index branch the feature number must be smaller than `functionData.length`; and inserting new members into `JWBleFunctionEnum` shifts every subsequent feature.

#### 2.10.2 Other capability queries

| API | Return value | Backing data |
| --- | --- | --- |
| `+ (int)jwCheckControlSwitchStates:(JWBleDeviceSwitchFunctionEnum)functionEnum;` | Current value; **`-1` means unsupported** | `connectionModel.deviceSwitchData` |
| `+ (JWBleHideFunctionStatesEnum)jwCheckHideFunctionStates:(JWBleFunctionEnum)functionEnum;` | `NotSupport` / `Show` / `Hidden`; only valid for `StopwatchTiming`, `FindPhone`, `AutomaticLockScreen`, `TwoButtonSliding`, `VoiceAssistant` | `connectionModel.hideFunctionMenu` |
| `+ (JWBleFunctionStatesEnum)jwCheckCustomFunctionStates:(JWBleCustomFunctionEnum)functionEnum;` | Custom feature support (pulse / sleep aid / sauna) | `connectionModel.customizedFunctionDic` |

---

## Chapter 3 — JWBleAction: device settings

### 3.1 Time

```objc
+ (void)jwSetTimeWithYear:(UInt8)year andMonth:(UInt8)month andDay:(UInt8)day
                 andHour:(UInt8)hour andMinute:(UInt8)minute andSecond:(UInt8)second
                 callBack:(void (^)(JWBleCommunicationStatus status))callBack;
```

`year` (**offset from 2000** — pass `26` for 2026, range 0-63), `month`, `day`, `hour`, `minute`, `second`.
Notes: `JWBleWeatherModel` requires the weather date to match the device date, so set the time before syncing weather.

### 3.2 `+ (void)jwCommonFunction:functionsState:callBack:`

Reads/writes generic switches (currently metric/imperial and 12/24-hour).

```objc
+ (void)jwCommonFunction:(JWBleFunctionEnum)functionEnum
           functionsState:(JWBleCommonFunctionsStatus)functionsState
                 callBack:(JWBleCommonFuctionReceiveCallBack)callBack;
```

| Parameter | Notes |
| --- | --- |
| `functionEnum` | `JWBleFunctionEnum_Unit` (open = metric), `JWBleFunctionEnum_TimeSystem` (open = 12-hour) |
| `functionsState` | `_Read` / `_Open` / `_Close` |
| `callBack` | `(JWBleCommunicationStatus, JWBleCommonFunctionsStatus)` |

### 3.3 Language

`+ (void)jwLanguageAction:(BOOL)isGet languageEnum:(JWBleLanguageEnum)languageEnum callBack:(JWBleLanguageCallBack)callBack;`
Requires `JWBleFunctionEnum_MoreLanguage`; 18 languages (see Chapter 11).

### 3.4 Screen

| Feature | Signature | Parameters | Callback |
| --- | --- | --- | --- |
| Bright screen duration | `+ jwbBrightScreenDuration:timeLength:callBack:` | `timeLength` 3-30 s (some firmwares support up to 60 — use the device-reported value) | `(status, timeLength, defalut)` |
| Brightness | `+ jwbBrightnessAdjustment:value:callBack:` | `value` 20-100 | in-method block |
| Wrist raise | `+ jwTurnWristCreenActionWithIsGet:open:sensitivity:startMinute:endMinute:callBack:` | time window in minutes | `JWBleTurnWristCreenActionCallBack` |
| Auto lock screen | `+ jwAutomaticLockScreenAction:open:callBack:` | — | in-method block |
| Interface colour | `+ jwUpdateInterfaceColor:callBack:` | `colorIndex` 1-7, special firmware only | in-method block |

Notes: auto lock screen is a hidden-menu feature (query with `jwCheckHideFunctionStates:`); the `jwb` prefix is legacy naming.

### 3.5 Do not disturb

`+ (void)jwNotDisturbAction:(BOOL)isGet model:(JWNotDisturbModel *)model callBack:(JWBleNotDisturbActionCallBack)callBack;`
Model: `open`, `enumType` (all day / not worn / scheduled), `startHour`, `startMinute`, `endHour`, `endMinute`.

### 3.6 Sedentary reminder

`+ (void)jwSedentaryReminder:(BOOL)isGet open:(BOOL)open startH:(int)startH endH:(int)endH span:(int)span threshold:(int)threshold dayFlagArr:(NSArray *)dayFlagArr callBack:(JWBleSedentaryReminderActionCallBack)callBack;`

| Parameter | Range |
| --- | --- |
| `startH` / `endH` | 0-23 |
| `span` | 30-240 minutes |
| `threshold` | 0-65535 steps |
| `dayFlagArr` | 7 elements (Monday first), true/false |

### 3.7 Alarms

| API | Notes |
| --- | --- |
| `+ jwAlarmAction:alarmArr:callBack:` | Legacy, full-replacement: pass only the enabled alarms |
| `+ jwAlarmV2Action:alarmModel:callBack:` | Alarm 2.0, single alarm; `month` and `day` both 0 deletes it |

Callback: `JWBleAlarmActionCallBack` → `(status, NSArray<JWBleAlarmClockModel *> *)`. The two APIs must not be mixed; reads wait for the device reply.

### 3.8 Notifications

| Feature | Signature |
| --- | --- |
| Single switch | `+ jwUpdateNotiStatus:open:callBack:` |
| Batch switches | `+ jwOneTimeUpdateNotiStatus:callBack:` — `@{@(JWBleNotiEnum_Call):@(YES), …}` |
| Read switches | `+ jwGetNotiStatusWithCallBack:` — returns a dictionary whose **keys are strings** (`"Call"`, `"QQ"`, `"WeChat"`…) |
| Hidden menu switch | `+ jwUpdateHideFunction:open:callBack:` — only 5 features, invalid enums immediately report `Faild`; **calls back `Success` after a successful write since 2026-09-29** |
| Batch show/hide | `+ jwDeviceFunctionShowOrHiddenAction:setDic:callBack:` — `isGet = YES` returns `@{@"hideFunctionMenu": NSData}`; writing reports `Faild` (the key-to-bit mapping is undefined) — use `jwUpdateHideFunction:` instead |

### 3.9 Countdown / find phone

| Feature | Signature | Notes |
| --- | --- | --- |
| Countdown | `+ jwCountDownAction:isGet:model:callBack:` | `JWCountDownModel` (`seconds` 1-86400, `optionEnum`, `open`); when reading a running countdown, `seconds` is the remaining time |
| Stop countdown callback | `+ jwStopCountDownCallBack;` | Clears the internal callback only; to stop the timer use `jwCountDownAction:` with `JWCountDownOptionEnum_Stop` |
| Find phone | no API — device triggered | `JWBleManager.findPhoneCallBack` / `findPhoneV2CallBack(BOOL start)` |

### 3.10 Temperature

| Feature | Signature | Parameters | Callback |
| --- | --- | --- | --- |
| Temperature switches | `+ jwTemperatureSwitchAction:unit:compensate:monitor:callBack:` | `unit` YES = Celsius, NO = Fahrenheit | `(status, unit, compensate, monitor)` |
| Fever reminder | `+ jwTemperatureReminderAction:isGet:value:callBack:` | 38.0-41.9 C, `0` disables | `(status, value)` |
| Set temperature | `+ jwSetTemperature:callBack:` | `365` = 36.5 C | `(status, success)` |
| Read calibration | `+ jwGetTemperatureWithCallBack:` | — | `(status, already, frequency, temperatureInital)` |

### 3.11 Other device settings

| Feature | API | Parameters | Callback |
| --- | --- | --- | --- |
| Blood pressure 2.0 | `+ jwBPV2Action:open:callBack:` | `isGet`, `open` | `(status, open)` |
| Private BP | `+ jwBPPrivateSet:h:l:callBack:` / `+ jwBPPrivateGetWithcallBack:` | systolic/diastolic | `(status)` / `(status, open, h, l)` |
| BP auto measurement | `+ jwBPAutomaticDetectionAction_V3:open:timeSpan:callBack:` | 5/30/60/120 min | `JWBleAutomaticDetectionActionCallBack` |
| HR auto measurement | `+ jwHrAutomaticDetectionAction:open:timeSpan:callBack:` | same | `JWBleAutomaticDetectionActionCallBack` |
| HR auto types | `+ jwGetHRAutomaticDetectionType:` | — | `(status, NSDictionary *)` keys `"0"/"5"/"30"/"60"/"120"` |
| HR upper limit | `+ jwHighHeartRateReminderAction:open:maxValue:callBack:` | 40-220 | `(status, open, maxValue)` |
| Low SpO2 reminder | `+ jwLowOxygenReminderAction:open:callBack:` | — | `(status, open)` |
| Continuous SpO2 | `+ jwContinuousBloodOxygenAction:open:callBack:` | — | `(status, open)` |
| All-day sleep | `+ jwSleepAllDayAction:open:callBack:` | — | `(status, open)` |
| Dial date format | `+ jwDialDateFormatAction:open:callBack:` | `false` = MM-DD, `true` = DD-MM | `(status, open)` |
| Drink water | `+ jwDrinkWaterReminderAction:open:startHour:startMinute:endHour:endMinute:span:callBack:` | `span` 30-480 min | full config tuple |
| Female health | `+ jwFemaleAction:mode:cycleDay:menstrualDay:year:month:day:callBack:` | set-only (no read) | `(status)` |
| Weather | `+ jwWeatherAction:callBack:` | `JWBleWeatherModel` (current + up to 6 forecast entries) | `(status)` |
| Audio | `+ jwAudioAction:open:callBack:` | — | `(status, open)` |
| User preferences | `+ jwUserPreferencesAction:values:callBack:` | `@[@{@"type":…, @"value":…}]` | `(status, values)` |
| Power off / factory reset | `+ jwTurnOffBracelet;` / `+ jwReset;` | — | none |
| Daily totals | `+ jwDialyDataSyncWithSteps:andDistance:andCalory:` | `UInt32` totals | none |
| Sync sleep to device | `+ jwSyncSleep2Device:deep:light:startMinuteIndex:endMinuteIndex:callBack:` | level 1-5 | `JWBleCommunicationCallBack` |
| Contacts / SOS | `+ jwSyncContacts:callBack:` (max 15) / `+ jwSyncSOSContacts:callBack:` (max 5) | `@{@"name":…, @"phone":…}` | `(status, index)`, `index == 100` when clearing with an empty array |
| Reset data index | `+ jwDeviceDataReset;` | — | none (pair with `jwRemoveDataTimeLessThan:`) |
| Current battery | `+ jwGetDeviceCurrentBattery;` | — | **no in-method callback**; read `connectionModel.power` on `BatteryUpdate` |
| Current battery (added 2026-09-29) | `+ jwGetDeviceCurrentBatteryWithCallBack:(JWBleGetPowerCallBack)callBack;` | — | `JWBleManager.getPowerCallBack` → `(status, power, charging)` |
| Headset pairing | `+ jwHeadphonePairing;` / `+ jwCancelHeadphonePairing;` | — | via `HeadphoneDeviceStatusChanged` + `connectionModel.headphoneDeviceStatus` |
| Rename device | `+ jwModifyDeviceName:(NSString *)name;` | Chinese <= 4 chars / 12 alphanumerics | none; success triggers `SyncSuccess` |
| Main interface style | `+ jwMainInterfaceAction:willShowIndex:callBack:` | `count+1` custom dial, `count+2` downloaded dial | `(status, curShowIndex, count)` |
| Resource upgrade type | `+ jwUpdateResourceType:type:callBack:` | `JWUpdateResourceType` | `(status, type)` |

---

## Chapter 4 — JWBleAction: health monitoring and real-time data

### 4.1 Manual spot measurement

#### `+ (void)jwTestHRAction:callBack:`

```objc
+ (void)jwTestHRAction:(BOOL)start callBack:(JWBleTestHRCallBack)callBack;
```

| Parameter | Type | Notes |
| --- | --- | --- |
| `start` | `BOOL` | `YES` starts, `NO` stops |
| `callBack` | `JWBleTestHRCallBack` | `(status, JWBleTestHRStatus testStatus, int hrValue)` |

The callback fires several times (`TestStart` → `DeviceResponse` → `TestEnd`); the value is delivered on `TestEnd`. Preconditions: connected, `JWBleFunctionEnum_HR` supported, device not busy. During measurement the device is busy and other commands may return `Busy`.

### 4.2 BP / temperature / SpO2 / blood glucose

| Feature | Signature | Parameters | Callback |
| --- | --- | --- | --- |
| Manual BP | `+ jwTestBPAction:callBack:` | `start` | `(status, JWBleTestBPStatus, int high, int low)` |
| Temperature monitoring | `+ jwTestTemperatureAction:callBack:` | `actionKey`: 0 off, 1 on, 2 query availability (depends on continuous HR) | `(status, JWBleTestTemperatureStatus)` |
| SpO2 | `+ jwTestOxygen:callBack:` | `JWTestOxygenRequestType` (`End`/`Start`/`Check`) | `(status, JWTestOxygenResultType, JWOxygenModel *)` |
| Blood glucose | `+ jwTestBloodGlucoseAction:callBack:` | `start` | `(status, JWBleTestBPStatus testStatus, int value)` |
| Private blood glucose | `+ jwPrivateBloodGlucoseAction:high:low:callBack:` | values **x10** (7.5 → 75) | `(status, high, low)` |
| Continuous glucose | `+ jwContinuousBloodGlucoseAction:open:callBack:` | — | `(status, open)` |
| Body fat | `+ jwCommonMeasurementAction:start:` | only `JWBleCommonMeasurementEnum_BodyFat` (5) | **no in-method callback**; data via `bodyFatDataCallBack`, completion via `endMeasurementStatusCallBack` |

Notes: spot measurements are asynchronous and multi-shot — always drive your UI from `testStatus`; the device is busy meanwhile.

### 4.3 ECG / ECG Belt

| Feature | Signature | Callback |
| --- | --- | --- |
| ECG switch | `+ jwECGAction:callBack:` | `ecgStatus`: 0 normal, 1 start, 2 end, 3 interrupt, 4 interrupt 10 s after end, 999 data collection |
| Belt switch | `+ jwBeltAction:callBack:` | same semantics as `ecgStatus` |
| ECG waveform | no API | `JWBleManager.ecgDataCallBack(originalSignals, filterSignals)` |
| ECG raw | no API | `JWBleManager.ecgOriDataCallBack(NSData *)` |
| ECG metrics | no API | `JWBleManager.ecgValueDataCallBack(bpm, qt, hrv, rri, progress)` |
| Belt waveform / metrics | no API | `JWBleManager.beltDataCallBack` / `beltValueDataCallBack` |

Preconditions: `JWBleFunctionEnum_ECG` / `JWBleFunctionEnum_Belt` supported.

### 4.4 Health assessments (uric acid / blood fat / glucose cycle / stress)

| Feature | Signature | Parameters | Callback |
| --- | --- | --- | --- |
| Uric acid | `+ jwUricAcidAction:open:privateValue:privateRtc:callBack:` | `open`/`privateValue`/`privateRtc` take effect only when `get == NO` | `(status, open, privateValue, privateRtc)` |
| Blood fat | `+ jwBloodFatAction:open:privateValue:privateRtc:callBack:` | same | same |
| Glucose cycle | `+ jwBloodGlucoseCycleAction:open:privateValue:privateRtc:callBack:` | same | same |
| Uric acid continuous | `+ jwUricAcidContinuesMonitoringAction:open:callBack:` | `get`, `open` | `(status, open)` |
| Uric acid private value | `+ jwUricAcidContinuesMonitoringPrivateAction:open:value:callBack:` | `value` | `(status, open, value)` |
| Blood fat continuous | `+ jwBloodFatContinuesMonitoringAction:open:callBack:` | `get`, `open` | `(status, open)` |
| Blood fat private value | `+ jwBloodFatContinuesMonitoringPrivateAction:open:value:callBack:` | `value` | `(status, open, value)` |
| Stress continuous | `+ jwStressContinuesMonitoringAction:open:callBack:` | `get`, `open` | `(status, open)` |
| Stress data | `+ jwSyncStressContinuesMonitoringDataWithBlock:` | — | `(status, NSArray *)` |

Async status callbacks: `JWBleManager.uricAcidStatusCallBack`, `bloodFatStatusCallBack`, `bloodGlucoseCycleStatusCallBack` — all `(BOOL open, int privateValue, int privateRtc)`.

Notes: `privateValue` units differ per feature (`mmol/L x10` for glucose, `μmol/L` for uric acid/blood fat); the header comments were corrected on 2026-09-29. Since 2026-09-29 error branches pass `NO` instead of a test-status value.

### 4.5 Real-time data (`JWBleManager` property blocks)

| Feature | Trigger | Callback |
| --- | --- | --- |
| Real-time HR | `+ jwRealTimeHeartRateAction:callBack:` | `realTimeHeartRateCallBack(NSInteger hrValue)`; `-999` = stopped by the device |
| Motion HR | `+ jwRealTimeHeartRateAction:sprotType:callBack:` | same; requires `JWBleFunctionEnum_APP_MOTION_HR_V2` |
| Real-time temperature | `+ jwTestTemperatureAction:` (actionKey 1) | `realTimeTemperatureCallBack(value, gradient, wearing, compensation)`; `-999` = stopped |
| Real-time steps | `+ jwGetRealTimeStepWithCallback:` | in-method block |
| Pulse | `+ jwCustomSetPulseAction:minute:level:callBack:` | `pulseDataCallBack(status, length, timestamp, value)`; `status`: 0 end, 1 start, 2 receiving |
| Pulse end | — | `endOfPulseCallBack(int value)` |
| Sauna | custom feature | `saunaDataCallBack(status, length, time, hr, tem, label, move)` |
| HR movement | — | `hrMovementDataCallBack(time, hr, tem, label, move)` |
| Body fat | `+ jwCommonMeasurementAction:start:` | `bodyFatDataCallBack(NSDictionary *)` |
| Device switch change | — | `deviceSwitchChangeCallBack(NSData *)` |
| Measurement finished | any common measurement | `endMeasurementStatusCallBack(JWBleEndMeasurementStatusType)` |
| Opus | `+ jwOpenOpus:` | `opusDataCallBack(NSData *)` |
| LANGCO translation | custom feature | `langCoTranslationCallBack(int value)` |

---

## Chapter 5 — JWBleAction: multi-sport (app controls the device)

Requires `JWBleFunctionEnum_APPControlMotion` (35).

### 5.1 Query the current motion state

```objc
+ (void)jwQueryDeviceMotionStatus:(JWBleDeviceMotionControlCallBack)callBack;
```

Callback: `(JWBleCommunicationStatus status, JWBleMotionStatusModel *statusModel)`; **`statusModel` is `nil` on communication failure, timeout or disconnect**.

### 5.2 Query supported sport types

```objc
+ (void)jwQuerySupportedDeviceMotionTypes:(JWBleDeviceMotionTypeListCallBack)callBack;
```

Callback: `(status, NSArray<NSNumber *> *motionTypes)` with `JWBleDeviceMotionEnum` values; **an empty array (with `Success`) means multi-sport is unsupported**.

### 5.3 Start / pause / resume / stop

| Action | Signature |
| --- | --- |
| Start | `+ (void)jwStartDeviceMotion:(JWBleDeviceMotionEnum)motionType callBack:(JWBleDeviceMotionControlCallBack)callBack;` |
| Pause | `+ (void)jwPauseDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` |
| Resume | `+ (void)jwResumeDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` |
| Stop | `+ (void)jwStopDeviceMotion:(JWBleDeviceMotionControlCallBack)callBack;` |

Notes: the device response is authoritative — sending a command does not change SDK state; `result` of `0x00`/`0x01` is success, `0x02`-`0x04` are protocol failures; **a 6 s timeout** resolves the request once as a communication failure; **only one pending request at a time** — call serially.

### 5.4 Continuous status and realtime data

| Callback | Data |
| --- | --- |
| `JWBleManager.deviceMotionStatusChangeCallBack` | `JWBleMotionStatusModel` (device-initiated status change) |
| `JWBleManager.deviceMotionRealtimeDataCallBack` | `JWBleMotionRealtimeDataModel` (only while Running/Paused) |

---

## Chapter 6 — JWBleDataAction (history sync and read)

### 6.1 `+ (void)jwSyncDataWithCallBack:`

Pulls history from the device into the local database. **Prerequisite for every history read API.**

```objc
+ (void)jwSyncDataWithCallBack:(JWBleSyncCallBack)callBack;   // (status, JWBleSyncStateEnum)
```

Callback order (from the implementation):

1. not connected → `(Faild, Interrupt)`;
2. device in DFU mode → `(IsDFUModel, Interrupt)`;
3. normal start → `(Success, Start)`;
4. completion based on the device's status field: `1` → `(Success, Complete)` (after optional data calibration), `2` → `(Faild, InconsistentTotals)`, anything else → `(Faild, Interrupt)`.

Preconditions: connected, not in DFU. Notes: long-running, so use `synchronousDataProgressCallBack`; the device is busy meanwhile; repeated syncs may create duplicate rows — clean up with `jwRemoveDataTimeLessThan:` / `jwFixDBData`.

### 6.2 Read APIs (local database only)

Common rules: every getter reads the **local SQLite database synchronously**; data comes from the last `jwSyncDataWithCallBack:`; date parameters use `yyyyMMdd`; each `ByYYYYMMDD` variant has a `ByStartT:endT:` timestamp sibling; the same timestamp returns only the first record; **no rows are deleted** and `time <= 0` records are skipped (since 2026-09-29).

| Data type | Method (date) | Timestamp variant | Result shape |
| --- | --- | --- | --- |
| Steps (15-min) | `+ jwGetStepDataByYYYYMMDDStr:callBack:` | `+ jwGetStepDataByStartT:endT:callBack:` | always 96 entries `@{offset, steps, calory, distance}` (all `NSNumber`) |
| Daily step total | `+ jwGetDayStepTotalValue:callback:` | — | `(status, step, dis, calories)` |
| Set daily steps | `+ jwSetTodayStepData:arr:` | — | none (write API) |
| Sleep (per minute) | `+ jwGetSleepDataByYYYYMMDDStr:callBack:` | — | `@{minute, status (1 light / 2 deep / 3 awake), yyyyMMdd}` |
| Filtered sleep | `+ jwGetFilterSleepDataByYYYYMMDDStr:callBack:` | — | `DEEP_HOUR`, `LIGHT_HOUR`, `SLEEP_LEVEL`, `SLEEP_TIME`, `SLE_HOUR`, `SLE_MINUTE`, `WAKE_TIME`, `WakeUpTime`, `oneSleLine` |
| Sleep quality (local) | `+ (int)jwSleepQualityCalculation:deepMinute:totalMinute:wakeUpCount:` | — | 0-5 |
| Sleep raw parsing | `+ (NSArray *)jwTestSleepOriData:(NSString *)oriData;` | — | array |
| Heart rate | `+ jwGetHRDataByYYYYMMDDStr:callBack:` | `+ jwGetHRDataByStartT:endT:callBack:` | `@{time, value}`, ascending |
| HR raw | `+ jwGetHRRawDataWithCallBack:` | — | all local HR rows |
| Blood pressure | `+ jwGetBpDataByYYYYMMDDStr:callBack:` | `+ jwGetBpDataByStartT:endT:callBack:` | `@{time, high, low}` |
| Temperature | `+ jwGetTemperatureDataByYYYYMMDDStr:callBack:` | `+ jwGetTemperatureDataByStartT:endT:callBack:` | `@{time, value, wearingState, compensationStatus}` |
| Temperature calibration | `+ (float)jwTemperatureCalibration:(float)value;` | — | calibrated value |
| SpO2 | `+ jwGetOxygenDataByYYYYDDStr:callBack:` | `+ jwGetOxygenDataByStartT:endT:callBack:` | `JWOxygenModel` array |
| HRV | `+ jwGetHrvDataByYYYYDDStr:callBack:` | `+ jwGetHrvDataByStartT:endT:callBack:` | `@{hrvValue, time}` (fixed 2026-09-29) |
| HRV-RMSSD | `+ jwGetHrvRmssdDataByYYYYDDStr:callBack:` | `+ jwGetHrvRmssdDataByStartT:endT:callBack:` | `@{time, value}` |
| Blood glucose | `+ jwGetBloodGlucoseDataByYYYYDDStr:callBack:` | `+ jwGetBloodGlucoseDataByStartT:endT:callBack:` | `@{value, time}` |
| Pulse | `+ jwGetPulseDataByYYYYDDStr:callBack:` | `+ jwGetPulseDataByStartT:endT:callBack:` | `@{value, time}` |
| Sauna | `+ jwGetSaunaDataByYYYYDDStr:callBack:` | `+ jwGetSaunaDataByStartT:endT:callBack:` | `@{time, hr, tem, label, move}` |
| HR movement | `+ jwGetHrMovementDataByYYYYDDStr:callBack:` | `+ jwGetHrMovementDataByStartT:endT:callBack:` | `@{time, hr, tem, label, move}` |
| UV | `+ jwGetUVDataByYYYYDDStr:callBack:` | `+ jwGetUVDataByStartT:endT:callBack:` | `@{time, value, vd, skin, skinCancer}` |
| Stress | `+ jwGetStressDataByYYYYDDStr:callBack:` | `+ jwGetStressDataByStartT:endT:callBack:` | `@{time, value}` |
| Wearing state | `+ jwGetWearStatusDataByYYYYDDStr:callBack:` | `+ jwGetWearStatusDataByStartT:endT:callBack:` | `@{time, wearingState}` |
| Uric acid (cycle) | `+ jwGetUricAcidCycleDataByYYYYDDStr:deviceMac:callBack:` | — | `cycleStartTime`, `cycleStartActionTime`, `valueTime`, `cycleEndTime`, `dayStatusList`, `evaluationResult` |
| Uric acid (continuous) | `+ jwGetUricAcidContinuousMonitoringDataByYYYYMMDDStr:callBack:` | — | `@{time, value}` |
| Blood fat (cycle) | `+ jwGetBloodFatCycleDataByYYYYDDStr:deviceMac:callBack:` | — | same cycle shape |
| Blood fat (continuous) | `+ jwGetBloodFatContinuousMonitoringDataByYYYYMMDDStr:callBack:` | — | `@{time, value}` |
| Glucose cycle | `+ jwGetBloodGlucoseCycleDataByYYYYDDStr:deviceMac:callBack:` | — | same cycle shape |
| Body fat | `+ jwGetBodyFatByYYYYDDStr:deviceMac:callBack:` | — | see `JWBleBodyFatDataCallBack` in Chapter 10 |
| Micro physical exam | `+ jwGetMicroPhysicalExaminationByYYYYDDStr:callBack:` | — | `time`, `hrValue`, `oxygenValue`, `stressValue`, `temperatureValue`, `skinTemperatureValue`, `bloodVesselElasticityValue`, `cardiovascularValue` |
| Sport records | `+ jwGetMotionDataByYYYYMMDDStr:callBack:` | — | `pk`, `year`, `month`, `day`, `minuteIndex`, `seconds`, `motionType`, `sportsMinute`, `sportsSeconds`, `pauseCount`, `pauseMinute`, `pauseSeconds`, `stepCount`, `distance`, `uid`, `calories`, `maxHr`, `minHr`, `avgHr` |
| Delete one sport record | `+ (void)jwRemoveMotionDataWithPK:(int)pk;` | — | none |

### 6.3 Data management

| API | Notes |
| --- | --- |
| `+ (void)jwRemoveDataTimeLessThan:(NSInteger)t;` | Deletes everything older than `t` |
| `+ (void)jwRemoveDataTimeLessThan:(NSInteger)t dataType:(JWDeleteDataType)dataType;` | Same, per data type |
| `+ (void)jwRemoveDataTime:(NSInteger)t dataType:(JWDeleteDataType)dataType;` | Deletes the record at `t` |
| `+ (void)jwFixDBData;` | Repairs duplicates after `jwDeviceDataReset` |

---

## Chapter 7 — OTA and watch face

### 7.1 `JWBleOTAAction`

Singleton: `+ (JWBleOTAAction *)shareInstance`.

**Pre-flight check (`JWBleAction`)**

```objc
+ (void)jwCheckOTAEnableWithCallBack:(void (^)(JWBleCommunicationStatus status, int deviceStatus))callBack;
```

| `deviceStatus` | Meaning |
| --- | --- |
| `0` | Silent upgrade can start |
| `1` | Device busy, warn the user |
| `-1` | Unknown/failure (the SDK passes `-1` when the read fails) |

**Start the upgrade**

| Signature | Parameters |
| --- | --- |
| `- startOTAV2ForWithData:prefersUpgradeUsingOTAMode:andPeripheral:callBack:` | firmware data, OTA-mode preference, explicit peripheral |
| `- startOTAV2ForWithData:prefersUpgradeUsingOTAMode:callBack:` | uses the connected device |
| `- startOTAV2ForWithData:prefersUpgradeUsingOTAMode:fsblMode:versionString:callBack:` | optional FSBL version check; matching version → `VersionConsistent` and the upgrade is skipped |
| `- cancelAllPeripheralConnections` | cancels all peripheral connections |

Callback: `JWBleDFUCallBack` → `(NSInteger didSend, NSInteger totalLength, JWBleDeviceDFUStatus deviceDFUStatus)`.

**Failure reason (added 2026-09-29, all read-only)**

| Member | Type | Notes |
| --- | --- | --- |
| `lastErrorCode` | `JWBleErrorCode` | Error code of the most recent failure; `JWBleErrorCodeNone` when the upgrade succeeded, was skipped (version consistent) or has not started |
| `lastErrorMessage` | `NSString *` (nullable) | Failure description including the underlying error |
| `lastUnderlyingError` | `NSError *` (nullable) | Underlying error, usually from `RTKOTAErrorDomain` |
| `- (NSError *)lastError` | `NSError *` (nullable) | Combined `NSError`; `nil` when there is no failure |

Sequence: `data == nil` → `FileNotExist`; no peripheral → `PeripheralIsNull`; `Start`; repeated `Updating` (progress = `didSend / totalLength`); `VersionConsistent`; then `Success` or `Failure`.
Notes: `connectionModel.otaIng` is `YES` during the upgrade and scans are ignored; reconnect and re-sync afterwards.

### 7.2 Watch face: `JWBleCustomizeMainInterfaceAction`

| Method | Parameters | Callback |
| --- | --- | --- |
| `+ startWithImage:previewImage:configModel:actionCallBack:updateCallBack:` | background image, preview image, config | `actionCallBack` (stage), `updateCallBack` (transfer progress) |
| `+ startWithImage:previewImage:previewWidth:configModel:actionCallBack:updateCallBack:` | adds preview width | same |
| `+ startWithImage:previewImage:deviceWidth:deviceHeight:configModel:actionCallBack:updateCallBack:` | dynamic device size | same |
| `+ startWithImage:previewImage:deviceWidth:deviceHeight:configModel:actionCallBack:combinedDataSuccessCallBack:updateCallBack:` | adds combined data | adds `combinedDataSuccessCallBack(NSDictionary *)` |
| `+ (unsigned char *)convertUIImageToBitmapRGBRGB:(UIImage *)image;` | — | returns an RGB byte buffer allocated with `malloc`; the **caller must `free()` it** |

Stages: `MakingResourcePack`, `PictureIsEmpty`, `FailedToParseImage`, `FailedToMakeResourcePack`, `Transmission`, `Success`, `Failure`.

Related `JWBleAction` methods (no in-method callback): `jwCustomizeMainInterfaceAction:configModel:`, `jwCustomizeRoundMainInterfaceAction:`, `jwCustomizeRectangleMainInterfaceAction:`, `wbSetCustomizeV102MainInterface:`, `jwCustomizeGT5MainInterfaceAction:`, `jwCustomize_1_47_MainInterfaceAction:`, `jwCustomize_238_MainInterfaceAction:`, `jwCustomizeMainInterfacePositionWithConfigModel:`. The suffixes (`V102`, `GT5`, `1.47`, `238`) are the SDK's internal dial-resource codes; **call `JWBleCustomizeMainInterfaceAction` with an explicit `deviceWidth:deviceHeight:`** and no model selection is needed.

### 7.3 `JWBleMyMainInterfaceAction`

| Member | Notes |
| --- | --- |
| `+ shareInstance` | singleton |
| `- getDeviceInterfaceConf` | reads the device watch-face config; result via the `callBack` property (`NSData`) |
| `- testSendData:` / `- testSendImageData:` | raw send calls of the custom-dial data channel (`wbSendData_my:` / `wbSendData_image_my:`); normally driven by the SDK itself |
| `- deviceRespnseData:` | device-response entry point; the SDK forwards the payload to the `callBack` property — integrators normally do not call it |
| `callBack` property | `JWBleMyMainInterfaceActionCallBack` → `(NSData *)` |

---

## Chapter 8 — Utilities

### 8.1 `JWBlePublicHelp`

| Signature | Parameters | Returns |
| --- | --- | --- |
| `+ (float)jw_step2DisWith:(int)height andStepCount:(int)stepCount;` | height cm, steps | kilometres |
| `+ (float)jw_dis2CalWith:(float)weight andDis:(float)dis;` | kg, km | kcal |

Synchronous, no callback. The formulas match the firmware:
`distance(km) = height(cm) × 0.0045 × steps ÷ 1000`; `calories(kcal) = weight(kg) × distance(km) × 0.8214`.

### 8.2 `JWLogAction` / `JWLogModel`

| Member | Notes |
| --- | --- |
| `+ (NSArray *)getLog;` | returns logged entries |
| `+ (void)clear;` | clears the local log |
| `+ (void)log:(NSString *)formatStr, ...NS_FORMAT_FUNCTION(1,2);` | writes a log line |
| `JWLogModel` | `NSTimeInterval t`, `NSString *str` |
| `JWNSLog(...)` | convenience macro |

Requires `JWBleManager.showLog = YES`; persistence requires `saveLog = YES`.

### 8.3 `JWBleDBModel`

Public database base class (`pk`, `columeNames`, `columeTypes`, `save`, `saveOrUpdate`, `update`, `deleteObject`, `findAll`, `findByPK:`, `findByCriteria:`, `createTable`, `clearTable`, …). Business table models are not public; integrators normally do not need this class.

---

## Chapter 9 — Callback reference (API → callback)

### 9.1 `JWBleManager` property callbacks (29, all delivered on the main thread)

| Callback | Type | Fired by | Parameters | Related API | Notes |
| --- | --- | --- | --- | --- | --- |
| `connectStateChangeCallBack` | `JWBleConnectStatusChangeCallBack` | Every connection-class event (connect/bind/sync/disconnect/battery/charging/timeout/device state/headset) | `JWBleDeviceConnectStatus` | any | Required — the single source of connection state |
| `centralManagerStateChangeBlock` | `JWCentralManagerStateChangeBlock` | Phone Bluetooth power state changes | `JWBleCentralManagerState` | after init | A power-off also emits `DisConnect` first |
| `getPowerCallBack` | `JWBleGetPowerCallBack` | Battery reported (query or change) | `(status, int power, bool charging)` | `jwGetDeviceCurrentBatteryWithCallBack:` (**new**) | Persistent block, register once |
| `remotePhotographyCallBack` | `JWBleRemotePhotographyCallBack` | Camera setting result + shutter event | `JWBleRemotePhotographyStatus` | `jwRemotePhotography:callBack:` | `_TakePhoto` = shutter |
| `synchronousDataProgressCallBack` | `JWBleSynchronousDataProgressCallBack` | History sync progress | `(int curPackageIndex, int packageCount)` | `jwSyncDataWithCallBack:` | progress UI |
| `langCoTranslationCallBack` | `JWBleLangCoTranslationCallBack` | Custom translation feature | `int value` | custom feature | requires customisation |
| `findPhoneCallBack` | `JWBleFindPhoneCallBack` | Device triggers "find phone" (legacy) | none | device triggered | — |
| `findPhoneV2CallBack` | `JWBleFindPhoneV2CallBack` | Device triggers "find phone" V2 | `BOOL start` | device triggered | — |
| `realTimeHeartRateCallBack` | `JWBleRealTimeHeartRateCallBack` | Real-time HR stream | `NSInteger hrValue` | `jwRealTimeHeartRateAction:callBack:` | `-999` = stopped by device |
| `realTimeTemperatureCallBack` | `JWBleRealTimeTemperatureCallBack` | Real-time temperature | `(float value, BOOL gradient, BOOL wearing, BOOL compensation)` | `jwTestTemperatureAction:` (actionKey 1) | `-999` = stopped |
| `deviceMotionStatusChangeCallBack` | `JWBleDeviceMotionStatusChangeCallBack` | Device-initiated motion status change | `JWBleMotionStatusModel` | multi-sport | may fire together with the request callback |
| `deviceMotionRealtimeDataCallBack` | `JWBleDeviceMotionRealtimeDataCallBack` | Multi-sport realtime data | `JWBleMotionRealtimeDataModel` | Running/Paused only | stops after stop/disconnect |
| `endOfPulseCallBack` | `JWBleEndOfPulseCallBack` | Pulse finished | `int value` | `jwCustomSetPulseAction:…` | custom feature |
| `pulseDataCallBack` | `JWBlePulseDataCallBack` | Pulse data | `(status, length, timestamp, value)` | same | status: 0 end / 1 start / 2 receiving |
| `saunaDataCallBack` | `JWBleSaunaDataCallBack` | Sauna data | `(status, length, time, hr, tem, label, move)` | custom feature | — |
| `hrMovementDataCallBack` | `JWBleHrMovementDataCallBack` | HR movement data | `(time, hr, tem, label, move)` | — | — |
| `opusDataCallBack` | `JWBleOpusDataCallBack` | Opus data | `NSData *` | `jwOpenOpus:` | feature dependent |
| `ecgDataCallBack` | `JwECGDataCallBack` | ECG waveform | `(originalSignals, filterSignals)` | `jwECGAction:callBack:` | high frequency |
| `ecgOriDataCallBack` | `JwECGOriDataCallBack` | ECG raw data | `NSData *` | same | — |
| `ecgValueDataCallBack` | `JwECGValueDataCallBack` | ECG metrics | `(bpm, qt, hrv, rri, progress)` | same | — |
| `deviceTestECGCallBack` | `JwDeviceTestECGCallBack` | Production-test ECG | `NSDictionary *` | production mode | not for third parties |
| `beltValueDataCallBack` | `JwBeltValueDataCallBack` | Belt metrics | `(bpm, qt, hrv, rri)` | `jwBeltAction:callBack:` | — |
| `beltDataCallBack` | `JwBeltDataCallBack` | Belt waveform | `(originalSignals, filterSignals)` | same | — |
| `deviceSwitchChangeCallBack` | `JwDeviceSwitchChangeCallBack` | Device switch data changed | `NSData *` | after connect / device push | parse with `jwGetDeviceSNIDWithBlock:` |
| `uricAcidStatusCallBack` | `JWBleUricAcidStatusCallBack` | Uric acid status change | `(open, privateValue, privateRtc)` | `jwUricAcidAction:…` | — |
| `bloodFatStatusCallBack` | `JWBleBloodFatStatusCallBack` | Blood fat status change | same | `jwBloodFatAction:…` | — |
| `bloodGlucoseCycleStatusCallBack` | `JWBleBloodGlucoseCycleStatusCallBack` | Glucose cycle status change | same | `jwBloodGlucoseCycleAction:…` | — |
| `endMeasurementStatusCallBack` | `JWBleEndMeasurementStatusCallBack` | Common measurement finished | `JWBleEndMeasurementStatusType` | common measurement | Cancel/Fail/Success |
| `bodyFatDataCallBack` | `JWBleBodyFatDataCallBack` | Body fat data | `NSDictionary *` | `jwCommonMeasurementAction:start:` | see Chapter 10 |

### 9.2 In-method blocks by module

| Module | Methods | Result |
| --- | --- | --- |
| Scan | `jwStartScanDeviceWithCallBack:` / `jwStartScanDeviceWithTimeout:callBack:` | `JWBleDeviceModel` |
| Profile/goals | `jwSynchronizePersonalInformation:…`, `jwSetStepTargetAction:` … | `JWBleCommunicationStatus` |
| Capability query | `jwCheckFunctionStates:`, `jwCheckControlSwitchStates:`, `jwCheckHideFunctionStates:`, `jwCheckCustomFunctionStates:` | **synchronous return value** |
| Time/unit/language/brightness/screen | `jwSetTimeWithYear:…`, `jwCommonFunction:…`, `jwLanguageAction:…`, `jwbBrightnessAdjustment:…`, `jwbBrightScreenDuration:…` | `JWBleCommunicationStatus` + read value |
| DND / sedentary / wrist | `jwNotDisturbAction:`, `jwSedentaryReminder:`, `jwTurnWristCreenActionWithIsGet:` | dedicated blocks |
| Alarms / medication | `jwAlarmAction:`, `jwAlarmV2Action:`, `jwMedicationReminderAction:` | model arrays |
| Notifications | `jwUpdateNotiStatus:`, `jwOneTimeUpdateNotiStatus:`, `jwGetNotiStatusWithCallBack:`, `jwUpdateHideFunction:open:callBack:` | status / notification dictionary |
| Spot measurements | `jwTestHRAction:`, `jwTestBPAction:`, `jwTestOxygen:`, `jwTestTemperatureAction:`, `jwTestBloodGlucoseAction:` | dedicated state machines |
| Multi-sport | `jwQueryDeviceMotionStatus:`, `jwStartDeviceMotion:` … | `status` + `JWBleMotionStatusModel` |
| History sync | `jwSyncDataWithCallBack:` | `status` + `JWBleSyncStateEnum` |
| History read | all `JWBleDataAction` getters | arrays/dictionaries (local DB, synchronous) |
| OTA | the three `startOTA…` methods | `JWBleDFUCallBack` |
| Watch face | the four `startWithImage:…` methods | `actionCallBack` + `updateCallBack` |
| Battery | `jwGetDeviceCurrentBatteryWithCallBack:` | `JWBleManager.getPowerCallBack` |

### 9.3 Declared but unused blocks (11, all marked deprecated on 2026-09-29)

`JWBleCheckMotionSupportCallBack`, `JWBleCommunicationReceiveCallBack`, `JWBleFindPhoneActionCallBack`, `JWBleGetImmediateDataCallBack`, `JWBleHRReminderActionCallBack`, `JWBleMainInterfaceStyleBlock`, `JWBleMotionActionCallBack`, `JWBleStopwatchTimingActionCallBack`, `JWBleTimeThemeActionCallBack`, `JWBleTimerActionCallBack`, `JWBleUpdatePWDCallBack`

> `JWBleGetPowerCallBack` used to be in this list; since `jwGetDeviceCurrentBatteryWithCallBack:` was added it is used by the battery API.

---

## Chapter 10 — Data models

### 10.1 `JWBleDeviceModel`

| Field | Type | Unit | Optional | Notes |
| --- | --- | --- | --- | --- |
| `rssi` | `NSNumber *` | dBm | yes | `@0` when there is no advertisement context |
| `systemMacAddress` | `NSString *` | — | yes | raw advertisement string / system UUID |
| `macAddress` | `NSString *` | — | yes | `AA:BB:CC:DD:EE:FF`, falls back to the UUID |
| `deviceName` | `NSString *` | — | yes | advertisement name, falls back to `CBPeripheral.name` |
| `versionName` | `NSString *` | — | after sync | `1.2.3` or `1.2.3.4` |
| `versionCode` | `int` | — | after sync | numeric encoding |
| `fontVersionCode` / `fontVersionCodeStr` | `int` / `NSString *` | — | after sync | `-1` / `0.0.0.0` when unsupported |
| `resourceVersionCode` / `resourceVersionCodeStr` | `int` / `NSString *` | — | after sync | same |
| `power` | `int` | % | after sync | battery |
| `deviceNumber` | `int` | — | after sync | device id |
| `functionData` | `NSData *` | — | yes | capability data (two encodings — see 2.10.1) |
| `functionDataV2` | `NSArray *` | — | yes | V2 feature list, elements `@{@"type": …}` |
| `hideFunctionMenu` | `NSData *` | — | yes | hidden-menu bitmap |
| `notiData` | `NSData *` | — | yes | notification switch data |
| `per` | `CBPeripheral *` | — | yes | system peripheral |
| `isDFU` / `otaIng` / `chargIng` / `headsetPaired` | `BOOL` | — | — | device flags |
| `headphoneDeviceStatus` | `int` | — | — | 0 off / 1 pairing / 2 ready / 3 connected / 4 connected to the phone |
| `deviceStatusTypeArr` | `NSArray *` | — | yes | e.g. power-saving mode |
| `chipType` | `int` | — | yes | 0 = C (normal), 1 = D (VD) |
| `platform` | `int` | — | yes | 0 = RTK, 100 = Lianrui Micro |
| `advertisementData` | `NSDictionary *` | — | yes | raw advertisement |
| `deviceSwitchData` | `NSData *` | — | yes | controllable switch data |
| `customizedFunctionDic` | `NSDictionary *` | — | yes | custom feature support |
| `DeviceInfoData` | `NSData *` | — | yes | raw RTK device info (absent from the older shipped header) |

### 10.2 `JWBleAlarmClockModel`

| Field | Type | Range | Notes |
| --- | --- | --- | --- |
| `year` | `int` | 0-63 (from 2000) | 13 = 2013 |
| `month` / `day` / `hour` / `minute` | `int` | 1-12 / 1-31 / 0-23 / 0-59 | V2: month and day both 0 deletes the alarm |
| `repeatWeekArr` | `NSArray *` | 7 × 0/1 | Monday first; all zeros / nil / empty / fewer than 7 means one-shot |
| `idd` / `isOpen` / `content` | `int` / `bool` / `NSString *` | — | Alarm 2.0 fields |

### 10.3 `JWBleMedicationReminderModel`

Same six fields as `JWBleAlarmClockModel` (`year`, `month`, `day`, `hour`, `minute`, `repeatWeekArr`) without the V2 fields.

### 10.4 `JWBleHeatStressReminderModel`

`open` (BOOL), `startHour` (0-23), `startMinute` (0-59), `endHour` (0-23), `endMinute` (0-59).
Included in the shipped 1.3.2 framework headers.

### 10.5 `JWNotDisturbModel`

`open` (BOOL), `enumType` (`JWBleNotDisturbEnum`: all day / not worn / scheduled), `startHour`, `startMinute`, `endHour`, `endMinute` (all `UInt32`).

### 10.6 `JWCountDownModel`

`seconds` (1-86400; remaining time when reading a running countdown), `optionEnum` (`JWCountDownOptionEnum`: Setting/Start/Stop), `open` (bool, show on the device UI).

### 10.7 `JWOxygenModel`

`mCurValue` (current), `mHighValue` (max), `mLowValue` (min) — all `int`, raw device values — plus `time` (`NSInteger`, seconds).

### 10.8 Weather models

`JWBleWeatherModel`: `open` (bool), `curWeatherModel` (must not be nil), `futureWeatherArr` (<= 6 entries).

`JWBleCurWeatherModel`:

| Field | Type | Unit/Range | Notes |
| --- | --- | --- | --- |
| `year` / `month` / `day` | `int` | — | must match the device date |
| `cityStr` | `NSString *` | <= 33 bytes | — |
| `weatherCode` | `JWBleWeatherCode` | 0-27 | — |
| `temp` / `maxTemp` / `minTemp` | `int` | C, > 0 | — |
| `humidity` | `int` | % | 0 hides it |
| `uv` | `int` | 0-5 | 0 invalid, 1 weakest (0-2), 2 weak (3-4), 3 medium (5-6), 4 strong (7-9), 5 very strong (>= 10) |
| `pm` | `int` | — | 0 hides it |

`JWBleFutureWeatherModel`: `weatherCode`, `maxTemp`, `minTemp`.

### 10.9 `JWBleCustomizeMainInterfaceActionConfigModel`

`color` (white/black), `position` (nine-grid 0-8), `devicePositionDic` (per-position device coordinates), `chipType`.

### 10.10 `JWBleBodyFatDataCallBack` dictionary

`time`, `weight`, `bmi` + `bmiLevel` + `bmiMaxLevel`, `fm*` (fat), `tbw*` (water), `pw*` (protein), `mm*` (BMC), `slm*` (muscle), `bmr*` (basal metabolism) — all `NSInteger`: `weight` is in kg, the component values are the device's raw values, and `*Level` / `*MaxLevel` give the current and full-scale steps for progress bars. Convert to % / kcal in your UI layer.

### 10.11 Multi-sport models

`JWBleMotionStatusModel`: `result` (`JWBleDeviceMotionResult`), `state` (`JWBleDeviceMotionState`), `motionType` (`JWBleDeviceMotionEnum`), `rawMotionType` (`NSInteger`).

`JWBleMotionRealtimeDataModel`:

| Field | Type | Unit | Notes |
| --- | --- | --- | --- |
| `state` | `JWBleDeviceMotionState` | — | — |
| `motionType` / `rawMotionType` | `JWBleDeviceMotionEnum` / `NSInteger` | — | — |
| `duration` | `uint32_t` | seconds | documented |
| `heartRate` | `uint8_t` | bpm | — |
| `steps` | `uint32_t` | steps | — |
| `distance` / `calories` | `uint32_t` | metres (m) / calories (cal) | same units as the device protocol sport fields; divide by 1000 when you display kilocalories |

### 10.12 `JWLogModel` / `JWBleDBModel`

`JWLogModel`: `t` (`NSTimeInterval`), `str` (`NSString *`). `JWBleDBModel`: `pk` (`int`) plus database helpers.

---

## Chapter 11 — Public enums

### 11.1 Connection and communication

**`JWBleDeviceConnectStatus`** — connection status (core)

| Value | Meaning |
| --- | --- |
| `DisConnect = 0` | Disconnected |
| `Connect` | BLE link established |
| `BondSuccess` / `BondFailure` | Binding succeeded / failed |
| `SyncSuccess` / `SyncFailure` | Device-info sync succeeded / failed (**`SyncSuccess` = device ready**) |
| `DiscoverNewUpdateFirm` | Upgradeable firmware found |
| `BatteryUpdate` | Battery changed |
| `ChargeStatusChanged` | Charging state changed |
| `HeadphoneDeviceStatusChanged` | Headset state changed |
| `TimeOutDisconnect` | Communication timed out, disconnected by the SDK |
| `DeviceStatusChanges` | Device state changed (power saving, flight mode, …) |
| `BondConfirm_NotAllowed` | Binding rejected by the user |
| `BondConfirm_TimeOut` | Binding confirmation timed out |
| `BleRemovedPairingInformation` | System pairing cache removed (usually bound by another phone) |
| `Temp` | Placeholder |

**`JWBleCommunicationStatus`** — communication status (the de-facto error code)

| Value | Meaning |
| --- | --- |
| `Faild = 0` | Communication failed / not connected |
| `Success = 1` | Command sent (setters) or device replied OK (getters) |
| `PWDError = 3` | Communication password mismatch |
| `IsDFUModel = 4` | Device is in DFU mode |
| `Busy = 5` | Device is busy (syncing) |

**`JWBleCentralManagerState`**: `Unknown = 0`, `Resetting`, `Unsupported`, `Unauthorized`, `PoweredOff`, `PoweredOn`.

**`JWBleSyncStateEnum`**: `Start = 0`, `Interrupt`, `InconsistentTotals`, `Complete`.

**`JWBleBusyStateEnum`**: `Busy = 2`, `Idle = 3`, `TimeOut = 4`.

**`JWBleRealTimeHeartRateStateEnum`**: `Close = 0`, `Open`, `Busy`, `TimeOut`.

**`JWBleDeviceDFUStatus`**: `FileNotExist = 0`, `Start`, `Updating`, `Success`, `Failure`, `PeripheralIsNull`, `VersionConsistent` (device version already matches the package — no upgrade needed).

### 11.2 Measurement states

| Enum | Values |
| --- | --- |
| `JWBleTestHRStatus` | `TestStart = 0`, `DeviceResponse`, `TestEnd`, `TestField` |
| `JWBleTestBPStatus` | `TestStart = 0`, `DeviceResponse`, `TestEnd`, `TestField`, `TestInterrupt` |
| `JWBleTestTemperatureStatus` | `TestEnd = 0`, `DeviceResponse = 1`, `NotOpen = 2`, `Open = 3`, `BUSY = 4`, `TestField` |
| `JWBleEndMeasurementStatusType` | `Cancel = 0`, `Fail`, `Success` |
| `JWTestOxygenRequestType` | `End = 0`, `Start`, `Check` |
| `JWTestOxygenResultType` | `End = 0`, `Start`, `Disable`, `Available` |

### 11.3 Features and settings

**`JWBleFunctionEnum`** — the capability enum (100 members in 3 segments). Values in the base and V2 segments are the implicit C enum values (verified against the implementation's `NSMakeRange(functionEnum, 1)` decoding). The "bitmap" column is the `byteIndex.bitIndex` used when `functionData.length <= 8`; `—` means the feature is **not** in the bitmap whitelist and therefore always reports "unsupported" on such devices.

**Base segment (0-33)**

| Enum | Value | Meaning | Bitmap |
| --- | --- | --- | --- |
| `JWBleFunctionEnum_Error` | -1 | Placeholder | — |
| `JWBleFunctionEnum_HeadphoneCall` | 0 | Headset call | 3.7 |
| `JWBleFunctionEnum_BloodPressureTest` | 1 | Blood pressure | 3.6 |
| `JWBleFunctionEnum_HR` | 2 | Heart rate | 3.5 |
| `JWBleFunctionEnum_DoNotDisturbMode` | 3 | Do not disturb | 3.4 |
| `JWBleFunctionEnum_Step` | 4 | Step counting | 3.3 |
| `JWBleFunctionEnum_Sleep` | 5 | Sleep monitoring | 3.2 |
| `JWBleFunctionEnum_WeChatRun` | 6 | WeChat Sports Airsync | 3.1 |
| `JWBleFunctionEnum_BrightScreenDuration` | 7 | Bright screen duration | 3.0 |
| `JWBleFunctionEnum_Noti` | 8 | Message notifications | 2.7 |
| `JWBleFunctionEnum_MainInterfaceStyle` | 9 | Main interface style | 2.6 |
| `JWBleFunctionEnum_LiftTheWristScreen` | 10 | Raise-to-wake | 2.5 |
| `JWBleFunctionEnum_MoreLanguage` | 11 | Multiple languages | 2.4 |
| `JWBleFunctionEnum_TimeSystem` | 12 | 12/24-hour time | 2.3 |
| `JWBleFunctionEnum_Unit` | 13 | Metric/imperial | 2.2 |
| `JWBleFunctionEnum_OTA` | 14 | OTA upgrade | 2.1 |
| `JWBleFunctionEnum_NFC` | 15 | NFC | 2.0 |
| `JWBleFunctionEnum_ExerciseMore` | 16 | Multi-sport | 1.7 |
| `JWBleFunctionEnum_StopwatchTiming` | 17 | Stopwatch (hidden menu) | 1.6 |
| `JWBleFunctionEnum_Countdown` | 18 | Countdown | 1.5 |
| `JWBleFunctionEnum_HeartRateReminder` | 19 | HR reminder | 1.4 |
| `JWBleFunctionEnum_RemotePhotography` | 20 | Remote camera | 1.3 |
| `JWBleFunctionEnum_FindPhone` | 21 | Find phone (hidden menu) | 1.2 |
| `JWBleFunctionEnum_FindBracelet` | 22 | Find band | 1.1 |
| `JWBleFunctionEnum_BrightnessControl` | 23 | Brightness control | 1.0 |
| `JWBleFunctionEnum_MusicControl` | 24 | Music control | 0.7 |
| `JWBleFunctionEnum_VolumeControl` | 25 | Volume control | 0.6 |
| `JWBleFunctionEnum_SmartAlarmClock` | 26 | Smart alarm | 0.5 |
| `JWBleFunctionEnum_SedentaryReminder` | 27 | Sedentary reminder | 0.4 |
| `JWBleFunctionEnum_EventReminder` | 28 | Event reminder | 0.3 |
| `JWBleFunctionEnum_AutomaticLockScreen` | 29 | Auto lock (hidden menu) | 0.2 |
| `JWBleFunctionEnum_RealTimeHeartRate` | 30 | Real-time HR | 0.1 |
| `JWBleFunctionEnum_HideFunctionMenu` | 31 | Hidden function menu | 0.0 |
| `JWBleFunctionEnum_TwoButtonSliding` | 32 | Two-button sliding (hidden menu) | — |
| `JWBleFunctionEnum_VoiceAssistant` | 33 | Voice assistant (hidden menu) | — |

> `TwoButtonSliding` and `VoiceAssistant` are queried through `jwCheckHideFunctionStates:`, not through the `jwCheckFunctionStates:` bitmap.

**High segment (63-35, declared descending; value 52 is unused)**

| Enum | Value | Meaning | Bitmap |
| --- | --- | --- | --- |
| `JWBleFunctionEnum_DataCalibration` | 63 | Data calibration | 4.0 |
| `JWBleFunctionEnum_SyncSleep` | 62 | Sync sleep to device | 4.1 |
| `JWBleFunctionEnum_Temperature` | 61 | Temperature | 4.2 |
| `JWBleFunctionEnum_BloodPressureV2` | 60 | Blood pressure 2.0 | 4.3 |
| `JWBleFunctionEnum_SmartAlarmClockV2` | 59 | Smart alarm 2.0 | 4.4 |
| `JWBleFunctionEnum_MainInterfaceStyle_Customize` | 58 | Custom interface style | 4.5 |
| `JWBleFunctionEnum_MainInterfaceStyle_Download` | 57 | Downloadable interface | 4.6 |
| `JWBleFunctionEnum_Blood_Oxygen` | 56 | Blood oxygen | 4.7 |
| `JWBleFunctionEnum_DisplayFontUpgrade` | 55 | Display font upgrade | 5.0 |
| `JWBleFunctionEnum_SleepQualityJudgment_V2` | 54 | Sleep quality 2.0 | 5.1 |
| `JWBleFunctionEnum_APP_MOTION_HR_V2` | 53 | App motion HR 2.0 | 5.2 |
| (unused) | 52 | — | 5.3 (bit unused) |
| `JWBleFunctionEnum_ContinuousBloodOxygen` | 51 | Continuous SpO2 | 5.4 |
| `JWBleFunctionEnum_ECG` | 50 | ECG | 5.5 |
| `JWBleFunctionEnum_Status_Check` | 49 | Status check | 5.6 |
| `JWBleFunctionEnum_Address_Book` | 48 | Address book | 5.7 |
| `JWBleFunctionEnum_HRV` | 47 | HRV | 6.0 |
| `JWBleFunctionEnum_DeviceBPMonitoring` | 46 | Device BP monitoring | 6.1 |
| `JWBleFunctionEnum_BloodGlucose` | 45 | Blood glucose | 6.2 |
| `JWBleFunctionEnum_LowOxygenReminder` | 44 | Low SpO2 reminder | 6.3 |
| `JWBleFunctionEnum_HighHeartRateReminder` | 43 | High HR reminder | 6.4 |
| `JWBleFunctionEnum_SleepAllDay` | 42 | All-day sleep | 6.5 |
| `JWBleFunctionEnum_DialDateFormat` | 41 | Dial date format | 6.6 |
| `JWBleFunctionEnum_ECGHidden_HRV_QT` | 40 | Hide QT/HRV in ECG | 6.7 |
| `JWBleFunctionEnum_Belt` | 39 | ECG belt | 7.0 |
| `JWBleFunctionEnum_Health_Hidden` | 38 | Hidden health features | 7.1 |
| `JWBleFunctionEnum_Stress` | 37 | Automatic stress monitoring | 7.2 |
| `JWBleFunctionEnum_HeatStress` | 36 | Heat stress | 7.3 |
| `JWBleFunctionEnum_APPControlMotion` | 35 | App-controlled multi-sport | 7.4 |

**Device feature 2 segment (10001-10016, none of them in the bitmap whitelist)**

| Enum | Value | Meaning |
| --- | --- | --- |
| `JWBleFunctionEnum_DevicePrivateBloodPressure` | 10001 | Private blood pressure |
| `JWBleFunctionEnum_SOS` | 10002 | SOS |
| `JWBleFunctionEnum_DrinkWaterReminder` | 10003 | Drink-water reminder |
| `JWBleFunctionEnum_TemperatureReminder` | 10004 | Temperature reminder |
| `JWBleFunctionEnum_MedicationReminder` | 10005 | Medication reminder |
| `JWBleFunctionEnum_Female` | 10006 | Female health |
| `JWBleFunctionEnum_Weather` | 10007 | Weather |
| `JWBleFunctionEnum_WearingTime` | 10008 | Wearing time |
| `JWBleFunctionEnum_UricAcid` | 10009 | Uric acid |
| `JWBleFunctionEnum_BloodFat` | 10010 | Blood fat |
| `JWBleFunctionEnum_BloodGlucoseCycle` | 10011 | Glucose cycle |
| `JWBleFunctionEnum_UricAcid_ContinuesMonitoring_Private` | 10012 | Uric acid continuous (private) |
| `JWBleFunctionEnum_BloodFat_ContinuesMonitoring_Private` | 10013 | Blood fat continuous (private) |
| `JWBleFunctionEnum_BodyFat` | 10014 | Body fat |
| `JWBleFunctionEnum_MicroPhysicalExamination` | 10015 | Micro physical examination |
| `JWBleFunctionEnum_UV` | 10016 | Ultraviolet |

> V2 lookup: any entry in `functionDataV2` with `type == value - 10000` means supported (`Open`); an empty list means `NotSupport`.

**Other feature enums**

| Enum | Values |
| --- | --- |
| `JWBleFunctionStatesEnum` | `NotSupport = 0\|2` (= 2), `Close = 1`, `Open = 3` |
| `JWBleHideFunctionStatesEnum` | `NotSupport = 0`, `Show = 1`, `Hidden = 2` |
| `JWBleDeviceSwitchFunctionEnum` | `Time_Format`, `Language`, `Heart_Rate_Monitoring`, `Blood_Pressure_Monitoring`, `Blood_Oxygen_Monitoring`, `Temperature_Monitoring`, `Temperature_Compensation`, `Temperature_Function_Independent`, `BloodGlucose_Monitoring`, `Gesture_Bright_Screen`, `UricAcidContinuesMonitoring`, `BloodFatContinuesMonitoring` |
| `JWBleCommonFunctionsStatus` | `Read`, `Open`, `Close` |
| `JWBleLanguageEnum` | `English = 0`, `ChineseSimplified = 1`, `Traditional_Chinese = 2`, `Polish = 13`, `German = 18`, `Russian = 19`, `French = 20`, `Korean = 29`, `Dutch = 31`, `Mongolian = 53`, `Portuguese = 62`, `Japanese = 65`, `Swedish = 66`, `Thai = 81`, `Turkey = 82`, `Spanish = 87`, `Italian = 96`, `Vietnamese = 102` |
| `JWBleNotiEnum` | `Error = -1`, `Call = 1`, `QQ = 3`, `WeChat = 5`, `SMS = 7`, `Line = 9`, `Twitter = 11`, `Facebook = 14`, `Messenger = 16`, `WhatsApp = 18`, `LinkedIn = 20`, `Instagram = 22`, `Skype = 24`, `Viber = 26`, `KakaoTalk = 28`, `VKontakte = 30`, `AppleMail = 32`, `AppleCalendar = 34`, `AppleFacetime = 36`, `Tim = 38`, `Gmail = 40`, `DingTalkPlus = 42`, `WorkWechat = 44`, `APlus = 46`, `LINK = 48`, `Beike = 50`, `Lianjia = 52`, `Other = 54` |
| `JWUserPreferenceType` | `BloodGlucose_Unit = 0` (0 = mmol/L, 1 = mg/dL) |
| `JWBleFemaleStatus` | `None = 0`, `Menstrual`, `Getting_Pregnant`, `Pregnancy`, `Mom` |
| `JWDeviceStatusType` | `Power_Saving_Mode = 63`, `Temp` |
| `JWUpdateResourceType` | `Main_display_resource = 0`, `Display_font`, `Font_libraries_involved_in_the_main_interface`, `Custom_interface_resources`, `Dial_market_resources` |

### 11.4 Sport

**`JWBleDeviceMotionEnum`**: `Unknown = -1`, `Run = 0`, `Climb`, `Football`, `Cycle`, `Rope`, `RunOutDoor`, `RideOutDoor`, `WalkOutDoor`, `RunInDoor`, `FreeTrain`, `Plank`, `Walk`, `Pranayama`, `Yoga`, `Hiking`, `Spinning`, `Rowing`, `Stepper`, `Elliptical`, `Basketball`, `Tennis`, `Badminton`, `Baseball`, `Rugby`, `PingPong = 0x18`, `Skiing = 0x19`, `Cricket = 0x1A`, `StrengthTraining = 0x1B`

**`JWBleDeviceMotionControlAction`**: `Query = 0x00`, `Start = 0x01`, `Pause = 0x02`, `Resume = 0x03`, `Stop = 0x04`

**`JWBleDeviceMotionResult`**: `Success = 0x00`, `AlreadyInTargetState = 0x01`, `UnsupportedType = 0x02`, `InvalidState = 0x03`, `LowBattery = 0x04`

**`JWBleDeviceMotionState`**: `Idle = 0x00`, `Running = 0x01`, `Paused = 0x02`

**`JWBleMotionActionEnum`**: `Stop = 0`, `Start = 1`, `Pause = 3` — **deprecated** (no public API uses it)

**`JWBleImmediateDataEnum`**: `Step = 0`, `HR`

### 11.5 Health and data

**`JWBleBusyStatus` (14 values)**: `Heart_Rate_Manual_Test = 0`, `Heart_Rate_Silent_Measurement`, `Manual_Blood_Pressure_Measurement`, `Blood_Pressure_Silent_Measurement`, `Manual_Blood_Oxygen_Measurement`, `Silent_Measurement_Of_Blood_Oxygen`, `Manual_Pressure_Measurement`, `Silent_Measurement_Of_Pressure`, `In_Motion`, `ECG_Testing`, `Manual_Blood_Glucose_Measurement`, `Silent_Measurement_Of_Blood_Glucose`, `Pulsed_Magnetic_Therapy`, `BodyFat_Testing`

**`JWBleCommonMeasurementEnum`**: `BodyFat = 5` (the comment previously said "blood fat" — corrected)

**`JWUricAcidEvaluationResultEnum`**: `None = 0`, `Insufficient_Wearing_Time = 1`, `Low_Risk = 2`, `Medium_Risk = 3`, `High_Risk = 4` — shared by uric acid, blood fat and glucose cycle with identical semantics.

**`JWDeleteDataType`**: `Step = 0`, `Sleep`, `HeartRate`, `BloodPressure`, `Oxygen`, `Temperature`, `BloodGlucose`, `Hrv`, `Sports`, `BloodFat`, `UricAcid`, `BloodGlucoseCycle`, `BloodFatContinuousMonitoring`, `UricAcidContinuousMonitoring`, `BodyFat`, `MicroPhysicalExamination`, `UV`

### 11.6 Status and password

| Enum | Values |
| --- | --- |
| `JWBleUpdatePWDStatus` | `Success = 0`, `OldPwdError`, `DeviceBusy`, `Faild` |
| `JWBleRemotePhotographyStatus` | `Success = 0`, `TakePhoto`, `DeviceBusy`, `Faild` |
| `JWBleCustomFunctionEnum` | `Error = -1`, `SetPulse = 0`, `SleepAid`, `Sauna` |

### 11.7 Model-level enums

| Enum | Values |
| --- | --- |
| `JWBleNotDisturbEnum` | `AllDay = 0`, `NotWorn`, `Timing` |
| `JWCountDownOptionEnum` | `Setting = 0`, `Start`, `Stop` |
| `JWBleWeatherCode` | `Other = 0`, `Sunny`, `Cloudy`, `Overcast`, `Rain`, `LightRain`, `ModerateRain`, `HeavyRain`, `Storm`, `ShowerRain`, `HeavyShowerRain`, `FreezingRain`, `Snow`, `LightSnow`, `ModerateSnow`, `HeavySnow`, `Sleet`, `Typhoon`, `Duststorm`, `SunnyAtNight`, `CloudyAtNight`, `Hot`, `Cold`, `Breeze`, `Gale`, `Mist`, `CloudyToClear` |
| `JWBleCustomizeMainInterfaceActionStatus` | `MakingResourcePack = 0`, `PictureIsEmpty`, `FailedToParseImage`, `FailedToMakeResourcePack`, `Transmission`, `Success`, `Failure` |
| `JWBleCustomizeMainInterfaceActionConfigModelColor` | `White = 0`, `Black` |
| `JWBleCustomizeMainInterfaceActionConfigModelPosition` | `Top_Left = 0`, `Top_Middle`, `Top_Right`, `Middle_Left`, `Middle_Middle`, `Middle_Right`, `Bottom_Left`, `Bottom_Middle`, `Bottom_Right` |

---

## Chapter 12 — Error codes and error handling

### 12.1 Unified error code (added 2026-09-29)

All original status enums are kept and **no method signature was changed**. A unified `JWBleErrorCode` (45 values) plus NSError helpers were added on top, purely additively:

| Capability | Declaration | Notes |
| --- | --- | --- |
| Error code enum | `JWBleErrorCode` (`JWBlePublicDefine.h`) | 45 values in five ranges: 1xxx state/parameter/communication, 2xxx Bluetooth and link, 3xxx device and protocol, 4xxx OTA/DFU, 9xxx unknown |
| Error domain | `JWBleErrorDomain` | `com.wosmart.JWBle.ErrorDomain`, used as `NSError.domain` |
| Message | `NSString *JWBleErrorMessageForCode(JWBleErrorCode)` | English technical description for logs/support; localise user-facing text in your app |
| Build NSError | `NSError *JWBleMakeError(JWBleErrorCode)` | Returns an `NSError` with `NSLocalizedDescriptionKey` |
| Build NSError with cause | `NSError *JWBleMakeErrorWithUnderlyingError(JWBleErrorCode, NSError *)` | userInfo carries `NSUnderlyingErrorKey` |
| Status mapping | `JWBleErrorCodeFromCommunicationStatus()`<br />`JWBleErrorCodeFromConnectStatus()`<br />`JWBleErrorCodeFromCentralManagerState()`<br />`JWBleErrorCodeFromDFUStatus()` | Header-only `NS_INLINE` functions, no I/O; success states map to `JWBleErrorCodeNone` |

**Ranges**

| Range | Values | Covers |
| --- | --- | --- |
| No error | `None = 0` | Success / normal state |
| State and parameters | 1000-1009 | not initialised, not connected, device busy, DFU mode, password error, unsupported, invalid parameter, timeout, out of range, communication failed |
| Bluetooth and link | 2000-2008 | powered off, unauthorised, unsupported, resetting, unknown, connection failed, connection timeout, link lost, pairing info removed |
| Device and protocol | 3000-3006 | device responded failure, invalid data, sync failed, inconsistent totals, bind failed, bind rejected, bind timeout |
| OTA / DFU | 4000-4016 | file missing/empty, no peripheral, invalid format, parse failed, version consistent (skip), image mismatch, image too old, battery low, method unsupported, start failed, transfer failed, validate failed, activate failed, timeout, disconnected, cancelled, failed (unclassified) |
| Unknown | 9000 | fallback |

**Usage**

```objc
// 1) Map a status enum from any SDK callback into an error code
JWBleErrorCode code = JWBleErrorCodeFromCommunicationStatus(status);
if (code != JWBleErrorCodeNone) {
    NSError *error = JWBleMakeError(code);      // report / log / analytics
    NSLog(@"%@", error.localizedDescription);
}

// 2) Connection-class failures
JWBleErrorCode connectError = [JWBleManager shareInstance].lastErrorCode;

// 3) OTA failure reason
JWBleOTAAction *ota = [JWBleOTAAction shareInstance];
if (ota.lastErrorCode != JWBleErrorCodeNone) {
    NSLog(@"OTA failed: %ld %@ (underlying: %@)",
          (long)ota.lastErrorCode, ota.lastErrorMessage, ota.lastUnderlyingError);
}
```

**Related properties**

| Property | Type | Notes |
| --- | --- | --- |
| `JWBleManager.lastErrorCode` | `JWBleErrorCode` (read-only) | Reason of the most recent connection-class failure; cleared after a successful connect/bind/sync |
| `JWBleOTAAction.lastErrorCode` | `JWBleErrorCode` (read-only) | Reason of the most recent OTA failure (`None` on success, skip or before starting) |
| `JWBleOTAAction.lastErrorMessage` | `NSString *` (read-only, nullable) | Failure description including the underlying error |
| `JWBleOTAAction.lastUnderlyingError` | `NSError *` (read-only, nullable) | Underlying error, usually `RTKOTAErrorDomain` |
| `- (NSError *)JWBleOTAAction.lastError` | `NSError *` (nullable) | Combines the three above; `nil` when there is no failure |

> OTA failure reasons come from RTKOTASDK and are mapped (for example `RTKOTAErrorImageOld` → `JWBleErrorCodeOTAImageTooOld`, `RTKOTAErrorDeviceBatteryLevelLow` → `JWBleErrorCodeOTADeviceBatteryLow`, `RTKOTAErrorUserCancelled` → `JWBleErrorCodeOTACancelled`); unrecognised codes fall back to `JWBleErrorCodeOTAFailed`.

### 12.2 Status enums are still in use

They remain the primary callback payloads; convert them with the helpers above when needed.

| Family | Enum | Typical values |
| --- | --- | --- |
| Communication | `JWBleCommunicationStatus` | `Faild`, `PWDError`, `IsDFUModel`, `Busy` |
| Connection | `JWBleDeviceConnectStatus` | `SyncFailure`, `TimeOutDisconnect`, `BondFailure`, `BondConfirm_NotAllowed`, `BondConfirm_TimeOut`, `BleRemovedPairingInformation` |
| Capability | `JWBleFunctionStatesEnum` / `JWBleHideFunctionStatesEnum` | `NotSupport`, `Close`, `Open` |
| Measurement | `JWBleTestHRStatus` / `JWBleTestBPStatus` / `JWBleTestTemperatureStatus` | `TestField`, `TestInterrupt`, `NotOpen`, `BUSY` |
| Firmware upgrade | `JWBleDeviceDFUStatus` | `FileNotExist`, `Failure`, `PeripheralIsNull`, `VersionConsistent` |

### 12.3 Symptom → action

| Symptom | Observed | Recommended handling |
| --- | --- | --- |
| API called while disconnected | `JWBleCommunicationStatus_Faild` | Check `isConnected` / wait for `SyncSuccess` |
| Device in DFU mode | `JWBleCommunicationStatus_IsDFUModel` | Ask the user to wait / reconnect |
| Sport history sync running | `JWBleCommunicationStatus_Busy` | Serialise calls, wait for sync to finish |
| Password mismatch | `JWBleCommunicationStatus_PWDError` | Rebind (unbind then connect again) |
| 60 s without sync | `connectStateChangeCallBack(TimeOutDisconnect)` | Prompt a retry; check whether another phone holds the device |
| Binding rejected / timed out | `BondConfirm_NotAllowed` / `BondConfirm_TimeOut` | Ask the user to operate the device again |
| System pairing cache removed | `BleRemovedPairingInformation` | Rebind |
| Feature unsupported | `jwCheckFunctionStates:` returns `NotSupport` (2) | Hide the entry point instead of calling the API |
| Missing firmware file / peripheral | `JWBleDeviceDFUStatus_FileNotExist` / `_PeripheralIsNull` | Validate and retry |
| Upgrade failed | `JWBleDeviceDFUStatus_Failure` | Read `JWBleOTAAction.lastErrorCode` / `lastError` for the concrete reason (since 2026-09-29), then retry or prompt |

### 12.4 What the integrator must handle

1. **Bluetooth turned off** — `DisConnect` is reported first, then `PoweredOff`.
2. **App backgrounded** — background reconnection is not guaranteed; declare the background mode yourself.
3. **Permission denied** — the SDK never prompts; `CBCentralManager` becomes `Unauthorized`.
4. **Local DB read failure** — getters return an empty array; "no data" cannot be distinguished from "read failure".

---

## Chapter 13 — Remaining public API detail

> Chapters 2-7 document the core APIs with the full template (including samples). This chapter applies the same template to the remaining public APIs: **purpose / signature / parameters / callback / preconditions / notes**.
> **Production-test APIs are excluded here** and listed separately in 13.4.

### 13.1 Reminders and periodic monitoring

| API | Purpose | Parameters | Callback | Preconditions / notes |
| --- | --- | --- | --- | --- |
| `+ jwHrAutomaticDetectionAction:open:timeSpan:callBack:` | HR auto measurement | `isGet`; `open`; `timeSpan` 5/30/60/120 min | `(status, open, timeSpan)` | Requires `HR`; confirm supported intervals with `jwGetHRAutomaticDetectionType:` |
| `+ jwBPAutomaticDetectionAction_V3:open:timeSpan:callBack:` | BP auto measurement | same | same | Requires BP support; `_V3` is a legacy suffix |
| `+ jwTurnWristCreenActionWithIsGet:open:sensitivity:startMinute:endMinute:callBack:` | Raise-to-wake | sensitivity + minute window | `(status, open, sensitivity, startMinute, endMinute)` | Requires `LiftTheWristScreen`; window is in minutes |
| `+ jwbBrightScreenDuration:timeLength:callBack:` | Screen-on duration | 3-30 s (some firmwares 60) | `(status, timeLength, defalut)` | Legacy `jwb` prefix |
| `+ jwbBrightnessAdjustment:value:callBack:` | Brightness | 20-100 | in-method block | Requires `BrightnessControl` |
| `+ jwDialDateFormatAction:open:callBack:` | Dial date format | `false` = MM-DD, `true` = DD-MM | `(status, open)` | Requires `DialDateFormat` (41) |
| `+ jwSleepAllDayAction:open:callBack:` | All-day sleep | `isGet`, `open` | `(status, open)` | Requires `SleepAllDay` (42) |
| `+ jwHighHeartRateReminderAction:open:maxValue:callBack:` | High HR reminder | 40-220 | `(status, open, maxValue)` | Requires `HighHeartRateReminder` (43) |
| `+ jwLowOxygenReminderAction:open:callBack:` | Low SpO2 reminder | `isGet`, `open` | `(status, open)` | Requires `LowOxygenReminder` (44) |
| `+ jwContinuousBloodOxygenAction:open:callBack:` | Continuous SpO2 | `isGet`, `open` | `(status, open)` | Requires `ContinuousBloodOxygen` (51) |
| `+ jwTemperatureReminderAction:isGet:value:callBack:` | Fever reminder | 38.0-41.9 C, `0` disables | `(status, value)` | Requires `TemperatureReminder` (10004) |
| `+ jwDrinkWaterReminderAction:open:startHour:startMinute:endHour:endMinute:span:callBack:` | Drink-water reminder | `span` 30-480 min | full tuple | ⚠️ `isGet = YES` reads the **cached** `functionDataV2`; the write path returns `Success` immediately without waiting for the device. **Read back with `isGet = YES` after writing** |
| `+ jwMedicationReminderAction:alarmArr:callBack:` | Medication reminders | model array = full replacement | `(status, array)` | Requires `MedicationReminder` (10005) |
| `+ jwHeatStressReminderAction:model:callBack:` | Heat-stress reminder | `JWBleHeatStressReminderModel` | `(status, model)` | Requires `HeatStress` (36); absent from the older shipped framework |
| `+ jwFemaleAction:mode:cycleDay:menstrualDay:year:month:day:callBack:` | Female health | mode + cycle days + last period date | `(status)` | Requires `Female` (10006); **set only, no read** |
| `+ jwWeatherAction:callBack:` | Push weather | `JWBleWeatherModel` (current + <= 6) | `(status)` | Requires `Weather` (10007); the date must match the device date |
| `+ jwUserPreferencesAction:values:callBack:` | User preferences | `@[@{@"type":…, @"value":…}]` | `(status, values)` | ⚠️ read failures used to be silent (fixed 2026-09-29) |

### 13.2 Data and settings helpers

| API | Purpose | Parameters | Callback | Preconditions / notes |
| --- | --- | --- | --- | --- |
| `+ jwGetRealTimeStepWithCallback:` | Real-time steps | — | `(status, step, dis, calories)` | metres / kcal |
| `+ jwGetHRAutomaticDetectionType:` | Supported auto intervals | — | `(status, NSDictionary *)` keys `"0"/"5"/"30"/"60"/"120"` | pairs with 13.1 |
| `+ jwCountDownAction:isGet:model:callBack:` | Countdown | `JWCountDownModel` | `(status, model)` | remaining seconds when reading a running countdown |
| `+ jwStopCountDownCallBack;` | Clear the countdown callback | — | none | does **not** stop the device timer |
| `+ jwAutomaticLockScreenAction:open:callBack:` | Auto lock | — | `(status, open)` | hidden-menu feature |
| `+ jwMainInterfaceAction:willShowIndex:callBack:` | Interface style | `count+1` custom dial, `count+2` downloaded dial | `(status, curShowIndex, count)` | read first to learn `count` |
| `+ jwUpdateResourceType:type:callBack:` | Resource upgrade target | `JWUpdateResourceType` | `(status, type)` | pairs with the font-upgrade feature |
| `+ jwDialyDataSyncWithSteps:andDistance:andCalory:` | Push daily totals | `UInt32` totals | none | name typo (`Dialy`); no completion |
| `+ jwSyncSleep2Device:deep:light:startMinuteIndex:endMinuteIndex:callBack:` | Push computed sleep | level 1-5 + minutes + indices | `JWBleCommunicationCallBack` | requires `SyncSleep` (62) |
| `+ jwUpdateInterfaceColor:callBack:` | Interface colour | 1-7 | `(status)` | special firmware only |
| `+ jwGetDeviceStatusWithBlock:` | Device status | — | `int`: 0 off / 1 matching / 2 ready / 3 connected | no communication status |
| `+ jwGetMacAddressWithBlock:` | MAC address | — | `NSString *` | no communication status — cannot distinguish failure |
| `+ jwCheckDeviceBusyWithCallBack:` | Busy state | — | `JWBleBusyStateEnum` (2/3/4) | — |
| `+ jwCheckDeviceBusyStatusWithCallBack:` | Busy reasons | — | array of `JWBleBusyStatus` | overlapping with the previous one — pick one |
| `+ jwDeviceDataReset;` | Reset the device data index | — | none | ⚠️ follow with `jwRemoveDataTimeLessThan:` |
| `+ jwSyncContacts:callBack:` / `+ jwSyncSOSContacts:callBack:` | Contacts / SOS | name <= 15, phone <= 19 UTF8; max 15 / 5 | `(status, index)`; `index == 100` when clearing | requires `Address_Book` (48) / `SOS` (10002) |
| `+ jwAudioAction:open:callBack:` | Audio switch | — | `(status, open)` | — |
| `+ jwHeadphonePairing;` / `+ jwCancelHeadphonePairing;` | Headset pairing | — | none; watch `HeadphoneDeviceStatusChanged` | — |
| `+ jwModifyDeviceName:` | Rename | Chinese <= 4 chars / 12 alphanumerics | none; success triggers `SyncSuccess` | — |
| `+ jwGetDeviceSNIDWithBlock:` | Device SN | — | `(status, snID, oriContentData)` | used to parse `deviceSwitchChangeCallBack` |
| `+ jwGetDeviceCurrentBatteryWithCallBack:` | Battery (new) | — | `(status, power, charging)` | persistent callback |
| `+ jwShowText:content:` / `+ jwShowMotor:` / `+ jwTurnOffBracelet;` / `+ jwReset;` / `+ jwOpenOpus:` | Tools | — | none / `opusDataCallBack` | production-oriented |

### 13.3 Blood pressure, glucose, health assessments and customisation

| API | Purpose | Parameters | Callback |
| --- | --- | --- | --- |
| `+ jwBPV2Action:open:callBack:` | Continuous BP switch | `isGet`, `open` | `(status, open)` |
| `+ jwBPPrivateSet:h:l:callBack:` / `+ jwBPPrivateGetWithcallBack:` | Private BP baseline | systolic/diastolic | `(status)` / `(status, open, h, l)` |
| `+ jwTemperatureSwitchAction:unit:compensate:monitor:callBack:` | Temperature unit/compensation/UI | `unit` YES = C | `(status, unit, compensate, monitor)` |
| `+ jwTestBloodGlucoseAction:callBack:` | Spot glucose | `start` | `(status, JWBleTestBPStatus, int value)` — same scale as `jwPrivateBloodGlucoseAction:` (mmol/L ×10, e.g. 7.5 → 75) |
| `+ jwPrivateBloodGlucoseAction:high:low:callBack:` | Private glucose range | values **x10** | `(status, high, low)` |
| `+ jwContinuousBloodGlucoseAction:open:callBack:` | Continuous glucose | `isGet`, `open` | `(status, open)` |
| `+ jwUricAcidAction:open:privateValue:privateRtc:callBack:` | Uric acid switch/threshold | `open`/`privateValue`/`privateRtc` apply when `get == NO` | `(status, open, privateValue, privateRtc)` |
| `+ jwBloodFatAction:open:privateValue:privateRtc:callBack:` | Blood fat | same | same |
| `+ jwBloodGlucoseCycleAction:open:privateValue:privateRtc:callBack:` | Glucose cycle | same | same |
| `+ jwUricAcidContinuesMonitoringAction:open:callBack:` / `…PrivateAction:open:value:callBack:` | Uric acid continuous | `get`, `open`, `value` | `(status, open[, value])` |
| `+ jwBloodFatContinuesMonitoringAction:open:callBack:` / `…PrivateAction:open:value:callBack:` | Blood fat continuous | same | same |
| `+ jwStressContinuesMonitoringAction:open:callBack:` / `+ jwSyncStressContinuesMonitoringDataWithBlock:` | Stress continuous | `get`, `open` | `(status, open)` / `(status, array)` |
| `+ jwCommonMeasurementAction:start:` | Body-fat measurement | `BodyFat` (5) | no in-method callback → `bodyFatDataCallBack` + `endMeasurementStatusCallBack` |
| `+ jwUpdateNotiStatus:open:callBack:` / `+ jwOneTimeUpdateNotiStatus:callBack:` / `+ jwGetNotiStatusWithCallBack:` | Notifications | enum / dictionary | status / dictionary (string keys) |
| `+ jwUpdateHideFunction:open:callBack:` | Show/hide a feature | 5 supported enums | `(status)` — **now reports `Success`** |
| `+ jwDeviceFunctionShowOrHiddenAction:setDic:callBack:` | Batch show/hide | `setDic` | read returns `@{@"hideFunctionMenu": NSData}`; write reports `Faild` — use the previous API |
| `+ jwGetHealthFunctionWithCallBack:` (+ per-feature getters/setters) | Health feature display switches | — | `(status, glucoseOpen, fatOpen, uricAcidOpen)`; **hidden = YES** |
| `+ jwSetHealthFunctionWithBloodGlucoseOpen:bloodFatOpen:uricAcidOpen:withCallBack:` | **Class method (new)** | — | `(status)`; the instance-method variant is kept for compatibility only |
| `+ jwCustomCustomizationNotifyAction:open:callBack:` | Custom notifications | — | `(status, open)`; package name must be provisioned |
| `+ jwCustomSetPulseAction:minute:level:callBack:` | Pulse | minute 1-15, level 1-7 | `(status)`; data via `pulseDataCallBack` |
| `+ jwCustomSleepAidAction:time:effectTime:level:callBack:` / `_V2:mode:time:level:callBack:` | Sleep aid | time in {10,15,20,30} | `(status)` / `(status, deviceStatus)` |
| `+ jwCustomHrvRmssdAction:timeInterval:callBack:` | HRV-RMSSD | 0 off / 5 / 10 / 15 | `(status, timeInterval)` |

### 13.4 Appendix: production-test APIs (**not for third-party apps**)

These live in the "production test" section of `JWBleAction.h` and are used by factory tools. Most are "sent" semantics or have no callback.

| API | Purpose |
| --- | --- |
| `jwGeBATTERT_VOLTAGEWithBlock:` | Battery voltage |
| `jwGetPATCH_VERSIONWithBlock:` | Patch version |
| `jwGetGSENSOR_IDWithBlock:` | G-sensor id |
| `jwGetHR_IC_IDWithBlock:` | HR IC id (correct flag + chip id) |
| `jwGetHALLWithBlock:` | Hall sensor state |
| `jwSendNotiWithType:andValue:` | Push a test notification |
| `jwDefaultFunctionSettings:…` (3 overloads) / `jwGetDefaultFunctionSettings…` | Default feature switches (heat stress uses an inverted off-bit) |
| `jwProduceEnd:` | End of production test |
| `jwReadConnectedRssi:` | RSSI of the connected device |
| `jwGetDeviceHeartRateLightLeakage:callBack:` | HR light leakage |
| `jwUpdateMacAddress:callBack:` / `jwUpdateSN:callBack:` / `jwUpdateSN_V2:callBack:` | Write MAC / SN |
| `jwSetTemperature:callBack:` / `jwGetTemperatureWithCallBack:` | Temperature calibration |
| `jwGetHistoryAddress:` / `jwGetHistoryAddress_oriData:` | History data addresses |
| `doLEBroadcast` / `enterDUT` | LE broadcast / DUT mode |
| `jwGetFactoryFunctionWithCallBack:` | Factory capability list |
| `jwUpdateTpModel:callBack:` / `jwGetTpInfoWithCallBack:` | TP feature and info |
| `jwGetLicense:` / `jwSetLicense:key:mac:sn:callBack:` | License |
| `jwPIDAction:pid:callBack:` | PID |
| `jwGetOriSleepDataWithCallBack:` | Raw sleep data |
| `jwGetDeviceTestResultWithCallBack:` | Device test result |
| `jwSteFirmwareBurningConfiguration:callBack:` / `jwGetFirmwareBurningConfigurationWithCallBack:` | Firmware burning config |
| `jwGetIcEuidWithCallBack:` | IC EUID |
| `jwDvtCheckAction:index:callBack:` | DVT check |
| `jwGetResourceOTAStatusWithCallBack:` | Resource OTA status |
| `jwGetDebugShowWithCallBack:` | Debug show |
| `jwSettingDeviceLaohuaWithCallBack:` | Ageing mode |
| `jwGetDeviceUV:callBack:` | UV level |
