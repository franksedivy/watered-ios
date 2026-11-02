//
//  DrinkCatalogueLoader.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Assembles a local catalogue from an explicit manifest and required category files.
///
/// Callers receive one validated catalogue, never a partially loaded set of definitions.
/// Loading does not modify drink history or application state.
nonisolated struct DrinkCatalogueLoader {
    /// A manifest or resource-loading failure specific to the catalogue.
    nonisolated enum LoadError: Error, Equatable {
        case resourceNotFound
        case unsupportedManifestVersion(Int)
        case invalidCategoryFile(String)
        case duplicateCategoryFile(String)
        case categoryResourceNotFound(String)
        case categoryMismatch(file: String, drinkID: String, categoryID: String)
    }

    /// Loads the manifest and its required files from the bundled DrinkCatalogue folder.
    ///
    /// - Parameter bundle: The bundle containing the catalogue resource.
    ///   Defaults to the running application's bundle.
    /// - Returns: The complete catalogue after assembly and validation.
    /// - Throws: A resource, file-reading, decoding, manifest or catalogue-validation error.
    func load(from bundle: Bundle = .main) throws -> DrinkCatalogue {
        guard let manifestURL = bundle.url(
            forResource: "Manifest",
            withExtension: "json",
            subdirectory: "DrinkCatalogue"
        ) else {
            throw LoadError.resourceNotFound
        }

        let directory = manifestURL.deletingLastPathComponent()
        return try load(
            from: Data(contentsOf: manifestURL),
            categoryData: { filename in
                let url = directory.appendingPathComponent(filename)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw LoadError.categoryResourceNotFound(filename)
                }
                return try Data(contentsOf: url)
            }
        )
    }

    /// Decodes a manifest, loads its files in listed order and validates the assembled catalogue.
    ///
    /// - Parameters:
    ///   - data: The manifest JSON, including versions, category metadata and filenames.
    ///   - categoryData: Reads a required category file by its validated basename.
    /// - Returns: One complete catalogue, independent of the physical file layout.
    /// - Throws: A reader, decoding, manifest or catalogue-validation error; no partial result.
    func load(
        from data: Data,
        categoryData: (String) throws -> Data
    ) throws -> DrinkCatalogue {
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(Manifest.self, from: data)
        try manifest.validate()

        var drinks: [DrinkDefinition] = []
        for source in manifest.categories {
            let definitions = try decoder.decode(
                [DrinkDefinition].self,
                from: categoryData(source.file)
            )
            for drink in definitions {
                guard drink.categoryID == source.id else {
                    throw LoadError.categoryMismatch(
                        file: source.file, drinkID: drink.id, categoryID: drink.categoryID
                    )
                }
            }
            drinks.append(contentsOf: definitions)
        }

        let catalogue = manifest.catalogue(with: drinks)
        try catalogue.validate()
        return catalogue
    }

    /// File-layout metadata; manifestVersion is separate from the catalogue's data schema.
    private nonisolated struct Manifest: Decodable {
        let manifestVersion: Int
        let schemaVersion: Int
        let version: String
        let categories: [CategorySource]

        /// Checks root metadata and safe, unique file references before reading definitions.
        func validate() throws {
            guard manifestVersion == 1 else {
                throw LoadError.unsupportedManifestVersion(manifestVersion)
            }
            try catalogue(with: []).validate()

            var files = Set<String>()
            for source in categories {
                let url = URL(fileURLWithPath: source.file)
                guard source.file == url.lastPathComponent,
                      url.pathExtension == "json",
                      !source.file.contains("\\") else {
                    throw LoadError.invalidCategoryFile(source.file)
                }
                guard files.insert(source.file).inserted else {
                    throw LoadError.duplicateCategoryFile(source.file)
                }
            }
        }

        /// Maps packaging metadata and assembled definitions into the unchanged app model.
        func catalogue(with drinks: [DrinkDefinition]) -> DrinkCatalogue {
            DrinkCatalogue(
                schemaVersion: schemaVersion,
                version: version,
                categories: categories.map { source in return source.category },
                drinks: drinks
            )
        }
    }

    /// One category's metadata and the single required file containing its definitions.
    private nonisolated struct CategorySource: Decodable {
        let id: String
        let name: String
        let sortOrder: Int
        let file: String

        var category: DrinkCategory {
            DrinkCategory(id: id, name: name, sortOrder: sortOrder)
        }
    }
}
