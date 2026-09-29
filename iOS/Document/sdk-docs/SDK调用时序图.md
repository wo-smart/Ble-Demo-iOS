# JWBle SDK 调用时序图

> 🌐 语言 / Language: **中文** ｜ [English](SDK_Call_Flow_Diagrams_EN.md)

> 全部时序图依据当前 SDK 源码绘制（`JWBleManager`、`JWBleCommunicationManager`、`WristBand`、`WristBandEvent`、`JWBleAction`、`JWBleDataAction`、`JWBleOTAAction`）。
> 图中「Comm」= `JWBleCommunicationManager`（内部实现，不对外暴露），「Band」= `WristBand`（内部实现）。
> 第三方只能看到 `JWBleManager` / `JWBleAction` / `JWBleDataAction` / `JWBleOTAAction` 这一层，其余参与者用于说明内部时序。

---

## 一、SDK 初始化时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Mgr as JWBleManager
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    App->>Mgr: shareInstance
    Mgr->>Mgr: 设置默认值 isAutoShowPair, checkUserBinding, cacheLogCount
    Mgr->>Comm: 注册连接状态回调转发
    Comm->>BLE: 创建 CBCentralManager 并注册通知监听
    Mgr-->>App: manager 实例

    App->>Mgr: setUpWithUid uid
    Mgr->>Comm: setUpWithUid uid
    Comm->>Comm: 对比 uid 是否变化
    Comm->>Mgr: shareInstance 初始化 JWBleOTAAction
    alt uid 变化且 isProduce 为 NO
        Comm->>Band: reConnect 读取本地绑定记录
        Band->>BLE: wbSearchDevice 服务 UUID 列表
    end

    BLE-->>Comm: BlePowerChangedNotification
    Comm-->>App: centralManagerStateChangeBlock state
    BLE-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack Connect 或 DisConnect
    Band-->>Comm: WbSyncEndNotification
    Comm-->>App: connectStateChangeCallBack SyncSuccess
```

**关键点**

- 未调用 `setUpWithUid:` 时不会触发自动回连。
- `uid` 与上次相同则整段初始化被忽略。
- 初始化阶段就会注册系统蓝牙状态回调，App 可立即获知 `PoweredOn` 并开始扫描。

---

## 二、设备扫描时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    App->>Act: jwStartScanDeviceWithCallBack
    Act->>Comm: startScanDeviceWithCallBack
    Comm->>Comm: 清空已扫描外设列表
    Comm->>Band: wbSearchDevice 6 个服务 UUID
    Band->>BLE: scanForPeripheralsWithServices
    Band->>BLE: retrieveConnectedPeripheralsWithServices 系统已连接设备
    loop 每个广播
        BLE-->>Band: didDiscoverPeripheral
        Band-->>Comm: BleDeviceDiscoveredNotification
        alt 广播带 FD50 但无 manufacturerData
            Comm->>Comm: 暂缓回调 等待后续广播
        else 该 CBPeripheral 未回调过
            Comm->>Comm: 解析 MAC 组装 JWBleDeviceModel
            Comm-->>App: scanCallBack model 主线程
        else 已回调过
            Comm->>Comm: 忽略 去重
        end
    end
    App->>Act: jwStopScanDevice
    Act->>Comm: stopScanDevice
    Comm->>Band: wbStopSearchDevice
    Band->>BLE: stopScan
```

**关键点**：SDK 不会自动停止扫描，也没有扫描超时；同一外设只回调一次。

---

## 三、设备连接时序（含绑定与同步）

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth
    participant Dev as 手环设备

    App->>Act: jwConnectDevice model
    Act->>Comm: connectPeripherals model
    Comm->>Comm: 清空缓存 functionDataV2
    Comm->>Comm: isConnecing 置 true 启动 60 秒超时定时器
    Comm->>Band: bleConnectDevice peripheral
    Band->>BLE: connectPeripheral

    alt 60 秒内未完成同步
        Comm-->>App: connectStateChangeCallBack TimeOutDisconnect
        Comm->>Band: jwDisConnectNotUnBond
    end

    BLE-->>Band: didConnectPeripheral
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack Connect

    Band->>Dev: 登录 校验密码 绑定
    Dev-->>Band: 绑定结果
    Band-->>Comm: WbBondFinishedNotification
    Comm-->>App: connectStateChangeCallBack BondSuccess 或 BondFailure

    Band->>Dev: 请求功能列表 设备信息 隐藏功能 开关数据
    loop 每个数据包
        Dev-->>Band: 数据响应
        Band-->>Comm: WbSyncEndNotification type
        Comm->>Comm: 累积到 deviceBaseInfoModel
    end
    Comm->>Comm: infoFull 或 infoSNQRFull 完成
    Comm->>Comm: 组装 connedModel 电量 MAC 版本 等
    Comm-->>App: connectStateChangeCallBack SyncSuccess
    App->>App: 设备 Ready 可调用业务 API

    alt 同步失败
        Comm-->>App: connectStateChangeCallBack SyncFailure
        Comm->>Band: jwDisConnectNotUnBond
    end
```

**四层状态对照**

| 层次 | 回调 | 含义 |
| --- | --- | --- |
| BLE 链路建立 | `Connect` | 仅蓝牙连上，设备信息尚未获取 |
| 绑定完成 | `BondSuccess` | 登录/绑定成功 |
| 信息同步完成 | `SyncSuccess` | 功能列表、设备信息、电量、MAC、版本等就绪 → **设备 Ready** |
| 可正常收发指令 | 以 `SyncSuccess` 为界 | 之前调用业务 API 可能失败 |

---

## 四、断开与自动重连时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    rect rgb(255, 245, 245)
    Note over App,BLE: 主动断开 不触发自动重连
    App->>Act: jwDisConnect 或 jwDisConnectNotUnBond
    Act->>Band: wbUnbond 或 wbUnbindFinishedProcessNotClean
    Band->>Band: activeDisconnect 置 true
    Band->>BLE: cancelPeripheralConnection
    BLE-->>Band: didDisconnectPeripheral
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack DisConnect
    end

    rect rgb(245, 255, 245)
    Note over App,BLE: 异常断开 触发自动重连
    BLE-->>Band: didDisconnectPeripheral error
    Band->>Band: activeDisconnect 为 false 且 isProduce 为 NO
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack DisConnect
    Band->>BLE: connectPeripheral 立即重连
    Band->>BLE: wbSearchDevice 重新扫描
    loop 每 3 秒
        Band->>BLE: retrieveConnectedPeripheralsWithServices
        alt 命中本地绑定 UUID 且未连接
            Band->>BLE: connectPeripheral
        end
    end
    end

    rect rgb(255, 250, 235)
    Note over App,BLE: 蓝牙被关闭
    BLE-->>Band: centralManagerDidUpdateState PoweredOff
    Band->>Band: 停止扫描 清空缓存
    Band-->>Comm: BlePowerChangedNotification
    Comm-->>App: connectStateChangeCallBack DisConnect
    Comm-->>App: centralManagerStateChangeBlock PoweredOff
    end
```

**关键点**：自动重连**只受 `isProduce` 控制**，没有公开的开关属性，也没有次数上限（持续重试）。

---

## 五、健康数据同步时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Data as JWBleDataAction
    participant Comm as Comm
    participant Band as Band
    participant Dev as 手环设备
    participant DB as 本地 SQLite

    App->>Data: jwSyncDataWithCallBack
    Data->>Comm: 校验 isConnected 与 isDFU
    alt 未连接
        Data-->>App: Faild 加 Interrupt
    else 设备处于 DFU 模式
        Data-->>App: IsDFUModel 加 Interrupt
    else 正常
        Data-->>App: Success 加 Start
        Data->>Band: wbSyncDataWithCallBack
        Band->>Dev: 请求历史数据分包
        loop 每个分包
            Dev-->>Band: 数据包
            Band-->>Comm: 数据回调
            Comm-->>App: synchronousDataProgressCallBack cur total
            Band->>DB: 写入步数 睡眠 心率 血压 等
        end
        Dev-->>Band: 同步结束与总数
        alt status 等于 1
            Band->>Band: 需要数据校准则先校准并回写设备
            Data-->>App: Success 加 Complete
        else status 等于 2
            Data-->>App: Faild 加 InconsistentTotals
        else 其他
            Data-->>App: Faild 加 Interrupt
        end
    end

    App->>Data: jwGetStepDataByYYYYMMDDStr 等读取
    Data->>DB: 同步查询本地数据
    Data-->>App: 直接回调数据数组或字典
```

**关键点**：读取接口**不访问设备**，只读本地数据库；重复读取部分接口会删除重复记录（见《SDK_API文档.md》6.2 节）。

---

## 六、健康点测时序（以心率为例）

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant Band as Band
    participant Dev as 手环设备

    App->>Act: jwTestHRAction start 为 true
    Act->>Band: 下发点测指令
    Band->>Dev: 点测请求
    Act-->>App: testStatus TestStart
    loop 测量过程
        Dev-->>Band: 状态与数据
        Band-->>Act: 回调
        Act-->>App: testStatus DeviceResponse
    end
    Dev-->>Band: 测量结束 hrValue
    Act-->>App: testStatus TestEnd 携带 hrValue

    Note over App,Dev: 点测期间设备繁忙 其他指令可能返回 Busy
    Note over App,Dev: 测量失败时 testStatus 为 TestField 血压另有 TestInterrupt
```

---

## 七、多运动控制时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant Mgr as JWBleManager
    participant Band as Band
    participant Dev as 手环设备

    App->>Act: jwCheckFunctionStates APPControlMotion
    Act-->>App: Open 或 NotSupport
    App->>Act: jwQuerySupportedDeviceMotionTypes
    Band->>Dev: 查询支持的运动类型
    Dev-->>Band: 类型列表
    Act-->>App: 回调运动类型数组

    App->>Act: jwStartDeviceMotion motionType
    Act->>Act: 校验连接 DFU 功能位 与 Busy
    Band->>Dev: 0x5C 指令
    Dev-->>Band: 0x5D 状态与结果
    Band-->>Act: 状态模型
    Act-->>App: callBack status 加 JWBleMotionStatusModel
    Band-->>Mgr: WBDeviceMotionStatusNotification
    Mgr-->>App: deviceMotionStatusChangeCallBack

    alt 状态进入 Running 或 Paused
        loop 运动过程中
            Dev-->>Band: 0x5E 实时数据
            Band-->>Mgr: WBDeviceMotionRealtimeDataNotification
            Mgr-->>App: deviceMotionRealtimeDataCallBack
        end
    end

    alt 6 秒内无 0x5D 响应
        Act-->>App: callBack Faild 且 model 为 nil
    end

    App->>Act: jwStopDeviceMotion
    Band->>Dev: 0x5C 停止
    Dev-->>Band: 0x5D 停止结果
    Act-->>App: callBack Success 加 model
    Note over Band: 停止成功或断开后 不再回调实时数据
```

**关键点**：同一时刻只允许一个待处理的多运动请求；设备响应才是权威结果。

---

## 八、OTA 升级时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Act as JWBleAction
    participant OTA as JWBleOTAAction
    participant RTK as RTKDFUUpgrade
    participant Dev as 手环设备

    App->>Act: jwCheckOTAEnableWithCallBack
    Act->>Dev: 查询设备状态
    Dev-->>Act: deviceStatus
    Act-->>App: status + deviceStatus（0 可直接升级、1 设备繁忙，其余为设备未就绪；请求失败时 status 为失败、deviceStatus 为 -1）

    App->>OTA: startOTAV2ForWithData data prefersUpgradeUsingOTAMode
    alt 升级包为空
        OTA-->>App: FileNotExist
    else 当前无可升级外设
        OTA-->>App: PeripheralIsNull
    else 正常
        OTA->>RTK: initWithPeripheral prepareForUpgrade
        RTK-->>OTA: 准备完成
        OTA-->>App: Start
        loop 传输中
            RTK->>Dev: 分包写入
            RTK-->>OTA: 进度
            OTA-->>App: Updating didSend totalLength
        end
        alt 升级成功
            OTA-->>App: Success 且 didSend 等于 totalLength
        else 升级失败
            OTA-->>App: Failure
        else 启用 FSBL 校验且版本一致
            OTA-->>App: VersionConsistent
        end
        Note over OTA,Dev: 升级期间 otaIng 为 true 扫描请求被忽略
    end
```

---

## 九、表盘自定义时序

```mermaid
sequenceDiagram
    autonumber
    participant App as App
    participant Cust as JWBleCustomizeMainInterfaceAction
    participant Dev as 手环设备

    App->>Cust: startWithImage previewImage configModel 等
    Cust-->>App: actionCallBack MakingResourcePack
    alt 图片为空
        Cust-->>App: PictureIsEmpty
    else 图片解析失败
        Cust-->>App: FailedToParseImage
    else 资源包制作失败
        Cust-->>App: FailedToMakeResourcePack
    else 正常
        Cust-->>App: actionCallBack Transmission
        loop 传输中
            Cust->>Dev: 分包写入表盘资源
            Cust-->>App: updateCallBack didSend totalLength
        end
        alt 成功
            Cust-->>App: actionCallBack Success
        else 失败
            Cust-->>App: actionCallBack Failure
        end
    end
```

---

## 十、时序图汇总表

| 时序 | 起点 API | 结果回调 |
| --- | --- | --- |
| SDK 初始化 | `shareInstance` + `setUpWithUid:` | `centralManagerStateChangeBlock`、`connectStateChangeCallBack` |
| 设备扫描 | `jwStartScanDeviceWithCallBack:` | `JWBleReceiveScanningDeviceCallBack` |
| 设备连接 | `jwConnectDevice:` | `connectStateChangeCallBack`（`Connect` → `BondSuccess` → `SyncSuccess`） |
| 断开/重连 | `jwDisConnect` 等 | `connectStateChangeCallBack`（`DisConnect` / `TimeOutDisconnect`） |
| 数据同步 | `jwSyncDataWithCallBack:` | `JWBleSyncCallBack` + `synchronousDataProgressCallBack` |
| 数据读取 | `JWBleDataAction` getter | 方法内 Block（读本地库） |
| 点测 | `jwTestHRAction:` 等 | 方法内 Block（测试状态机） |
| 多运动 | `jwStartDeviceMotion:` 等 | 方法内 Block + `deviceMotionStatusChangeCallBack` / `deviceMotionRealtimeDataCallBack` |
| OTA | `startOTAV2ForWithData:…` | `JWBleDFUCallBack` |
| 表盘自定义 | `startWithImage:…` | `JWBleCustomizeMainInterfaceActionCallBack` + `JWBleDFUCallBack` |
