// Models.swift
import Foundation

struct StockPrice: Codable {
    let dateTime: String
    let value: Double

    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateTime)
    }
}

struct StockData: Codable {
    let price: [StockPrice]
    let ticker: String
}

