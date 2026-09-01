import Combine

public enum RecognitionContinuationResolution<Payload> {
    case noPendingInput
    case resume(Payload)
    case discard
}

@MainActor
public final class RecognitionContinuation<Payload>: ObservableObject {
    private var pendingInput: Payload?

    public init() {}

    public var hasPendingInput: Bool {
        pendingInput != nil
    }

    public func enqueue(_ input: Payload) {
        pendingInput = input
    }

    public func resolveAfterPaywall(
        hasRecognitionAccess: Bool
    ) -> RecognitionContinuationResolution<Payload> {
        guard let pendingInput else {
            return .noPendingInput
        }

        self.pendingInput = nil
        guard hasRecognitionAccess else {
            return .discard
        }
        return .resume(pendingInput)
    }

    public func clear() {
        pendingInput = nil
    }
}
