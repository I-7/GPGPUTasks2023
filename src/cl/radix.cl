#ifdef __CLION_IDE__
    #include <libgpu/opencl/cl/clion_defines.cl>
#endif

#line 6

__kernel void fill0(__global unsigned int *t,
                     const unsigned int n)
{
    const unsigned int i = get_global_id(0);
    if (i >= n)
        return;

    t[i] = 0;
}

__kernel void counts(__global unsigned int *as,
                     __global unsigned int *t,
                     const unsigned int d,
                     const unsigned int n)
{
    const unsigned int i = get_global_id(0);
    if (i >= n)
        return;

    atomic_add(&t[(i / WORKGROUP_SIZE) * MAX_DIGIT + (as[i] >> (d * LOG_MAX_DIGIT) & (MAX_DIGIT - 1))], 1);
}

__kernel void sums(__global unsigned int *t,
                   const unsigned int len,
                   const unsigned int n)
{
    const unsigned int i = get_global_id(0) * len + len - 1;
    if (i >= n)
        return;

    for (int j = 0; j < MAX_DIGIT; j++) {
        t[i * MAX_DIGIT + j] += t[(i - len / 2) * MAX_DIGIT + j];
    }
}

__kernel void radix(__global unsigned int *as,
                    __global unsigned int *bs,
                    __global unsigned int *t,
                    const unsigned int d,
                    const unsigned int n,
                    __global unsigned int *digits_less)
{
    unsigned int li = get_local_id(0);
    unsigned int gi = get_group_id(0);

    __local unsigned int outside[MAX_DIGIT];
    __local unsigned int inside[WORKGROUP_SIZE];
    if (li < MAX_DIGIT) {
        outside[li] = digits_less[li];
        int pnt = gi;
        pnt--;
        while (pnt >= 0) {
            outside[li] += t[pnt * MAX_DIGIT + li];
            pnt &= (pnt + 1);
            pnt--;
        }
    } else if (li < 2 * MAX_DIGIT) {
        unsigned int cnt = 0;
        for (int i = 0; i < WORKGROUP_SIZE; i++) {
            if (gi * WORKGROUP_SIZE + i >= n) {
                break;
            }
            if ((as[gi * WORKGROUP_SIZE + i] >> (d * LOG_MAX_DIGIT) & (MAX_DIGIT - 1)) == li - MAX_DIGIT) {
                inside[i] = cnt;
                cnt++;
            }
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);

    unsigned int i = gi * WORKGROUP_SIZE + li;
    if (i >= n)
        return;

    bs[outside[as[i] >> (d * LOG_MAX_DIGIT) & (MAX_DIGIT - 1)] + inside[li]] = as[i];
}
