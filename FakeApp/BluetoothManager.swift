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
    func updateState(state: BluetoothManager.State)
}

class BluetoothManager: NSObject {
    
    enum State: Printable {
        case Idle, Enroll, Auth, Both
        
        var description: String {
            switch self {
            case .Idle: return "Idle"
            case .Enroll: return "Enroll"
            case .Auth: return "Auth"
            case .Both: return "Both"
            }
        }
    }
    
    private let enrollServiceUUID              = CBUUID(string: "80CBFCD9-C13A-4817-8921-349F3702A4D0")
    private let enrollInputCharacteristicUUID  = CBUUID(string: "40A70AAD-6E05-4EBD-B9DB-2010DC412881")
    private let enrollOutputCharacteristicUUID = CBUUID(string: "AC103510-5E49-41C5-94DA-CBA4329A6CF5")
    
    private let authServiceUUID                = CBUUID(string: "1012A197-B767-421C-B49C-10F385BA22E1")
    private let authInputCharacteristicUUID    = CBUUID(string: "E11C666D-A68C-4775-A05E-2765830D5D60")
    private let authOutputCharacteristicUUID   = CBUUID(string: "BEDFA15A-9048-4ABD-8455-6E164F4878E3")
    
    private let enrollService: CBMutableService
    private let authService: CBMutableService
    
    private var peripheralManager: CBPeripheralManager!
    
    private var isPoweredOn = false
    
    private var state: State = .Idle {
        didSet {
            log("state changed to \(state.description)")
            delegate?.updateState(state)
        }
    }
    
    private var pendingResponse = ""
    
    var delegate: BluetoothManagerDelegate?
    
    override init() {
        var inputCharacteristic: CBMutableCharacteristic
        var outputCharacteristic: CBMutableCharacteristic
        
        enrollService = CBMutableService(type: enrollServiceUUID, primary: true)
        inputCharacteristic = CBMutableCharacteristic(
            type: enrollInputCharacteristicUUID,
            properties: CBCharacteristicProperties.Write,
            value: nil,
            permissions: CBAttributePermissions.Writeable)
        outputCharacteristic = CBMutableCharacteristic(
            type: enrollOutputCharacteristicUUID,
            properties: CBCharacteristicProperties.Read,
            value: nil,
            permissions: CBAttributePermissions.Readable)
        enrollService.characteristics = [inputCharacteristic, outputCharacteristic]
        
        authService = CBMutableService(type: authServiceUUID, primary: true)
        inputCharacteristic = CBMutableCharacteristic(
            type: authInputCharacteristicUUID,
            properties: CBCharacteristicProperties.Write,
            value: nil,
            permissions: CBAttributePermissions.Writeable)
        outputCharacteristic = CBMutableCharacteristic(
            type: authOutputCharacteristicUUID,
            properties: CBCharacteristicProperties.Read,
            value: nil,
            permissions: CBAttributePermissions.Readable)
        authService.characteristics = [inputCharacteristic, outputCharacteristic]
        
        super.init()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
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
    
    func startEnroll() {
        log("startEnroll in state \(state.description)")
        if isPoweredOn {
            addService(enrollServiceUUID)
        } else {
            log("not powered on")
        }
    }
    
    func startAuth() {
        log("startAuth in state \(state.description)")
        if isPoweredOn {
            addService(authServiceUUID)
        } else {
            log("not powered on")
        }
    }
    
    private func addService(serviceUUID: CBUUID) {
        log("addService \(nameFromUUID(serviceUUID)) in state \(state.description)")
        if state == .Both || (serviceUUID == enrollServiceUUID && state == .Enroll) || (serviceUUID == authServiceUUID && state == .Auth) {
            log("service is already added")
            return
        }
        peripheralManager.addService(serviceUUID == enrollServiceUUID ? enrollService : authService)
        if state == .Idle {
            state = serviceUUID == enrollServiceUUID ? .Enroll : .Auth
        } else {
            state = .Both
        }
        startAdvertising()
    }
    
    private func removeService(serviceUUID: CBUUID) {
        log("removeService \(nameFromUUID(serviceUUID)) in state \(state.description)")
        if state == .Idle || (serviceUUID == enrollServiceUUID && state == .Auth) || (serviceUUID == authServiceUUID && state == .Enroll) {
            log("service is already removed")
            return
        }
        peripheralManager.removeService(serviceUUID == enrollServiceUUID ? enrollService : authService)
        if state == .Both {
            state = serviceUUID == enrollServiceUUID ? .Auth : .Enroll
        } else {
            state = .Idle
        }
        startAdvertising()
    }
    
    private func startAdvertising() {
        if isPoweredOn {
            peripheralManager.stopAdvertising()
            var uuids = [CBUUID]()
            if state == .Enroll || state == .Both {
                uuids.append(enrollServiceUUID)
            }
            if state == .Auth || state == .Both {
                uuids.append(authServiceUUID)
            }
            if !uuids.isEmpty {
                peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: uuids])
            }
        }
    }
    
    private func processRequest(requestData: NSData) {
        let request = NSString(data: requestData, encoding: NSUTF8StringEncoding)! as String
        log("request received: \(request)")
        var response = request.stringByReplacingOccurrencesOfString("request", withString: "response")
        response += " [\(timestamp())]"
        log("pending response: " + response)
        pendingResponse = response
//        if startsWith(response, "Enroll 3") {
//            dispatch_async(dispatch_get_main_queue()) {
//                self.addService(self.authServiceUUID)
//            }
//        }
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
            startEnroll()
        }
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {
        var message = "peripheralManagerDidStartAdvertising "
        if error == nil {
            message += "ok"
        } else {
            message += "error " + error.localizedDescription
        }
        log(message)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didAddService service: CBService!, error: NSError!) {
        var message = "peripheralManager didAddService \(nameFromUUID(service.UUID)) "
        if error == nil {
            message += "ok"
            log(message)
        } else {
            message += "error " + error.localizedDescription
            log(message)
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {
        log("peripheralManager didReceiveWriteRequests \(requests.count)")
        if requests.count == 0 {
            return
        }
        let request = requests[0] as! CBATTRequest
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
            log("pendingResponse: \(pendingResponse)")
            request.value = pendingResponse.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
            if startsWith(pendingResponse, "Enroll 3") {
                dispatch_async(dispatch_get_main_queue()) {
                    self.removeService(self.enrollServiceUUID)
                    self.addService(self.authServiceUUID)
                }
            }
            pendingResponse = ""
        } else {
            log("no pending responses")
            peripheralManager.respondToRequest(request, withResult: CBATTError.RequestNotSupported)
        }
    }
    
}