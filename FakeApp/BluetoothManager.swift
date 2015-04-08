//
//  BluetoothManager.swift
//  FakeApp
//
//  Created by Jay Tucker on 4/8/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate {
    func startedAdvertisingService(service: String)
}

class BluetoothManager: NSObject {
    
    private let enrollServiceUUID              = CBUUID(string: "80CBFCD9-C13A-4817-8921-349F3702A4D0")
    private let enrollInputCharacteristicUUID  = CBUUID(string: "40A70AAD-6E05-4EBD-B9DB-2010DC412881")
    private let enrollOutputCharacteristicUUID = CBUUID(string: "AC103510-5E49-41C5-94DA-CBA4329A6CF5")
    
    private var authServiceUUID                = CBUUID(string: "1012A197-B767-421C-B49C-10F385BA22E1")
    private let authInputCharacteristicUUID    = CBUUID(string: "E11C666D-A68C-4775-A05E-2765830D5D60")
    private let authOutputCharacteristicUUID   = CBUUID(string: "BEDFA15A-9048-4ABD-8455-6E164F4878E3")
    
    private var currentServiceUUID: CBUUID!
    
    private let peripheralManager: CBPeripheralManager!
    private var isPoweredOn = false
    
    private var pendingResponse: String!
    
    var delegate: BluetoothManagerDelegate?
    
    override init() {
        super.init()
        currentServiceUUID = enrollServiceUUID
        pendingResponse = ""
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startEnroll() {
        log("startEnroll")
        if isPoweredOn {
            startService(enrollServiceUUID)
        } else {
            log("is not powered on")
        }
    }

    private func timestamp() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
        return dateFormatter.stringFromDate(NSDate())
    }
    
    private func log(message: String) {
        println("[\(timestamp())] \(message)")
    }
    
    private func nameFromUUID(uuid: CBUUID) -> String {
        switch uuid {
        case enrollServiceUUID: return "enrollService"
        case enrollInputCharacteristicUUID: return "enrollInput"
        case enrollOutputCharacteristicUUID: return "enrollOutput"
        case authServiceUUID: return "authService"
        case authInputCharacteristicUUID: return "authInput"
        case authOutputCharacteristicUUID: return "authOutput"
        default: return "unknown"
        }
    }
    
    private func startService(serviceUUID: CBUUID) {
        log("startService \(nameFromUUID(serviceUUID))")
        currentServiceUUID = serviceUUID
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        let service = CBMutableService(type: serviceUUID, primary: true)
        let inputCharacteristic = CBMutableCharacteristic(
            type: serviceUUID == enrollServiceUUID ? enrollInputCharacteristicUUID : authInputCharacteristicUUID,
            properties: CBCharacteristicProperties.Write,
            value: nil,
            permissions: CBAttributePermissions.Writeable)
        let outputCharacteristic = CBMutableCharacteristic(
            type: serviceUUID == enrollServiceUUID ? enrollOutputCharacteristicUUID : authOutputCharacteristicUUID,
            properties: CBCharacteristicProperties.Read,
            value: nil,
            permissions: CBAttributePermissions.Readable)
        service.characteristics = [inputCharacteristic, outputCharacteristic]
        peripheralManager.addService(service)
    }
    
    private func startAdvertising() {
        log("startAdvertising")
        peripheralManager.startAdvertising(nil) // [CBAdvertisementDataServiceUUIDsKey: [currentServiceUUID]])
        delegate?.startedAdvertisingService(currentServiceUUID == enrollServiceUUID ? "Enroll" : "Auth")
    }
    
    private func processRequest(requestData: NSData) {
        let request = NSString(data: requestData, encoding: NSUTF8StringEncoding)!
        log("request received: " + request)
        let response = "\(request) (\(timestamp()))"
        log("pending response: " + response)
        pendingResponse = response
    }

}

extension BluetoothManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(peripheralManager: CBPeripheralManager!) {
        var caseString: String!
        switch peripheralManager.state {
        case .Unknown:
            caseString = "Unknown"
        case .Resetting:
            caseString = "Resetting"
        case .Unsupported:
            caseString = "Unsupported"
        case .Unauthorized:
            caseString = "Unauthorized"
        case .PoweredOff:
            caseString = "PoweredOff"
        case .PoweredOn:
            caseString = "PoweredOn"
        default:
            caseString = "WTF"
        }
        log("peripheralManagerDidUpdateState \(caseString)")
        isPoweredOn = (peripheralManager.state == .PoweredOn)
        if isPoweredOn {
            startService(enrollServiceUUID)
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didAddService service: CBService!, error: NSError!) {
        var message = "peripheralManager didAddService \(nameFromUUID(service.UUID)) "
        if error == nil {
            message += "ok"
            log(message)
            startAdvertising()
        } else {
            message = "error " + error.localizedDescription
            log(message)
        }
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {
        var message = "peripheralManagerDidStartAdvertising "
        if error == nil {
            message += "ok"
        } else {
            message = "error " + error.localizedDescription
        }
        log(message)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {
        log("peripheralManager didReceiveWriteRequests \(requests.count)")
        if requests.count == 0 {
            return
        }
        let request = requests[0] as CBATTRequest
        processRequest(request.value)
        peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {
        let serviceUUID = request.characteristic.service.UUID
        let serviceName = nameFromUUID(serviceUUID)
        let characteristicUUID = request.characteristic.UUID
        let characteristicName = nameFromUUID(characteristicUUID)
        log("peripheralManager didReceiveReadRequest \(serviceName) \(characteristicName)")
        if !pendingResponse.isEmpty {
            request.value = pendingResponse.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
            pendingResponse = ""
        } else {
            log("no pending responses")
            peripheralManager.respondToRequest(request, withResult: CBATTError.RequestNotSupported)
        }
    }
    
}