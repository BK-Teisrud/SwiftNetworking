# Komplett offentlig API-referanse

Generert fra Swift-symbolgraphs. Ikke rediger deklarasjonene manuelt.

Se [håndboken](Handbook.md) for defaults, eksempler, sikkerhetsgrenser og lifecycle. Referansen inkluderer alle offentlige deklarasjoner og eventuelle syntetiserte protokollmedlemmer fra den bygde toolchainen.

## Networking

280 offentlige symboler.

### AuthenticationError

```swift
enum AuthenticationError
```

### AuthenticationError.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### AuthenticationError.invalidToken

```swift
case invalidToken
```

### AuthenticationError.localizedDescription

```swift
var localizedDescription: String { get }
```

### AuthenticationError.missingProvider

```swift
case missingProvider
```

### AuthenticationError.networkFailureCategory

```swift
var networkFailureCategory: NetworkFailureCategory { get }
```

### AuthenticationError.providerFailure

```swift
case providerFailure
```

### AuthenticationError.rejected

```swift
case rejected
```

### ClientConfiguration

```swift
struct ClientConfiguration
```

### ClientConfiguration.baseURL

```swift
let baseURL: URL
```

### ClientConfiguration.cachePolicy

```swift
let cachePolicy: URLRequest.CachePolicy
```

### ClientConfiguration.clock

```swift
let clock: any RetryClock
```

### ClientConfiguration.coding

```swift
let coding: JSONCoding
```

### ClientConfiguration.credentialProvider

```swift
let credentialProvider: (any CredentialProvider)?
```

### ClientConfiguration.defaultHeaders

```swift
let defaultHeaders: [String : String]
```

### ClientConfiguration.diagnostics

```swift
let diagnostics: (any NetworkingDiagnostics)?
```

### ClientConfiguration.init(baseURL:defaultHeaders:timeout:coding:transport:retry:credentialProvider:diagnostics:cachePolicy:redirectPolicy:security:clock:maximumTotalAttempts:maximumErrorBodyBytes:maximumResponseBytes:operationTimeout:diagnosticQueueCapacity:redirectHeaderAllowlist:sensitiveHeaderNames:)

```swift
init(baseURL: URL, defaultHeaders: [String : String] = [:], timeout: TimeInterval = ClientLimits.standard.requestTimeout, coding: JSONCoding = .init(), transport: any HTTPTransport = URLSessionTransport(), retry: RetryPolicy = .disabled, credentialProvider: (any CredentialProvider)? = nil, diagnostics: (any NetworkingDiagnostics)? = nil, cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, redirectPolicy: RedirectPolicy = RedirectOptions.standard.policy, security: ConnectionSecurity = .httpsOnly, clock: any RetryClock = SystemRetryClock(), maximumTotalAttempts: Int? = nil, maximumErrorBodyBytes: Int = ClientLimits.standard.maximumErrorBodyBytes, maximumResponseBytes: Int = ClientLimits.standard.maximumResponseBytes, operationTimeout: TimeInterval? = nil, diagnosticQueueCapacity: Int = DiagnosticsOptions.standard.queueCapacity, redirectHeaderAllowlist: Set<String> = RedirectOptions.standard.headerAllowlist, sensitiveHeaderNames: Set<String> = RedirectOptions.standard.sensitiveHeaderNames) throws
```

### ClientConfiguration.init(baseURL:limits:defaultHeaders:coding:transport:retry:credentialProvider:redirects:diagnostics:cachePolicy:security:clock:)

```swift
init(baseURL: URL, limits: ClientLimits, defaultHeaders: [String : String] = [:], coding: JSONCoding = .init(), transport: any HTTPTransport = URLSessionTransport(), retry: RetryPolicy = .disabled, credentialProvider: (any CredentialProvider)? = nil, redirects: RedirectOptions = .init(), diagnostics: DiagnosticsOptions = .init(), cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, security: ConnectionSecurity = .httpsOnly, clock: any RetryClock = SystemRetryClock()) throws
```

Grouped configuration. The original initializer remains available for existing consumers.

### ClientConfiguration.limits

```swift
var limits: ClientLimits { get }
```

### ClientConfiguration.maximumErrorBodyBytes

```swift
let maximumErrorBodyBytes: Int
```

### ClientConfiguration.maximumResponseBytes

```swift
let maximumResponseBytes: Int
```

### ClientConfiguration.maximumTotalAttempts

```swift
let maximumTotalAttempts: Int
```

Shared cap for all sends, including credential recovery. Defaults to retry.maximumAttempts + 1.

### ClientConfiguration.operationTimeout

```swift
let operationTimeout: TimeInterval?
```

### ClientConfiguration.redirectHeaderAllowlist

```swift
let redirectHeaderAllowlist: Set<String>
```

### ClientConfiguration.redirectPolicy

```swift
let redirectPolicy: RedirectPolicy
```

### ClientConfiguration.redirects

```swift
var redirects: RedirectOptions { get }
```

### ClientConfiguration.retry

```swift
let retry: RetryPolicy
```

### ClientConfiguration.sensitiveHeaderNames

```swift
let sensitiveHeaderNames: Set<String>
```

### ClientConfiguration.timeout

```swift
let timeout: TimeInterval
```

### ClientConfiguration.transport

```swift
let transport: any HTTPTransport
```

### ClientLimits

```swift
struct ClientLimits
```

Shared send, duration and memory limits. Validated when creating ClientConfiguration.

### ClientLimits.init(requestTimeout:operationTimeout:maximumTotalAttempts:maximumResponseBytes:maximumErrorBodyBytes:)

```swift
init(requestTimeout: TimeInterval = ClientLimits.standard.requestTimeout, operationTimeout: TimeInterval? = nil, maximumTotalAttempts: Int? = nil, maximumResponseBytes: Int = ClientLimits.standard.maximumResponseBytes, maximumErrorBodyBytes: Int = ClientLimits.standard.maximumErrorBodyBytes)
```

### ClientLimits.maximumErrorBodyBytes

```swift
let maximumErrorBodyBytes: Int
```

### ClientLimits.maximumResponseBytes

```swift
let maximumResponseBytes: Int
```

### ClientLimits.maximumTotalAttempts

```swift
let maximumTotalAttempts: Int?
```

### ClientLimits.operationTimeout

```swift
let operationTimeout: TimeInterval?
```

### ClientLimits.requestTimeout

```swift
let requestTimeout: TimeInterval
```

### ClientLimits.standard

```swift
static let standard: ClientLimits
```

### ConnectionSecurity

```swift
enum ConnectionSecurity
```

### ConnectionSecurity.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### ConnectionSecurity.allowLocalHTTP

```swift
case allowLocalHTTP
```

### ConnectionSecurity.httpsOnly

```swift
case httpsOnly
```

### CredentialProvider

```swift
protocol CredentialProvider : Sendable
```

Implementations own storage and concurrent refresh coordination; never initiate interactive login.

### CredentialProvider.bearerToken()

```swift
func bearerToken() async throws -> String
```

### CredentialProvider.recover(rejectedToken:)

```swift
func recover(rejectedToken: String) async throws -> String
```

### DecodedResponse

```swift
struct DecodedResponse<Value> where Value : Sendable
```

### DecodedResponse.init(value:metadata:)

```swift
init(value: Value, metadata: ResponseMetadata)
```

### DecodedResponse.metadata

```swift
let metadata: ResponseMetadata
```

### DecodedResponse.value

```swift
let value: Value
```

### DecodingFailure

```swift
struct DecodingFailure
```

### DecodingFailure.Kind

```swift
enum Kind
```

### DecodingFailure.Kind.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### DecodingFailure.Kind.dataCorrupted

```swift
case dataCorrupted
```

### DecodingFailure.Kind.keyNotFound

```swift
case keyNotFound
```

### DecodingFailure.Kind.other

```swift
case other
```

### DecodingFailure.Kind.typeMismatch

```swift
case typeMismatch
```

### DecodingFailure.Kind.valueNotFound

```swift
case valueNotFound
```

### DecodingFailure.codingPath

```swift
let codingPath: [String]
```

### DecodingFailure.description

```swift
let description: String
```

### DecodingFailure.init(error:metadata:)

```swift
init(error: any Error, metadata: ResponseMetadata)
```

### DecodingFailure.kind

```swift
let kind: DecodingFailure.Kind
```

### DecodingFailure.metadata

```swift
let metadata: ResponseMetadata
```

### DiagnosticEvent

```swift
struct DiagnosticEvent
```

Contains no URL, headers, credentials or body. Labels must be static operation names.

### DiagnosticEvent.Kind

```swift
enum Kind
```

### DiagnosticEvent.Kind.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### DiagnosticEvent.Kind.authenticationFailure

```swift
case authenticationFailure
```

### DiagnosticEvent.Kind.cancelled

```swift
case cancelled
```

### DiagnosticEvent.Kind.deadlineExceeded

```swift
case deadlineExceeded
```

### DiagnosticEvent.Kind.decodingFailure

```swift
case decodingFailure
```

### DiagnosticEvent.Kind.operationFailure

```swift
case operationFailure
```

### DiagnosticEvent.Kind.policyRejected

```swift
case policyRejected
```

### DiagnosticEvent.Kind.response

```swift
case response
```

### DiagnosticEvent.Kind.transportFailure

```swift
case transportFailure
```

### DiagnosticEvent.attempt

```swift
let attempt: Int
```

### DiagnosticEvent.duration

```swift
let duration: TimeInterval
```

### DiagnosticEvent.kind

```swift
let kind: DiagnosticEvent.Kind
```

### DiagnosticEvent.label

```swift
let label: String?
```

### DiagnosticEvent.method

```swift
let method: HTTPMethod
```

### DiagnosticEvent.operationID

```swift
let operationID: UUID
```

### DiagnosticEvent.statusCode

```swift
let statusCode: Int?
```

### DiagnosticsOptions

```swift
struct DiagnosticsOptions
```

Bounded asynchronous diagnostics; capacity is validated by ClientConfiguration.

### DiagnosticsOptions.init(sink:queueCapacity:)

```swift
init(sink: (any NetworkingDiagnostics)? = nil, queueCapacity: Int = DiagnosticsOptions.standard.queueCapacity)
```

### DiagnosticsOptions.queueCapacity

```swift
let queueCapacity: Int
```

### DiagnosticsOptions.sink

```swift
let sink: (any NetworkingDiagnostics)?
```

### DiagnosticsOptions.standard

```swift
static let standard: DiagnosticsOptions
```

### HTTPBody

```swift
struct HTTPBody
```

### HTTPBody.data(_:contentType:)

```swift
static func data(_ data: Data, contentType: String) -> HTTPBody
```

### HTTPBody.form(_:)

```swift
static func form(_ fields: [URLQueryItem]) -> HTTPBody
```

UTF-8 form encoding, preserving duplicate names/order; nil values become empty strings.

### HTTPBody.json(_:)

```swift
static func json<T>(_ value: T) -> HTTPBody where T : Encodable, T : Sendable
```

### HTTPClient

```swift
struct HTTPClient
```

### HTTPClient.configuration

```swift
let configuration: ClientConfiguration
```

### HTTPClient.data(_:)

```swift
func data(_ request: HTTPRequest) async throws -> HTTPResponse
```

### HTTPClient.decode(_:as:)

```swift
func decode<Value>(_ request: HTTPRequest, as type: Value.Type) async throws -> DecodedResponse<Value> where Value : Decodable, Value : Sendable
```

### HTTPClient.droppedDiagnosticEvents

```swift
var droppedDiagnosticEvents: Int { get }
```

### HTTPClient.execute(_:)

```swift
@discardableResult func execute(_ request: HTTPRequest) async throws -> ResponseMetadata
```

### HTTPClient.flushDiagnostics()

```swift
func flushDiagnostics() async
```

### HTTPClient.init(configuration:)

```swift
init(configuration: ClientConfiguration)
```

### HTTPClient.prepare(_:)

```swift
func prepare(_ request: HTTPRequest) async throws -> URLRequest
```

Builds and authenticates one request for an adapter. Does not send, retry or recover credentials.

### HTTPFailure

```swift
struct HTTPFailure
```

### HTTPFailure.body

```swift
let body: Data
```

### HTTPFailure.bodyWasTruncated

```swift
let bodyWasTruncated: Bool
```

### HTTPFailure.init(metadata:body:bodyWasTruncated:)

```swift
init(metadata: ResponseMetadata, body: Data, bodyWasTruncated: Bool = false)
```

### HTTPFailure.metadata

```swift
let metadata: ResponseMetadata
```

### HTTPMethod

```swift
struct HTTPMethod
```

Case-sensitive HTTP token. Custom methods still require URLSession/backend support.

### HTTPMethod.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### HTTPMethod.delete

```swift
static let delete: HTTPMethod
```

### HTTPMethod.get

```swift
static let get: HTTPMethod
```

### HTTPMethod.hash(into:)

```swift
func hash(into hasher: inout Hasher)
```

### HTTPMethod.hashValue

```swift
var hashValue: Int { get }
```

### HTTPMethod.head

```swift
static let head: HTTPMethod
```

### HTTPMethod.init(rawValue:)

```swift
init?(rawValue: String)
```

Creates a new instance with the specified raw value.

If there is no value of the type that corresponds with the specified raw
value, this initializer returns `nil`. For example:

    enum PaperSize: String {
        case A4, A5, Letter, Legal
    }

    print(PaperSize(rawValue: "Legal"))
    // Prints "Optional(PaperSize.Legal)"

    print(PaperSize(rawValue: "Tabloid"))
    // Prints "nil"

- Parameter rawValue: The raw value to use for the new instance.

### HTTPMethod.options

```swift
static let options: HTTPMethod
```

### HTTPMethod.patch

```swift
static let patch: HTTPMethod
```

### HTTPMethod.post

```swift
static let post: HTTPMethod
```

### HTTPMethod.put

```swift
static let put: HTTPMethod
```

### HTTPMethod.rawValue

```swift
let rawValue: String
```

The corresponding value of the raw type.

A new instance initialized with `rawValue` will be equivalent to this
instance. For example:

    enum PaperSize: String {
        case A4, A5, Letter, Legal
    }

    let selectedSize = PaperSize.Letter
    print(selectedSize.rawValue)
    // Prints "Letter"

    print(selectedSize == PaperSize(rawValue: selectedSize.rawValue)!)
    // Prints "true"

### HTTPRequest

```swift
struct HTTPRequest
```

### HTTPRequest.body

```swift
let body: HTTPBody?
```

### HTTPRequest.cachePolicy

```swift
let cachePolicy: URLRequest.CachePolicy?
```

### HTTPRequest.diagnosticLabel

```swift
let diagnosticLabel: StaticString?
```

### HTTPRequest.headers

```swift
let headers: [String : String]
```

### HTTPRequest.idempotencyKey

```swift
let idempotencyKey: String?
```

### HTTPRequest.init(method:path:query:headers:body:idempotencyKey:requiresAuthentication:replayPolicy:timeout:cachePolicy:operationTimeout:diagnosticLabel:)

```swift
init(method: HTTPMethod = .get, path: String, query: [URLQueryItem] = [], headers: [String : String] = [:], body: HTTPBody? = nil, idempotencyKey: String? = nil, requiresAuthentication: Bool = false, replayPolicy: ReplayPolicy = .safeMethodsOnly, timeout: TimeInterval? = nil, cachePolicy: URLRequest.CachePolicy? = nil, operationTimeout: TimeInterval? = nil, diagnosticLabel: StaticString? = nil)
```

### HTTPRequest.init(method:pathSegments:query:headers:body:idempotencyKey:requiresAuthentication:replayPolicy:timeout:cachePolicy:operationTimeout:diagnosticLabel:)

```swift
init(method: HTTPMethod = .get, pathSegments: [String], query: [URLQueryItem] = [], headers: [String : String] = [:], body: HTTPBody? = nil, idempotencyKey: String? = nil, requiresAuthentication: Bool = false, replayPolicy: ReplayPolicy = .safeMethodsOnly, timeout: TimeInterval? = nil, cachePolicy: URLRequest.CachePolicy? = nil, operationTimeout: TimeInterval? = nil, diagnosticLabel: StaticString? = nil)
```

Raw segment values are encoded exactly once; a slash in a value remains within its segment.

### HTTPRequest.method

```swift
let method: HTTPMethod
```

### HTTPRequest.operationTimeout

```swift
let operationTimeout: TimeInterval?
```

### HTTPRequest.path

```swift
var path: String { get }
```

### HTTPRequest.pathSegments

```swift
var pathSegments: [String]? { get }
```

### HTTPRequest.query

```swift
let query: [URLQueryItem]
```

### HTTPRequest.replayPolicy

```swift
let replayPolicy: ReplayPolicy
```

### HTTPRequest.requiresAuthentication

```swift
let requiresAuthentication: Bool
```

### HTTPRequest.timeout

```swift
let timeout: TimeInterval?
```

### HTTPRequestPreparing

```swift
protocol HTTPRequestPreparing : Sendable
```

Builds and authenticates one request without sending, retrying or credential recovery.

### HTTPRequestPreparing.prepare(_:)

```swift
func prepare(_ request: HTTPRequest) async throws -> URLRequest
```

### HTTPResponse

```swift
struct HTTPResponse
```

### HTTPResponse.data

```swift
let data: Data
```

### HTTPResponse.init(data:metadata:receivedBodyBytes:)

```swift
init(data: Data, metadata: ResponseMetadata, receivedBodyBytes: Int? = nil)
```

### HTTPResponse.metadata

```swift
let metadata: ResponseMetadata
```

### HTTPResponse.receivedBodyBytes

```swift
let receivedBodyBytes: Int
```

### HTTPTransport

```swift
protocol HTTPTransport : Sendable
```

Transports must return redirects without following them. Override bounded send to enforce limits during download.

### HTTPTransport.send(_:redirectPolicy:)

```swift
func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse
```

### HTTPTransport.send(_:redirectPolicy:options:)

```swift
func send(_ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions) async throws -> HTTPResponse
```

### HTTPTransport.send(_:redirectPolicy:options:)

```swift
func send(_ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions) async throws -> HTTPResponse
```

### HTTPTransportOptions

```swift
struct HTTPTransportOptions
```

### HTTPTransportOptions.allowsCaching

```swift
let allowsCaching: Bool
```

### HTTPTransportOptions.discardSuccessBody

```swift
let discardSuccessBody: Bool
```

### HTTPTransportOptions.init(maximumResponseBytes:discardSuccessBody:maximumErrorBodyBytes:allowsCaching:)

```swift
init(maximumResponseBytes: Int = 10_485_760, discardSuccessBody: Bool = false, maximumErrorBodyBytes: Int = 16_384, allowsCaching: Bool = true)
```

### HTTPTransportOptions.maximumErrorBodyBytes

```swift
let maximumErrorBodyBytes: Int
```

### HTTPTransportOptions.maximumResponseBytes

```swift
let maximumResponseBytes: Int
```

### JSONCoding

```swift
struct JSONCoding
```

### JSONCoding.Options

```swift
struct Options
```

### JSONCoding.Options.Dates

```swift
enum Dates
```

### JSONCoding.Options.Dates.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### JSONCoding.Options.Dates.deferred

```swift
case deferred
```

### JSONCoding.Options.Dates.iso8601

```swift
case iso8601
```

### JSONCoding.Options.Dates.millisecondsSince1970

```swift
case millisecondsSince1970
```

### JSONCoding.Options.Dates.secondsSince1970

```swift
case secondsSince1970
```

### JSONCoding.Options.Keys

```swift
enum Keys
```

### JSONCoding.Options.Keys.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### JSONCoding.Options.Keys.snakeCase

```swift
case snakeCase
```

### JSONCoding.Options.Keys.standard

```swift
case standard
```

### JSONCoding.Options.dates

```swift
let dates: JSONCoding.Options.Dates
```

### JSONCoding.Options.init(keys:dates:)

```swift
init(keys: JSONCoding.Options.Keys = .standard, dates: JSONCoding.Options.Dates = .deferred)
```

### JSONCoding.Options.keys

```swift
let keys: JSONCoding.Options.Keys
```

### JSONCoding.init(makeEncoder:makeDecoder:)

```swift
init(makeEncoder: @escaping () -> JSONEncoder, makeDecoder: @escaping () -> JSONDecoder)
```

Factories must return a new coder on each invocation.

### JSONCoding.init(options:)

```swift
init(options: JSONCoding.Options = .init())
```

### JSONCoding.makeDecoder

```swift
let makeDecoder: () -> JSONDecoder
```

### JSONCoding.makeEncoder

```swift
let makeEncoder: () -> JSONEncoder
```

### NetworkFailureCategory

```swift
enum NetworkFailureCategory
```

Stable handling categories across HTTP, file transfers and realtime; no automatic retry decision.

### NetworkFailureCategory.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### NetworkFailureCategory.authentication

```swift
case authentication
```

### NetworkFailureCategory.cancelled

```swift
case cancelled
```

### NetworkFailureCategory.configuration

```swift
case configuration
```

### NetworkFailureCategory.decoding

```swift
case decoding
```

### NetworkFailureCategory.encoding

```swift
case encoding
```

### NetworkFailureCategory.fileSystem

```swift
case fileSystem
```

### NetworkFailureCategory.http

```swift
case http
```

### NetworkFailureCategory.other

```swift
case other
```

### NetworkFailureCategory.policy

```swift
case policy
```

### NetworkFailureCategory.timeout

```swift
case timeout
```

### NetworkFailureCategory.transport

```swift
case transport
```

### NetworkFailureClassifying

```swift
protocol NetworkFailureClassifying : Error
```

Allows modules and custom adapters to classify their own errors without losing payloads.

### NetworkFailureClassifying.networkFailureCategory

```swift
var networkFailureCategory: NetworkFailureCategory { get }
```

### NetworkFailures

```swift
enum NetworkFailures
```

### NetworkFailures.category(of:)

```swift
static func category(of error: any Error) -> NetworkFailureCategory
```

Classifies package errors and raw Foundation errors; preserves the original error for inspection.

### NetworkingDiagnostics

```swift
protocol NetworkingDiagnostics : Sendable
```

### NetworkingDiagnostics.record(_:)

```swift
func record(_ event: DiagnosticEvent) async
```

### NetworkingError

```swift
enum NetworkingError
```

### NetworkingError.authentication(_:)

```swift
case authentication(AuthenticationError)
```

### NetworkingError.deadlineExceeded

```swift
case deadlineExceeded
```

### NetworkingError.emptyResponse(_:)

```swift
case emptyResponse(ResponseMetadata)
```

### NetworkingError.http(_:)

```swift
case http(HTTPFailure)
```

### NetworkingError.invalidConfiguration(_:)

```swift
case invalidConfiguration(String)
```

### NetworkingError.invalidRequest(_:)

```swift
case invalidRequest(String)
```

### NetworkingError.invalidResponse

```swift
case invalidResponse
```

### NetworkingError.localizedDescription

```swift
var localizedDescription: String { get }
```

### NetworkingError.networkFailureCategory

```swift
var networkFailureCategory: NetworkFailureCategory { get }
```

### NetworkingError.redirectRejected(_:)

```swift
case redirectRejected(RedirectFailure)
```

### NetworkingError.requestEncoding(_:)

```swift
case requestEncoding(String)
```

### NetworkingError.responseDecoding(_:)

```swift
case responseDecoding(DecodingFailure)
```

### NetworkingError.responseTooLarge(limit:metadata:)

```swift
case responseTooLarge(limit: Int, metadata: ResponseMetadata?)
```

### NetworkingError.timeout

```swift
case timeout
```

### NetworkingError.transport(_:)

```swift
case transport(TransportFailure)
```

### RedirectFailure

```swift
struct RedirectFailure
```

### RedirectFailure.Reason

```swift
enum Reason
```

### RedirectFailure.Reason.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### RedirectFailure.Reason.attemptLimit

```swift
case attemptLimit
```

### RedirectFailure.Reason.credentialsInURL

```swift
case credentialsInURL
```

### RedirectFailure.Reason.invalidLocation

```swift
case invalidLocation
```

### RedirectFailure.Reason.outsideAPIPrefix

```swift
case outsideAPIPrefix
```

### RedirectFailure.Reason.policyDenied

```swift
case policyDenied
```

### RedirectFailure.Reason.replayUnsafe

```swift
case replayUnsafe
```

### RedirectFailure.Reason.retryAfterExceedsLimit

```swift
case retryAfterExceedsLimit
```

### RedirectFailure.Reason.unapprovedOrigin

```swift
case unapprovedOrigin
```

### RedirectFailure.Reason.unsafePath

```swift
case unsafePath
```

### RedirectFailure.init(reason:metadata:)

```swift
init(reason: RedirectFailure.Reason, metadata: ResponseMetadata)
```

### RedirectFailure.metadata

```swift
let metadata: ResponseMetadata
```

### RedirectFailure.reason

```swift
let reason: RedirectFailure.Reason
```

### RedirectOptions

```swift
struct RedirectOptions
```

Redirect forwarding and credential-header classification, validated by ClientConfiguration.

### RedirectOptions.headerAllowlist

```swift
let headerAllowlist: Set<String>
```

### RedirectOptions.init(policy:headerAllowlist:sensitiveHeaderNames:)

```swift
init(policy: RedirectPolicy = RedirectOptions.standard.policy, headerAllowlist: Set<String> = RedirectOptions.standard.headerAllowlist, sensitiveHeaderNames: Set<String> = RedirectOptions.standard.sensitiveHeaderNames)
```

### RedirectOptions.policy

```swift
let policy: RedirectPolicy
```

### RedirectOptions.sensitiveHeaderNames

```swift
let sensitiveHeaderNames: Set<String>
```

### RedirectOptions.standard

```swift
static let standard: RedirectOptions
```

### RedirectPolicy

```swift
enum RedirectPolicy
```

### RedirectPolicy.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### RedirectPolicy.reject

```swift
case reject
```

### RedirectPolicy.sameOriginWithoutCredentials

```swift
case sameOriginWithoutCredentials
```

### ReplayPolicy

```swift
enum ReplayPolicy
```

Explicit confirmation that the server contract permits repeating this operation.

### ReplayPolicy.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### ReplayPolicy.confirmedSafe

```swift
case confirmedSafe
```

### ReplayPolicy.never

```swift
case never
```

### ReplayPolicy.safeMethodsOnly

```swift
case safeMethodsOnly
```

### ResponseMetadata

```swift
struct ResponseMetadata
```

### ResponseMetadata.header(_:)

```swift
func header(_ name: String) -> String?
```

### ResponseMetadata.headers

```swift
let headers: [String : String]
```

### ResponseMetadata.init(statusCode:headers:url:wasRedirected:)

```swift
init(statusCode: Int, headers: [String : String] = [:], url: URL? = nil, wasRedirected: Bool = false)
```

### ResponseMetadata.requestID

```swift
var requestID: String? { get }
```

### ResponseMetadata.statusCode

```swift
let statusCode: Int
```

### ResponseMetadata.url

```swift
let url: URL?
```

### ResponseMetadata.wasRedirected

```swift
let wasRedirected: Bool
```

### RetryClock

```swift
protocol RetryClock : Sendable
```

### RetryClock.now()

```swift
func now() async -> Date
```

### RetryClock.sleep(for:)

```swift
func sleep(for seconds: TimeInterval) async throws
```

### RetryPolicy

```swift
struct RetryPolicy
```

### RetryPolicy.baseDelay

```swift
let baseDelay: TimeInterval
```

### RetryPolicy.disabled

```swift
static let disabled: RetryPolicy
```

### RetryPolicy.init(maximumAttempts:baseDelay:maximumDelay:statusCodes:transportCodes:jitter:)

```swift
init(maximumAttempts: Int = 1, baseDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 30, statusCodes: Set<Int> = [408, 429, 500, 502, 503, 504], transportCodes: Set<Int> = [
      URLError.timedOut.rawValue, URLError.networkConnectionLost.rawValue,
    ], jitter: @escaping () -> Double = { Double.random(in: 0...1) })
```

maximumAttempts includes the initial send. 400, 401 and 403 are never automatic retries.

### RetryPolicy.jitter

```swift
let jitter: () -> Double
```

### RetryPolicy.maximumAttempts

```swift
let maximumAttempts: Int
```

### RetryPolicy.maximumDelay

```swift
let maximumDelay: TimeInterval
```

### RetryPolicy.statusCodes

```swift
let statusCodes: Set<Int>
```

### RetryPolicy.transportCodes

```swift
let transportCodes: Set<Int>
```

### SystemRetryClock

```swift
struct SystemRetryClock
```

### SystemRetryClock.init()

```swift
init()
```

### SystemRetryClock.now()

```swift
func now() async -> Date
```

### SystemRetryClock.sleep(for:)

```swift
func sleep(for seconds: TimeInterval) async throws
```

### TransportFailure

```swift
struct TransportFailure
```

### TransportFailure.Cause

```swift
struct Cause
```

### TransportFailure.Cause.code

```swift
let code: Int
```

### TransportFailure.Cause.description

```swift
let description: String
```

### TransportFailure.Cause.domain

```swift
let domain: String
```

### TransportFailure.causes

```swift
let causes: [TransportFailure.Cause]
```

### TransportFailure.code

```swift
let code: Int
```

### TransportFailure.description

```swift
let description: String
```

### TransportFailure.domain

```swift
let domain: String
```

### TransportFailure.init(error:)

```swift
init(error: any Error)
```

### URLSessionTransport

```swift
final class URLSessionTransport
```

### URLSessionTransport.Options

```swift
struct Options
```

### URLSessionTransport.Options.allowsConstrainedNetworkAccess

```swift
let allowsConstrainedNetworkAccess: Bool
```

### URLSessionTransport.Options.allowsExpensiveNetworkAccess

```swift
let allowsExpensiveNetworkAccess: Bool
```

### URLSessionTransport.Options.init(waitsForConnectivity:allowsExpensiveNetworkAccess:allowsConstrainedNetworkAccess:memoryCacheBytes:)

```swift
init(waitsForConnectivity: Bool = false, allowsExpensiveNetworkAccess: Bool = true, allowsConstrainedNetworkAccess: Bool = true, memoryCacheBytes: Int = 0) throws
```

### URLSessionTransport.Options.memoryCacheBytes

```swift
let memoryCacheBytes: Int
```

### URLSessionTransport.Options.waitsForConnectivity

```swift
let waitsForConnectivity: Bool
```

### URLSessionTransport.clearCache()

```swift
func clearCache()
```

Removes cached responses. Account changes also require cancellation/discarding of old operations.

### URLSessionTransport.init()

```swift
convenience init()
```

### URLSessionTransport.init(options:)

```swift
convenience init(options: URLSessionTransport.Options)
```

### URLSessionTransport.invalidateAndCancel()

```swift
func invalidateAndCancel()
```

### URLSessionTransport.send(_:redirectPolicy:)

```swift
func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse
```

### URLSessionTransport.send(_:redirectPolicy:options:)

```swift
func send(_ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions) async throws -> HTTPResponse
```

## NetworkingTransfers

114 offentlige symboler.

### BackgroundReceiptIssue

```swift
struct BackgroundReceiptIssue
```

### BackgroundReceiptIssue.Category

```swift
enum Category
```

### BackgroundReceiptIssue.Category.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### BackgroundReceiptIssue.Category.invalidReceipt

```swift
case invalidReceipt
```

### BackgroundReceiptIssue.Category.tooLarge

```swift
case tooLarge
```

### BackgroundReceiptIssue.Category.unreadable

```swift
case unreadable
```

### BackgroundReceiptIssue.category

```swift
let category: BackgroundReceiptIssue.Category
```

### BackgroundReceiptIssue.fileName

```swift
let fileName: String
```

### BackgroundReceiptScan

```swift
struct BackgroundReceiptScan
```

### BackgroundReceiptScan.issues

```swift
let issues: [BackgroundReceiptIssue]
```

### BackgroundReceiptScan.receipts

```swift
let receipts: [BackgroundTransferReceipt]
```

### BackgroundReceiptStore

```swift
final class BackgroundReceiptStore
```

One store per directory. Serializes receipt writes, scanning and acknowledgement.
Corrupt receipts are retained and reported individually; no completion is silently deleted.

### BackgroundReceiptStore.acknowledge(jobID:removeDownloadedFile:)

```swift
func acknowledge(jobID: UUID, removeDownloadedFile: Bool = false) throws
```

### BackgroundReceiptStore.directory

```swift
let directory: URL
```

### BackgroundReceiptStore.init(directory:maximumReceiptBytes:)

```swift
init(directory: URL, maximumReceiptBytes: Int = 16_777_216) throws
```

### BackgroundReceiptStore.scan()

```swift
func scan() throws -> BackgroundReceiptScan
```

### BackgroundRedirectPolicy

```swift
enum BackgroundRedirectPolicy
```

Apple background sessions always follow HTTP redirects; choose only for trusted servers.

### BackgroundRedirectPolicy.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### BackgroundRedirectPolicy.systemManagedForTrustedServers

```swift
case systemManagedForTrustedServers
```

### BackgroundTransferEvent

```swift
enum BackgroundTransferEvent
```

### BackgroundTransferEvent.finished(_:)

```swift
case finished(BackgroundTransferReceipt)
```

### BackgroundTransferEvent.progress(jobID:_:)

```swift
case progress(jobID: UUID, TransferProgress)
```

### BackgroundTransferManager

```swift
final class BackgroundTransferManager
```

App-lifecycle component; recreate with the same identifier and directory after relaunch.
Use a distinct identifier/directory per account. Completion receipts survive process termination.

### BackgroundTransferManager.acknowledge(jobID:removeDownloadedFile:)

```swift
func acknowledge(jobID: UUID, removeDownloadedFile: Bool = false) throws
```

Acknowledgement removes the receipt. Download file is retained unless explicitly requested.

### BackgroundTransferManager.cancel(jobID:)

```swift
func cancel(jobID: UUID) async
```

### BackgroundTransferManager.cancelAll()

```swift
func cancelAll() async
```

### BackgroundTransferManager.directory

```swift
let directory: URL
```

### BackgroundTransferManager.download(_:)

```swift
@discardableResult func download(_ request: URLRequest) throws -> UUID
```

### BackgroundTransferManager.finishTasksAndInvalidate()

```swift
func finishTasksAndInvalidate()
```

Stop accepting new jobs; finish existing jobs and then release the system session.
Keep this manager alive until outstanding callbacks have been delivered.

### BackgroundTransferManager.identifier

```swift
let identifier: String
```

### BackgroundTransferManager.init(identifier:directory:options:redirectPolicy:isDiscretionary:receiptStore:onEvent:onBackgroundEventsFinished:)

```swift
init(identifier: String, directory: URL, options: TransferOptions, redirectPolicy: BackgroundRedirectPolicy, isDiscretionary: Bool = false, receiptStore: BackgroundReceiptStore? = nil, onEvent: @escaping (BackgroundTransferEvent) -> Void = { _ in }, onBackgroundEventsFinished: @escaping () -> Void = {}) throws
```

### BackgroundTransferManager.invalidateAndCancel()

```swift
func invalidateAndCancel()
```

Permanently invalidates this instance; recreating the same identifier can attach again.

### BackgroundTransferManager.receiptScan()

```swift
func receiptScan() throws -> BackgroundReceiptScan
```

### BackgroundTransferManager.receiptStore

```swift
let receiptStore: BackgroundReceiptStore
```

### BackgroundTransferManager.receipts()

```swift
func receipts() throws -> [BackgroundTransferReceipt]
```

Reads persisted completions, including completions received while no UI listener existed.

### BackgroundTransferManager.tasks()

```swift
func tasks() async -> [BackgroundTransferTask]
```

### BackgroundTransferManager.upload(_:from:)

```swift
@discardableResult func upload(_ request: URLRequest, from file: URL) throws -> UUID
```

### BackgroundTransferReceipt

```swift
struct BackgroundTransferReceipt
```

Persisted completion, scoped to one system background-session identifier/account.

### BackgroundTransferReceipt.failureCategory

```swift
let failureCategory: String?
```

nil means HTTP success; categories contain no URL, headers or error descriptions.

### BackgroundTransferReceipt.fileName

```swift
let fileName: String?
```

### BackgroundTransferReceipt.init(from:)

```swift
init(from decoder: any Decoder) throws
```

### BackgroundTransferReceipt.jobID

```swift
let jobID: UUID
```

### BackgroundTransferReceipt.receivedBodyBytes

```swift
let receivedBodyBytes: Int64
```

### BackgroundTransferReceipt.responseBody

```swift
let responseBody: Data
```

### BackgroundTransferReceipt.statusCode

```swift
let statusCode: Int?
```

### BackgroundTransferTask

```swift
struct BackgroundTransferTask
```

### BackgroundTransferTask.completedBytes

```swift
let completedBytes: Int64
```

### BackgroundTransferTask.expectedBytes

```swift
let expectedBytes: Int64?
```

### BackgroundTransferTask.jobID

```swift
let jobID: UUID?
```

### BackgroundTransferTask.taskIdentifier

```swift
let taskIdentifier: Int
```

### DownloadedFile

```swift
struct DownloadedFile
```

### DownloadedFile.fileURL

```swift
let fileURL: URL
```

Caller owns the destination file after a successful return.

### DownloadedFile.init(fileURL:metadata:receivedBodyBytes:)

```swift
init(fileURL: URL, metadata: ResponseMetadata, receivedBodyBytes: Int64)
```

### DownloadedFile.metadata

```swift
let metadata: ResponseMetadata
```

### DownloadedFile.receivedBodyBytes

```swift
let receivedBodyBytes: Int64
```

### FileTransferTransport

```swift
protocol FileTransferTransport : Sendable
```

### FileTransferTransport.download(_:to:progress:)

```swift
func download(_ request: URLRequest, to destination: URL, progress: ((TransferProgress) -> Void)?) async throws -> DownloadedFile
```

### FileTransferTransport.upload(_:from:progress:)

```swift
func upload(_ request: URLRequest, from file: URL, progress: ((TransferProgress) -> Void)?) async throws -> HTTPResponse
```

### MultipartForm

```swift
struct MultipartForm
```

Writes multipart to a caller-owned file using bounded chunks; does not load attachments into memory.

### MultipartForm.Encoded

```swift
struct Encoded
```

### MultipartForm.Encoded.byteCount

```swift
let byteCount: Int64
```

### MultipartForm.Encoded.contentType

```swift
let contentType: String
```

### MultipartForm.Encoded.fileURL

```swift
let fileURL: URL
```

### MultipartForm.Part

```swift
struct Part
```

### MultipartForm.Part.Content

```swift
enum Content
```

### MultipartForm.Part.Content.data(_:)

```swift
case data(Data)
```

### MultipartForm.Part.Content.file(_:)

```swift
case file(URL)
```

### MultipartForm.Part.content

```swift
let content: MultipartForm.Part.Content
```

### MultipartForm.Part.contentType

```swift
let contentType: String
```

### MultipartForm.Part.filename

```swift
let filename: String?
```

### MultipartForm.Part.init(name:filename:contentType:content:)

```swift
init(name: String, filename: String? = nil, contentType: String = "text/plain; charset=utf-8", content: MultipartForm.Part.Content)
```

### MultipartForm.Part.name

```swift
let name: String
```

### MultipartForm.init(parts:)

```swift
init(parts: [MultipartForm.Part])
```

### MultipartForm.parts

```swift
let parts: [MultipartForm.Part]
```

### MultipartForm.write(to:maximumBytes:)

```swift
func write(to destination: URL, maximumBytes: Int64 = 524_288_000) throws -> MultipartForm.Encoded
```

A random boundary is generated for each encoding. Destination must not exist.

### TransferClient

```swift
struct TransferClient
```

Foreground file transfers. A single send; no implicit replay, recovery or redirects.

### TransferClient.download(_:to:progress:)

```swift
func download(_ request: HTTPRequest, to destination: URL, progress: ((TransferProgress) -> Void)? = nil) async throws -> DownloadedFile
```

### TransferClient.download(_:to:progress:)

```swift
func download(_ request: URLRequest, to destination: URL, progress: ((TransferProgress) -> Void)? = nil) async throws -> DownloadedFile
```

### TransferClient.init(httpClient:transport:)

```swift
init(httpClient: HTTPClient, transport: any FileTransferTransport)
```

### TransferClient.init(requestPreparer:transport:)

```swift
init(requestPreparer: any HTTPRequestPreparing, transport: any FileTransferTransport)
```

### TransferClient.init(transport:)

```swift
init(transport: any FileTransferTransport)
```

For absolute, presigned URLRequests; HTTPRequest calls require a preparer.

### TransferClient.upload(_:from:progress:)

```swift
func upload(_ request: URLRequest, from file: URL, progress: ((TransferProgress) -> Void)? = nil) async throws -> HTTPResponse
```

Explicit absolute URLRequest for presigned URLs/signers. No base headers or bearer token are added.

### TransferClient.upload(_:from:progress:)

```swift
func upload(_ request: HTTPRequest, from file: URL, progress: ((TransferProgress) -> Void)? = nil) async throws -> HTTPResponse
```

### TransferError

```swift
enum TransferError
```

### TransferError.destinationExists

```swift
case destinationExists
```

### TransferError.fileTooLarge(limit:)

```swift
case fileTooLarge(limit: Int64)
```

### TransferError.invalidConfiguration

```swift
case invalidConfiguration
```

### TransferError.invalidFile

```swift
case invalidFile
```

### TransferError.localizedDescription

```swift
var localizedDescription: String { get }
```

### TransferError.networkFailureCategory

```swift
var networkFailureCategory: NetworkFailureCategory { get }
```

### TransferError.unexpectedResult

```swift
case unexpectedResult
```

### TransferOptions

```swift
struct TransferOptions
```

### TransferOptions.init(maximumUploadBytes:maximumDownloadBytes:maximumResponseBytes:maximumErrorBodyBytes:resourceTimeout:security:)

```swift
init(maximumUploadBytes: Int64 = 524_288_000, maximumDownloadBytes: Int64 = 524_288_000, maximumResponseBytes: Int = 10_485_760, maximumErrorBodyBytes: Int = 16_384, resourceTimeout: Double = 300, security: ConnectionSecurity = .httpsOnly) throws
```

### TransferOptions.maximumDownloadBytes

```swift
let maximumDownloadBytes: Int64
```

### TransferOptions.maximumErrorBodyBytes

```swift
let maximumErrorBodyBytes: Int
```

### TransferOptions.maximumResponseBytes

```swift
let maximumResponseBytes: Int
```

### TransferOptions.maximumUploadBytes

```swift
let maximumUploadBytes: Int64
```

### TransferOptions.resourceTimeout

```swift
let resourceTimeout: Double
```

### TransferOptions.security

```swift
let security: ConnectionSecurity
```

### TransferProgress

```swift
struct TransferProgress
```

### TransferProgress.Direction

```swift
enum Direction
```

### TransferProgress.Direction.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### TransferProgress.Direction.download

```swift
case download
```

### TransferProgress.Direction.upload

```swift
case upload
```

### TransferProgress.completedBytes

```swift
let completedBytes: Int64
```

### TransferProgress.direction

```swift
let direction: TransferProgress.Direction
```

### TransferProgress.fractionCompleted

```swift
var fractionCompleted: Double? { get }
```

### TransferProgress.init(direction:completedBytes:totalBytes:)

```swift
init(direction: TransferProgress.Direction, completedBytes: Int64, totalBytes: Int64? = nil)
```

### TransferProgress.totalBytes

```swift
let totalBytes: Int64?
```

### URLSessionFileTransferTransport

```swift
struct URLSessionFileTransferTransport
```

### URLSessionFileTransferTransport.download(_:to:progress:)

```swift
func download(_ request: URLRequest, to destination: URL, progress: ((TransferProgress) -> Void)?) async throws -> DownloadedFile
```

### URLSessionFileTransferTransport.init(options:)

```swift
init(options: TransferOptions)
```

### URLSessionFileTransferTransport.options

```swift
let options: TransferOptions
```

### URLSessionFileTransferTransport.upload(_:from:progress:)

```swift
func upload(_ request: URLRequest, from file: URL, progress: ((TransferProgress) -> Void)?) async throws -> HTTPResponse
```

## NetworkingRealtime

45 offentlige symboler.

### RealtimeError

```swift
enum RealtimeError
```

### RealtimeError.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### RealtimeError.bufferOverflow

```swift
case bufferOverflow
```

### RealtimeError.invalidConfiguration

```swift
case invalidConfiguration
```

### RealtimeError.localizedDescription

```swift
var localizedDescription: String { get }
```

### RealtimeError.messageTooLarge

```swift
case messageTooLarge
```

### RealtimeError.networkFailureCategory

```swift
var networkFailureCategory: NetworkFailureCategory { get }
```

### RealtimeError.notConnected

```swift
case notConnected
```

### RealtimeError.unsupportedMessage

```swift
case unsupportedMessage
```

### RealtimeEvent

```swift
enum RealtimeEvent
```

### RealtimeEvent.connected(attempt:)

```swift
case connected(attempt: Int)
```

### RealtimeEvent.message(_:)

```swift
case message(WebSocketMessage)
```

### RealtimeEvent.reconnecting(attempt:delay:)

```swift
case reconnecting(attempt: Int, delay: Double)
```

### URLSessionWebSocketConnector

```swift
struct URLSessionWebSocketConnector
```

### URLSessionWebSocketConnector.init(security:maximumMessageBytes:)

```swift
init(security: ConnectionSecurity = .httpsOnly, maximumMessageBytes: Int = 1_048_576)
```

### URLSessionWebSocketConnector.maximumMessageBytes

```swift
let maximumMessageBytes: Int
```

### URLSessionWebSocketConnector.open(_:)

```swift
func open(_ request: URLRequest) async throws -> any WebSocketConnection
```

Must return an isolated connection and cooperate with cancellation.

### URLSessionWebSocketConnector.security

```swift
let security: ConnectionSecurity
```

### WebSocketClient

```swift
actor WebSocketClient
```

One active event stream per client. Start a new stream to start a new connection budget.

### WebSocketClient.assertIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### WebSocketClient.assumeIsolated(_:file:line:)

```swift
nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable
```

### WebSocketClient.disconnect()

```swift
func disconnect() async
```

### WebSocketClient.events()

```swift
func events() async -> AsyncThrowingStream<RealtimeEvent, any Error>
```

### WebSocketClient.init(options:connector:makeRequest:)

```swift
init(options: WebSocketOptions, connector: (any WebSocketConnector)? = nil, makeRequest: @escaping () async throws -> URLRequest)
```

### WebSocketClient.preconditionIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### WebSocketClient.send(_:)

```swift
func send(_ message: WebSocketMessage) async throws
```

### WebSocketConnection

```swift
protocol WebSocketConnection : Sendable
```

### WebSocketConnection.close()

```swift
func close() async
```

### WebSocketConnection.ping()

```swift
func ping() async throws
```

### WebSocketConnection.receive()

```swift
func receive() async throws -> WebSocketMessage
```

### WebSocketConnection.send(_:)

```swift
func send(_ message: WebSocketMessage) async throws
```

### WebSocketConnector

```swift
protocol WebSocketConnector : Sendable
```

### WebSocketConnector.open(_:)

```swift
func open(_ request: URLRequest) async throws -> any WebSocketConnection
```

Must return an isolated connection and cooperate with cancellation.

### WebSocketMessage

```swift
enum WebSocketMessage
```

Wire messages, without assumptions about a backend's chat or subscription protocol.

### WebSocketMessage.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### WebSocketMessage.data(_:)

```swift
case data(Data)
```

### WebSocketMessage.text(_:)

```swift
case text(String)
```

### WebSocketOptions

```swift
struct WebSocketOptions
```

### WebSocketOptions.eventBufferCapacity

```swift
let eventBufferCapacity: Int
```

### WebSocketOptions.heartbeatInterval

```swift
let heartbeatInterval: Double?
```

### WebSocketOptions.init(maximumConnectionAttempts:reconnectBaseDelay:maximumReconnectDelay:heartbeatInterval:maximumMessageBytes:eventBufferCapacity:)

```swift
init(maximumConnectionAttempts: Int = 1, reconnectBaseDelay: Double = 1, maximumReconnectDelay: Double = 30, heartbeatInterval: Double? = 30, maximumMessageBytes: Int = 1_048_576, eventBufferCapacity: Int = 64) throws
```

### WebSocketOptions.maximumConnectionAttempts

```swift
let maximumConnectionAttempts: Int
```

### WebSocketOptions.maximumMessageBytes

```swift
let maximumMessageBytes: Int
```

### WebSocketOptions.maximumReconnectDelay

```swift
let maximumReconnectDelay: Double
```

### WebSocketOptions.reconnectBaseDelay

```swift
let reconnectBaseDelay: Double
```

## NetworkingSync

64 offentlige symboler.

### FileOutboxStore

```swift
actor FileOutboxStore
```

Account-bound atomic JSON storage. Use one instance/writer per file; not a multiprocess database.

### FileOutboxStore.accountID

```swift
let accountID: String
```

### FileOutboxStore.assertIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### FileOutboxStore.assumeIsolated(_:file:line:)

```swift
nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable
```

### FileOutboxStore.fileURL

```swift
let fileURL: URL
```

### FileOutboxStore.init(fileURL:accountID:maximumItems:maximumPayloadBytes:maximumFileBytes:)

```swift
init(fileURL: URL, accountID: String, maximumItems: Int = 1000, maximumPayloadBytes: Int = 1_048_576, maximumFileBytes: Int = 16_777_216) throws
```

### FileOutboxStore.insert(_:)

```swift
func insert(_ item: OutboxItem) throws
```

### FileOutboxStore.items(accountID:)

```swift
func items(accountID: String) throws -> [OutboxItem]
```

### FileOutboxStore.nextItem(accountID:)

```swift
func nextItem(accountID: String) throws -> OutboxItem?
```

### FileOutboxStore.preconditionIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### FileOutboxStore.remove(id:accountID:)

```swift
func remove(id: UUID, accountID: String) throws
```

### FileOutboxStore.update(_:)

```swift
func update(_ item: OutboxItem) throws
```

### OutboxClock

```swift
protocol OutboxClock : Sendable
```

Time source for persisted delivery scheduling; no HTTP or sleep dependency.

### OutboxClock.now()

```swift
func now() async -> Date
```

### OutboxEngine

```swift
actor OutboxEngine
```

FIFO, at-least-once outbox delivery. No automatic reachability monitor or domain merge rules.

### OutboxEngine.accountID

```swift
let accountID: String
```

### OutboxEngine.assertIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### OutboxEngine.assumeIsolated(_:file:line:)

```swift
nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable
```

### OutboxEngine.discard(id:)

```swift
func discard(id: UUID) async throws
```

### OutboxEngine.enqueue(payload:idempotencyKey:)

```swift
@discardableResult func enqueue(payload: Data, idempotencyKey: String = UUID().uuidString) async throws -> UUID
```

### OutboxEngine.flush(maximumOperations:)

```swift
func flush(maximumOperations: Int = 100) async throws -> SyncReport
```

### OutboxEngine.init(accountID:store:maximumAttempts:clock:deliver:)

```swift
init(accountID: String, store: any OutboxStore, maximumAttempts: Int = 10, clock: any OutboxClock = SystemOutboxClock(), deliver: @escaping (OutboxItem) async throws -> SyncDisposition) throws
```

### OutboxEngine.pending()

```swift
func pending() async throws -> [OutboxItem]
```

### OutboxEngine.preconditionIsolated(_:file:line:)

```swift
@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0)
nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)
```

### OutboxEngine.retryBlocked(id:)

```swift
func retryBlocked(id: UUID) async throws
```

### OutboxItem

```swift
struct OutboxItem
```

### OutboxItem.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### OutboxItem.accountID

```swift
let accountID: String
```

### OutboxItem.attempts

```swift
var attempts: Int
```

### OutboxItem.blockedReason

```swift
var blockedReason: String?
```

### OutboxItem.createdAt

```swift
let createdAt: Date
```

### OutboxItem.id

```swift
let id: UUID
```

### OutboxItem.idempotencyKey

```swift
let idempotencyKey: String
```

### OutboxItem.init(from:)

```swift
init(from decoder: any Decoder) throws
```

### OutboxItem.init(id:accountID:idempotencyKey:payload:createdAt:)

```swift
init(id: UUID = UUID(), accountID: String, idempotencyKey: String, payload: Data, createdAt: Date = Date())
```

### OutboxItem.notBefore

```swift
var notBefore: Date
```

### OutboxItem.payload

```swift
let payload: Data
```

### OutboxStore

```swift
protocol OutboxStore : Sendable
```

Each mutation must be atomic. One engine owns delivery for an account/store.

### OutboxStore.insert(_:)

```swift
func insert(_ item: OutboxItem) async throws
```

### OutboxStore.items(accountID:)

```swift
func items(accountID: String) async throws -> [OutboxItem]
```

### OutboxStore.nextItem(accountID:)

```swift
func nextItem(accountID: String) async throws -> OutboxItem?
```

### OutboxStore.nextItem(accountID:)

```swift
func nextItem(accountID: String) async throws -> OutboxItem?
```

### OutboxStore.remove(id:accountID:)

```swift
func remove(id: UUID, accountID: String) async throws
```

### OutboxStore.update(_:)

```swift
func update(_ item: OutboxItem) async throws
```

### SyncDisposition

```swift
enum SyncDisposition
```

### SyncDisposition.acknowledged

```swift
case acknowledged
```

### SyncDisposition.blocked(reason:)

```swift
case blocked(reason: String)
```

### SyncDisposition.retry(after:)

```swift
case retry(after: Double)
```

### SyncError

```swift
enum SyncError
```

### SyncError.!=(_:_:)

```swift
static func != (lhs: Self, rhs: Self) -> Bool
```

### SyncError.accountMismatch

```swift
case accountMismatch
```

### SyncError.capacityExceeded

```swift
case capacityExceeded
```

### SyncError.corruptStore

```swift
case corruptStore
```

### SyncError.invalidConfiguration

```swift
case invalidConfiguration
```

### SyncError.localizedDescription

```swift
var localizedDescription: String { get }
```

### SyncError.operationNotFound

```swift
case operationNotFound
```

### SyncReport

```swift
struct SyncReport
```

### SyncReport.acknowledged

```swift
let acknowledged: Int
```

### SyncReport.alreadyRunning

```swift
let alreadyRunning: Bool
```

### SyncReport.blocked

```swift
let blocked: Int
```

### SyncReport.deferred

```swift
let deferred: Int
```

### SystemOutboxClock

```swift
struct SystemOutboxClock
```

### SystemOutboxClock.init()

```swift
init()
```

### SystemOutboxClock.now()

```swift
func now() async -> Date
```
