import SwiftUI

@available(iOS 16, *)
extension Binding {
    private class BindingHolder {
        var value: Value
        
        init(value: Value) {
            self.value = value
        }
    }
    
    static func Just(value: Value) -> Binding<Value> {
        let holder = BindingHolder(value: value)
        return Binding(get: {
            holder.value
        }, set: { newValue in
            holder.value = newValue
        })
    }
}
