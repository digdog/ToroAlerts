//
//  DeviceCoordinator.swift
//  ToroAlerts
//
//  Coordinates USB Hubcot device request and event streams.
//

import Foundation
import os
import Synchronization

/// Coordinates a Hubcot USB device's request stream and event stream.
///
/// `DeviceCoordinator` follows the `AsyncStreamCoordinator` pattern: a `Sendable` final class
/// using `Mutex<State>` for thread-safe state management. It accepts requests via
/// `yield(_:interval:)` (synchronous, fire-and-forget) and broadcasts lifecycle events to multiple
/// consumers via `newEventStream()` (fan-out).
///
/// Usage:
/// ```swift
/// let coordinator = DeviceCoordinator()
/// coordinator.start()
///
/// // Observe events (supports multiple consumers)
/// Task {
///     for await event in coordinator.newEventStream() {
///         switch event {
///         case .connected(let type): print("Connected: \(type)")
///         case .disconnected: print("Disconnected")
///         case .sendFailed(let error): print("Error: \(error)")
///         }
///     }
/// }
///
/// // Send commands (fire-and-forget)
/// coordinator.yield(.left, interval: .milliseconds(100))
/// coordinator.yield(.right)
///
/// // Finish
/// coordinator.finish()
/// ```
public final class DeviceCoordinator: Sendable {

    // MARK: - Types

    /// Lifecycle events broadcast to event stream consumers.
    public enum Event: Sendable {
        /// A device was found and connected.
        case connected(DeviceType)
        /// The device was disconnected.
        case disconnected
        /// A send operation failed with an error.
        case sendFailed(DeviceError)
    }

    /// Internal request element flowing through the stream.
    private enum RequestElement: Sendable {
        case request(DeviceRequest, interval: Duration)
        case rawValue(UInt8, interval: Duration)
    }

    /// Internal mutable state protected by Mutex.
    private struct State: @unchecked Sendable {
        /// Continuation for the request stream (input).
        var requestContinuation: AsyncStream<RequestElement>.Continuation?

        /// Fan-out event continuations keyed by UUID (output).
        var eventContinuations: [UUID: AsyncStream<Event>.Continuation] = [:]

        /// The processing task that runs the for-await loop.
        var processingTask: Task<Void, Never>?
    }

    // MARK: - Properties

    private static let logger = Logger(subsystem: "ToroAlerts", category: "DeviceCoordinator")

    private let state: Mutex<State>
    private let deviceType: DeviceType?
    private let bufferSize: Int

    // MARK: - Initialization

    /// Creates a new stream coordinator.
    ///
    /// - Parameters:
    ///   - deviceType: Specific device type to connect to, or `nil` for auto-detection.
    ///   - bufferSize: Maximum number of buffered requests. Newest requests are kept when full.
    ///     Defaults to `3`, which drops stale commands when the device is slow.
    public init(
        deviceType: DeviceType? = nil,
        bufferSize: Int = 3
    ) {
        self.deviceType = deviceType
        self.bufferSize = bufferSize
        self.state = Mutex(State())
    }

    // MARK: - Public API

    /// Starts the device connection and request processing loop.
    ///
    /// This method creates the internal request stream and launches a background task that:
    /// 1. Connects to the Hubcot device
    /// 2. Processes requests serially via `for await`
    /// 3. Broadcasts lifecycle events to all event stream consumers
    /// 4. Attempts reconnection on send failure
    ///
    /// Calling `start()` again cancels any previous processing loop.
    public func start() {
        let previousTask = state.withLock { state in
            let prev = state.processingTask
            state.processingTask = nil
            state.requestContinuation?.finish()
            state.requestContinuation = nil
            return prev
        }
        previousTask?.cancel()

        let (requestStream, requestContinuation) = AsyncStream<RequestElement>.makeStream(
            bufferingPolicy: .bufferingNewest(bufferSize)
        )

        let task = Task { [weak self, deviceType] in
            guard let self else { return }

            // Connect to device
            var controller = Self.attemptConnect(deviceType: deviceType, coordinator: self)

            // Process requests serially
            for await element in requestStream {
                guard !Task.isCancelled else { break }

                // Ensure connected
                if controller == nil || !controller!.isConnected {
                    controller = Self.attemptConnect(deviceType: deviceType, coordinator: self)
                    if controller == nil {
                        continue
                    }
                }

                do {
                    switch element {
                    case .request(let request, let interval):
                        try controller!.send(request, interval: interval)
                    case .rawValue(let rawValue, let interval):
                        try controller!.send(rawValue: rawValue, interval: interval)
                    }
                } catch let error as DeviceError {
                    self.yieldEvent(.sendFailed(error))
                    Self.logger.error("Send failed: \(error.description, privacy: .public)")
                    controller?.disconnect()
                    controller = nil
                    self.yieldEvent(.disconnected)
                } catch {
                    controller?.disconnect()
                    controller = nil
                    self.yieldEvent(.disconnected)
                }
            }

            // Cleanup on loop exit
            controller?.disconnect()
            if controller != nil {
                self.yieldEvent(.disconnected)
            }
            self.finishEventContinuations()
        }

        state.withLock { state in
            state.requestContinuation = requestContinuation
            state.processingTask = task
        }
    }

    /// Yields a predefined request into the processing stream.
    ///
    /// This method is synchronous and non-throwing — fire-and-forget semantics.
    /// The request is buffered according to the coordinator's buffering policy.
    ///
    /// - Parameters:
    ///   - request: The predefined request type to send.
    ///   - interval: Delay between movements. Defaults to 100ms.
    public func yield(_ request: DeviceRequest, interval: Duration = .milliseconds(100)) {
        state.withLock {
            _ = $0.requestContinuation?.yield(.request(request, interval: interval))
        }
    }

    /// Yields a raw request value into the processing stream.
    ///
    /// - Parameters:
    ///   - rawValue: The raw request value (0-255).
    ///   - interval: Delay between movements. Defaults to 100ms.
    public func yield(rawValue: UInt8, interval: Duration = .milliseconds(100)) {
        state.withLock {
            _ = $0.requestContinuation?.yield(.rawValue(rawValue, interval: interval))
        }
    }

    /// Creates a new event stream for observing lifecycle events.
    ///
    /// Multiple consumers can observe events simultaneously (fan-out pattern).
    /// The stream finishes when `finish()` is called or the processing loop ends.
    ///
    /// - Returns: An `AsyncStream` of lifecycle events.
    public func newEventStream() -> AsyncStream<Event> {
        AsyncStream<Event>(bufferingPolicy: .unbounded) { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let id = UUID()
            state.withLock { state in
                state.eventContinuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                Task.detached { [weak self] in
                    guard let self else { return }
                    self.state.withLock { state in
                        _ = state.eventContinuations.removeValue(forKey: id)
                    }
                }
            }
        }
    }

    /// Stops accepting new requests and cancels the processing loop immediately.
    ///
    /// Buffered requests that have not yet been processed are discarded.
    /// After calling `finish()`, the coordinator can be restarted with `start()`.
    public func finish() {
        let task = state.withLock { state in
            state.requestContinuation?.finish()
            state.requestContinuation = nil
            let t = state.processingTask
            state.processingTask = nil
            return t
        }
        task?.cancel()
    }

    /// Stops accepting new requests and waits for buffered requests to be processed.
    ///
    /// Unlike `finish()`, this method does not cancel the processing loop. The `for await`
    /// loop drains remaining buffered requests, disconnects the device, and finishes
    /// event streams before returning.
    ///
    /// After this method returns, the coordinator can be restarted with `start()`.
    public func finishAndWait() async {
        let task = state.withLock { state in
            state.requestContinuation?.finish()
            state.requestContinuation = nil
            return state.processingTask
        }
        await task?.value
        state.withLock { $0.processingTask = nil }
    }

    // MARK: - Private

    /// Broadcasts an event to all event stream consumers.
    private func yieldEvent(_ event: Event) {
        let continuations = state.withLock { $0.eventContinuations }
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Finishes all event continuations and clears them.
    private func finishEventContinuations() {
        let continuations = state.withLock { state in
            let c = state.eventContinuations
            state.eventContinuations = [:]
            return c
        }
        for continuation in continuations.values {
            continuation.finish()
        }
    }

    /// Attempts to connect to a Hubcot device and broadcasts the result.
    private static func attemptConnect(
        deviceType: DeviceType?,
        coordinator: DeviceCoordinator
    ) -> DeviceController? {
        do {
            let controller = try DeviceController.connect(deviceType: deviceType)
            coordinator.yieldEvent(.connected(controller.deviceType))
            logger.info("Connected to \(controller.deviceType.rawValue, privacy: .public) device")
            return controller
        } catch {
            logger.error("Connection failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension DeviceCoordinator {

    /// The number of active event continuations.
    public var test_eventContinuationCount: Int {
        state.withLock { $0.eventContinuations.count }
    }
}
#endif
