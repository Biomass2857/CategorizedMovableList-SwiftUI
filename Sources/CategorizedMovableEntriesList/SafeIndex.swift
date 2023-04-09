import Foundation

extension Array {
    subscript(safeIndex index: Int) -> Element? {
        if 0..<count ~= index {
            return self[index]
        }
        
        return nil
    }
}
