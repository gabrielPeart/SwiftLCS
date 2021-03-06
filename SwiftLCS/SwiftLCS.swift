//
// The MIT License (MIT)
//
// Copyright (c) 2015 Tommaso Madonia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

/**
A generic struct that represents a diff between two collections.
*/
public struct Diff<Index: Comparable> {
    
    /// The indexes whose corresponding values in the old collection are in the LCS.
    public var commonIndexes: [Index] {
        return self.common.indexes
    }
    
    /// The indexes whose corresponding values in the new collection are not in the LCS.
    public var addedIndexes: [Index] {
        return self.added.indexes
    }
    
    /// The indexes whose corresponding values in the old collection are not in the LCS.
    public var removedIndexes: [Index] {
        return self.removed.indexes
    }
    
    internal let common: (indexes: [Index], startIndex: Index)
    internal let added: (indexes: [Index], startIndex: Index)
    internal let removed: (indexes: [Index], startIndex: Index)
    
    /// Construct the `Diff` between two given collections.
    public init<C: Collection>(_ old: C, _ new: C) where C.Index == Index, C.Iterator.Element: Equatable {
        self = old.diff(new)
    }
    
    fileprivate init<C: Collection>(common: ([Index], C), added: ([Index], C), removed: ([Index], C)) where C.Index == Index {
        self.common = (indexes: common.0, startIndex: common.1.startIndex)
        self.added = (indexes: added.0, startIndex: added.1.startIndex)
        self.removed = (indexes: removed.0, startIndex: removed.1.startIndex)
    }
    
}

/**
An extension of `Collection`, which calculates the diff between two collections.
*/
public extension Collection where Iterator.Element: Equatable {

    /**
    Returns the diff between two collections.
    
    - complexity: O(mn) where `m` and `n` are the lengths of the receiver and the given collection.
    - parameter collection: The collection with which to compare the receiver.
    - returns: The diff between the receiver and the given collection.
    */
    public func diff(_ otherCollection: Self) -> Diff<Index> {
        let (suffix, suffixIndexes) = self.suffix(otherCollection)
        let (_, prefixIndexes) = self.prefix(otherCollection, suffixLength: suffixIndexes.count)

        let commonIndexes = prefixIndexes + self.computeLCS(otherCollection, endIndex: suffix, prefixLength: prefixIndexes.count, suffixLength: suffixIndexes.count) + suffixIndexes
        
        let removedIndexes = self.map { self.index(of: $0)! }.filter { !commonIndexes.contains($0) }

        var addedIndexes = [Index]()
        var commonObjects = self.filter { commonIndexes.contains(self.index(of: $0)!) }
        for value in otherCollection {
            if commonObjects.first == value {
                commonObjects.removeFirst()
            } else {
                addedIndexes.append(otherCollection.index(of: value)!)
            }
        }

        return Diff(common: (commonIndexes, self), added: (addedIndexes, otherCollection), removed: (removedIndexes, self))
    }
    
    // MARK: - Private
    
    fileprivate func prefix(_ otherCollection: Self, suffixLength: Int) -> (Index, [Index]) {
        var iterator = (self.dropLast(suffixLength).makeIterator(), otherCollection.dropLast(suffixLength).makeIterator())
        var entry = (iterator.0.next(), iterator.1.next())
        
        var prefixIndexes = [Index]()
        var prefix = self.startIndex
        while entry.0 != nil && entry.1 != nil && entry.0 as! Iterator.Element == entry.1 as! Iterator.Element {
            prefixIndexes.append(prefix)
            prefix = self.index(after: prefix)
            
            entry = (iterator.0.next(), iterator.1.next())
        }
        
        return (prefix, prefixIndexes)
    }
    
    fileprivate func suffix(_ otherCollection: Self) -> (Index, [Index]) {
        var iterator = (self.reversed().makeIterator(), otherCollection.reversed().makeIterator())
        var entry = (iterator.0.next(), iterator.1.next())
        
        var suffixIndexes = [Index]()
        var suffix = self.endIndex
        while entry.0 != nil && entry.1 != nil && entry.0! == entry.1! {
            suffix = self.index(suffix, offsetBy: -1)
            suffixIndexes.append(suffix)
            
            entry = (iterator.0.next(), iterator.1.next())
        }
        
        return (suffix, suffixIndexes.reversed())
    }
    
    fileprivate func computeLCS(_ otherCollection: Self, endIndex: Index, prefixLength: Int, suffixLength: Int) -> [Index] {
        let rows = Int(self.count.toIntMax()) - prefixLength - suffixLength + 1
        let columns = Int(otherCollection.count.toIntMax()) - prefixLength - suffixLength + 1
        var lengths = Array(repeating: Array(repeating: 0, count: columns), count: rows)
        for (i, element) in self.enumerated().dropFirst(prefixLength).dropLast(suffixLength).map({($0.0 - prefixLength, $0.1)}) {
            for (j, otherElement) in otherCollection.enumerated().dropFirst(prefixLength).dropLast(suffixLength).map({($0.0 - prefixLength, $0.1)}) {
                if element == otherElement {
                    lengths[i+1][j+1] = lengths[i][j] + 1
                } else {
                    lengths[i+1][j+1] =  [ lengths[i+1][j], lengths[i][j+1] ].max()!
                }
            }
        }
        
        var commonIndexes = [Index]()
        
        var index = endIndex
        var (i, j) = (rows - 1, columns - 1)
        while i != 0 && j != 0 {
            if lengths[i][j] == lengths[i - 1][j] {
                i -= 1
                index = self.index(index, offsetBy: -1)
            } else if lengths[i][j] == lengths[i][j - 1] {
                j -= 1
            } else {
                index = self.index(index, offsetBy: -1)
                commonIndexes.append(index)
                (i, j) = (i - 1, j - 1)
            }
        }
        
        return commonIndexes.reversed()
    }

}

/**
An extension of `RangeReplaceableCollection`, which calculates the longest common subsequence between two collections.
*/
public extension RangeReplaceableCollection where Iterator.Element: Equatable {

    /**
    Returns the longest common subsequence between two collections.
    
    - parameter collection: The collection with which to compare the receiver.
    - returns: The longest common subsequence between the receiver and the given collection.
    */
    public func longestCommonSubsequence(_ collection: Self) -> Self {
        return Self(self.diff(collection).commonIndexes.map { self[$0] })
    }

}

/**
An extension of `String`, which calculates the longest common subsequence between two strings.
*/
public extension String {

    /**
    Returns the longest common subsequence between two strings.
    
    - parameter string: The string with which to compare the receiver.
    - returns: The longest common subsequence between the receiver and the given string.
    */
    public func longestCommonSubsequence(_ string: String) -> String {
        return String(self.characters.longestCommonSubsequence(string.characters))
    }

}
