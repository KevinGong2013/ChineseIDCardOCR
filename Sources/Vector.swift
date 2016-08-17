//
//  Vector.swift
//  Swift-AI-OSX
//
//  Created by Collin Hundley on 12/2/15.
//

import Accelerate


class Vector {
    
    /// The vector as an array of `Double`.
    var flat = [Double]()
    
    /// Converts the receiver into a `Matrix` with one row and `size` columns.
    var matrixView: Matrix {
        get {
            let m = Matrix(rows: 1, columns: self.size)
            m.flat.flat = self.flat
            return m
        }
    }
    
    /// The size of the vector (total number of elements).
    var size: Int {
        get {
            return self.flat.count
        }
    }
    
    /// The textual representation of the vector.
    var description: String {
        get {
            return self.flat.description
        }
    }
    
    init(size: Int) {
        self.flat = [Double](count: size, repeatedValue: 0.0)
    }
    
    /// Returns/sets the element value at the given index.
    subscript(index: Int) -> Double {
        get {
            return self.flat[index]
        }
        set(value){
            self.flat[index] = value
        }
    }
    
    // TODO: Finish this.
    /// Computes the dot product of the receiver with another vector.
    func dot(v: Vector) -> Double {
        var c: Double = 0.0
        vDSP_dotprD(self.flat, 1, self.flat, 1, &c, vDSP_Length(self.size))
        return 0.0
    }
    
    /// Returns a new `Vector` that is a copy of the receiver.
    func copy() -> Vector {
        let v = Vector(size: self.size)
        v.flat = self.flat
        return v
    }
    
}