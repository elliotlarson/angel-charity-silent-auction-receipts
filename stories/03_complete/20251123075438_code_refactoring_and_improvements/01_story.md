# Code Refactoring and Improvements

## Problem Statement

A code review identified several issues that need to be addressed to improve code quality, robustness, and maintainability:

### Critical Issues

1. **Unsafe error handling** - `AnthropicClient` uses `Req.post!` which raises exceptions instead of returning error tuples, breaking the function contract
2. **Broken currency formatting** - `ReceiptGenerator.format_currency/1` contains pointless division and hardcoded cents value
3. **Unsafe user input parsing** - Mix task uses `String.to_integer/1` on user input without error handling

### Code Quality Issues

4. **DRY violation** - ChromicPDF initialization code duplicated across two Mix tasks
5. **Non-idiomatic changeset** - `AuctionItem.changeset/1` doesn't follow Ecto conventions
6. **Misplaced alias** - Function-level alias instead of module-level in Mix task
7. **Dead code** - Placeholder `Receipts` module serves no purpose

### Refactoring Opportunities

8. **Configuration inconsistency** - Some modules use module attributes for paths, others use `Application.get_env`
9. **Template reading inefficiency** - HTML template read from disk on every call
10. **Complex default logic** - Convoluted `put_default/3` logic in AuctionItem
11. **Regex compilation** - Regexes compiled on every function call in TextNormalizer

## Expected Outcome

- All critical safety issues resolved
- Code follows idiomatic Elixir patterns
- Consistent configuration management
- Improved performance through optimizations
- DRY principle applied throughout
- All tests passing
