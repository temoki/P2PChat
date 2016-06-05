//
//  ViewController.swift
//  P2PChat
//
//  Created by temoki on 2016/06/03.
//  Copyright © 2016年 temoki.com. All rights reserved.
//

import UIKit
import MultipeerConnectivity

private let SERVICE_TYPE = "P2PChat"

typealias Message = (text: String, mine: Bool)

class ViewController: UITableViewController,
    MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    private let session = MCSession(peer: MCPeerID(displayName: UIDevice.currentDevice().name))
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    
    private var searchButton: UIBarButtonItem?
    private var disconnectButton: UIBarButtonItem?
    
    private var messages = [Message]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.session.delegate = self
        self.searchButton = UIBarButtonItem(barButtonSystemItem: .Search, target: self, action: #selector(self.searchAction))
        self.disconnectButton = UIBarButtonItem(barButtonSystemItem: .Stop, target: self, action: #selector(self.disconnectAction))

        self.updateState(.NotConnected)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    // MARK:- Action
    
    func searchAction(sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        actionSheet.addAction(UIAlertAction(title: "Browse", style: .Default) { action in
            self.startBrowsing()
            })
        actionSheet.addAction(UIAlertAction(title: "Advertise", style: .Default) { action in
            self.startAdvertising()
            })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    func disconnectAction(sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        actionSheet.addAction(UIAlertAction(title: "Disconnect", style: .Default) { action in
            if !self.session.connectedPeers.isEmpty {
                self.session.disconnect()
                self.messages.removeAll()
                self.tableView.reloadData()
            }
            })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    
    // MARK:- Private
    
    private func startBrowsing() {
        self.startAdvertising()
        self.browser = MCNearbyServiceBrowser(peer: self.session.myPeerID, serviceType: SERVICE_TYPE)
        self.browser?.delegate = self
        self.browser?.startBrowsingForPeers()
        self.updateState(.Browsing)
    }
    
    private func stopBrowsing() {
        self.browser?.stopBrowsingForPeers()
        self.browser = nil
    }
    
    private func startAdvertising() {
        self.stopBrowsing()
        self.advertiser = MCNearbyServiceAdvertiser(peer: self.session.myPeerID, discoveryInfo: nil, serviceType: SERVICE_TYPE)
        self.advertiser?.delegate = self
        self.advertiser?.startAdvertisingPeer()
        self.updateState(.Advertising)
    }
    
    private func stopAdvertising() {
        self.advertiser?.stopAdvertisingPeer()
        self.advertiser = nil
    }
    
    private enum State {
        case NotConnected
        case Browsing
        case Advertising
        case Connecting
        case Connected
    }
    
    private func updateState(state: State, peerName: String? = nil) {
        dispatch_async(dispatch_get_main_queue()) {
            switch state {
            case .NotConnected:
                print("  + state = Not Connected")
                self.navigationItem.title = "Not Connected"
                self.navigationItem.rightBarButtonItem = self.searchButton
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            case .Browsing:
                print("  + state = Browsing")
                self.navigationItem.title = "Browsing..."
                self.navigationItem.rightBarButtonItem = self.searchButton
                UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            case .Advertising:
                print("  + state = Advertising")
                self.navigationItem.title = "Advertising..."
                self.navigationItem.rightBarButtonItem = self.searchButton
                UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            case .Connecting:
                print("  + state = Connecting")
                self.navigationItem.title = "Connecting..."
                self.navigationItem.rightBarButtonItem = nil
                UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            case .Connected:
                print("  + state = Connected")
                self.stopBrowsing()
                self.stopAdvertising()
                self.navigationItem.title = peerName ?? "(Unknown Name)"
                self.navigationItem.rightBarButtonItem = self.disconnectButton
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
        }
    }
    
    // MARK:- MCSessionDelegate
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        print("[MCSessionDelegate] session:peerID:didChangeState:")
        print("  + peerID = \(peerID.displayName)")
        switch state {
        case .NotConnected:
            self.updateState(.NotConnected)
        case .Connecting:
            self.updateState(.Connecting)
        case .Connected:
            self.updateState(.Connected, peerName: peerID.displayName)
        }
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        print("[MCSessionDelegate] session:didReceiveData:fromPeer:")
        print("  + peerID = \(peerID.displayName)")
        guard let text = NSString(data: data, encoding: NSUTF8StringEncoding) as String? else { return }
        guard !text.isEmpty else { return }
        print("  + data = \(text)")
        self.messages.append((text: text, mine: false))
        dispatch_async(dispatch_get_main_queue()) {
            self.tableView.reloadData()
        }
    }
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
    }
    
    
    // MARK; - MCNearbyServiceBrowserDelegate
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("[MCNearbyServiceBrowserDelegate] browser:foundPeer:withDiscoveryInfo:")
        print("  + peerID = \(peerID.displayName)")
        print("  + info = \(info)")
        browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 10)
    }

    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[MCNearbyServiceBrowserDelegate] browser:lostPeer:")
        print("  + peerID = \(peerID.displayName)")
    }
    
    
    // MARK:- MCNearbyServiceAdvertiserDelegate
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        print("[MCNearbyServiceAdvertiserDelegate] advertiser:didReceiveInvitationFromPeer:withContext:invitationHandler:")
        print("  + peerID = \(peerID.displayName)")
        
        let alert = UIAlertController(title: "Invitation", message: "from \(peerID.displayName)", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Accept", style: .Default) { action in
            invitationHandler(true, self.session)
            })
        alert.addAction(UIAlertAction(title: "Decline", style: .Cancel) { action in
            invitationHandler(false, self.session)
            })
        self.presentViewController(alert, animated: true, completion: nil)
    }


    // MARK:- UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count + 1
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if self.messages.count == indexPath.row {
            cell = tableView.dequeueReusableCellWithIdentifier("CellID_Add", forIndexPath: indexPath)
        } else {
            let message = self.messages[indexPath.row]
            let cellID = message.mine ? "CellID_Me" : "CellID_You"
            cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: indexPath)
            if let messageLabel = cell.viewWithTag(1) as? UILabel {
                messageLabel.text = message.text
            }
        }
        return cell
    }
    
    
    // MARK:- UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        guard self.messages.count == indexPath.row else { return }
        guard !self.session.connectedPeers.isEmpty else { return }
        
        let alert = UIAlertController(title: "Message", message: nil, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Send", style: .Default) { action in
            guard let textField = alert.textFields?.first as UITextField? else { return }
            guard let text = textField.text where !text.isEmpty else { return }
            guard let textData = (text as NSString).dataUsingEncoding(NSUTF8StringEncoding) else { return }
            do {
                try self.session.sendData(textData, toPeers: self.session.connectedPeers, withMode: .Reliable)
                self.messages.append((text: text, mine: true))
                self.tableView.reloadData()
            } catch let error as NSError {
                print(error)
            }
            })
        alert.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "message"
        }
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

