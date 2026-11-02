import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkCatalogueManifestTests {
    // GIVEN explicitly listed category files and an unlisted malformed file, when loading,
    // THEN only listed files are read in manifest order and one complete catalogue is returned.
    @Test func assemblesOnlyListedFilesInManifestOrder() throws {
        let manifest = try manifestData(categories: [
            category("coffee", file: "coffee.json"),
            category("water", file: "water.json")
        ])
        var files = try categoryFiles()
        files["ignored.json"] = Data("not JSON".utf8)
        var reads: [String] = []
        let catalogue = try DrinkCatalogueLoader().load(
            from: manifest,
            categoryData: { filename in
                reads.append(filename)
                return try #require(files[filename])
            }
        )

        #expect(reads == ["coffee.json", "water.json"])
        #expect(catalogue.drinks.map(\.id) == ["test-coffee", "test-water"])
        #expect(catalogue.categories.map(\.id) == ["coffee", "water"])
        #expect(catalogue.schemaVersion == 1)
        #expect(catalogue.version == "test-content-1")
        #expect(try load(manifest: manifest, files: files) == catalogue)
    }

    // GIVEN a new synthetic category and a supported rule, when its file is listed,
    // THEN the loader includes it without any category-specific Swift selection logic.
    @Test func addingCategoryRequiresOnlyManifestAndDefinitions() throws {
        let manifest = try manifestData(categories: [category("new-category", file: "new.json")])
        let definition = drink("new-drink", categoryID: "new-category")
        let catalogue = try load(
            manifest: manifest,
            files: ["new.json": JSONEncoder().encode([definition])]
        )

        #expect(catalogue.drinks == [definition])
        #expect(catalogue.categories.map(\.id) == ["new-category"])
    }

    // GIVEN an unsupported manifest format, when loading is attempted,
    // THEN the layout is rejected before a category file is read.
    @Test func rejectsUnsupportedManifestVersionBeforeReadingFiles() throws {
        let manifest = try manifestData(manifestVersion: 2)
        var reads = 0

        #expect(throws: DrinkCatalogueLoader.LoadError.unsupportedManifestVersion(2)) {
            _ = try DrinkCatalogueLoader().load(from: manifest, categoryData: { _ in
                reads += 1
                return Data()
            })
        }
        #expect(reads == 0)
    }

    // GIVEN an invalid file reference, when the manifest is read,
    // THEN the loader rejects paths, remote URLs and non-JSON files before opening anything.
    @Test(arguments: ["../water.json", "/water.json", "folder/water.json", "water.txt",
                      "folder\\water.json", "", ".json", "https://example.com/water.json"])
    func rejectsInvalidCategoryFileReference(filename: String) throws {
        let manifest = try manifestData(categories: [category("water", file: filename)])

        #expect(throws: DrinkCatalogueLoader.LoadError.invalidCategoryFile(filename)) {
            _ = try load(manifest: manifest, files: [:])
        }
    }

    // GIVEN two categories referring to one file, when the manifest is checked,
    // THEN the duplicate reference is rejected rather than reusing or double-loading it.
    @Test func rejectsDuplicateCategoryFiles() throws {
        let manifest = try manifestData(categories: [
            category("water", file: "shared.json"),
            category("coffee", file: "shared.json")
        ])

        #expect(throws: DrinkCatalogueLoader.LoadError.duplicateCategoryFile("shared.json")) {
            _ = try load(manifest: manifest, files: [:])
        }
    }

    // GIVEN duplicate category identities, when root metadata is validated,
    // THEN the existing catalogue validation error is reported before reading definitions.
    @Test func rejectsDuplicateCategoryIDs() throws {
        let manifest = try manifestData(categories: [
            category("water", file: "first.json"),
            category("water", file: "second.json")
        ])

        #expect(throws: DrinkCatalogue.ValidationError.duplicateCategoryID("water")) {
            _ = try load(manifest: manifest, files: [:])
        }
    }

    // GIVEN a manifest category without a filename, when it is decoded,
    // THEN decoding fails rather than discovering a file or substituting a default.
    @Test func rejectsMissingRequiredFilename() throws {
        var source = category("water", file: "water.json")
        source.removeValue(forKey: "file")
        let manifest = try manifestData(categories: [source])

        #expect(throws: DecodingError.self) {
            _ = try load(manifest: manifest, files: [:])
        }
    }

    // GIVEN one valid category and one missing file, when loading is attempted,
    // THEN the load fails; a subsequent complete load contains each definition only once.
    @Test func rejectsMissingFileWithoutRetainingPartialCatalogue() throws {
        let manifest = try manifestData()
        let files = try categoryFiles()
        let waterData = try #require(files["water.json"])

        #expect(throws: DrinkCatalogueLoader.LoadError.categoryResourceNotFound("coffee.json")) {
            _ = try load(manifest: manifest, files: ["water.json": waterData])
        }
        let catalogue = try load(manifest: manifest, files: files)
        #expect(catalogue.drinks.map(\.id) == ["test-water", "test-coffee"])
    }

    // GIVEN a malformed required category after a valid one, when the files are decoded,
    // THEN the whole load fails rather than returning the first category alone.
    @Test(arguments: ["not JSON", "{}", "null"])
    func rejectsUndecodableRequiredCategory(json: String) throws {
        let manifest = try manifestData()
        var files = try categoryFiles()
        files["coffee.json"] = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try load(manifest: manifest, files: files)
        }
    }

    // GIVEN a required file whose reader fails, when loading is attempted,
    // THEN the original error is propagated without a fallback catalogue.
    @Test func propagatesCategoryReadFailure() throws {
        let manifest = try manifestData()

        #expect(throws: CocoaError(.fileReadNoPermission)) {
            _ = try DrinkCatalogueLoader().load(from: manifest, categoryData: { _ in
                throw CocoaError(.fileReadNoPermission)
            })
        }
    }

    // GIVEN a definition assigned to another or unknown category, when its file is read,
    // THEN the mismatch is rejected rather than silently moving the drink between files.
    @Test(arguments: ["water", "missing-category"])
    func rejectsCategoryReferenceMismatch(categoryID: String) throws {
        let manifest = try manifestData()
        var files = try categoryFiles()
        files["coffee.json"] = try JSONEncoder().encode([
            drink("test-coffee", categoryID: categoryID)
        ])
        let expected = DrinkCatalogueLoader.LoadError.categoryMismatch(
            file: "coffee.json", drinkID: "test-coffee", categoryID: categoryID
        )

        #expect(throws: expected) {
            _ = try load(manifest: manifest, files: files)
        }
    }

    // GIVEN matching drink IDs in otherwise valid category files, when assembly completes,
    // THEN cross-file duplicate identity is rejected by catalogue validation.
    @Test func rejectsDuplicateDrinkIDsAcrossFiles() throws {
        let manifest = try manifestData()
        let files = [
            "water.json": try JSONEncoder().encode([drink("shared", categoryID: "water")]),
            "coffee.json": try JSONEncoder().encode([drink("shared", categoryID: "coffee")])
        ]

        #expect(throws: DrinkCatalogue.ValidationError.duplicateDrinkID("shared")) {
            _ = try load(manifest: manifest, files: files)
        }
    }

    // GIVEN an invalid definition in a later file, when the complete catalogue is validated,
    // THEN its numeric validation error prevents any partial result from being returned.
    @Test func validatesDefinitionsAfterAssembly() throws {
        let manifest = try manifestData()
        var files = try categoryFiles()
        let invalid = DrinkDefinition(
            id: "invalid-coffee", name: "Invalid coffee", categoryID: "coffee",
            sortOrder: 1, isRetired: false, defaultVolume: 0
        )
        files["coffee.json"] = try JSONEncoder().encode([invalid])

        #expect(throws: DrinkCatalogue.ValidationError.invalidDefaultVolume(drinkID: invalid.id)) {
            _ = try load(manifest: manifest, files: files)
        }
    }

    private func category(_ id: String, file: String) -> [String: Any] {
        ["id": id, "name": id, "sortOrder": 1, "file": file]
    }

    private func manifestData(
        categories: [[String: Any]]? = nil,
        manifestVersion: Int = 1
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "manifestVersion": manifestVersion,
            "schemaVersion": 1,
            "version": "test-content-1",
            "categories": categories ?? [
                category("water", file: "water.json"),
                category("coffee", file: "coffee.json")
            ]
        ])
    }

    private func drink(_ id: String, categoryID: String) -> DrinkDefinition {
        DrinkDefinition(
            id: id, name: id, categoryID: categoryID, sortOrder: 1,
            isRetired: false, hydrationContributionRule: .ratio(1)
        )
    }

    private func categoryFiles() throws -> [String: Data] {
        [
            "water.json": try JSONEncoder().encode([drink("test-water", categoryID: "water")]),
            "coffee.json": try JSONEncoder().encode([drink("test-coffee", categoryID: "coffee")])
        ]
    }

    private func load(manifest: Data, files: [String: Data]) throws -> DrinkCatalogue {
        try DrinkCatalogueLoader().load(from: manifest, categoryData: { filename in
            guard let data = files[filename] else {
                throw DrinkCatalogueLoader.LoadError.categoryResourceNotFound(filename)
            }
            return data
        })
    }
}
