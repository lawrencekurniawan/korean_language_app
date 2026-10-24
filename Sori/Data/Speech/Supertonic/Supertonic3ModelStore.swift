@preconcurrency import CoreML
import Foundation

/// Loads the Supertonic-3 CoreML stages that ship inside the app bundle.
///
/// The app bundles the INT8 L128 vector-estimator build. L128 covers roughly
/// 8.9 seconds of audio per chunk; the Korean chunker keeps each pass well
/// below that, so one bucket is enough for lesson vocabulary and sentences.
actor Supertonic3ModelStore {
    enum ModelNames {
        static let textEncoder = "TextEncoder_v2.mlmodelc"
        static let durationPredictor = "DurationPredictor_v2.mlmodelc"
        static let vocoder = "Vocoder.mlmodelc"
        static let vectorEstimator = "VectorEstimatorVariants/VectorEstimator_v2_L128_int8.mlmodelc"
        static let config = "tts.json"
        static let unicodeIndexer = "unicode_indexer.json"
        static let bucketLength = 128
    }

    private let resourceDirectory: URL?
    private let computeUnits: MLComputeUnits
    private var loadedDirectory: URL?
    private var textEncoderModel: MLModel?
    private var durationPredictorModel: MLModel?
    private var vocoderModel: MLModel?
    private var vectorEstimatorModel: MLModel?

    private(set) var config: Supertonic3Config = .defaults

    init(directory: URL? = nil, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
        self.resourceDirectory = directory
        self.computeUnits = computeUnits
    }

    func loadIfNeeded() async throws {
        if textEncoderModel != nil, let loadedDirectory {
            _ = loadedDirectory
            return
        }

        let directory = try resolvedDirectory()
        loadedDirectory = directory

        let configURL = directory.appendingPathComponent(ModelNames.config)
        if FileManager.default.fileExists(atPath: configURL.path) {
            do {
                config = try JSONDecoder().decode(
                    Supertonic3Config.self,
                    from: Data(contentsOf: configURL)
                )
            } catch {
                config = .defaults
            }
        }

        textEncoderModel = try load(ModelNames.textEncoder, in: directory)
        durationPredictorModel = try load(ModelNames.durationPredictor, in: directory)
        vocoderModel = try load(ModelNames.vocoder, in: directory)
        vectorEstimatorModel = try load(ModelNames.vectorEstimator, in: directory)
    }

    func textEncoder() throws -> MLModel {
        guard let textEncoderModel else { throw Supertonic3Error.notInitialized }
        return textEncoderModel
    }

    func durationPredictor() throws -> MLModel {
        guard let durationPredictorModel else { throw Supertonic3Error.notInitialized }
        return durationPredictorModel
    }

    func vocoder() throws -> MLModel {
        guard let vocoderModel else { throw Supertonic3Error.notInitialized }
        return vocoderModel
    }

    func vectorEstimator(forLatentLength latentLength: Int) throws -> (model: MLModel, paddedLength: Int) {
        guard let vectorEstimatorModel else { throw Supertonic3Error.notInitialized }
        guard latentLength <= ModelNames.bucketLength else {
            throw Supertonic3Error.inferenceFailed(
                stage: "vector_estimator",
                underlying: "latent length \(latentLength) exceeds the bundled L128 bucket"
            )
        }
        return (vectorEstimatorModel, ModelNames.bucketLength)
    }

    func unicodeIndexerURL() throws -> URL {
        guard let loadedDirectory else { throw Supertonic3Error.notInitialized }
        return loadedDirectory.appendingPathComponent(ModelNames.unicodeIndexer)
    }

    func voiceStyleURL(named name: String) throws -> URL {
        guard let loadedDirectory else { throw Supertonic3Error.notInitialized }
        let url = loadedDirectory.appendingPathComponent("voice_styles/\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Supertonic3Error.modelFileNotFound("voice_styles/\(name).json")
        }
        return url
    }

    func unload() {
        textEncoderModel = nil
        durationPredictorModel = nil
        vocoderModel = nil
        vectorEstimatorModel = nil
        loadedDirectory = nil
    }

    private func load(_ relativePath: String, in directory: URL) throws -> MLModel {
        let url = directory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Supertonic3Error.modelFileNotFound(relativePath)
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        do {
            return try MLModel(contentsOf: url, configuration: configuration)
        } catch {
            throw Supertonic3Error.corruptedModel(relativePath, underlying: "\(error)")
        }
    }

    private func resolvedDirectory() throws -> URL {
        if let resourceDirectory {
            return resourceDirectory
        }

        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Supertonic3"),
            Bundle.main.resourceURL?.appendingPathComponent("Models/Supertonic3"),
            Bundle.main.bundleURL.appendingPathComponent("Supertonic3"),
        ]

        for candidate in candidates {
            guard let candidate else { continue }
            if FileManager.default.fileExists(
                atPath: candidate.appendingPathComponent(ModelNames.config).path
            ) {
                return candidate
            }
        }

        throw Supertonic3Error.modelFileNotFound("Supertonic3 resources")
    }
}
