//
/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import Foundation
import MediaPlayer

extension SingleTrackPlayer {
    private enum CommandError: Error {
        case commandFailed
    }

    func setUpRemoteControlEvents() {
        for command in registeredCommands {
            command.removeHandler()
            command.addHandler { [weak self] command, event in
                guard let self else {
                    return .commandFailed
                }

                return self.setupHandler(forCommand: command, event: event)
            }
        }
    }

    func removeAllRemoteControlEvents() {
        registeredCommands.forEach { $0.removeHandler() }
    }

    private func setupHandler(forCommand command: NowPlayableCommand,
                              event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        do {
            switch command {
            case .togglePausePlay:
                togglePlayPause()
            case .play:
                play()
            case .pause:
                pause()
            case .skipBackward:
                try skipBackward(event: event)
            case .skipForward:
                try skipForward(event: event)
            case .changePlaybackPosition:
                try changePlaybackPosition(event: event)
            case .changePlaybackRate:
                try changePlaybackRate(event: event)
            default:
                return .commandFailed
            }
            return .success
        } catch {
            return .commandFailed
        }
    }

    private func skipBackward(event: MPRemoteCommandEvent) throws {
        guard let event = event as? MPSkipIntervalCommandEvent else {
            throw CommandError.commandFailed
        }
        skipBackward(by: event.interval)
    }

    private func skipForward(event: MPRemoteCommandEvent) throws {
        guard let event = event as? MPSkipIntervalCommandEvent else {
            throw CommandError.commandFailed
        }
        skipForward(by: event.interval)
    }

    private func changePlaybackPosition(event: MPRemoteCommandEvent) throws {
        guard let event = event as? MPChangePlaybackPositionCommandEvent else {
            throw CommandError.commandFailed
        }
        seek(to: event.positionTime)
    }

    private func changePlaybackRate(event: MPRemoteCommandEvent) throws {
        guard let event = event as? MPChangePlaybackRateCommandEvent else {
            throw CommandError.commandFailed
        }
        setPlaybackRate(event.playbackRate)
    }
}
