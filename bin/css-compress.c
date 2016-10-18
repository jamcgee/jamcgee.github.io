#include <ctype.h>
#include <stdio.h>
#include <string.h>

static const char separators[] = ":;{},+";

static int collapse_whitespace() {
  int ch;
  for (ch = fgetc(stdin); isspace(ch); ch = fgetc(stdin)) {}
  return ch;
}

int main() {
  // Delete leading white space
  int ch = collapse_whitespace();

  // Main processing loop
  while (ch != EOF) {
    switch (ch) {
      case ';':
        // We collapse semicolons with themselves and }
        while (ch == ';') {
          ch = collapse_whitespace();
        }
        if (ch != '}') {
          fputc(';', stdout);
        }
        break;

      case '"':
        // Ignore everything until the next "
        fputc('"', stdout);
        for (ch = fgetc(stdin); (ch != EOF) && (ch != '"'); ch = fgetc(stdin)) {
          fputc(ch, stdout);
        }
        if (ch == '"') {
          fputc('"', stdout);
          ch = collapse_whitespace();
        }
        break;

      case '0': {
        // Collapse leading zeros
        for (ch = fgetc(stdin); ch == '0'; ch = fgetc(stdin)) {}
        if (ch != '.') {
          fputc('0', stdout);
        }
        if (isspace(ch)) {
          ch = collapse_whitespace();
          if (!strchr(separators, ch)) {
            fputc(' ', stdout);
          }
        }
        break;
      }

      default:
        // Everything else...
        if (strchr(separators, ch)) {
          // Delete all following whitespace
          fputc(ch, stdout);
          ch = collapse_whitespace();
        } else {
          // Copy block until whitespace or separator
          do {
            fputc(ch, stdout);
            ch = fgetc(stdin);
          } while ((ch != EOF) && !isspace(ch) && !strchr(separators, ch));
          // If whitespace, eat the whitespace
          if (isspace(ch)) {
            ch = collapse_whitespace();
            if (!strchr(separators, ch) && (ch != EOF)) {
              fputc(' ', stdout);
            }
          }
        }
        break;
    }
  }
}
