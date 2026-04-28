#include "testlib.h"
#include <sstream>
#include <string>
#include <vector>

using namespace std;

static vector<string> splitTokens(const string& s) {
    stringstream ss(s);
    vector<string> tokens;
    string token;
    while (ss >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

int main(int argc, char* argv[]) {
    registerTestlibCmd(argc, argv);

    int lineNumber = 0;
    while (!ans.eof()) {
        string expected = ans.readLine();
        if (ans.eof() && expected.empty()) {
            break;
        }
        string actual = ouf.readLine();
        ++lineNumber;
        if (splitTokens(expected) != splitTokens(actual)) {
            quitf(_wa, "line %d differs: expected '%s', found '%s'", lineNumber, compress(expected).c_str(), compress(actual).c_str());
        }
    }

    ouf.readEof();
    quitf(_ok, "accepted");
}
