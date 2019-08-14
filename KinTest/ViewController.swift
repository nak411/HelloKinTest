//
//  ViewController.swift
//  KinTest
//
//  Created by Naveed on 8/13/19.
//  Copyright © 2019 Naveed. All rights reserved.
//

import UIKit

import KinSDK

class ViewController: UIViewController {

    private var kinClient: KinClient!
    var str : String = ""
    
    //MARK: Properties

    @IBOutlet weak var resultLabel: UILabel!
    
    @IBAction func btnCheck(_ sender: Any) {
        //Try to get accouont
        var account = getFirstAccount(kinClient: self.kinClient)
        if account != nil {
            str.append("Successfully retrieved account\n")
        } else {
            //Not found - create new account
            str.append("Creating new account\n")
            account = createLocalAccount(kinClient: self.kinClient)
            if account != nil {
                str.append("Successfully created new account\n")
            } else {
                str.append("Failed to create new account\n")
            }
        }
        str.append("Public address: \(account!.publicAddress)\n")
        account!.status().then { (status) in
            self.str.append("Account status: \(status)\n")
            if status == AccountStatus.notCreated {
                //Enroll on block change
                self.createAccountOnPlaygroundBlockchain(account: account!, completionHandler: { r in
                    if(r == nil) {
                        self.str.append("Successfully enrolled on blockchain\n")
                        account!.balance().then({ (balance) in
                            self.str.append("Account balance: \(balance)")
                            DispatchQueue.main.async {
                                self.resultLabel.text = self.str
                            }
                        })
                    } else {
                        self.str.append("Failed to enroll on blockchain\n")
                    }
                 
                    DispatchQueue.main.async {
                        self.resultLabel.text = self.str
                    }
                })
            } else {
                self.str.append("Account already enrolled on blockchain!\n")
                account!.balance().then({ (balance) in
                    self.str.append("Account balance: \(balance)")
                    DispatchQueue.main.async {
                        self.resultLabel.text = self.str
                    }
                })
            }
            DispatchQueue.main.async {
                self.resultLabel.text = self.str
            }
        }
        //Add account to blockchain
        
        resultLabel.text = str
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.kinClient = initializeKinClientOnPlaygroundNetwork()
    }
    
    func getFirstAccount(kinClient: KinClient) -> KinAccount? {
        return kinClient.accounts.first
    }
    
    func createLocalAccount(kinClient: KinClient) -> KinAccount? {
        do {
            let account = try kinClient.addAccount()
            return account
        }
        catch let error {
            print("Error creating an account \(error)")
        }
        return nil
    }
    
    /**
     Get the balance using the method with callback.
     */
    func getBalance(forAccount account: KinAccount, completionHandler: ((Kin?) -> ())?) {
        account.balance { (balance: Kin?, error: Error?) in
            if error != nil || balance == nil {
                print("Error getting the balance")
                if let error = error { print("with error: \(error)") }
                completionHandler?(nil)
                return
            }
            completionHandler?(balance!)
        }
    }
    
    func createAccountOnPlaygroundBlockchain(account: KinAccount,
                                             completionHandler: @escaping (([String: Any]?) -> ())) {
        // Playground blockchain URL for account creation and funding
        let createUrlString = "https://friendbot-testnet.kininfrastructure.com?addr=\(account.publicAddress)"
        
        guard let createUrl = URL(string: createUrlString) else { return }
        
        let request = URLRequest(url: createUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Account creation on playground blockchain failed with error: \(error)")
                completionHandler(nil)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let result = json as? [String: Any] else {
                    print("Account creation on playground blockchain failed with no parsable JSON")
                    completionHandler(nil)
                    return
            }
            // check if there's a bad status
            guard result["status"] == nil else {
                print("Error status \(result)")
                completionHandler(nil)
                return
            }
            print("Account creation on playground blockchain was successful with response data: \(result)")
            completionHandler(result)
        }
        
        task.resume()
    }

    /**
     Initializes the Kin Client with the playground environment.
     */
    func initializeKinClientOnPlaygroundNetwork() -> KinClient? {
        let url = "https://horizon-testnet.kininfrastructure.com"
        guard let providerUrl = URL(string: url) else { return nil }
        
        do {
            let appId = try AppId("test")
            return KinClient(with: providerUrl, network: .testNet, appId: appId)
        }
        catch let error {
            print("Error \(error)")
        }
        return nil
    }

}

