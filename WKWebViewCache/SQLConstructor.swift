//
//  SQLConstructor.swift
//  WKWebViewCache
//
//  Created by monstar1 on 2018/6/25.
//  Copyright © 2018年 monstar1. All rights reserved.
//

import Foundation

class SQLConstructor {    
    var url = "url"
    var key = "key"
    var time = "time"
    var request = "request"
    var response = "response"
    var size = "size"
    private var cacheName = "Caches"
    private var redirectName = "RedirectURLS"
    func createCacheSQL(name: String) -> String {
        return "CREATE TABLE IF NOT EXISTS \(name) (key text primary key, url text, time text,request text,response text,size text)"
    }
    
    func createRedirectTableSQL(name: String) ->String {
         return "CREATE TABLE IF NOT EXISTS \(name) (key text primary key, url text, time text,request text,response text,size text);"
    }
    
    /// 这里根据猜测为查询的意思
    func fetchSQL(tableName: String, primaryKey: String?) -> String {
        if let primaryKey = primaryKey {
            return "select * from \(tableName) where key == \'" + primaryKey + "\'"
        }
        return "select * from \(tableName)"
    }
    
    func updateRedirectSQL(tableName: String, dic: [String: String]) ->String {
        let allKeys = dic.keys
        var sqlString = "UPDATE \(tableName) set"
        for key in allKeys {
            sqlString = sqlString + "\(key)=\(String(describing: dic["\(key)"]))"
        }
        return sqlString
    }

    func updateCacheSQL(tableName: String, dic: [String: String]) ->String {
        let allKeys = dic.keys
        var sqlString = "UPDATE \(tableName) SET "
        for (index,key) in allKeys.enumerated() {
            if index <= allKeys.count - 2 {
                sqlString = sqlString + "\(key)=\'" + dic["\(key)"]! + "\'" + ","
            } else {
                sqlString = sqlString + "\(key)=\'" + dic["\(key)"]! + "\'" + " where key=\'" + dic["key"]! + "\'"
            }
        }
        print(sqlString)
        return sqlString
    }
    
    func insertRedirectSQL(tableName: String, dic: [String: String]) ->String {
        let allKeys = dic.keys
        var sqlString = "INSERT INTO \(tableName) ("
        for (index,key) in allKeys.enumerated() {
            if index <= dic.keys.count - 2 {
                sqlString = sqlString + "\(key),"
            } else {
                sqlString = sqlString + "\(key)" + ") VALUES ("
            }

        }
        for (index,key) in allKeys.enumerated() {
            if index <= dic.keys.count - 2 {
                let str = dic["\(key)"] ?? ""
                sqlString = sqlString + "\'" + str + "\'" + ","
            } else {
                let str = dic["\(key)"] ?? ""
                sqlString = sqlString + "\'" + str + "\'"  + ")"
                print(sqlString)
            }

        }
        return sqlString
    }
    
    func insertCacheSQL(tableName: String, dic: [String: String]) ->String {
        let allKeys = dic.keys
        var sqlString = "INSERT INTO \(tableName) ("
        for (index,key) in allKeys.enumerated() {
            if index <= dic.keys.count - 2 {
                sqlString = sqlString + "\(key),"
            } else {
                sqlString = sqlString + "\(key)" + ") VALUES ("
            }
            
        }
        for (index,key) in allKeys.enumerated() {
            if index <= dic.keys.count - 2 {
                let str = dic["\(key)"] ?? ""
                sqlString = sqlString + "\'" + str + "\'" + ","
            } else {
                let str = dic["\(key)"] ?? ""
                sqlString = sqlString + "\'" + str + "\'"  + ")"
                print(sqlString)
            }

        }
        return sqlString
    }

    func fetchCacheWillDeleteSQL(tableName: String, timeInterval: Int) ->String {
        return ""
    }
    
    func deleteSQL(tableName: String, primaryKey: String) ->String {
        var sqlString = ""
        sqlString = "DELETE FROM \(tableName) WHERE key = \'" + primaryKey + "\'"
        return sqlString
    }
    
    func searchTableSQL(tableName: String) ->String {
        return ""
    }
    
    
}
