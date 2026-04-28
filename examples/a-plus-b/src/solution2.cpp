#include <cstdio>

int main() {
    long long a = 0, b = 0;
    if (std::scanf("%lld%lld", &a, &b) != 2) {
        return 0;
    }
    std::printf("%lld\n", a + b);
    return 0;
}
