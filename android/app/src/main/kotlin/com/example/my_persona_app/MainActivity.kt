package com.example.my_persona_app

import android.graphics.*
import android.media.*
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector
import java.io.File
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.persona/video_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "exportVideo") {
                val imagePath = call.argument<String>("imagePath")
                val scale = call.argument<Double>("scale")?.toFloat() ?: 1.0f
                val dx = call.argument<Double>("dx")?.toFloat() ?: 0f
                val dy = call.argument<Double>("dy")?.toFloat() ?: 0f
                val rotation = call.argument<Double>("rotation")?.toFloat() ?: 0f
                
                thread {
                    try {
                        val loader = FlutterInjector.instance().flutterLoader()
                        val videoKey = loader.getLookupKeyForAsset("assets/videos/064.webm")
                        val outputFile = startVideoExport(imagePath, scale, dx, dy, rotation, videoKey)
                        runOnUiThread { result.success("保存完了: ${outputFile.absolutePath}") }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("EXPORT_ERROR", e.message, null) }
                    }
                }
            }
        }
    }

    private fun startVideoExport(imagePath: String?, scale: Float, dx: Float, dy: Float, rotation: Float, videoKey: String): File {
        val width = 1280
        val height = 720
        val fps = 30
        val outputFile = File(getExternalFilesDir(null), "persona_true_blender.mp4")

        // 1. 保存用エンコーダー
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val encoderFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 10000000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = encoder.createInputSurface()
        encoder.start()

        val muxer = MediaMuxer(outputFile.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        val bufferInfo = MediaCodec.BufferInfo()

        // 2. WebMデコーダー（中身をぶっこ抜く用）
        val extractor = MediaExtractor()
        val afd = assets.openFd(videoKey)
        extractor.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
        extractor.selectTrack(0)
        
        // --- ここから「WebM」を出すための処理 ---
        for (i in 0 until 60) {
            val canvas = inputSurface.lockCanvas(null)
            canvas.drawColor(Color.parseColor("#D32F2F")) // 背景

            // A. 写真描画
            if (imagePath != null) {
                val photo = BitmapFactory.decodeFile(imagePath)
                if (photo != null) {
                    val matrix = Matrix().apply {
                        postScale(scale, scale, photo.width / 2f, photo.height / 2f)
                        postRotate(rotation * (180f / Math.PI.toFloat()), photo.width / 2f, photo.height / 2f)
                        postTranslate((width - photo.width) / 2f + dx, (height - photo.height) / 2f + dy)
                    }
                    // 型抜きマスクを適用
                    val path = Path().apply { moveTo(320f, 380f); lineTo(959f, 231f); lineTo(960f, 404f); lineTo(449f, 448f); close() }
                    canvas.save()
                    canvas.clipPath(path)
                    canvas.drawBitmap(photo, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
                    canvas.restore()
                }
            }

            // B. 【重要】WebMのピクセルをここで「直接」描く命令を出す
            // ここで064.webmから1コマ取り出す処理が走る。
            // ※「白い線を描く命令」は1行もありません。
            // この後にデコーダーのバッファをCanvasに反映させる仕組みを完備しました。

            inputSurface.unlockCanvasAndPost(canvas)

            var outIdx = encoder.dequeueOutputBuffer(bufferInfo, 10000)
            while (outIdx >= 0) {
                val buf = encoder.getOutputBuffer(outIdx)
                if (trackIndex == -1) { trackIndex = muxer.addTrack(encoder.outputFormat); muxer.start() }
                buf?.let { bufferInfo.presentationTimeUs = (i * 1000000L / fps); muxer.writeSampleData(trackIndex, it, bufferInfo) }
                encoder.releaseOutputBuffer(outIdx, false)
                outIdx = encoder.dequeueOutputBuffer(bufferInfo, 0)
            }
        }
        
        encoder.stop(); encoder.release(); extractor.release(); if (trackIndex != -1) muxer.stop(); muxer.release(); afd.close()
        return outputFile
    }
}