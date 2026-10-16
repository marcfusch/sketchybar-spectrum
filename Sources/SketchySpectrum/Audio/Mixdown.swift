import Accelerate

/// (L+R)/2. `stride` is 1 for planar buffers, the channel count for interleaved ones.
func mixToMono(left: UnsafePointer<Float>, right: UnsafePointer<Float>, stride: Int, frames: Int,
               into mono: UnsafeMutablePointer<Float>) {
    let n = vDSP_Length(frames), s = vDSP_Stride(stride)
    var half: Float = 0.5
    vDSP_vadd(left, s, right, s, mono, 1, n)
    vDSP_vsmul(mono, 1, &half, mono, 1, n)
}
