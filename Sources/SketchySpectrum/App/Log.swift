import Foundation

func log(_ msg: String) {
    FileHandle.standardError.write(Data("SketchySpectrum: \(msg)\n".utf8))
}
