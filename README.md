# ToroAlerts

一個用於控制 USB Hubcot 裝置的 Swift 套件與命令列工具，支援 Toro 與 Kitty 裝置。

## 簡介

ToroAlerts 提供了一個 Swift 原生的解決方案，用於透過 IOKit 與 USB Hubcot 裝置進行通訊。本專案參考 Tomoaki MITSUYOSHI 的 hubcot_linux 驅動程式，並專為 macOS 環境設計。

### 關於 Hubcot

Hubcot 是 Dreams come true co., Ltd. 的註冊商標，為 2000 年代初期在日本推出的吉祥物造型 USB Hub。其特色在於內建軟體控制的左右可動手臂，透過不同的揮動組合與時間差，能表達出開心、興奮、招手等各種生動的情緒動作。最受歡迎的兩款裝置為：

- **Toro**: どこでもいっしょ的トロ造型 USB Hub
- **Kitty**: Hello Kitty 造型的 USB Hub

這些裝置不僅具備完整的 USB Hub 功能，更是能為桌面增添療癒氛圍的趣味小物。Linux 平台的驅動程式支援始於 2001 年，由 Tomoaki MITSUYOSHI 基於 Takuya SHIOZAKI 所開發的 NetBSD uhubcot 驅動程式進行移植。

ToroAlerts 將這個經典的 Linux 驅動程式帶到了目前的 macOS 平台，使用 Swift 6 和 IOKit 重新實作，讓這些可愛的 USB Hub 能在 Mac 上繼續揮舞雙臂。

## 功能特點

- 自動偵測並連接 Toro 或 Kitty 裝置
- 支援 10 種預先定義好的揮動模式及自訂請求 (0x00-0xFF)
- 可調整揮動延遲間隔（使用 Swift `Duration` 型別）
- `DeviceCoordinator` 提供 AsyncStream 為基礎的非同步事件驅動架構
- 支援多個事件消費者（fan-out 模式）
- 使用 `.bufferingNewest` 策略自動丟棄過時指令
- 使用 `Mutex` 確保執行緒安全
- 使用 `os.Logger` 提供結構化除錯日誌
- 提供命令列工具 `toroalertsctl`（支援純文字與 JSON 輸出）

## 系統需求

- macOS 15.0 (Sequoia) 或更新版本
- Swift 6.0 或更新版本
- Xcode 26.0 或更新版本（用於開發）

## 支援的裝置

| 裝置 | Vendor ID | Product ID |
|------|-----------|------------|
| Toro | `0x054D` | `0x1B59` |
| Kitty | `0x0D74` | `0xD001` |

## 安裝

### 作為 Swift Package 使用

將以下依賴加入您的 `Package.swift` 檔案：

```swift
dependencies: [
    .package(url: "https://github.com/digdog/ToroAlerts.git", from: "1.0.0")
]
```

然後在目標中加入依賴：

```swift
.target(
    name: "YourTarget",
    dependencies: ["ToroAlerts"]
)
```

### 建置命令列工具

```bash
swift build -c release
```

可執行檔將位於 `.build/release/toroalertsctl`。

## 使用方式

### 命令列工具

#### 傳送請求到裝置

```bash
# 使用十六進位格式傳送請求，延遲 100 毫秒
toroalertsctl send --request 0x03 --delay 100

# 使用十進位格式
toroalertsctl send -r 3 -d 100

# 啟用詳細輸出
toroalertsctl send -r 0x03 -d 100 --verbose

# 測量執行時間
toroalertsctl send -r 0x03 -d 100 --measure
```

#### 列出可用的請求類型

```bash
toroalertsctl list

# JSON 格式輸出
toroalertsctl list --json
```

#### 顯示裝置資訊

```bash
toroalertsctl info

# JSON 格式輸出
toroalertsctl info --json
```

#### 顯示版本資訊

```bash
toroalertsctl version

# JSON 格式輸出
toroalertsctl version --json
```

#### 全域選項

所有命令皆支援以下選項：

- `-v, --verbose`: 顯示詳細輸出
- `--measure`: 測量並顯示執行時間

### 作為程式庫使用

透過 `DeviceCoordinator` 管理裝置的連線與指令串流：

```swift
import ToroAlerts

let coordinator = DeviceCoordinator()

// 監聽事件（支援多個消費者）
Task {
    for await event in coordinator.newEventStream() {
        switch event {
        case .connected(let type): print("已連線: \(type)")
        case .disconnected: print("已斷線")
        case .sendFailed(let error): print("錯誤: \(error)")
        }
    }
}

// 啟動連線與處理迴圈
coordinator.start()

// 傳送指令（fire-and-forget，同步且不阻塞）
coordinator.yield(.lrlrlr, interval: .milliseconds(100))
coordinator.yield(.both)

// 傳送自訂請求值
coordinator.yield(rawValue: 0x03, interval: .milliseconds(200))

// 等待所有 buffer 中的指令處理完畢後結束
await coordinator.finishAndWait()

// 或立刻中斷，丟棄未處理的指令
coordinator.finish()
```

#### 指定裝置類型

```swift
let coordinator = DeviceCoordinator(deviceType: .toro)
```

## 支援的動作模式

| 請求類型 | 數值 | 說明 |
|---------|------|------|
| `noop` | 0x00 | 無操作 |
| `right` | 0x01 | 右臂移動 |
| `left` | 0x02 | 左臂移動 |
| `both` | 0x03 | 雙臂同時移動 |
| `bothQuad` | 0x04 | 雙臂移動 x4 |
| `lrlrlr` | 0x05 | 左右交替模式 |
| `rightTriple` | 0x06 | 右臂移動 x3 |
| `bothTriple` | 0x08 | 雙臂移動 x3 |
| `rl` | 0x0B | 右-左 |
| `rlrlrl` | 0x0C | 右左交替模式 |

亦可使用 0x00-0xFF 範圍內的自訂請求值，但有可能有重複的動作模式（含無操作）。

## 延遲參數

`interval` 參數控制動作的延遲時間：

- `.zero` = 最快速度
- 數值越大 = 動作越慢
- 預設值：`.milliseconds(100)`
- 建議範圍：0-1000 毫秒

## API 參考

### DeviceCoordinator

協調 Hubcot USB 裝置的請求串流與事件串流。使用 `Mutex<State>` 確保執行緒安全，透過 `AsyncStream` 管理非同步資料流。

#### 初始化

```swift
// 自動偵測裝置，buffer 大小預設為 3
DeviceCoordinator(deviceType: DeviceType? = nil, bufferSize: Int = 3)
```

#### 生命週期

```swift
// 啟動連線與處理迴圈
func start()

// 立刻中斷，丟棄未處理的指令
func finish()

// 等待 buffer 中的指令處理完畢後結束
func finishAndWait() async
```

#### 傳送指令

```swift
// 傳送預定義請求（fire-and-forget）
func yield(_ request: DeviceRequest, interval: Duration = .milliseconds(100))

// 傳送原始請求值（fire-and-forget）
func yield(rawValue: UInt8, interval: Duration = .milliseconds(100))
```

#### 事件監聽

```swift
// 建立新的事件串流（支援多個消費者，fan-out）
func newEventStream() -> AsyncStream<DeviceCoordinator.Event>
```

#### 事件類型

| 事件 | 說明 |
|------|------|
| `.connected(DeviceType)` | 裝置已連線 |
| `.disconnected` | 裝置已斷線 |
| `.sendFailed(DeviceError)` | 傳送失敗 |

### DeviceRequest

預定義請求類型的列舉，遵循 `CaseIterable` 和 `Sendable`。

### DeviceType

裝置類型列舉（`.toro`、`.kitty`），提供 `vendorID` 和 `productID` 屬性，遵循 `Codable`。

### DeviceError

| 錯誤 | 說明 |
|------|------|
| `deviceNotFound` | 找不到 Hubcot 裝置 |
| `connectionFailed(IOReturn?)` | 連接裝置失敗 |
| `deviceNotConnected` | 裝置未連接 |
| `requestFailed(IOReturn)` | 控制傳輸失敗 |

## 架構

`DeviceCoordinator` 是主要的公開 API，內部使用 `DeviceController` 處理 IOKit USB 通訊：

```
                       DeviceCoordinator
 ┌──────────────────────────────────────────────────────────────┐
 │                                                              │
 │   ┌──────────┐    ┌───────────────────┐    ┌──────────────┐  │
 │   │          │    │    AsyncStream    │    │  processing  │  │
 │   │  yield() │───>│  <RequestElement> │───>│     loop     │  │
 │   │          │    │ (bufferingNewest) │    │              │  │
 │   └──────────┘    └───────────────────┘    └──────┬───────┘  │
 │                                                   │          │
 │                                                   v          │
 │                                            ┌──────────────┐  │
 │                                            │   Device     │  │
 │                                            │  Controller  │  │
 │                                            │ (IOKit USB)  │  │
 │                                            └──────┬───────┘  │
 │                                                   │          │
 │                                                   v          │
 │   ┌──────────────────┐    ┌───────────────────────────────┐  │
 │   │ newEventStream() │    │        event fan-out          │  │
 │   │ newEventStream() │<───│  AsyncStream<Event> x N       │  │
 │   │ newEventStream() │    │  (.connected / .disconnected  │  │
 │   └──────────────────┘    │   / .sendFailed)              │  │
 │                           └───────────────────────────────┘  │
 │                                                              │
 └──────────────────────────────────────────────────────────────┘
```

- **Request 方向**：`yield()` → `AsyncStream<RequestElement>` → processing loop → `DeviceController.send()`
- **Event 方向**：`DeviceController` 結果 → event fan-out → 所有 `newEventStream()` 消費者
- **Buffer 策略**：`.bufferingNewest(3)`，裝置處理速度跟不上時自動丟棄過時指令

## 開發

### 執行測試

```bash
swift test
```

### 執行整合測試（需連接裝置）

```bash
RUN_INTEGRATION_TESTS=1 swift test
```

### 建置專案

```bash
swift build
```

## 專案結構

```
ToroAlerts/
├── Package.swift
├── Sources/
│   └── ToroAlerts/
│       ├── DeviceCoordinator.swift    # 非同步串流協調器（公開 API）
│       ├── DeviceController.swift     # IOKit USB 裝置控制
│       ├── DeviceRequest.swift        # 請求類型列舉
│       ├── DeviceType.swift           # 裝置類型定義
│       ├── DeviceError.swift          # 錯誤類型
│       └── DeviceConstants.swift      # USB ID 與 IOKit UUID 常量
├── Tools/
│   └── ToroAlertsCLI/
│       ├── ToroAlertsCLI.swift
│       └── Commands/
│           ├── ToroAlertsCommands.swift
│           ├── ToroAlertsCommands.GlobalOptions.swift
│           ├── ToroAlertsCommands.Subcommand.swift
│           ├── Send.swift
│           ├── List.swift
│           ├── Info.swift
│           └── Version.swift
└── Tests/
    └── ToroAlertsTests/
        └── ToroAlertsTests.swift
```

## 致謝

本專案基於以下開源專案與貢獻者的努力：

- **Tomoaki MITSUYOSHI** (micchan@geocities.co.jp) - hubcot_linux 驅動程式原作者 (2001)
- **Takuya SHIOZAKI** ([GitHub](https://github.com/AoiMoe)) - NetBSD uhubcot 驅動程式作者

## 授權

本專案採用 **GNU General Public License v2.0 或更新版本** 授權。

```
ToroAlerts - USB Hubcot device driver for macOS
Copyright (C) 2026 Ching-Lan 'digdog' HUANG

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

雖然本專案以 hubcot_linux 驅動程式為參考，但實作上已使用 Swift 6 與 IOKit 完全重寫，與原始 C 語言的程式碼截然不同，技術上並無沿用 GPL 的義務。然而，本專案純粹出於個人興趣，選擇 GPL 這種強調互惠共享的授權，正是希望這份對老玩具的熱情能以開放的方式延續下去。

完整授權條款請參閱 [LICENSE](LICENSE) 檔案或訪問 <https://www.gnu.org/licenses/gpl-2.0.html>

### 商標聲明

"Hubcot" 是 Dreams come true co.,Ltd. 的註冊商標。本專案與 Dreams come true co.,Ltd. 無關聯，僅為支援其硬體產品的開源驅動程式。

## 貢獻

歡迎提交 Pull Request 或回報問題！由於本專案採用 GPL 授權，所有貢獻都將在相同的授權條款下發布。

## 相關連結

- [IOKit 文件](https://developer.apple.com/documentation/iokit)
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- [GNU General Public License](https://www.gnu.org/licenses/gpl-2.0.html)
