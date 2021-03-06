//
//  ViewController.swift
//  FakeApp
//
//  Created by Jay Tucker on 4/8/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import UIKit

class ViewController: UIViewController, BluetoothManagerDelegate {

    @IBOutlet weak var modeLabel: UILabel!
    
    private var bluetoothManager: BluetoothManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        bluetoothManager = BluetoothManager()
        bluetoothManager.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func enroll(sender: AnyObject) {
        bluetoothManager.startEnroll()
    }

    @IBAction func auth(sender: AnyObject) {
        bluetoothManager.startAuth()
    }
    
}

extension ViewController: BluetoothManagerDelegate {
    
    func updateState(state: BluetoothManager.State) {
        modeLabel.text = state.description
    }
    
}

