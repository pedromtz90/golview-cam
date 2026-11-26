// BallFollow.swift — Fase 1 del auto-seguimiento de balón con gimbal DockKit (paridad con FoloCam).
//
// Mecanismo (confirmado contra el SDK real de DockKit, iOS 17+):
//   frame (CVPixelBuffer) -> detector de balón -> DockAccessory.Observation(type: .object, rect:)
//   -> Gimbal.track([obs], cameraInformation:, image:) ~20 Hz -> el gimbal sigue el balón.
// Antes hay que soltar el tracking de personas de Apple: Gimbal.setTracking(on: false).
//
// Esta Fase 1 deja la plomería compilando contra la API real. El detector de balón de producción
// (CoreML/YOLO "sports ball") se enchufa por el protocolo BallDetector; aquí va un detector SIN
// modelo (saliencia de Vision) como stand-in para probar el lazo. El suavizado EMA (idea del motor
// de Reco) evita que la cámara vaya a tirones. Todavía NO se engancha a la captura en vivo: eso es
// el siguiente paso y necesita gimbal + modelo reales para validarse.

import AVFoundation
import CoreVideo
import DockKit
import Foundation
import ImageIO
import QuartzCore
import Vision

/// Devuelve el recuadro del objeto a seguir en coordenadas NORMALIZadas de Vision
/// (origen abajo-izquierda, 0...1), o nil si no hay candidato en el frame.
@available(iOS 18.0, *)
protocol BallDetector {
    func detect(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGRect?
}

/// Detector SIN modelo: usa la saliencia por atención de Vision y toma el objeto más saliente.
/// Stand-in para validar el movimiento del gimbal hasta enchufar el modelo de balón real.
/// ponytail: saliencia, no balón. Se reemplaza por un VNCoreMLRequest con YOLO cuando haya modelo.
@available(iOS 18.0, *)
final class SaliencyBallDetector: BallDetector {
    func detect(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = request.results?.first as? VNSaliencyImageObservation,
              let salient = result.salientObjects?.max(by: { $0.confidence < $1.confidence })
        else {
            return nil
        }
        return salient.boundingBox
    }
}

/// Lazo de auto-seguimiento: por cada frame, detecta y le manda la observación al gimbal.
/// Reusa `Gimbal` (que ya tiene la conexión al accesorio y el toggle de tracking de sistema).
@available(iOS 18.0, *)
@MainActor
final class BallFollowController {
    private let gimbal: Gimbal
    private let detector: BallDetector
    private var enabled = false
    private var lastSentAt: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 20.0 // DockKit pide 10–30 Hz
    private var emaRect: CGRect?
    private let emaAlpha: CGFloat = 0.35 // suavizado (idea del panner de Reco)

    init(gimbal: Gimbal, detector: BallDetector = SaliencyBallDetector()) {
        self.gimbal = gimbal
        self.detector = detector
    }

    /// Enciende/apaga el seguimiento. Al encender, se quita el tracking de personas de Apple.
    func setEnabled(_ on: Bool) {
        enabled = on
        gimbal.setTracking(on: !on) // on=true -> dejamos de usar el system tracking de DockKit
        if !on {
            emaRect = nil
        }
    }

    /// Llamar por cada frame de la cámara (desde el delegado de captura).
    func onFrame(
        _ sampleBuffer: CMSampleBuffer,
        device: AVCaptureDevice,
        orientation: DockAccessory.CameraOrientation
    ) {
        guard enabled, gimbal.isConnected() else {
            return
        }
        let now = CACurrentMediaTime()
        guard now - lastSentAt >= minInterval else {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        guard let raw = detector.detect(pixelBuffer, orientation: .right) else {
            return
        }
        lastSentAt = now

        let rect = smoothed(raw)
        let camera = DockAccessory.CameraInformation(
            captureDevice: device.deviceType,
            cameraPosition: device.position,
            orientation: orientation,
            cameraIntrinsics: nil, // opcional: DockKit usa sus defaults
            referenceDimensions: nil
        )
        let observation = DockAccessory.Observation(identifier: 0, type: .object, rect: rect, faceYawAngle: nil)
        gimbal.track(observations: [observation], cameraInformation: camera, image: pixelBuffer)
    }

    /// EMA sobre el recuadro para que el gimbal no persiga saltos de un solo frame.
    func smoothed(_ raw: CGRect) -> CGRect {
        guard let prev = emaRect else {
            emaRect = raw
            return raw
        }
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
            a + emaAlpha * (b - a)
        }
        let next = CGRect(
            x: lerp(prev.origin.x, raw.origin.x),
            y: lerp(prev.origin.y, raw.origin.y),
            width: lerp(prev.size.width, raw.size.width),
            height: lerp(prev.size.height, raw.size.height)
        )
        emaRect = next
        return next
    }
}
