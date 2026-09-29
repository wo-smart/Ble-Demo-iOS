# JWBle SDK 设备能力矩阵

> 🌐 语言 / Language: **中文** ｜ [English](SDK_Device_Capability_Matrix_EN.md)

> 本文档说明**不同设备支持能力存在差异**时，第三方应如何判断与适配。
> 依据来源：`JWBleFunctionEnum` 功能位、`JWBleDeviceSwitchFunctionEnum` 开关位、`customizedFunctionDic`、`JWBleDeviceModel` 字段、Demo/文档与实现代码。
> **能力一律以运行时接口返回为准**，不要按设备名称或型号推断；本文给出的每个判断方式都可直接落到代码里。

---

## 一、核心结论（先读这一节）

1. **SDK 不提供“型号 → 功能”映射**：能力判断全部基于设备上报的功能位/开关位/定制位，与型号无关，因此不需要在 App 内维护型号清单。
2. **SDK 提供了运行时能力查询接口**，包括：
   - `+[JWBleAction jwCheckFunctionStates:]`（功能位）
   - `+[JWBleAction jwCheckControlSwitchStates:]`（可控开关值）
   - `+[JWBleAction jwCheckHideFunctionStates:]`（隐藏功能菜单）
   - `+[JWBleAction jwCheckCustomFunctionStates:]`（客户定制功能）
   - `+[JWBleAction jwQuerySupportedDeviceMotionTypes:]`（支持的运动类型列表）
3. **正确做法**：设备同步完成（`JWBleDeviceConnectStatus_SyncSuccess`）后，通过上述接口动态判断，然后决定是否展示/调用对应功能。**不要把型号判断写死在 App 里**。
4. 能力查询接口全部**只读缓存**，依赖 `JWBleManager.connectionModel` 中的 `functionData`、`functionDataV2`、`deviceSwitchData`、`hideFunctionMenu`、`customizedFunctionDic`，这些字段在同步完成前为空 → 未同步时统一返回“不支持”。

---

## 二、能力判断的数据来源

| 来源 | 对应模型字段 | 判断接口 | 说明 |
| --- | --- | --- | --- |
| 功能数据（两种编码） | `JWBleDeviceModel.functionData` | `jwCheckFunctionStates:` | **同一字段有两种编码，SDK 按长度自动判定**：长度 ≤ 8 字节 → 位图（bitmap）；长度 > 8 字节 → 字节下标（byte index）。详见 2.1 |
| 功能列表 V2 | `JWBleDeviceModel.functionDataV2` | `jwCheckFunctionStates:` | 数组形式，元素 `@{@"type": @(功能号 - 10000)}`；列表中存在即支持 |
| 可控开关 | `JWBleDeviceModel.deviceSwitchData` | `jwCheckControlSwitchStates:` | 返回开关当前值，`-1` 表示不支持 |
| 隐藏功能菜单 | `JWBleDeviceModel.hideFunctionMenu` | `jwCheckHideFunctionStates:` | 仅 5 个功能支持（见下） |
| 客户定制功能 | `JWBleDeviceModel.customizedFunctionDic` | `jwCheckCustomFunctionStates:` | 脉冲 / 辅助睡眠 / 桑拿 |
| 多运动类型列表 | 协议 0x5C 查询返回 | `jwQuerySupportedDeviceMotionTypes:` | 设备实报，**唯一权威来源** |
| 芯片差异 | `chipType`（0 = C 芯片 / 1 = D（VD）版本）、`platform`（0 = rtk / 100 = 联睿微） | 无查询接口，读字段 | 影响表盘资源打包等流程 |

### ⚠️ 判断优先级建议

```
1. 先判断 jwCheckFunctionStates: 是否为 Open/Close/NotSupport
2. 再判断 jwCheckControlSwitchStates: 是否返回 -1（不支持该设置）
3. 隐藏功能额外判断 jwCheckHideFunctionStates:
4. 多运动类型必须以 jwQuerySupportedDeviceMotionTypes: 的返回为准
5. 客户定制功能判断 jwCheckCustomFunctionStates:
```

### 2.1 重要：`functionData` 有两种编码（能力判断口径随设备而变）

`+[JWBleAction jwCheckFunctionStates:]` 内部按 `functionData.length` 走两条不同分支（`JWBleAction.m` 第 854~960 行）：

| 分支 | 触发条件 | 解码方式 | 可能返回的值 | 依据 |
| --- | --- | --- | --- | --- |
| **A. 位图模式** | `functionData.length <= 8` | 按内置 `switch` 表把枚举映射为 `(byteIndex, bitIndex)`，取 `(byte >> bit) & 0x01` | **只可能返回 `Open`(3) 或 `NotSupport`(2)** | 静态映射表共 58 项 |
| **B. 字节下标模式** | `functionData.length > 8` | `NSMakeRange(functionEnum, 1)`，即**枚举值就是字节下标** | `0`/`2` → `NotSupport`；`1` → `Close`；其他 → `Open` | 依赖枚举值的连续性 |

**对第三方的直接影响**

1. **同品牌不同批次的设备可能走不同分支**，因此：
   - 只能依赖返回值判断“是否支持”（`!= NotSupport`）与“是否开启”（`== Open`）；
   - **不要假设 `Close` 一定会出现**——位图模式永远不会返回 `Close`；
   - **不要假设 `NotSupport` 等于 0**——它是 `0 | 2`，即 **2**。
2. 位图模式支持的功能是**白名单**（仅 58 项）；未列入 `switch` 的功能（含全部 `10001~10016` 与部分基础功能）走 `default` → 直接返回 `NotSupport`。
   例如 `WearingTime`、`MedicationReminder` 等 V2 段功能，在 8 字节位图设备上必然返回“不支持”。
3. 字节下标模式下功能号必须小于 `functionData.length`，否则返回 `NotSupport`；该模式的隐含契约是“枚举值 = 字节下标”，因此**在枚举中间插入新成员会导致老固件全部错位**。

> 建议统一封装，不要散落写死：
>
> ```objc
> static inline BOOL JWBLE_FunctionSupported(JWBleFunctionEnum e) {
>     return [JWBleAction jwCheckFunctionStates:e] != JWBleFunctionStateEnum_NotSupport;
> }
> static inline BOOL JWBLE_FunctionEnabled(JWBleFunctionEnum e) {
>     return [JWBleAction jwCheckFunctionStates:e] == JWBleFunctionStateEnum_Open;
> }
> ```
>
> 完整位图映射表（58 项）见《SDK_API文档.md》第 11.3 节。

---

## 三、能力查询接口速查

| 接口 | 返回值 | 语义 | 前置条件 |
| --- | --- | --- | --- |
| `+ (JWBleFunctionStatesEnum)jwCheckFunctionStates:(JWBleFunctionEnum)e;` | `Open = 3` / `Close = 1` / `NotSupport = 2` | 支持且开启 / 支持但关闭 / 不支持 | 已 `SyncSuccess` |
| `+ (int)jwCheckControlSwitchStates:(JWBleDeviceSwitchFunctionEnum)e;` | `-1` 或具体值 | `-1` 表示不支持该设置 | 已 `SyncSuccess` |
| `+ (JWBleHideFunctionStatesEnum)jwCheckHideFunctionStates:(JWBleFunctionEnum)e;` | `NotSupport = 0` / `Show = 1` / `Hidden = 2` | 隐藏功能菜单状态 | 已 `SyncSuccess`；仅 5 个功能有效 |
| `+ (JWBleFunctionStatesEnum)jwCheckCustomFunctionStates:(JWBleCustomFunctionEnum)e;` | 同 `JWBleFunctionStatesEnum` | 客户定制功能状态 | 已 `SyncSuccess` |
| `+ (void)jwQuerySupportedDeviceMotionTypes:(JWBleDeviceMotionTypeListCallBack)cb;` | `NSArray<NSNumber *>` | 设备支持的运动类型（`JWBleDeviceMotionEnum`）；**不支持多运动时成功返回空数组** | 已连接 |

### 3.1 `JWBleFunctionStatesEnum` 取值陷阱

```objc
typedef NS_ENUM (NSInteger, JWBleFunctionStatesEnum) {
    JWBleFunctionStateEnum_NotSupport = 0 | 2,  // = 2
    JWBleFunctionStateEnum_Close = 1,
    JWBleFunctionStateEnum_Open = 3
};
```

- `NotSupport` 的值是 `0 | 2`，即 **2**，不是 0；
- 代码中常用 `!= NotSupport` 判断“是否支持”（如 `jwCheckFunctionStates:JWBleFunctionEnum_APPControlMotion != NotSupport`），第三方请保持一致；
- 枚举名与枚举类型名不一致（类型为 `JWBleFunctionStatesEnum`，成员用 `JWBleFunctionStateEnum_` 前缀）。

---

## 四、功能能力矩阵（按功能分类）

> “判断方式”即第三方在运行时应调用的接口；“不可静态判断”表示必须运行时查询。

### 4.1 设备与通信

| 功能 | 判断方式 | 依据 | 说明 |
| --- | --- | --- | --- |
| 设备扫描 | 无（默认支持） | — | 所有 SDK 支持设备均可被扫描 |
| 设备连接/绑定 | 无（默认支持） | — | 连接成功后 `connectionModel` 有值 |
| 多语言 | `jwCheckFunctionStates:JWBleFunctionEnum_MoreLanguage` | 功能位 | 支持的语种见 `JWBleLanguageEnum` |
| OTA 升级 | `jwCheckFunctionStates:JWBleFunctionEnum_OTA`；升级前再调 `jwCheckOTAEnableWithCallBack:` | 功能位 | `deviceStatus == 0` 才建议直接升级 |
| 显示字库升级 | `JWBleFunctionEnum_DisplayFontUpgrade`（55） | 功能位 | 配合 `jwUpdateResourceType:` 使用 |
| 资源升级 | `jwUpdateResourceType:type:callBack:` + `JWUpdateResourceType` 枚举 | 功能位 + 设备返回 | 共 5 种：主显示资源 / 显示字库 / 主界面字库 / 自定义界面资源 / 表盘市场资源；单次上传是否成功以回调 `status` 为准 |
| SN / MAC / 版本查询 | 无（默认支持） | 设备信息同步 | `connectionModel.versionName/versionCode/macAddress` |
| 生产测试能力 | `jwGetFactoryFunctionWithCallBack:` | 设备实报 | 产测专用，第三方通常不使用 |

### 4.2 屏幕与交互

| 功能 | 判断方式 | 依据 | 说明 |
| --- | --- | --- | --- |
| 亮屏时长 | `jwCheckFunctionStates:JWBleFunctionEnum_BrightScreenDuration` | 功能位 | 上限因固件而异（注释 3~30s，实际有 60s 的设备）→ **必须按设备实报** |
| 亮度控制 | `jwCheckFunctionStates:JWBleFunctionEnum_BrightnessControl` | 功能位 | 取值 20~100 |
| 抬腕/转腕亮屏 | `jwCheckFunctionStates:JWBleFunctionEnum_LiftTheWristScreen` | 功能位 | 另可读 `jwCheckControlSwitchStates:Gesture_Bright_Screen` |
| 主界面风格 | `jwCheckFunctionStates:JWBleFunctionEnum_MainInterfaceStyle` | 功能位 | 实际风格数量以 `jwMainInterfaceAction:` 回调的 `count` 为准 |
| 自定义主界面（表盘） | `jwCheckFunctionStates:JWBleFunctionEnum_MainInterfaceStyle_Customize`（58） | 功能位 | 另有 `MainInterfaceStyle_Download`（57）表示下载表盘 |
| 表盘日期格式 | `jwCheckFunctionStates:JWBleFunctionEnum_DialDateFormat`（41） | 功能位 | MM-DD / DD-MM |
| 自动锁屏 | `jwCheckHideFunctionStates:JWBleFunctionEnum_AutomaticLockScreen` | 隐藏功能菜单 | 仅 5 个功能走隐藏菜单 |
| 双按键滑动 | `jwCheckHideFunctionStates:JWBleFunctionEnum_TwoButtonSliding` | 隐藏功能菜单 | 同上 |
| 语音助手 | `jwCheckHideFunctionStates:JWBleFunctionEnum_VoiceAssistant` | 隐藏功能菜单 | 同上 |
| 界面颜色 | **无能力查询接口** | — | 头文件注明“仅支持特殊手环固件”；如有该需求，请提供目标机型由我方确认支持情况 |
| 常驻显示文本 / 马达 | **无能力查询接口** | — | `jwShowText:content:`、`jwShowMotor:` 属工具类接口 |

### 4.3 提醒与通知

| 功能 | 判断方式 | 依据 | 说明 |
| --- | --- | --- | --- |
| 消息通知 | `jwCheckFunctionStates:JWBleFunctionEnum_Noti`；具体 App 开关用 `jwGetNotiStatusWithCallBack:` | 功能位 + 通知数据 | 支持的 App 列表由设备决定，需以读取结果为准 |
| 来电/短信等分类 | `JWBleNotiEnum` + `jwGetNotiStatusWithCallBack:` | 通知数据 | 读取返回的是字符串 key 字典 |
| 久坐提醒 | `jwCheckFunctionStates:JWBleFunctionEnum_SedentaryReminder` | 功能位 | 间隔 30~240 分钟 |
| 智能闹钟（旧） | `jwCheckFunctionStates:JWBleFunctionEnum_SmartAlarmClock` | 功能位 | 全量覆盖式设置 |
| 智能闹钟 2.0 | `jwCheckFunctionStates:JWBleFunctionEnum_SmartAlarmClockV2`（59） | 功能位（62 段） | 单条增删改 |
| 事件提醒 | `jwCheckFunctionStates:JWBleFunctionEnum_EventReminder` | 功能位 | SDK 仅提供功能位查询，未提供设置接口 |
| 心率提醒（上限） | `jwCheckFunctionStates:JWBleFunctionEnum_HeartRateReminder` + `HighHeartRateReminder`（43） | 功能位 | 上限 40~220 |
| 低氧提醒 | `LowOxygenReminder`（44） | 功能位 | — |
| 体温提醒 | `TemperatureReminder`（10004） | 功能位（V2 段） | 阈值 38.0~41.9℃ |
| 喝水提醒 | `DrinkWaterReminder`（10003） | 功能位（V2 段） | 间隔 30~480 分钟 |
| 吃药提醒 | `MedicationReminder`（10005） | 功能位（V2 段） | 模型数组操作 |
| 热应激提醒 | `HeatStress`（36） | 功能位 | 模型 `JWBleHeatStressReminderModel`（1.3.2 起随 framework 交付） |
| 运动不足提醒 | **无能力查询接口** | — | `jwSettingCustomExerciseLack` 无参数无回调 |
| SOS | `SOS`（10002） | 功能位（V2 段） | 最多 5 个联系人 |
| 通讯录 | `Address_Book`（48） | 功能位 | 最多 15 条 |
| 女性健康 | `Female`（10006） | 功能位（V2 段） | — |
| 天气 | `Weather`（10007） | 功能位（V2 段） | 当前天气 + ≤6 天预报 |
| 勿扰模式 | `jwCheckFunctionStates:JWBleFunctionEnum_DoNotDisturbMode` | 功能位 | 三种情景 |

### 4.4 健康监测

| 功能 | 判断方式 | 依据 | 说明 |
| --- | --- | --- | --- |
| 心率 | `JWBleFunctionEnum_HR` | 功能位 | 手动点测 `jwTestHRAction:` |
| 实时心率 | `JWBleFunctionEnum_RealTimeHeartRate`；运动心率另需 `APP_MOTION_HR_V2`（53） | 功能位 | 实时数据走 `JWBleManager` 回调 |
| 心率自动检测 | `JWBleFunctionEnum_HR` + `jwGetHRAutomaticDetectionType:` | 功能位 + 设备实报 | 返回支持的间隔集合 |
| 血压 | `JWBleFunctionEnum_BloodPressureTest` | 功能位 | 手动点测 |
| 连续血压 2.0 | `JWBleFunctionEnum_BloodPressureV2`（60） | 功能位 | `jwBPV2Action:open:callBack:` |
| 设备血压监测 | `DeviceBPMonitoring`（46） | 功能位 | — |
| 私人血压 | `DevicePrivateBloodPressure`（10001） | 功能位（V2 段） | — |
| 血氧 | `JWBleFunctionEnum_Blood_Oxygen`（56） | 功能位 | 点测 |
| 连续血氧 | `ContinuousBloodOxygen`（51） | 功能位 | `jwContinuousBloodOxygenAction:` |
| 体温 | `JWBleFunctionEnum_Temperature`（61） | 功能位 | 依赖连续心率（`JWBleTestTemperatureStatus_NotOpen` 表示未开连续心率） |
| 压力 | `Stress`（37） | 功能位 | 支持连续监测（`jwStressContinuesMonitoringAction:`） |
| ECG | `JWBleFunctionEnum_ECG`（50） | 功能位 | 波形/指标走 `JWBleManager` 回调 |
| ECG 隐藏 QT/HRV | `ECGHidden_HRV_QT`（40） | 功能位 | 控制是否展示 QT/HRV |
| ECG Belt | `JWBleFunctionEnum_Belt`（39） | 功能位 | `jwBeltAction:` |
| HRV | `HRV`（47） | 功能位 | 数据读取见 `jwGetHrvDataByYYYYDDStr:` |
| 血糖 | `BloodGlucose`（45） | 功能位 | 点测 + 私人值 |
| 连续血糖 | `BloodGlucose_Monitoring`（开关） | 可控开关 | `jwContinuousBloodGlucoseAction:` |
| 周期血糖 | `BloodGlucoseCycle`（10011） | 功能位（V2 段） | 14 天周期数据 |
| 血脂 | `BloodFat`（10010） | 功能位（V2 段） | 含连续监测 |
| 尿酸 | `UricAcid`（10009） | 功能位（V2 段） | 含连续监测 |
| 尿酸/血脂连续监测（私人模式） | `UricAcid_ContinuesMonitoring_Private`（10012）、`BloodFat_ContinuesMonitoring_Private`（10013） | 功能位（V2 段） | 另有 `UricAcidContinuesMonitoring` / `BloodFatContinuesMonitoring` 可控开关 |
| 体脂 | `BodyFat`（10014） | 功能位（V2 段） | `jwCommonMeasurementAction:`（`BodyFat = 5`） |
| 微体检 | `MicroPhysicalExamination`（10015） | 功能位（V2 段） | 8 项指标 |
| 紫外线 | `UV`（10016） | 功能位（V2 段） | 等级值 |
| 佩戴时间 | `WearingTime`（10008） | 功能位（V2 段） | 佩戴状态数据读取 |
| 全天睡眠 | `SleepAllDay`（42） | 功能位 | — |
| 睡眠质量判断 2.0 | `SleepQualityJudgment_V2`（54） | 功能位 | 本地算法 `jwSleepQualityCalculation:` 始终可用 |
| 健康功能隐藏 | `Health_Hidden`（38） | 功能位 | 另有 `jwGetHealthFunctionWithCallBack:` 读取血糖/血脂/尿酸显示开关 |
| 数据校准 | `DataCalibration`（63） | 功能位 | 同步后 SDK 内部自动处理 |
| 同步睡眠给设备 | `SyncSleep`（62） | 功能位 | `jwSyncSleep2Device:…` |

### 4.5 运动

| 功能 | 判断方式 | 依据 | 说明 |
| --- | --- | --- | --- |
| 多运动（App 控制设备） | `JWBleFunctionEnum_APPControlMotion`（35） | 功能位 | 能力列表必须以 `jwQuerySupportedDeviceMotionTypes:` 为准 |
| 运动类型枚举 | 上述查询接口返回 | 设备实报 | `JWBleDeviceMotionEnum` 共 29 种运动 |
| 历史运动记录 | `JWBleFunctionEnum_ExerciseMore` | 功能位 | `jwGetMotionDataByYYYYMMDDStr:` |
| 秒表 | `jwCheckHideFunctionStates:JWBleFunctionEnum_StopwatchTiming` | 隐藏功能菜单 | SDK 仅提供功能位查询，未提供启停接口 |
| 倒计时 | `JWBleFunctionEnum_Countdown` | 功能位 | `jwCountDownAction:` |
| 查找手机 | `jwCheckHideFunctionStates:JWBleFunctionEnum_FindPhone` | 隐藏功能菜单 | 设备侧触发 |
| 遥控拍照 | `JWBleFunctionEnum_RemotePhotography` | 功能位 | — |
| 音乐 / 音量控制 | `MusicControl`、`VolumeControl` | 功能位 | SDK 仅提供功能位查询，未提供控制接口 |
| 微信运动 | `JWBleFunctionEnum_WeChatRun` | 功能位 | — |
| 耳机通话 / 耳机状态 | `JWBleFunctionEnum_HeadphoneCall` | 功能位 | 配对状态走 `connectionModel.headphoneDeviceStatus` |

### 4.6 客户定制功能

| 功能 | 判断方式 | 依据 |
| --- | --- | --- |
| 脉冲 | `jwCheckCustomFunctionStates:JWBleCustomFunctionEnum_SetPulse` | `customizedFunctionDic` |
| 辅助睡眠 | `jwCheckCustomFunctionStates:JWBleCustomFunctionEnum_SleepAid` | `customizedFunctionDic` |
| 桑拿 | `jwCheckCustomFunctionStates:JWBleCustomFunctionEnum_Sauna` | `customizedFunctionDic` |
| 客户定制消息通知 | `jwCustomCustomizationNotifyAction:open:callBack:` | 需向 SDK 提供方申请对应包名 |

---

## 五、已知的设备差异证据（来自代码与工程文档）

以下差异均已在 SDK 代码或工程文档中确认，可作为适配参考：

| 差异点 | 依据 | 说明 |
| --- | --- | --- |
| 亮屏时长上限不同 | 提交记录与代码注释冲突（30s vs 60s） | 部分设备（虎麟）上限提到 60s；**必须以设备实报为准** |
| 芯片类型差异 `chipType` | `JWBleDeviceModel.chipType`（0 = C 正常芯片，1 = D/VD 版本） | 影响表盘资源打包流程（`JWBleCustomizeMainInterfaceAction.m` 按 `chipType` 分支） |
| 芯片平台差异 `platform` | `JWBleDeviceModel.platform`（0 = rtk，100 = 联睿微） | 影响底层通信实现 |
| 是否支持隐藏功能菜单 | `hideFunctionMenu` 位图 | 仅在功能位 `HideFunctionMenu` 为 3 且非产测模式时才请求 |
| 涂鸦（FD50）协议设备 | 扫描时按 `FD50` 服务识别；扫描需等待 `manufacturerData` 到达才回调 | 该类型设备广播 MAC 可能延迟到达 |
| 双协议服务（自有 / 涂鸦） | 扫描服务 UUID 列表中同时包含 `000001ff-…`、`FD50`、`00006287-…` 等 | 不同设备使用不同服务/特征，SDK 内部统一处理 |
| 部分设备连接后会监听 FD04 服务导致弹窗 | 提交记录：W39、V35S 在生产模式下取消该监听 | 属生产模式差异 |
| 冷启动配对弹窗 | `isAutoShowPair`（默认 YES） | 部分设备/固件会弹系统配对框，可关闭 |
| SN 快速扫描模式 | `isSNQR` | 决定是否全量获取设备信息，影响同步完成条件 |

---

## 六、型号维度矩阵

SDK 不提供型号与能力的映射表，也不按型号分支判断能力。**请不要在 App 里维护“型号 → 功能”表**，改为在运行时使用第四节的能力查询接口动态渲染功能入口：

```objc
// 设备同步完成后（JWBleDeviceConnectStatus_SyncSuccess）再查询
BOOL hasHr  = [JWBleAction jwCheckFunctionStates:JWBleFunctionEnum_HeartRate];
BOOL hasSpo2 = [JWBleAction jwCheckFunctionStates:JWBleFunctionEnum_BloodOxygen];
```

如需某型号的出厂能力清单，请提供目标型号，由我方业务/技术支持确认后提供。

---

## 七、按机型确认的能力项（SDK 侧无查询接口）

| 序号 | 项目 | 说明与处理方式 |
| --- | --- | --- |
| 1 | 设备型号清单及各型号能力 | SDK 不提供；请以运行时功能位查询结果为准 |
| 2 | 界面颜色（`jwUpdateInterfaceColor:`）支持条件 | 头文件注明仅特殊固件支持；请提供目标机型由我方确认 |
| 3 | 自定义表盘分机型接口（`jwCustomizeRoundMainInterfaceAction:`、`jwCustomizeGT5MainInterfaceAction:`、`jwCustomize_1_47_MainInterfaceAction:`、`jwCustomize_238_MainInterfaceAction:`、`wbSetCustomizeV102MainInterface:`） | 后缀是本 SDK 内部对表盘资源的机型/尺寸代号；建议统一改用 `JWBleCustomizeMainInterfaceAction` 的显式 `deviceWidth:deviceHeight:` 版本，无需按型号选择接口 |
| 4 | 秒表、音乐控制、音量控制、事件提醒的调用接口 | SDK 未提供公开调用接口（仅有功能位查询）；如需通过客户定制通道实现，请与我方联系 |
| 5 | `JWUpdateResourceType` 各资源类型支持情况 | 无独立查询接口；上传结果以 `jwUpdateResourceType:type:callBack:` 的回调状态为准 |
| 6 | 亮屏时长上限 | 不同固件不同（3~30s，部分机型 60s）；设置前先读取当前值并按设备实报展示 |
| 7 | 耳机相关功能 | 由 `RTKAudioConnectSDK` 提供，`JWBle.framework` 未暴露公开接口；需要时请联系我方获取该通道接入说明 |
| 8 | `platform = 100`（联睿微）设备差异 | SDK 透传该字段；能力差异请以运行时查询结果为准 |
| 9 | 产测模式（`isProduce = YES`）行为差异 | 产测模式下 SDK 会关闭自动回连与连接超时重试、跳过 OTA 电量门槛、按需清空本地库、取消 FD04 服务监听等；正式 App 请保持 `isProduce = NO` |
