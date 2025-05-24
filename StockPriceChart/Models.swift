// Models.swift
import Foundation


struct StockPrice {
    let date: Date
    let value: Double
}



struct YahooFinanceResponse: Codable {
    let chart: Chart
}

struct Chart: Codable {
    let result: [ChartResult]
}

struct ChartResult: Codable {
    let timestamp: [Int]
    let indicators: Indicators
    let meta:meta
}

struct Indicators: Codable {
    let quote: [Quote]
}

struct meta: Codable {
    let shortName: String
}

struct Quote: Codable {
    let close: [Double?]
}


