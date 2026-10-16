import Combine
import SwiftUI

/// Drop-in stand-in for `@State`.
///
/// In this SDK `@State` is a macro whose plugin ships only with full Xcode,
/// so a Command Line Tools build can't expand it. `@Local` gives the same
/// view-owned, persistent storage by wrapping `@StateObject`.
@propertyWrapper
struct Local<Value>: DynamicProperty {
    @StateObject private var box: LocalBox<Value>

    init(wrappedValue: Value) {
        _box = StateObject(wrappedValue: LocalBox(wrappedValue))
    }

    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    var projectedValue: Binding<Value> {
        let box = box
        return Binding(get: { box.value }, set: { box.value = $0 })
    }
}

final class LocalBox<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
