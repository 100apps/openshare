import Foundation

public enum ShareContent {
    case text(String)
    case link(URL, title: String? = nil, summary: String? = nil)
    case images([URL], caption: String? = nil)
    case video(URL, caption: String? = nil)
    case file(URL)

    public func validate() throws {
        switch self {
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareError.invalidContent }
        case .link(let url, _, _):
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false else {
                throw ShareError.invalidContent
            }
        case .images(let urls, _):
            guard !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { throw ShareError.invalidContent }
        case .video(let url, _), .file(let url):
            guard url.isFileURL else { throw ShareError.invalidContent }
        }
    }
}

public enum ShareRequest {
    case share(provider: String, channel: String = "default", content: ShareContent)
    case authorize(provider: String, scope: String, credential: ShareCredential.Kind = .authorizationCode)

    public var provider: String {
        switch self { case .share(let id, _, _), .authorize(let id, _, _): return id }
    }
    public func validate() throws {
        guard !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareError.invalidContent }
        switch self {
        case .share(_, let channel, let content):
            guard !channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareError.invalidContent }
            try content.validate()
        case .authorize(_, let scope, _):
            guard !scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareError.invalidContent }
        }
    }
}

public enum ShareError: String, Error {
    case invalidContent, unsupportedOperation, unsupportedContent, unsupportedField, unsupportedChannel
    case unsupportedCredentialKind, unsupportedObservation, unsupportedCorrelation, unknownProvider
    case configurationConflict, invalidPresenter, resourceUnavailable, providerUnavailable, busy
    case dispatchRejected, invalidResponse, providerError
}
public enum ShareOutcome: String, Hashable {
    case handedOff, activityCompleted, notCompleted, sdkReportedSuccess, credentialReceived
    case cancelledByUser, cancelledLocally, failed, indeterminate
}
public enum ShareCorrelation: String { case requestBound, serializedOnly, unknown }

public struct ShareCredential: CustomStringConvertible, CustomDebugStringConvertible {
    public enum Kind: String { case authorizationCode, identityToken, accessToken }
    public let kind: Kind
    public let value: String
    public init(kind: Kind, value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareError.invalidResponse }
        self.kind = kind; self.value = value
    }
    public var description: String { "ShareCredential(\(kind.rawValue), <redacted>)" }
    public var debugDescription: String { description }
}

public struct ShareResult: CustomStringConvertible, CustomDebugStringConvertible {
    public let provider: String
    public let outcome: ShareOutcome
    public let correlation: ShareCorrelation
    public let credential: ShareCredential?
    public let error: ShareError?
    public let providerCode: Int?
    public var description: String { "\(provider): \(outcome.rawValue)" }
    public var debugDescription: String { description }
}

public struct ShareCapabilities {
    public let outcomes: Set<ShareOutcome>
    public let correlation: ShareCorrelation
    public init(outcomes: Set<ShareOutcome>, correlation: ShareCorrelation) {
        self.outcomes = outcomes; self.correlation = correlation
    }
}

/// Implement this protocol to add a platform. Calls and callbacks belong on the main actor.
@MainActor public protocol ShareProvider: AnyObject {
    var id: String { get }
    /// One app-wide lane for SDKs whose requests must not overlap. nil for independent operations.
    var lane: String? { get }
    /// Exclusive callback namespaces, e.g. "scheme:wx123" or "sdk:wechat".
    var callbackKeys: Set<String> { get }
    func prepare(_ request: ShareRequest) throws -> ShareCapabilities
    func start(_ request: ShareRequest, context: AnyObject, operation: ShareOperation)
    func handleCallback(_ url: URL) -> Bool
}
public extension ShareProvider {
    var lane: String? { id }
    var callbackKeys: Set<String> { [] }
    func handleCallback(_ url: URL) -> Bool { false }
}

public struct SharePlan {
    public let request: ShareRequest
    public let capabilities: ShareCapabilities
    fileprivate let provider: any ShareProvider
}

/// A local cancellation ends the caller's wait, not the external SDK request.
@MainActor public final class ShareOperation {
    public private(set) var result: ShareResult?
    private let plan: SharePlan
    private var callback: ((ShareResult) -> Void)?
    private var timer: Timer?
    private var released = false

    fileprivate init(plan: SharePlan, timeout: TimeInterval, callback: @escaping (ShareResult) -> Void) {
        self.plan = plan; self.callback = callback
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [self] _ in
            MainActor.assumeIsolated { expire() }
        }
    }
    public func cancel() { deliver(.cancelledLocally) }
    func expire() { deliver(.indeterminate) }

    public func complete(_ outcome: ShareOutcome, credential: ShareCredential? = nil,
                         error: ShareError? = nil, providerCode: Int? = nil) {
        guard !released else { return }
        released = true
        ShareClient.release(plan: plan, operation: self)
        var outcome = outcome
        var error = error
        if outcome == .credentialReceived {
            if case .authorize(_, _, let kind) = plan.request, credential?.kind == kind {
                // The credential is still unverified by the application's server.
            } else { outcome = .failed; error = .invalidResponse }
        }
        if ![.failed, .indeterminate].contains(outcome) && !plan.capabilities.outcomes.contains(outcome) {
            outcome = .failed; error = .invalidResponse
        }
        if outcome == .failed && error == nil { error = .invalidResponse }
        deliver(outcome, credential: outcome == .credentialReceived ? credential : nil,
                error: error, providerCode: providerCode)
    }
    public func fail(_ error: ShareError, providerCode: Int? = nil) {
        complete(.failed, error: error, providerCode: providerCode)
    }
    private func deliver(_ outcome: ShareOutcome, credential: ShareCredential? = nil,
                         error: ShareError? = nil, providerCode: Int? = nil) {
        guard result == nil else { return }
        let value = ShareResult(provider: plan.request.provider, outcome: outcome,
                                correlation: plan.capabilities.correlation, credential: credential,
                                error: error, providerCode: providerCode)
        result = value; timer?.invalidate(); timer = nil
        let completion = callback; callback = nil
        if let completion { Task { @MainActor in completion(value) } }
    }
}

@MainActor public final class ShareClient {
    private final class Owner { weak var value: (any ShareProvider)?; init(_ value: any ShareProvider) { self.value = value } }
    private static var owners: [String: Owner] = [:]
    private static var active: [String: ShareOperation] = [:]
    private let providers: [String: any ShareProvider]

    public init(providers: [any ShareProvider]) throws {
        var registry: [String: any ShareProvider] = [:]
        var keys = Set<String>()
        for provider in providers {
            guard !provider.id.isEmpty, registry[provider.id] == nil else { throw ShareError.configurationConflict }
            registry[provider.id] = provider
            for key in provider.callbackKeys {
                guard keys.insert(key).inserted else { throw ShareError.configurationConflict }
                if let owner = Self.owners[key]?.value, owner !== provider { throw ShareError.configurationConflict }
            }
        }
        self.providers = registry
        for provider in providers { for key in provider.callbackKeys { Self.owners[key] = Owner(provider) } }
    }
    public func prepare(_ request: ShareRequest, requiring outcome: ShareOutcome? = nil,
                        requestBound: Bool = false) throws -> SharePlan {
        try request.validate()
        guard let provider = providers[request.provider] else { throw ShareError.unknownProvider }
        let capabilities = try provider.prepare(request)
        if let outcome, !capabilities.outcomes.contains(outcome) { throw ShareError.unsupportedObservation }
        if requestBound && capabilities.correlation != .requestBound { throw ShareError.unsupportedCorrelation }
        return SharePlan(request: request, capabilities: capabilities, provider: provider)
    }
    @discardableResult public func execute(_ plan: SharePlan, context: AnyObject, timeout: TimeInterval = 300,
                                          completion: @escaping (ShareResult) -> Void) throws -> ShareOperation {
        guard providers[plan.request.provider] === plan.provider else { throw ShareError.configurationConflict }
        guard timeout.isFinite && timeout > 0 else { throw ShareError.invalidContent }
        // Recheck content/resources and provider configuration, but never silently select another provider.
        try plan.request.validate()
        let current = try plan.provider.prepare(plan.request)
        guard current.outcomes == plan.capabilities.outcomes, current.correlation == plan.capabilities.correlation else {
            throw ShareError.configurationConflict
        }
        if let lane = plan.provider.lane, Self.active[lane] != nil { throw ShareError.busy }
        let operation = ShareOperation(plan: plan, timeout: timeout, callback: completion)
        if let lane = plan.provider.lane { Self.active[lane] = operation }
        plan.provider.start(plan.request, context: context, operation: operation)
        return operation
    }
    @discardableResult public func execute(_ request: ShareRequest, context: AnyObject, timeout: TimeInterval = 300,
                                          completion: @escaping (ShareResult) -> Void) throws -> ShareOperation {
        try execute(prepare(request), context: context, timeout: timeout, completion: completion)
    }
    public func handleCallback(_ url: URL) -> Bool {
        providers.values.contains { $0.handleCallback(url) }
    }
    fileprivate static func release(plan: SharePlan, operation: ShareOperation) {
        if let lane = plan.provider.lane, active[lane] === operation { active[lane] = nil }
    }
}
