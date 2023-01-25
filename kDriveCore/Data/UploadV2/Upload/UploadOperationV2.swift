/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

/// Something that can create an monitor the uploading of a chunk
public final class UploadOperationV2: AsynchronousOperation {

    @InjectService public var chunkService: ChunkService
    
    override public init() {
        super.init()
        
        print("init :\(chunkService)")
    }
    
    public override func execute() {
        // TODO
        
        finish()
    }
}
