# JWBle SDK Call Flow Diagrams

> 🌐 Language: [中文](SDK调用时序图.md) ｜ **English**

> All diagrams are drawn from the current SDK source (`JWBleManager`, `JWBleCommunicationManager`, `WristBand`, `WristBandEvent`, `JWBleAction`, `JWBleDataAction`, `JWBleOTAAction`).
> "Comm" = `JWBleCommunicationManager` and "Band" = `WristBand`; both are internal implementation classes. Third parties only see `JWBleManager` / `JWBleAction` / `JWBleDataAction` / `JWBleOTAAction`.

---

## 1. SDK initialisation

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Mgr as JWBleManager
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    App->>Mgr: shareInstance
    Mgr->>Mgr: apply defaults isAutoShowPair, checkUserBinding, cacheLogCount
    Mgr->>Comm: register connection-state forwarding
    Comm->>BLE: create CBCentralManager and observe notifications
    Mgr-->>App: manager instance

    App->>Mgr: setUpWithUid
    Mgr->>Comm: setUpWithUid
    Comm->>Comm: compare uid
    Comm->>Mgr: initialise JWBleOTAAction
    alt uid changed and isProduce == NO
        Comm->>Band: reConnect from the local binding record
        Band->>BLE: wbSearchDevice with the service UUID list
    end

    BLE-->>Comm: BlePowerChangedNotification
    Comm-->>App: centralManagerStateChangeBlock(state)
    BLE-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack(Connect / DisConnect)
    Band-->>Comm: WbSyncEndNotification
    Comm-->>App: connectStateChangeCallBack(SyncSuccess)
```

Key points: auto-reconnect is not attempted before `setUpWithUid:`; an identical `uid` is ignored; the Bluetooth state callback is registered during initialisation.

---

## 2. Device scanning

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    App->>Act: jwStartScanDeviceWithCallBack (or ...WithTimeout)
    Act->>Comm: startScanDeviceWithCallBack
    Comm->>Comm: clear the discovered-peripheral list
    Comm->>Band: wbSearchDevice with 6 service UUIDs
    Band->>BLE: scanForPeripheralsWithServices
    Band->>BLE: retrieveConnectedPeripheralsWithServices
    loop each advertisement
        BLE-->>Band: didDiscoverPeripheral
        Band-->>Comm: BleDeviceDiscoveredNotification
        alt FD50 advertised without manufacturerData
            Comm->>Comm: defer the callback until manufacturerData arrives
        else first time this CBPeripheral is seen
            Comm->>Comm: parse MAC, build JWBleDeviceModel
            Comm-->>App: scanCallBack(model) on the main thread
        else already reported
            Comm->>Comm: ignore (de-duplication)
        end
    end
    App->>Act: jwStopScanDevice
    Act->>Comm: stopScanDevice
    Comm->>Band: wbStopSearchDevice
    Band->>BLE: stopScan
```

Key points: scanning never stops by itself (unless you use the timeout variant), and each peripheral is only reported once.

---

## 3. Device connection (binding and sync)

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth
    participant Dev as Band device

    App->>Act: jwConnectDevice
    Act->>Comm: connectPeripherals
    Comm->>Comm: clear cached functionDataV2
    Comm->>Comm: isConnecing = true, start the 60 s timeout timer
    Comm->>Band: bleConnectDevice
    Band->>BLE: connectPeripheral

    alt sync not finished within 60 s
        Comm-->>App: connectStateChangeCallBack(TimeOutDisconnect)
        Comm->>Band: jwDisConnectNotUnBond
    end

    BLE-->>Band: didConnectPeripheral
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack(Connect)

    Band->>Dev: login, password check, binding
    Dev-->>Band: binding result
    Band-->>Comm: WbBondFinishedNotification
    Comm-->>App: connectStateChangeCallBack(BondSuccess / BondFailure)

    Band->>Dev: request feature list, device info, hidden menu, switch data
    loop each data packet
        Dev-->>Band: response
        Band-->>Comm: WbSyncEndNotification(type)
        Comm->>Comm: accumulate into deviceBaseInfoModel
    end
    Comm->>Comm: infoFull / infoSNQRFull reached
    Comm->>Comm: build connedModel (battery, MAC, versions, ...)
    Comm-->>App: connectStateChangeCallBack(SyncSuccess)
    App->>App: device ready

    alt sync failed
        Comm-->>App: connectStateChangeCallBack(SyncFailure)
        Comm->>Band: jwDisConnectNotUnBond
    end
```

Four layers: `Connect` (BLE link only) → `BondSuccess` (login/binding) → `SyncSuccess` (device info ready = device ready) → business commands allowed.

---

## 4. Disconnect and auto-reconnect

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant Comm as Comm
    participant Band as Band
    participant BLE as CoreBluetooth

    rect rgb(255, 245, 245)
    Note over App,BLE: Deliberate disconnect - no auto-reconnect
    App->>Act: jwDisConnect or jwDisConnectNotUnBond
    Act->>Band: wbUnbond or wbUnbindFinishedProcessNotClean
    Band->>Band: activeDisconnect = true
    Band->>BLE: cancelPeripheralConnection
    BLE-->>Band: didDisconnectPeripheral
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack(DisConnect)
    end

    rect rgb(245, 255, 245)
    Note over App,BLE: Unexpected disconnect - auto-reconnect
    BLE-->>Band: didDisconnectPeripheral(error)
    Band->>Band: activeDisconnect == false and isProduce == NO
    Band-->>Comm: BleConnectionStatusChangedNotification
    Comm-->>App: connectStateChangeCallBack(DisConnect)
    Band->>BLE: connectPeripheral immediately
    Band->>BLE: wbSearchDevice again
    loop every 3 seconds
        Band->>BLE: retrieveConnectedPeripheralsWithServices
        alt matches the stored binding UUID and is not connected
            Band->>BLE: connectPeripheral
        end
    end
    end

    rect rgb(255, 250, 235)
    Note over App,BLE: Bluetooth turned off
    BLE-->>Band: centralManagerDidUpdateState(PoweredOff)
    Band->>Band: stop scanning, clear caches
    Band-->>Comm: BlePowerChangedNotification
    Comm-->>App: connectStateChangeCallBack(DisConnect)
    Comm-->>App: centralManagerStateChangeBlock(PoweredOff)
    end
```

Key point: auto-reconnect is controlled **only** by `isProduce` — there is no public toggle and no retry limit.

---

## 5. Health data sync

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Data as JWBleDataAction
    participant Comm as Comm
    participant Band as Band
    participant Dev as Band device
    participant DB as Local SQLite

    App->>Data: jwSyncDataWithCallBack
    Data->>Comm: check isConnected and isDFU
    alt not connected
        Data-->>App: Faild + Interrupt
    else device in DFU mode
        Data-->>App: IsDFUModel + Interrupt
    else normal
        Data-->>App: Success + Start
        Data->>Band: wbSyncDataWithCallBack
        Band->>Dev: request history packets
        loop each packet
            Dev-->>Band: data
            Band-->>Comm: data callback
            Comm-->>App: synchronousDataProgressCallBack(cur, total)
            Band->>DB: persist steps / sleep / HR / BP / ...
        end
        Dev-->>Band: sync finished with totals
        alt status == 1
            Band->>Band: calibrate and write back if required
            Data-->>App: Success + Complete
        else status == 2
            Data-->>App: Faild + InconsistentTotals
        else anything else
            Data-->>App: Faild + Interrupt
        end
    end

    App->>Data: jwGetXxxByYYYYMMDDStr
    Data->>DB: synchronous local query
    Data-->>App: data array / dictionary
```

Key point: read APIs never touch the device; since 2026-09-29 they are purely read-only (no implicit deletion).

---

## 6. Spot measurement (heart rate)

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant Band as Band
    participant Dev as Band device

    App->>Act: jwTestHRAction(start = true)
    Act->>Band: send the measurement command
    Band->>Dev: measurement request
    Act-->>App: testStatus = TestStart
    loop measuring
        Dev-->>Band: state and data
        Band-->>Act: callback
        Act-->>App: testStatus = DeviceResponse
    end
    Dev-->>Band: finished with hrValue
    Act-->>App: testStatus = TestEnd (hrValue)

    Note over App,Dev: the device is busy meanwhile - other commands may return Busy
```

---

## 7. Multi-sport control

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant Mgr as JWBleManager
    participant Band as Band
    participant Dev as Band device

    App->>Act: jwCheckFunctionStates(APPControlMotion)
    Act-->>App: Open or NotSupport
    App->>Act: jwQuerySupportedDeviceMotionTypes
    Band->>Dev: query supported sports
    Dev-->>Band: list
    Act-->>App: motion types array

    App->>Act: jwStartDeviceMotion(motionType)
    Act->>Act: validate connection, DFU, feature bit and Busy
    Band->>Dev: 0x5C command
    Dev-->>Band: 0x5D status/result
    Band-->>Act: status model
    Act-->>App: callBack(status, JWBleMotionStatusModel)
    Band-->>Mgr: WBDeviceMotionStatusNotification
    Mgr-->>App: deviceMotionStatusChangeCallBack

    alt state becomes Running or Paused
        loop while exercising
            Dev-->>Band: 0x5E realtime data
            Band-->>Mgr: WBDeviceMotionRealtimeDataNotification
            Mgr-->>App: deviceMotionRealtimeDataCallBack
        end
    end

    alt no 0x5D within 6 seconds
        Act-->>App: callBack(Faild, nil)
    end

    App->>Act: jwStopDeviceMotion
    Band->>Dev: 0x5C stop
    Dev-->>Band: 0x5D result
    Act-->>App: callBack(Success, model)
    Note over Band: after a successful stop or disconnect, realtime data stops
```

---

## 8. OTA upgrade

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Act as JWBleAction
    participant OTA as JWBleOTAAction
    participant RTK as RTKDFUUpgrade
    participant Dev as Band device

    App->>Act: jwCheckOTAEnableWithCallBack
    Act->>Dev: query device state
    Dev-->>Act: deviceStatus
    Act-->>App: status + deviceStatus (0 = ready to upgrade, 1 = device busy, other = not ready; -1 when the request failed)

    App->>OTA: startOTAV2ForWithData:prefersUpgradeUsingOTAMode:
    alt empty firmware data
        OTA-->>App: FileNotExist
    else no available peripheral
        OTA-->>App: PeripheralIsNull
    else normal
        OTA->>RTK: initWithPeripheral, prepareForUpgrade
        RTK-->>OTA: ready
        OTA-->>App: Start
        loop transferring
            RTK->>Dev: chunked write
            RTK-->>OTA: progress
            OTA-->>App: Updating(didSend, totalLength)
        end
        alt success
            OTA-->>App: Success
        else failure
            OTA-->>App: Failure
        else FSBL check enabled and version matches
            OTA-->>App: VersionConsistent
        end
        Note over OTA,Dev: otaIng is true during the upgrade; scan requests are ignored
    end
```

---

## 9. Watch face customisation

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant Cust as JWBleCustomizeMainInterfaceAction
    participant Dev as Band device

    App->>Cust: startWithImage:previewImage:configModel:...
    Cust-->>App: actionCallBack(MakingResourcePack)
    alt empty image
        Cust-->>App: PictureIsEmpty
    else image parsing failed
        Cust-->>App: FailedToParseImage
    else resource pack failed
        Cust-->>App: FailedToMakeResourcePack
    else normal
        Cust-->>App: actionCallBack(Transmission)
        loop transferring
            Cust->>Dev: chunked watch-face data
            Cust-->>App: updateCallBack(didSend, totalLength)
        end
        alt success
            Cust-->>App: actionCallBack(Success)
        else failure
            Cust-->>App: actionCallBack(Failure)
        end
    end
```

---

## 10. Diagram index

| Flow | Entry point | Result callback |
| --- | --- | --- |
| SDK init | `shareInstance` + `setUpWithUid:` | `centralManagerStateChangeBlock`, `connectStateChangeCallBack` |
| Scan | `jwStartScanDeviceWithCallBack:` | `JWBleReceiveScanningDeviceCallBack` |
| Connect | `jwConnectDevice:` | `connectStateChangeCallBack` (`Connect` → `BondSuccess` → `SyncSuccess`) |
| Disconnect / reconnect | `jwDisConnect` etc. | `connectStateChangeCallBack` (`DisConnect` / `TimeOutDisconnect`) |
| Data sync | `jwSyncDataWithCallBack:` | `JWBleSyncCallBack` + `synchronousDataProgressCallBack` |
| Data read | `JWBleDataAction` getters | in-method block (local DB) |
| Spot measurement | `jwTestHRAction:` etc. | in-method block (state machine) |
| Multi-sport | `jwStartDeviceMotion:` etc. | in-method block + 2 property callbacks |
| OTA | `startOTAV2ForWithData:…` | `JWBleDFUCallBack` |
| Watch face | `startWithImage:…` | `JWBleCustomizeMainInterfaceActionCallBack` + `JWBleDFUCallBack` |
