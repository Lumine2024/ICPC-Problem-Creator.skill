using System;
using System.Runtime.InteropServices;

public static class RLimit
{
    [StructLayout(LayoutKind.Sequential)]
    public struct rlimit
    {
        public UIntPtr rlim_cur;
        public UIntPtr rlim_max;
    }
    
    [DllImport("libc", SetLastError = true)]
    public static extern int getrlimit(int resource, out rlimit rlp);

    [DllImport("libc", SetLastError = true)]
    public static extern int setrlimit(int resource, ref rlimit rlp);
}
