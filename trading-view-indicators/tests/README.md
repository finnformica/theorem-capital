# Tests Directory

This directory contains test scripts and validation tools for TradingView Pine Script indicators following a consistent naming convention: `test_<indicator_name>.py`

## Core Files

### `test_sessions_bottom_pane.py`
Comprehensive test suite for `theorems_sessions_bottom_pane.pine`:
- Validates 90-minute segment calculations (0-15 segments per day)
- Tests 22.5-minute micro-segment calculations (0-3 quarters per 90M segment)
- Verifies day session boundaries (Night, Morning, Afternoon, Evening)
- Tests edge cases around segment boundaries
- Exports validation data to JSON for MT4 comparison

Usage:
```bash
python3 trading-view-indicators/tests/test_sessions_bottom_pane.py
```

### `pine_script_validator.py` (MANDATORY)
Pine Script linting tool that MUST be run on all indicators:
- Validates Pine Script v6 compatibility
- Checks for deprecated function usage (int(), max(), min(), etc.)
- Analyzes array operations and drawing object limits
- Identifies potential performance issues
- **REQUIRED**: All indicators must pass this linter with zero errors

Usage:
```bash
python3 trading-view-indicators/tests/pine_script_validator.py
```

### `run_tests.sh`
Master test runner that executes all validation tools

Usage:
```bash
bash trading-view-indicators/tests/run_tests.sh
```

## Testing the TradingView Indicator

1. Copy the Pine Script code from `../theorems_sessions_bottom_pane.pine`
2. Paste it into TradingView's Pine Editor
3. Add to chart on a 1-minute or 5-minute timeframe
4. Verify the session layers display correctly:
   - 22.5M cycle (top layer) - 4 quarters per 90M segment
   - 90M cycle - 16 segments per day (alternating colors)
   - Day sessions - 4 fixed time windows (00:00-06:00, 06:00-12:00, 12:00-18:00, 18:00-00:00)
   - Week, Month, Year, and 4-Year cycles as configured

## Key Fixes Applied

- Fixed `int()` to `math.floor()` for Pine Script v6 compatibility
- Added null checks for historical data access
- Fixed midnight boundary handling for day sessions
- Improved array management and cleanup
- Enhanced performance with better bar indexing logic