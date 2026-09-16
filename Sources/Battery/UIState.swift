import SwiftUI

/// Safe State property wrapper to avoid CommandLineTools missing SwiftUIMacros plugin
@propertyWrapper
public struct UIState<Value>: DynamicProperty {
    private var _storage: SwiftUI.State<Value>

    public init(wrappedValue: Value) {
        _storage = SwiftUI.State(wrappedValue: wrappedValue)
    }

    public init(initialValue: Value) {
        _storage = SwiftUI.State(initialValue: initialValue)
    }

    public var wrappedValue: Value {
        get { _storage.wrappedValue }
        nonmutating set { _storage.wrappedValue = newValue }
    }

    public var projectedValue: Binding<Value> {
        _storage.projectedValue
    }
}
