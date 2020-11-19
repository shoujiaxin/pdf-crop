//
//  main.swift
//  PDFCrop
//
//  Created by Jiaxin Shou on 2020/9/19.
//

import ArgumentParser
import Foundation
import PDFKit

struct PdfCrop: ParsableCommand {
    @Argument(help: "Input PDF file.")
    var file: String?

    @Option(name: .shortAndLong, help: "Output PDF file.")
    var output: String?

    @Option(name: .shortAndLong, help: "Top margin.")
    var topMargin: Int = 0

    @Option(name: .shortAndLong, help: "Left margin.")
    var leftMargin: Int = 0

    @Option(name: .shortAndLong, help: "Bottom margin.")
    var bottomMargin: Int = 0

    @Option(name: .shortAndLong, help: "Right margin.")
    var rightMargin: Int = 0

    @Flag(name: .shortAndLong, help: "Save the cropped file in place.")
    var inPlace: Bool = false

    mutating func run() throws {
        guard let file = file, let document = PDFDocument(url: URL(fileURLWithPath: file)) else {
            throw ValidationError("Please input a PDF file.")
        }

        for i in 0 ..< document.pageCount {
            let page = document.page(at: i)

            page?.autoCropByContent(with: CropMargins(top: topMargin, left: leftMargin, bottom: bottomMargin, right: rightMargin))
        }

        if let output = output {
            document.write(toFile: output)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let fileName = "pdf-crop-\(dateFormatter.string(from: Date())).pdf"

            var url = URL(fileURLWithPath: file)
            if !inPlace {
                url.deleteLastPathComponent()
                url.appendPathComponent(fileName)
            }

            document.write(to: url)
        }
    }
}

public struct CropMargins {
    public var top: Int
    public var left: Int
    public var bottom: Int
    public var right: Int

    public init(top: Int, left: Int, bottom: Int, right: Int) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = CropMargins(top: 0, left: 0, bottom: 0, right: 0)
}

extension PDFPage {
    private var height: Int {
        return Int(bounds(for: .mediaBox).height)
    }

    private var width: Int {
        return Int(bounds(for: .mediaBox).width)
    }

    public func autoCropByContent(with margins: CropMargins) {
        let image = thumbnail(of: NSSize(width: width, height: height), for: .mediaBox)
        guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else {
            return
        }

        var top = 0
        var left = 0
        var bottom = height - 1
        var right = width - 1

        while top < bottom {
            if bitmap.checkRow(at: top) {
                top += 1
            } else {
                break
            }
        }

        while top < bottom {
            if bitmap.checkRow(at: bottom) {
                bottom -= 1
            } else {
                break
            }
        }

        while left < right {
            if bitmap.checkColumn(at: left) {
                left += 1
            } else {
                break
            }
        }

        while left < right {
            if bitmap.checkColumn(at: right) {
                right -= 1
            } else {
                break
            }
        }

        if margins.top > 0 {
            top = (top - margins.top >= 0) ? top - margins.top : 0
        }
        if margins.left > 0 {
            left = (left - margins.left >= 0) ? left - margins.left : 0
        }
        if margins.bottom > 0 {
            bottom = (bottom + margins.bottom >= height) ? height - 1 : bottom + margins.bottom
        }
        if margins.right > 0 {
            right = (right + margins.right >= width) ? width - 1 : right + margins.right
        }

        let rect = NSRect(x: left, y: height - bottom, width: right - left, height: bottom - top)
        setBounds(rect, for: .mediaBox)
    }
}

extension NSBitmapImageRep {
    private var height: Int {
        return Int(size.height)
    }

    private var width: Int {
        return Int(size.width)
    }

    public func checkRow(at row: Int) -> Bool {
        let whiteColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)

        for i in 0 ..< width {
            if colorAt(x: i, y: row) != whiteColor {
                return false
            }
        }

        return true
    }

    public func checkColumn(at column: Int) -> Bool {
        let whiteColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)

        for i in 0 ..< height {
            if colorAt(x: column, y: i) != whiteColor {
                return false
            }
        }

        return true
    }
}

PdfCrop.main()
