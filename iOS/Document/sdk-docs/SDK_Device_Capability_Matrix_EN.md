# JWBle SDK Device Capability Matrix

> 🌐 Language: [中文](SDK设备能力矩阵.md) ｜ **English**

> How to handle the fact that devices differ in supported features.
> Sources: `JWBleFunctionEnum` feature data, `JWBleDeviceSwitchFunctionEnum` switch data, `customizedFunctionDic`, `JWBleDeviceModel` fields, the demo/docs and the implementation.
> **Always decide capabilities from runtime query results** — never from a device name or model. Every check in this document maps directly to code.

---

## 1. Key conclusions (read this first)

1. **The SDK ships no model → feature map.** Capabilities come from the feature/switch/custom flags reported by the device itself, so there is no model list to maintain in your app.
2. The SDK **does** provide runtime capability queries:
   - `+[JWBleAction jwCheckFunctionStates:]` (feature data)
   - `+[JWBleAction jwCheckControlSwitchStates:]` (controllable switch value)
   - `+[JWBleAction jwCheckHideFunctionStates:]` (hidden menu)
   - `+[JWBleAction jwCheckCustomFunctionStates:]` (customised features)
   - `+[JWBleAction jwQuerySupportedDeviceMotionTypes:]` (supported sport types)
3. **Correct approach**: after `SyncSuccess`, query these APIs and render/call features dynamically. Do not hard-code model checks.
4. All capability queries are **cache reads** backed by `JWBleManager.connectionModel`. Before sync completes they report "not supported".

---

## 2. Data sources for capability decisions

| Source | Model field | Query API | Notes |
| --- | --- | --- | --- |
| Feature data (**two encodings**) | `JWBleDeviceModel.functionData` | `jwCheckFunctionStates:` | `length <= 8` → bitmap; `length > 8` → byte index. See 2.1 |
| Feature list V2 | `JWBleDeviceModel.functionDataV2` | `jwCheckFunctionStates:` | `@{@"type": @(value - 10000)}`; presence means supported |
| Controllable switches | `JWBleDeviceModel.deviceSwitchData` | `jwCheckControlSwitchStates:` | returns the value, `-1` = unsupported |
| Hidden menu | `JWBleDeviceModel.hideFunctionMenu` | `jwCheckHideFunctionStates:` | only 5 features |
| Customised features | `JWBleDeviceModel.customizedFunctionDic` | `jwCheckCustomFunctionStates:` | pulse / sleep aid / sauna |
| Sport types | protocol 0x5C response | `jwQuerySupportedDeviceMotionTypes:` | device-reported, the only authority |
| Chip differences | `chipType` (0 = C, 1 = D/VD), `platform` (0 = RTK, 100 = Lianrui Micro) | fields only | affects dial packaging |

### 2.1 Important: `functionData` has two encodings

`+[JWBleAction jwCheckFunctionStates:]` switches on `functionData.length` (`JWBleAction.m` lines 854-960):

| Branch | Condition | Decoding | Possible results |
| --- | --- | --- | --- |
| **A. Bitmap** | `functionData.length <= 8` | Built-in `switch` maps the enum to `(byteIndex, bitIndex)`, result `(byte >> bit) & 0x01` | **Only `Open`(3) or `NotSupport`(2)** |
| **B. Byte index** | `functionData.length > 8` | `NSMakeRange(functionEnum, 1)` — the enum value *is* the byte index | `0`/`2` → NotSupport, `1` → Close, else → Open |

Impact for integrators:

1. Devices from the same vendor can use either branch:
   - decide support with `!= NotSupport` and enablement with `== Open`;
   - **do not assume `Close` ever appears** — the bitmap branch never returns it;
   - **do not assume `NotSupport == 0`** — it is `0 | 2` = **2**.
2. The bitmap branch is a **58-entry whitelist**; anything not listed (including all `10001-10016`) goes to `default` and returns "not supported". For example `WearingTime` and `MedicationReminder` always report unsupported on 8-byte-bitmap devices.
3. In the byte-index branch the feature value must be `< functionData.length`; the implicit contract "enum value = byte index" means **inserting a member in the middle shifts every later feature**.

Recommended wrappers:

```objc
static inline BOOL JWBLE_FunctionSupported(JWBleFunctionEnum e) {
    return [JWBleAction jwCheckFunctionStates:e] != JWBleFunctionStateEnum_NotSupport;
}
static inline BOOL JWBLE_FunctionEnabled(JWBleFunctionEnum e) {
    return [JWBleAction jwCheckFunctionStates:e] == JWBleFunctionStateEnum_Open;
}
```

The full 58-entry bitmap mapping is in `SDK_API_Reference_EN.md` section 11.3.

---

## 3. Capability query cheat sheet

| API | Return value | Semantics | Precondition |
| --- | --- | --- | --- |
| `+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:(JWBleFunctionEnum)e;` | `Open = 3` / `Close = 1` / `NotSupport = 2` | supported+enabled / supported+disabled / unsupported | `SyncSuccess` |
| `+ (int)jwCheckControlSwitchStates:(JWBleDeviceSwitchFunctionEnum)e;` | `-1` or the value | `-1` = unsupported | `SyncSuccess` |
| `+ (JWBleHideFunctionStatesEnum)jwCheckHideFunctionStates:(JWBleFunctionEnum)e;` | `NotSupport = 0` / `Show = 1` / `Hidden = 2` | hidden menu state | `SyncSuccess`; 5 features only |
| `+ (JWBleFunctionStatesEnum)jwCheckCustomFunctionStates:(JWBleCustomFunctionEnum)e;` | same as above | customised features | `SyncSuccess` |
| `+ (void)jwQuerySupportedDeviceMotionTypes:(JWBleDeviceMotionTypeListCallBack)cb;` | `NSArray<NSNumber *>` | supported sports; **empty array = multi-sport unsupported** | connected |

---

## 4. Feature capability matrix (by area)

### 4.1 Device and communication

| Feature | How to check | Backing | Notes |
| --- | --- | --- | --- |
| Scanning / connecting | always available | — | — |
| Multiple languages | `jwCheckFunctionStates:JWBleFunctionEnum_MoreLanguage` | feature | 18 languages |
| OTA | `jwCheckFunctionStates:JWBleFunctionEnum_OTA` + `jwCheckOTAEnableWithCallBack:` | feature | only `deviceStatus == 0` starts silently |
| Display-font upgrade | `DisplayFontUpgrade` (55) | feature | used with `jwUpdateResourceType:` |
| Resource upgrade | `jwUpdateResourceType:type:callBack:` | feature + resource version | the 5 resource types are not all guaranteed |
| SN / MAC / version | always available after sync | device info | `connectionModel` |

### 4.2 Screen and interaction

| Feature | How to check | Notes |
| --- | --- | --- |
| Screen-on duration | `BrightScreenDuration` | upper bound varies per firmware (header says 3-30 s, some devices reach 60 s) — use the device-reported value |
| Brightness | `BrightnessControl` | 20-100 |
| Raise-to-wake | `LiftTheWristScreen` + `jwCheckControlSwitchStates:Gesture_Bright_Screen` | — |
| Main interface style | `MainInterfaceStyle` | actual count comes from the `jwMainInterfaceAction:` callback |
| Custom dial | `MainInterfaceStyle_Customize` (58) | download dial: `MainInterfaceStyle_Download` (57) |
| Dial date format | `DialDateFormat` (41) | MM-DD / DD-MM |
| Auto lock | `jwCheckHideFunctionStates:AutomaticLockScreen` | hidden menu |
| Two-button sliding / voice assistant | hidden menu | — |
| Interface colour | **no query API** | header notes "special firmware only"; give us the target model and we will confirm support |

### 4.3 Reminders and notifications

| Feature | How to check | Notes |
| --- | --- | --- |
| Notifications | `Noti` + `jwGetNotiStatusWithCallBack:` | the app list is device-defined |
| Sedentary | `SedentaryReminder` | 30-240 min |
| Alarm (legacy / 2.0) | `SmartAlarmClock` / `SmartAlarmClockV2` (59) | do not mix the two APIs |
| Event reminder | `EventReminder` | feature-bit query only; the SDK exposes no setup API |
| HR reminder | `HeartRateReminder` + `HighHeartRateReminder` (43) | 40-220 |
| Low SpO2 / fever / drink / medication | `LowOxygenReminder` (44), `TemperatureReminder` (10004), `DrinkWaterReminder` (10003), `MedicationReminder` (10005) | V2 segment |
| Heat stress | `HeatStress` (36) | absent from the older shipped framework |
| SOS / address book / female / weather | `SOS` (10002), `Address_Book` (48), `Female` (10006), `Weather` (10007) | — |
| DND | `DoNotDisturbMode` | three scenarios |

### 4.4 Health monitoring

| Feature | How to check | Notes |
| --- | --- | --- |
| Heart rate | `HR` | spot measurement |
| Real-time HR | `RealTimeHeartRate`; motion HR also needs `APP_MOTION_HR_V2` (53) | continuous callback |
| BP | `BloodPressureTest`; continuous BP 2.0: `BloodPressureV2` (60) | private BP: `DevicePrivateBloodPressure` (10001) |
| SpO2 | `Blood_Oxygen` (56); continuous: `ContinuousBloodOxygen` (51) | — |
| Temperature | `Temperature` (61) | depends on continuous HR (`NotOpen` means continuous HR is off) |
| Stress | `Stress` (37) | supports continuous monitoring |
| ECG / belt | `ECG` (50) / `Belt` (39); `ECGHidden_HRV_QT` (40) | waveforms via `JWBleManager` callbacks |
| HRV | `HRV` (47) | — |
| Blood glucose | `BloodGlucose` (45); continuous switch; cycle: `BloodGlucoseCycle` (10011) | — |
| Blood fat / uric acid | `BloodFat` (10010) / `UricAcid` (10009) (+ private continuous variants) | V2 segment |
| Body fat | `BodyFat` (10014) | `jwCommonMeasurementAction:` |
| Micro physical exam | `MicroPhysicalExamination` (10015) | 8 metrics |
| UV / wearing time | `UV` (10016) / `WearingTime` (10008) | V2 segment |
| All-day sleep / sleep quality 2.0 | `SleepAllDay` (42) / `SleepQualityJudgment_V2` (54) | local algorithm always available |
| Health feature hiding | `Health_Hidden` (38) + `jwGetHealthFunctionWithCallBack:` | note "hidden = YES" |
| Data calibration / sync sleep | `DataCalibration` (63) / `SyncSleep` (62) | handled internally on sync |

### 4.5 Sport

| Feature | How to check | Notes |
| --- | --- | --- |
| App-controlled multi-sport | `APPControlMotion` (35) | the sport list must come from `jwQuerySupportedDeviceMotionTypes:` |
| History records | `ExerciseMore` | `jwGetMotionDataByYYYYMMDDStr:` |
| Stopwatch | hidden menu | feature-bit query only; the SDK exposes no start/stop API |
| Countdown | `Countdown` | — |
| Find phone | hidden menu | device triggered |
| Remote camera | `RemotePhotography` | — |
| Music / volume control | `MusicControl`, `VolumeControl` | feature-bit query only; the SDK exposes no control API |
| WeChat Sports | `WeChatRun` | — |
| Headset | `HeadphoneCall` | state via `connectionModel.headphoneDeviceStatus` |

### 4.6 Customised features

| Feature | How to check |
| --- | --- |
| Pulse | `jwCheckCustomFunctionStates:JWBleCustomFunctionEnum_SetPulse` |
| Sleep aid | `…SleepAid` |
| Sauna | `…Sauna` |
| Custom notifications | `jwCustomCustomizationNotifyAction:open:callBack:` (package name must be provisioned) |

---

## 5. Known device differences (evidence-backed)

| Difference | Evidence | Notes |
| --- | --- | --- |
| Screen-on duration limit varies | commit history vs header comment (30 s vs 60 s) | always trust the device-reported value |
| `chipType` | 0 = C (normal), 1 = D/VD | affects dial resource packaging |
| `platform` | 0 = RTK, 100 = Lianrui Micro | affects the low-level transport |
| Hidden menu availability | `hideFunctionMenu` bitmap | requested only when the feature bit is 3 and not in production mode |
| Tuya (`FD50`) devices | recognised during scan; the callback waits for `manufacturerData` | their advertised MAC may arrive late |
| Dual-protocol services | scan list contains `000001ff-…`, `FD50`, `00006287-…` etc. | different devices use different services |
| W39 / V35S FD04 popup | commit history: the FD04 listener is disabled in production mode | production-mode difference |
| Pairing popup | `isAutoShowPair` (default YES) | some firmwares show the system pairing dialog |
| SN fast-scan mode | `isSNQR` | affects the sync-completion condition |

---

## 6. Model-level matrix

The SDK ships no model→feature map and never branches on a model. **Do not maintain such a table in your app** — render feature entries from the runtime queries in section 4:

```objc
// Query after sync completes (JWBleDeviceConnectStatus_SyncSuccess)
BOOL hasHr   = [JWBleAction jwCheckFunctionStates:JWBleFunctionEnum_HeartRate];
BOOL hasSpo2 = [JWBleAction jwCheckFunctionStates:JWBleFunctionEnum_BloodOxygen];
```

If you need the factory capability list for a specific model, send us the model number and our support team will confirm it.

---

## 7. Per-model items (no SDK-side query API)

| # | Item | How to handle |
| --- | --- | --- |
| 1 | Supported model list and per-model capabilities | not provided by the SDK; use the runtime feature queries |
| 2 | Conditions for `jwUpdateInterfaceColor:` | header notes "special firmware only"; give us the target model and we will confirm |
| 3 | Which model/resolution each of the 8 watch-face APIs targets (`jwCustomizeRoundMainInterfaceAction:`, `jwCustomizeGT5MainInterfaceAction:`, `jwCustomize_1_47_MainInterfaceAction:`, `jwCustomize_238_MainInterfaceAction:`, `wbSetCustomizeV102MainInterface:`) | these suffixes are the SDK's internal resource codes; call `JWBleCustomizeMainInterfaceAction` with an explicit `deviceWidth:deviceHeight:` instead and no model selection is needed |
| 4 | Stopwatch / music / volume / event reminder APIs | the SDK exposes no public call API (feature-bit queries only); contact us if you need them through the custom-command channel |
| 5 | Support for each `JWUpdateResourceType` | no dedicated query; the upload result comes back in the `jwUpdateResourceType:type:callBack:` status |
| 6 | Real screen-on duration limit | differs per firmware (3-30 s, some models 60 s); read the current value first and show what the device reports |
| 7 | Headset features | provided by `RTKAudioConnectSDK`; not exposed by `JWBle.framework` — contact us for that channel |
| 8 | Feature differences for `platform = 100` (Lianrui Micro) | the SDK passes the field through; decide capabilities from runtime queries |
| 9 | Production-mode (`isProduce = YES`) behaviour | in production mode the SDK disables auto-reconnect and connect-timeout retries, skips the OTA battery threshold, may clear the local database and skips the FD04 listener; keep `isProduce = NO` in shipping apps |
