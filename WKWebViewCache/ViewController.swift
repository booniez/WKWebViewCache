//
//  ViewController.swift
//  WKWebViewCache
//
//  Created by monstar1 on 2018/6/25.
//  Copyright © 2018年 monstar1. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    let webView = WKWebView()
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.frame = view.frame
//        let request = URLRequest.init(url: URL(string: "https://www.baidu.com")!, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
//        webView.load(request)
        webView.load(URLRequest(url: URL(string: "https://www.baidu.com")!))
        view.addSubview(webView)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

