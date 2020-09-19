//
//  main.swift
//  PDFCropper-CLI
//
//  Created by Jiaxin Shou on 2020/9/19.
//

import ArgumentParser
import Foundation
import PDFKit

struct PdfCropper: ParsableCommand {
    @Option(name: .shortAndLong, parsing: SingleValueParsingStrategy.next, help: "Input PDF file.", completion: nil)
    var input: String?

    @Option(name: .shortAndLong, parsing: SingleValueParsingStrategy.next, help: "Output PDF file.", completion: nil)
    var output: String?

    @Option(name: .shortAndLong, parsing: ArrayParsingStrategy.upToNextOption, help: "Crop margins (top, left, bottom, right).", completion: nil)
    var margins: [Int] = []

    mutating func run() throws {
        guard let input = input, let document = PDFDocument(url: URL(fileURLWithPath: input)) else {
            return
        }

        for i in 0 ..< document.pageCount {
            let page = document.page(at: i)

            if margins.isEmpty {
                page?.autoCropByContent(with: CropMargins.zero)
            } else {
                while margins.count < 4 {
                    margins.append(0)
                }
                page?.autoCropByContent(with: CropMargins(top: margins[0], left: margins[1], bottom: margins[2], right: margins[3]))
            }
        }

        if let output = output {
            document.write(toFile: output)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let fileName = "pdf-cropper-\(dateFormatter.string(from: Date())).pdf"

            var url = URL(fileURLWithPath: input)
            url.deleteLastPathComponent()
            url.appendPathComponent(fileName)

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

PdfCropper.main()
