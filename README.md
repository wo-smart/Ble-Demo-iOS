# Wo-Smart Technologies Bluetooth SDK and Demo 

## SDK 文档 / SDK Documentation

随包文档位于 `iOS/Document/sdk-docs/`，与本次更新后的 **JWBle 1.3.2** 编译包一致：

| 中文 | English |
| --- | --- |
| [SDK接入指南](iOS/Document/sdk-docs/SDK接入指南.md) | [Integration Guide](iOS/Document/sdk-docs/SDK_Integration_Guide_EN.md) |
| [SDK_API文档](iOS/Document/sdk-docs/SDK_API文档.md) | [API Reference](iOS/Document/sdk-docs/SDK_API_Reference_EN.md) |
| [SDK设备能力矩阵](iOS/Document/sdk-docs/SDK设备能力矩阵.md) | [Device Capability Matrix](iOS/Document/sdk-docs/SDK_Device_Capability_Matrix_EN.md) |
| [SDK调用时序图](iOS/Document/sdk-docs/SDK调用时序图.md) | [Call Flow Diagrams](iOS/Document/sdk-docs/SDK_Call_Flow_Diagrams_EN.md) |

示例工程：`iOS/JWBleSdkDemo`（完整功能 Demo）、`iOS/JWBleProtocolDemo`（协议调试 Demo），两者内置的 `JWBle.framework` 已同步为本次编译包；SDK 库文件另见 `iOS/SDK/`。

集成前置依赖与 Xcode 配置（bitcode、蓝牙权限、FMDB 等）见 [中文简体说明](iOS/Document/中文简体说明.md) / [English Description](iOS/Document/English%20Description.md)。

## iOS  Version Description

| Version |                         Description                          |
| :-----: | :----------------------------------------------------------: |
|  1.3.2  |      1：hrv-rmssd time zone 2:fixed setting sleep goal       |
|  1.3.1  |                       1：add hrv-rmssd                       |
|  1.3.0  |                    1：fix hrv time zone;                     |
|  1.1.0  | 1: New data function, body fat;<br/>2: Added data exception cleaning function;<br/>3: Optimize known issues; |
| 1.0.18  | Fix the problem of sending a large number of steps to the device abnormally |
| 1.0.17  | 1: Three cycle data optimization;<br/>2: Repair synchronization timeout does not work;<br/>3: Custom dial added to return data callback;<br/>4: Add ecgoridatacallback; |
| 1.0.16  |                   1:Optimize 3 cycle data                    |
| 1.0.15  | 1: Add the current resource version number and return to JWBleDeviceModel.resourceVersionCode;<br/>2: Optimize the sleep data duplication problem; |
| 1.0.14  | 1: Fix [JWBleDataAction jwTemperatureCalibration:xx]; abnormal value;<br/>2: Message notification, add full open example; |
| 1.0.13  | 1) Fix: When JWBleManager.isProduce = true; The device is connected to the system and automatically reconnects the device;<br/><br/>2) Fix: sleep data returns abnormal value |
| 1.0.12  | 1.sleep add filter method <br />[JWBleDataAction jwGetFilterSleepDataByYYYYMMDDStr:dateString callBack:^(NSArray *dataArr) { }]; |
| 1.0.11  | 1.Weather function optimization<br />2.Added 【uric acid】function |
| 1.0.10  |        }];1. Fix sedentary reminder weekly repeat bug        |
|  1.0.9  | 1.optimize heart rate data storage, adapt to different firmware versions |
|  1.0.8  | 1. Added female and weather functions;<br/>2. Delete the abnormal value of heart rate; |
