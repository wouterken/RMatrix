__kernel void addition(__global const float *x, __global const float *z, __global float *y) {
  size_t ig = get_global_id(0);
  y[ig] = (z[ig] + x[ig]);
}