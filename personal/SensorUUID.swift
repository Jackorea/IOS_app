import CoreBluetooth

public struct SensorUUID {
    // EEG (공통 서비스, Notify & Write)
    public static let eegService          = CBUUID(string: "df7b5d95-3afe-00a1-084c-b50895ef4f95")
    public static let eegNotifyChar       = CBUUID(string: "00ab4d15-66b4-0d8a-824f-8d6f8966c6e5")
    public static let eegWriteChar        = CBUUID(string: "0065cacb-9e52-21bf-a849-99a80d83830e")

    // PPG
    public static let ppgService          = CBUUID(string: "1cc50ec0-6967-9d84-a243-c2267f924d1f")
    public static let ppgChar             = CBUUID(string: "6c739642-23ba-818b-2045-bfe8970263f6")

    // Accelerometer
    public static let accelService        = CBUUID(string: "75c276c3-8f97-20bc-a143-b354244886d4")
    public static let accelChar           = CBUUID(string: "d3d46a35-4394-e9aa-5a43-e7921120aaed")

    // Battery
    public static let batteryService      = CBUUID(string: "0000180f-0000-1000-8000-00805f9b34fb")
    public static let batteryChar         = CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb")
} 