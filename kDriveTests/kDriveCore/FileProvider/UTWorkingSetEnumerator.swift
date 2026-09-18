/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import FileProvider
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct UTWorkingSetEnumerator {
    private let initialPage = NSFileProviderPage(NSFileProviderPage.initialPageSortedByDate as Data)

    @Test func queuedRequestsFinishInOrder() async {
        let events = EventObserver.makeStream()
        let started = EventObserver.makeStream()
        let gate = Gate()
        let enumerator = WorkingSetEnumerator {
            started.continuation.yield("started")
            await gate.wait()
            return []
        }
        let first = EventObserver(name: "first", events: events.continuation)
        let second = EventObserver(name: "second", events: events.continuation)

        enumerator.enumerateItems(for: first, startingAt: initialPage)
        var startIterator = started.stream.makeAsyncIterator()
        _ = await startIterator.next()
        enumerator.enumerateItems(for: second, startingAt: initialPage)
        await gate.open()

        var received = [String]()
        for await event in events.stream.prefix(4) {
            received.append(event)
        }
        enumerator.invalidate()
        await enumerator.enumerationTask.value

        #expect(received == ["first:items:0", "first:finished", "second:items:0", "second:finished"])
    }

    @Test func invalidationDiscardsInFlightEmptyResultsAndQueuedRequests() async {
        let events = EventObserver.makeStream()
        let started = EventObserver.makeStream()
        let gate = Gate()
        let enumerator = WorkingSetEnumerator {
            started.continuation.yield("started")
            await gate.wait()
            return []
        }
        let observer = EventObserver(name: "request", events: events.continuation)
        enumerator.enumerateItems(for: observer, startingAt: initialPage)
        var startIterator = started.stream.makeAsyncIterator()
        _ = await startIterator.next()
        enumerator.enumerateItems(for: observer, startingAt: initialPage)

        enumerator.invalidate()
        enumerator.invalidate()
        enumerator.enumerateItems(for: observer, startingAt: initialPage)
        await gate.open()
        await enumerator.enumerationTask.value
        events.continuation.finish()
        started.continuation.finish()

        for await event in events.stream {
            Issue.record("Unexpected callback after invalidation: \(event)")
        }
        #expect(await startIterator.next() == nil)
    }

    @Test func invalidationDuringDeliveryStopsFurtherCallbacks() async {
        let events = EventObserver.makeStream()
        let enumerator = WorkingSetEnumerator { [] }
        let observer = EventObserver(name: "request", events: events.continuation) {
            enumerator.invalidate()
        }
        enumerator.enumerateItems(for: observer, startingAt: initialPage)
        await enumerator.enumerationTask.value
        events.continuation.finish()

        var received = [String]()
        for await event in events.stream {
            received.append(event)
        }
        #expect(received == ["request:items:0"])
    }

    private actor Gate {
        private var isOpen = false
        private var waiter: CheckedContinuation<Void, Never>?

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { waiter = $0 }
        }

        func open() {
            isOpen = true
            waiter?.resume()
            waiter = nil
        }
    }

    private final class EventObserver: NSObject, NSFileProviderEnumerationObserver {
        let name: String
        let events: AsyncStream<String>.Continuation
        let onItems: () -> Void

        init(name: String, events: AsyncStream<String>.Continuation, onItems: @escaping () -> Void = {}) {
            self.name = name
            self.events = events
            self.onItems = onItems
        }

        static func makeStream() -> (stream: AsyncStream<String>, continuation: AsyncStream<String>.Continuation) {
            var continuation: AsyncStream<String>.Continuation!
            let stream = AsyncStream<String> { continuation = $0 }
            return (stream, continuation)
        }

        func didEnumerate(_ updatedItems: [NSFileProviderItem]) {
            events.yield("\(name):items:\(updatedItems.count)")
            onItems()
        }

        func finishEnumerating(upTo nextPage: NSFileProviderPage?) {
            #expect(nextPage == nil)
            events.yield("\(name):finished")
        }

        func finishEnumeratingWithError(_ error: Error) {
            events.yield("\(name):error:\(error)")
        }
    }
}
