// BLEManager.swift
// CoreBluetooth central manager for glasses connectivity.
//
// Responsibilities:
//   • Track Bluetooth hardware state
//   • Scan for peripherals advertising glasses services
//   • Connect / disconnect with a target peripheral
//   • Forward characteristic notifications to the command pipeline
//
// TODO (hardware integration):
//   • Replace GlassesServiceUUID with your glasses' actual BLE service UUID.
//   • Replace GlassesCommandCharacteristicUUID with the characteristic the
//     glasses write command bytes to.
//   • Implement parseGlassesData(_:) to decode your glasses' binary protocol.

import CoreBluetooth
import Combine
import Foundation

// MARK: - Service / characteristic UUID placeholders

extension CBUUID {
    /// TODO: Replace with the real BLE service UUID advertised by your glasses.
    static let glassesService = CBUUID(string: "00000000-0000-0000-0000-000000000001")

    /// TODO: Replace with the characteristic UUID that carries command data.
    static let glassesCommandCharacteristic = CBUUID(string: "00000000-0000-0000-0000-000000000002")
}

// MARK: - BLEManager

@MainActor
final class BLEManager: NSObject, ObservableObject {

    // ── Published state ──────────────────────────────────────────────────────

    /// Human-readable Bluetooth hardware state string.
    @Published private(set) var bluetoothStateDescription: String = "Unknown"

    /// True when Bluetooth is powered on and ready to scan.
    @Published private(set) var isReady: Bool = false

    /// True while the manager is actively scanning.
    @Published private(set) var isScanning: Bool = false

    /// All peripherals discovered during the current scan session.
    @Published private(set) var discoveredPeripherals: [CBPeripheral] = []

    /// The peripheral the app is currently connected to (nil = disconnected).
    @Published private(set) var connectedPeripheral: CBPeripheral?

    // ── Raw data passthrough for the command pipeline ────────────────────────

    /// Emits raw Data blobs received from the glasses characteristic.
    /// Subscribe in AIBackendClient or CommandRouter to process commands.
    let rawDataSubject = PassthroughSubject<Data, Never>()

    // ── Internal CoreBluetooth objects ───────────────────────────────────────

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    override init() {
        super.init()
        // Restore state if app was backgrounded — requires "bluetooth-central"
        // background mode in Info.plist (only enable if truly needed for always-on BLE).
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    // MARK: Public API

    /// Begin scanning for peripherals advertising the glasses service UUID.
    /// Safe to call repeatedly; ignored if already scanning or Bluetooth not ready.
    func startScanning() {
        guard isReady, !isScanning else { return }
        discoveredPeripherals = []
        centralManager.scanForPeripherals(
            withServices: [.glassesService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    /// Stop an active scan.
    func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
    }

    /// Connect to a discovered peripheral.
    /// - Parameter peripheral: A CBPeripheral from `discoveredPeripherals`.
    func connect(to peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    /// Disconnect the currently connected peripheral.
    func disconnect() {
        guard let p = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(p)
    }

    // MARK: Private helpers

    private func discoverServices(on peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([.glassesService])
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                bluetoothStateDescription = "On"
                isReady = true
            case .poweredOff:
                bluetoothStateDescription = "Off"
                isReady = false
                isScanning = false
            case .unauthorized:
                bluetoothStateDescription = "Not authorised"
                isReady = false
            case .unsupported:
                bluetoothStateDescription = "Unsupported"
                isReady = false
            case .resetting:
                bluetoothStateDescription = "Resetting…"
                isReady = false
            case .unknown:
                bluetoothStateDescription = "Unknown"
                isReady = false
            @unknown default:
                bluetoothStateDescription = "Unknown"
                isReady = false
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            guard !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
            discoveredPeripherals.append(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            isScanning = false
            discoverServices(on: peripheral)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if connectedPeripheral?.identifier == peripheral.identifier {
                connectedPeripheral = nil
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            // TODO: Surface connection error to the UI / retry logic.
            targetPeripheral = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in
            peripheral.services?
                .filter { $0.uuid == .glassesService }
                .forEach { peripheral.discoverCharacteristics([.glassesCommandCharacteristic], for: $0) }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        Task { @MainActor in
            service.characteristics?
                .filter { $0.uuid == .glassesCommandCharacteristic }
                .forEach { peripheral.setNotifyValue(true, for: $0) }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        Task { @MainActor in
            rawDataSubject.send(data)
        }
    }
}
