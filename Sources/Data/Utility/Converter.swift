//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Foundation
import Domain

//protocol DomainConvertible {
//    associatedtype DomainType
//    var toDomain: DomainType { get }
//}
//
//extension Future where T: DomainConvertible {
//    func mapToDomain<D>() -> Future<D> where D == T.DomainType {
//        return map {
//            $0.toDomain
//        }
//    }
//}
//
//extension Future {
//    func mapToVoid() -> Future<Void> {
//        return map { _ -> Void in }
//    }
//}
