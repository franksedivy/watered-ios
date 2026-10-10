//
//  DrinkCatalogueLoader.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Loads catalogue data and validates it before retruning it to callers.
///
/// Loading is local and does not modify drink history or application state.
nonisolated struct DrinkCatalogueLoader {
    /// A resource-loading failure specific to the catalogue.
    enum LoadError: Error, Equatable {
        case resourceNotFound
    }
    
    /// Loads and validates DrinkCatalogue.json from an application bundle.
    ///
    /// - Parameter bundle: The bundle containing the catalogue resource.
    ///   Defaults to the running application's bundle.
    /// - Returns: A decoded catalogue that has passed validation.
    /// - Throws: A resource-not-found, file-reading, decoding or validation error.
    func load(from bundle: Bundle = .main) throws -> DrinkCatalogue {
        guard let url = bundle.url(
            forResource: "DrinkCatalogue",
            withExtension: "json"
        ) else {
            throw LoadError.resourceNotFound
        }
        
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }
    
    /// Decodes and validates catalogue JSON supplied as data.
    ///
    /// - Parameter data: The complete catalogue JSON.
    /// - Returns: A decoded catalogue that has passed validation.
    /// - Throws: A decoding or catalogue-validation error.
    func load(from data: Data) throws -> DrinkCatalogue {
        let catalogue = try JSONDecoder().decode(
            DrinkCatalogue.self,
            from: data
        )
        
        try catalogue.validate()
        return catalogue
    }
}
