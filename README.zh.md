# BorneoIoT: 开源 WiFi 智能水族灯 DIY 套件

![Firmware Build Status](https://github.com/oldrev/borneo/actions/workflows/fw-ci.yml/badge.svg)
![App Build Status](https://github.com/oldrev/borneo/actions/workflows/flutter-ci.yml/badge.svg)

![BorneoIoT Banner](assets/borneo-repo-banner.jpg)

[English](README.md) | 中文

---

Borneo-IoT 项目是一套商业级、高度可自定义的开源智能 WiFi 水族 LED 灯具 PWM 控制器和手机 App，并且包含了一个 5 颜色通道 63W 的 LED 成品灯具作为参考设计。 

详情和文档请参阅本项目网站：[www.borneoiot.com](https://www.borneoiot.com).
中英文硬件规格书已包括在此仓库中：[hw/datasheets](hw/datasheets)

如果喜欢本项目请别忘记点亮星标，谢谢！

## 功能特性

- **全栈开源**
    - WiFi LED 控制器模块（核心板）的原理图、PCB 的 [Horizon EDA](https://horizon-eda.org) 设计源文件
    - 一个 5 通道 63W 灯具参考设计的原理图、PCB 的 Horizon EDA 设计源文件
    - 使用[乐鑫 ESP-IDF](https://idf.espressif.com/) 框架开发的全套固件源代码
    - 使用的 Flutter 开发的移动端 App 全套源代码
- **高度可自定义的模块化设计**
    - 控制器模块核心板仅为 2cm x 3.5cm 大小，易于集成
    - 不便于使用核心板的情况下也可以参考原理图将单片机和外围电路集成到自定义 PCB 上
    - 组件化的固件架构：
        - 独立的板级定义，可支持不同家族的 Espressif 单片机，无需修代码就能同时支持 ESP32/ESP32-C3/ESP32-C5 等等全系列；
        - 固件架构采用了我研发的类似 Zephyr RTOS 的驱动和初始化管理框架进行集成，底层与应用功能分离
    - 通用 CoAP + CBOR 底层协议，手机 App 可支持灯具、滴定泵、温度计等不同设备；
- **功能齐全**
    - 手机操作的独立五通道 PWM LED 控制器，仅需要极少的外围元件
    - 控制器自主多段式日出日落图形调光、灯光软起动，并提供简易设置模式
    - 基于 SNTP 协议的自动对时
    - 基于 PID 的全自动散热风扇控制和完整的保护功能
    - 提供设备通信的 Python 客户端库和演示脚本
    - 可选的外围 INA139 电流监测
- **预算友好**
    - 主控单片机采用流行的低成本 ESP32-C3（5 通道版）或者 ESP32 (10 通道版)，不需要特殊定制任何元件
    - 通过内建调压电路可直接驱动最便宜的两线散热风扇，当然也能够支持 PWM 调速风扇
    - 核心板默认采用排针连接方便 DIY 爱好者
- **可量产**[^1]
    - 设备支持无线 OTA 方式直接从服务器下载固件升级
    - 提供具备 GUI 的量产治具和软件：
        - 自动烧录固件
        - 自动 QA 测试
        - 根据整体产品自动设置产品名称、型号、序列号、PID 参数、初始参数等
- **实战验证**
    - 此控制器和 LED 驱动方案的原型已在我自己的鱼缸上稳定运行了几年

还有更多难以列举，如基于此固件和 App 架构正在开发中的滴定泵和 pH 监测器。

[^1]: 此开源仓库不提供量产相关治具和软件。

## 演示图片与视频

- Youtube: TODO
- Bilibili: TODO

https://github.com/user-attachments/assets/08cb37ea-8b35-413a-9ee4-c4d95e3cb3bf


| ![BLC05MK3](assets/blc05mk3.jpg) <br/> LED 控制器模块外观 | ![BLC05MK3-SCH](assets/blc05mk3-sch.png) <br/> LED 控制器模块原理图 |
|------------------------------------------|------------------------------------------ |
| ![BLB08103 Board](assets/blc05mk3-old-prototype.jpg) <br/> 老版 LED 控制器原型外观 | ![BLB08103 Old Board](assets/blb08103-old-prototype.jpg) <br/> 老版原型铝基板外观 |
| ![BLB08103 Board](assets/blb08103.jpg) <br/> 参考设计灯具铝基板外观 | ![BLB08103 Case](assets/blb08103-case.jpg) <br/> 参考设计灯具外观[^2] |

[^2]: 外壳由我从友人处购得并手工测绘建模，恕不方便公开设计图纸。如果感兴趣的人多我可以重新设计。

## 项目状态

### 硬件与固件

**Beta**：固件功能已经齐全且稳定，手机 App 已具备全部功能但仍需进一步完善。

### 手机 App

**前 Beta**：所有主要功能均已实现且正常运作，但一些细节功能，比如设置时区之类的仍然尚未实现，程序的稳定性和性能也还需要打磨。

## 开发路线图

请参见项目的[里程碑页面](https://github.com/oldrev/borneo/milestones)。


## 目录结构

- `fw/`：固件源代码
    - `cmake`：CMake 脚本
    - `components`：通用 ESP-IDF 部件源代码
    - `lyfi`：LED 控制器固件相关源代码
    - `doser`：滴定泵固件相关源代码（开发移植中）
    - `scripts`：相关 Python 脚本，包含设备 Python 客户端库
- `hw/`：电路设计源文件
    - `blc05mk3`：5 通道 LED 控制器核心板设计
    - `blc05mk3-horizontal`：5 通道 LED 控制器核心板，水平排针的设计
    - `blb08103`：5 通道 63W LED 灯具铝基板设计
    - `3d-models`：导出的 STEP 格式核心板的 3D 模型
    - `datasheets`: 模块的 PDF 格式规格书[^3]
- `tools/`：相关脚本和工具
- `client/`：手机 App 源代码

[^3]: 由于规格书用到了我其他产品的模板，故规格书不提供源文件。


## 起步

请参阅[在线文档](https://docs.borneoiot.com/getting-started)。

## 贡献

请阅读 [CONTRIBUTING.md](.github/CONTRIBUTING.md) 获取更多信息。

如果你想支持本项目的开发，可以考虑请我喝杯啤酒：

[![爱发电支持](assets/aifadian.jpg)](https://afdian.com/a/mingshu)

## 反馈与技术支持

欢迎任何反馈！如果你遇到任何技术问题或者 bug，请提交 [issue](https://github.com/oldrev/borneo/issues)。

- 本项目官网：[www.borneoiot.com](https://www.borneoiot.com)
- 文档：[docs.borneoiot.com](https://docs.borneoiot.com)
- GitHub 讨论区: [github.com/oldrev/borneo/discussions](https://github.com/oldrev/borneo/discussions)
- 作者邮箱：[oldrev@gmail.com](mailto:oldrev@gmail.com)
- 作者 QQ：55431671

### 社交网络聊天群：

- 《命玩电子社区 QQ 群》：[635466819](http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=JhLsrlvUuFkCRWei_ibemBJP6csUn197&authKey=uWjzu8HkJtpxAQQ5DErNJDJOjbubCQRkSRDvBYU2ZT0KJlYsOyY32aUy6m8dCN6h&noverify=0&group_code=635466819)
- Borneo-IoT Discord 服务器：[https://discord.gg/25mK6KAc](https://discord.gg/25mK6KAc)（仅英文）

---

> 作者超巨型广告：没事儿时可以承接网站前端开发/管理系统开发/电路画板打样/单片机开发/压水晶头/中老年陪聊/工地打灰等软硬件项目。

## 授权

### 软件与固件

开源的项目的软件和固件采用 GPLv3 协议和私有协议双授权模式，GPLv3 协议全文在 [LICENSE](LICENSE) 文件中。

### 硬件

本项目硬件部分采用 CERN Open Hardware Licence Version 2 - Strongly Reciprocal (CERN-OHL-S-2.0) 协议授权，
协议全文在 [LICENSE-HARDWARE](LICENSE-HARDWARE) 文件中。

### 专有授权

有兴趣将本项目的软硬件集成到产品中的也可以[联系我](mailto:oldrev@gmail.com)获得非开源的私有协议。
