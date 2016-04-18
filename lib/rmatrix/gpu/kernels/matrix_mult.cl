__kernel void
matrix_mult(__global float* Output,
          __global float* Left,
          __global float* Right,
          int wLeft, int wRight)
{

   int tx = get_global_id(0);
   int ty = get_global_id(1);

   float result = 0;
   for (int k = 0; k <= wLeft; ++k)
   {
      float elementLeft = Left[ty * wLeft + k];
      float elementRight = Right[k * wRight + tx];
      result += elementLeft * elementRight;
   }

   Output[ty * wRight + tx] = result;
}
