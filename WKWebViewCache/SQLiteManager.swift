//
//  SQLiteManager.swift
//  WKWebViewCache
//
//  Created by monstar1 on 2018/6/25.
//  Copyright © 2018年 monstar1. All rights reserved.
//

import UIKit
import FMDB

final class SQLiteManager {
    //#MARK: - 创建类对象的实例-单例
    // let是线程安全的
    static let shared = SQLiteManager()
    
    //#MARK: - 对外接口
    /// 更改缓存存储默认时间
    func setValidateTime(_ time: Int) {
        timeout = time
    }
    
    // MARK: 数据库相关操作
    func checkSize() -> Double {
        var size:Double = 0
        
        let checkCacheSQL = SQLConstructor().fetchSQL(tableName: cacheName, primaryKey: nil)
        let redirectSQL = SQLConstructor().fetchSQL(tableName: redirectName, primaryKey: nil)
        
        let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
        dbQueue.inDatabase { (db) in
            guard let rsCache = try?db.executeQuery(checkCacheSQL, values: nil) else {return}
            guard let rsRedir = try?db.executeQuery(redirectSQL, values: nil) else {return}
            while rsCache.next() {
                if let sizeStr = rsCache.string(forColumn: SQLConstructor().size) {
                    size += (Double.init(sizeStr) ?? 0)
                }
            }
            while rsRedir.next() {
                if let sizeStr = rsRedir.string(forColumn: SQLConstructor().size) {
                    size += (Double.init(sizeStr) ?? 0)
                }
            }
            rsRedir.close()
            rsCache.close()
        }
        dbQueue.close()
        return size
    }
    
    
    /// 查找并且更新或者插入重定向记录
    ///
    /// - Parameters:
    ///   - url: 请求URL
    ///   - response: 重定向回复
    ///   - request: 重定向后的新请求
    func searchAndUpdateOrInsertRedirectInfo(url: String,response: HTTPURLResponse, request: URLRequest) {
        var dic = [String:String]()
        let key = url.md5()
        let requestPath = cachePath.appendingPathComponent("\(request.hashValue)")
        let reponsePath = cachePath.appendingPathComponent("\(response.hashValue)")
        
        dic[SQLConstructor().key] = key
        dic[SQLConstructor().request] = "\(request.hashValue)"
        dic[SQLConstructor().response] = "\(response.hashValue)"
        dic[SQLConstructor().time] = formatterDateToString(date: Date())
        
        /// 归档重定向记录
        if NSKeyedArchiver.archiveRootObject(request, toFile: requestPath) && NSKeyedArchiver.archiveRootObject(response, toFile: reponsePath) {
            
            var size = try!FileManager.default.attributesOfItem(atPath: requestPath)[FileAttributeKey.size] as! Double
            size += try!FileManager.default.attributesOfItem(atPath: reponsePath)[FileAttributeKey.size] as! Double
            dic[SQLConstructor().size] = "\(size)"
            
            let querySQL = SQLConstructor().fetchSQL(tableName: redirectName, primaryKey: key)
            let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
            dbQueue.inDatabase({ (db) in
                if let result = try?db.executeQuery(querySQL, values: nil) {
                    if result.next() {
                        print("\(key)执行更新数据库操作")
                        let updateSQL = SQLConstructor().updateRedirectSQL(tableName: redirectName, dic: dic)
                        try?db.executeUpdate(updateSQL, values: nil)
                    } else {
                        print("\(key)执行插入数据库操作")
                        let insertSQL = SQLConstructor().insertRedirectSQL(tableName: redirectName, dic: dic)
                        try?db.executeUpdate(insertSQL, values: nil)
                    }
                    result.close()
                } else {
                    print("\(key)执行插入数据库操作")
                    let insertSQL = SQLConstructor().insertRedirectSQL(tableName: redirectName, dic: dic)
                    try?db.executeUpdate(insertSQL, values: nil)
                }
            })
            dbQueue.close()
        }
        
    }
    
    /// 查找并更新数据库记录，如果没有记录则插入记录
    ///
    /// - Parameters:
    ///   - url: 请求URL
    ///   - response: 回复头
    ///   - data: 回复数据
    func searchAndUpdateOrInsertCacheInfo(url: String,_ response:URLResponse,_ data:Data) {
        let key = url.md5()
        var dic = [String:String]()
        dic[SQLConstructor().url] = url
        dic[SQLConstructor().key] = key
        dic[SQLConstructor().time] = formatterDateToString(date: Date())
        
        // 归档成功---缓存
        if NSKeyedArchiver.archiveRootObject(CachedURLResponse(response: response, data: data, userInfo: nil, storagePolicy: .notAllowed), toFile: cachePath.appendingPathComponent(key)) {
            print("\(key.md5())本地归档成功")
            let size = try!FileManager.default.attributesOfItem(atPath: cachePath.appendingPathComponent(key) as String)[FileAttributeKey.size] as! Int
            dic[SQLConstructor().size] = "\(size)"
            print("存入缓存-----MD5:\(key)")
            
            let querySQL = SQLConstructor().fetchSQL(tableName: cacheName, primaryKey: key)
            let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
            dbQueue.inDatabase({ (db) in
                if let result = try?db.executeQuery(querySQL, values: nil) {
                    if result.next() {
                        print("\(key)执行更新数据库操作")
                        let updateSQL = SQLConstructor().updateCacheSQL(tableName: cacheName, dic: dic)
                        try?db.executeUpdate(updateSQL, values: nil)
                    } else {
                        print("\(key)执行插入数据库操作")
                        let insertSQL = SQLConstructor().insertCacheSQL(tableName: cacheName, dic: dic)
                        try?db.executeUpdate(insertSQL, values: nil)
                    }
                    result.close()
                } else {
                    print("\(key)执行插入数据库操作")
                    let insertSQL = SQLConstructor().insertCacheSQL(tableName: cacheName, dic: dic)
                    print(insertSQL)
                    try?db.executeUpdate(insertSQL, values: nil)
                }
            })
            dbQueue.close()
        }
    }
    
    
    
    /// 从数据库获取重定向URL记录，如果过期则删除
    ///
    /// - Parameters:
    ///   - primaryKeyValue: 重定向URL
    ///   - success: 查找成功CallBack
    ///   - failure: 查找失败CallBack
    func fetchOrDeleteRedirectInfo(url:String? ,success:(URLRequest,URLResponse)->Void,failure:()->Void) {
        guard let confirmURL = url else {return}
        let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
        dbQueue.inDatabase { (db) in
            // 查看是否有重定向
            let fetchSQL = SQLConstructor().fetchSQL(tableName: redirectName, primaryKey: confirmURL.md5())
            if let rs = try?db.executeQuery(fetchSQL, values: nil) {
                // 有重定向
                if rs.next() {
                    guard let request = rs.string(forColumn: SQLConstructor().request) else {failure();return}
                    guard let response = rs.string(forColumn: SQLConstructor().response) else {failure();return}
                    guard let time = rs.string(forColumn: SQLConstructor().time) else {failure();return}
                    let requestPath = cachePath.appendingPathComponent(request)
                    let responsePath = cachePath.appendingPathComponent(response)
                    
                    let now = formatterDateToString(date: Date())
                    let cnn = Reachability(hostName: "www.baidu.com")
                    if cacheIsOutDate(before: time, now: now) && cnn?.currentReachabilityStatus() != NotReachable {
                        print("缓存过期,执行删除")
                        let deleteSQL = SQLConstructor().deleteSQL(tableName: redirectName, primaryKey: confirmURL.md5())
                        try?FileManager.default.removeItem(atPath: requestPath)
                        try?FileManager.default.removeItem(atPath: responsePath)
                        try?db.executeUpdate(deleteSQL, values: nil)
                        failure()
                    } else {
                        if FileManager.default.fileExists(atPath: requestPath) && FileManager.default.fileExists(atPath: responsePath) {
                            success(NSKeyedUnarchiver.unarchiveObject(withFile: requestPath) as! URLRequest,
                                    NSKeyedUnarchiver.unarchiveObject(withFile: responsePath) as! URLResponse)
                        } else {
                            try?db.executeUpdate(SQLConstructor().deleteSQL(tableName: redirectName, primaryKey: confirmURL.md5()), values: nil)
                            failure()
                        }
                    }
                } else {
                    failure()
                }
            } else {
                failure()
            }
        }
        dbQueue.close()
    }
    
    
    /// 从数据库获取缓存记录，如果过期则删除
    ///
    /// - Parameters:
    ///   - url: 请求URL
    ///   - success: 命中缓存回调
    ///   - failure: 未命中回调
    func fetchOrDeleteCacheInfo(url: String,success:(CachedURLResponse)->Void,failure:()->Void) {
        let querySQL = SQLConstructor().fetchSQL(tableName: cacheName, primaryKey: url.md5())
        let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
        dbQueue.inDatabase({ (db) in
            // 保存查询到的值
            var dic = [String:String]()
            if let result = try?db.executeQuery(querySQL, values: nil) {
                if result.next() {
                    dic[SQLConstructor().key] = result.string(forColumn: SQLConstructor().key)
                    dic[SQLConstructor().time] = result.string(forColumn: SQLConstructor().time)
                    if let key = dic[SQLConstructor().key], let time = dic[SQLConstructor().time] {
                        
                        let now = formatterDateToString(date: Date())
                        let cnn = Reachability(hostName: "www.baidu.com")
                        // 判断网络状态，网络连通则可以抛弃过期缓存。无网络则直接加载缓存
                        if cacheIsOutDate(before: time, now: now) && cnn?.currentReachabilityStatus() != NotReachable {
                            print("缓存过期,执行删除")
                            let deleteSQL = SQLConstructor().deleteSQL(tableName: cacheName, primaryKey: key)
                            try?db.executeUpdate(deleteSQL, values: nil)
                            failure()
                        } else {
                            let path = cachePath.appendingPathComponent(key)
                            if FileManager.default.fileExists(atPath: path) {
                                success(NSKeyedUnarchiver.unarchiveObject(withFile: path) as! CachedURLResponse)
                            } else {
                                print("\(key)本地文件不存在，删除数据库记录")
                                let deleteSQL = SQLConstructor().deleteSQL(tableName: cacheName, primaryKey: key)
                                try?db.executeUpdate(deleteSQL, values: nil)
                                failure()
                            }
                        }
                    } else {
                        failure()
                    }
                } else {
                    failure()
                }
                result.close()
            } else {
                failure()
            }
        })
        dbQueue.close()
    }
    
    // MARK: - 缓存策略逻辑
    /// 根据设定时间节点来删除缓存
    func programDeleteCacheFile() {
        // 查看数据库，筛选时间节点，时间节点超过缓存有效时间则删除
        let cacheoutSQL = SQLConstructor().fetchCacheWillDeleteSQL(tableName: cacheName, timeInterval: timeout)
        let redirectoutSQL = SQLConstructor().fetchCacheWillDeleteSQL(tableName: redirectName, timeInterval: timeout)
        let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
        dbQueue.inDatabase { (db) in
            guard let rsCacheout = try?db.executeQuery(cacheoutSQL, values: nil) else {return}
            guard let rsRedirect = try?db.executeQuery(redirectoutSQL, values: nil) else {return}
            while rsCacheout.next() {
                guard let MD5 = rsCacheout.string(forColumn: SQLConstructor().key) else {continue}
                if FileManager.default.fileExists(atPath: cachePath.appendingPathComponent(MD5)) {
                    try!FileManager.default.removeItem(atPath: cachePath.appendingPathComponent(MD5))
                    try?db.executeUpdate(SQLConstructor().deleteSQL(tableName: cacheName, primaryKey: MD5), values: nil)
                }
            }
            while rsRedirect.next() {
                guard let MD5 = rsRedirect.string(forColumn: SQLConstructor().key) else {continue}
                guard let requestHash = rsRedirect.string(forColumn: SQLConstructor().request) else {continue}
                guard let responseHash = rsRedirect.string(forColumn: SQLConstructor().response) else {continue}
                if FileManager.default.fileExists(atPath: cachePath.appendingPathComponent(requestHash)) {
                    try!FileManager.default.removeItem(atPath: cachePath.appendingPathComponent(requestHash))
                    
                }
                if FileManager.default.fileExists(atPath: cachePath.appendingPathComponent(responseHash)) {
                    try!FileManager.default.removeItem(atPath: cachePath.appendingPathComponent(responseHash))
                }
                try?db.executeUpdate(SQLConstructor().deleteSQL(tableName: redirectName, primaryKey: MD5), values: nil)
            }
            rsCacheout.close()
            rsRedirect.close()
        }
        dbQueue.close()
    }
    
    // MARK: - 私有属性
    private var timeout:Int = 60*2
    private var cacheSize:Double = 1024*1024*10
    private var cacheName = "Caches"
    private var redirectName = "RedirectURLS"
    private let documentPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last
    private var db : FMDatabase? = nil
    
    // MARK: - 私有方法
    private init() {
        _ = openDB()
    }
    
    deinit {
        db?.close()
    }
    
    /// 打开数据库
    fileprivate func openDB() -> Bool{
        db = FMDatabase(path: "\(documentPath!)/app.sqlite")
        print("路径：\(documentPath!)/app.sqlite")
        if !db!.open() {
            return false
        }
        createTable()
        return true
    }
    
    /// 根据名字建表,表中所有数据均为TEXT类型,即String,请自行转换
    fileprivate func createTable() {
        if !isTableExist(tableName: cacheName) {
            let createTable = SQLConstructor().createCacheSQL(name: cacheName)
            let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
            dbQueue.inDatabase({ (db) in
                try!db.executeUpdate(createTable, values: nil)
            })
            dbQueue.close()
        }
        if !isTableExist(tableName: redirectName) {
            let createRedirect = SQLConstructor().createRedirectTableSQL(name: redirectName)
            let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
            dbQueue.inDatabase({ (db) in
                try!db.executeUpdate(createRedirect, values: nil)
            })
            dbQueue.close()
        }
    }
    
    /// 判断缓存是否过期
    fileprivate func cacheIsOutDate(before: String, now: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyy-MM-dd HH:mm:ss"
        if let beforeTime = formatter.date(from: before), let nowTime = formatter.date(from: now) {
            let inter = nowTime.timeIntervalSince(beforeTime)
            if inter < TimeInterval(timeout) {
                return false
            } else {
                return true
            }
        }
        return false
    }
    
    /// 日期格式化
    fileprivate func formatterDateToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    /// 查询表是否存在
    fileprivate func isTableExist(tableName name: String) -> Bool {
        var isExist = false
        let search = SQLConstructor().searchTableSQL(tableName: name)
        let dbQueue = FMDatabaseQueue(path: "\(documentPath!)/app.sqlite")
        dbQueue.inDatabase({ (db) in
            guard let result = try?db.executeQuery(search, values: nil) else {return}
            if result.next() {
                isExist = true
            }
            result.close()
        })
        dbQueue.close()
        return isExist
    }
}
