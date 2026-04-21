# TradingView Pine Script Indicators - Claude Context

## Project Overview
This directory contains Pine Script indicators for TradingView, specifically focused on session-based trading analysis that mirrors MT4 functionality.

## Key Files

### `theorems_sessions_bottom_pane.pine`
**Status**: Recently debugged and fixed (April 2026)
**Purpose**: Multi-layer session timeline indicator that displays various time cycles
**Layers (bottom to top)**:
1. 4-Year Cycle (4 phases)
2. Year Cycle (4 quarters)
3. Month Cycle (4 weeks)
4. Week Cycle (4 phases: Mon-Tue, Wed-Thu, Fri, Sat-Sun)
5. Day Cycle (4 fixed sessions: 00:00-06:00, 06:00-12:00, 12:00-18:00, 18:00-00:00)
6. 90-Minute Cycle (16 segments per day, alternating colors)
7. 22.5-Minute Cycle (4 quarters per 90M segment)

**Recent Fixes Applied**:
- ✅ Fixed `int()` to `math.floor()` for Pine Script v6 compatibility
- ✅ Fixed midnight boundary logic for day sessions (18:00-00:00)
- ✅ Added null checks for historical data access
- ✅ Improved array management and cleanup
- ✅ Enhanced bar indexing logic to prevent errors
- ✅ Added `session_timezone` input (default `Europe/London`) threaded through every `timestamp()`/`year()`/`month()`/`dayofmonth()`/`hour()`/`minute()`/`dayofweek()` call so master DOW/hour/minute are interpreted in the user's chart timezone instead of `syminfo.timezone`

## Testing Infrastructure

### `tests/` Directory
Comprehensive test suite for validating indicator calculations:

- **`test_sessions_indicator.py`**: Basic timing calculations validation
- **`session_validation.py`**: Advanced validation with full-day analysis and JSON export
- **`pine_script_validator.py`**: Pine Script syntax and compatibility checker
- **`run_tests.sh`**: Master test runner for all validation tools

**Test Results**: All timing calculations verified correct ✅
**MT4 Alignment**: Session boundaries match expected MT4 behavior ✅

### Key Test Commands
```bash
# Run all tests
bash trading-view-indicators/tests/run_tests.sh

# Individual tests
python3 trading-view-indicators/tests/test_sessions_indicator.py
python3 trading-view-indicators/tests/session_validation.py
python3 trading-view-indicators/tests/pine_script_validator.py
```

## Session Calculation Logic

### 90-Minute Segments
- 16 segments per day (0-15)
- Each segment = 90 minutes starting from 00:00
- Formula: `segment = floor(total_minutes / 90)`

### 22.5-Minute Quarters
- 4 quarters per 90M segment (0-3)
- Formula: `quarter = floor((total_minutes % 90) / 22.5)`
- Maps to Phase 1-4 colors (Q1=Gray, Q2=Maroon, Q3=Green, Q4=Navy)

### Day Sessions
- **Session 1**: 00:00-06:00 (Night)
- **Session 2**: 06:00-12:00 (Morning)
- **Session 3**: 12:00-18:00 (Afternoon)
- **Session 4**: 18:00-00:00 (Evening) - **Note**: Handles midnight crossing correctly

## Known Issues & Solutions

### Previous Issues (RESOLVED)
1. **Compilation Errors**: `int()` function deprecated → Fixed with `math.floor()`
2. **Session Misalignment**: Midnight boundary issues → Fixed with special case handling
3. **Performance Issues**: Array management → Fixed with proper cleanup
4. **Historical Data Errors**: Missing null checks → Added comprehensive validation

### Current Status
- ✅ Compiles without errors in TradingView
- ✅ Session timing matches MT4 reference
- ✅ All test cases pass
- ✅ Performance optimized for 500 bars

## Development Workflow

### MANDATORY: All New/Modified Indicators Must Follow This Process

#### 1. Development Phase
- Write or modify the Pine Script indicator
- Follow Pine Script v6 best practices (see below)
- Test manually on TradingView with 1M/5M charts

#### 2. Testing Phase (ALL STEPS REQUIRED)
```bash
# Step 1: Run comprehensive test suite
bash trading-view-indicators/tests/run_tests.sh

# Step 2: Run indicator-specific tests (if available)
python3 trading-view-indicators/tests/test_<indicator_name>.py

# Step 3: MANDATORY - Run Pine Script linter on ALL indicators
python3 trading-view-indicators/tests/pine_script_validator.py
```

#### 3. Quality Gates (ALL MUST PASS)
- ✅ **Pine Script Linter**: Zero errors, warnings acceptable if documented
- ✅ **Timing Tests**: All calculations validated against expected behavior
- ✅ **Manual Testing**: Indicator loads and displays correctly on TradingView
- ✅ **Performance**: Loads within 10 seconds on 500 bars
- ✅ **Documentation**: CLAUDE.md updated with any changes

#### 4. Pre-Deployment Checklist
- [ ] Pine Script validator passes (MANDATORY)
- [ ] All timing/calculation tests pass
- [ ] Tested on multiple timeframes (M1, M5, M15 minimum)
- [ ] Session boundaries align with MT4 reference (where applicable)
- [ ] No compilation errors in TradingView
- [ ] CLAUDE.md updated with changes

### Pine Script v6 Best Practices (ENFORCED BY LINTER)
- **Functions**: Use `math.floor()` instead of `int()`, `math.max()` instead of `max()`, etc.
- **Arrays**: Use `array.new<type>()` syntax for type safety
- **Historical Data**: Add null checks: `if na(value) continue`
- **Drawing Objects**: Set limits: `max_boxes_count=500, max_labels_count=500`
- **Time Logic**: Handle midnight crossings explicitly
- **Version**: Always use `//@version=6`

### Testing Commands for New Indicators
```bash
# Create new test file for your indicator
cp trading-view-indicators/tests/test_sessions_bottom_pane.py trading-view-indicators/tests/test_<your_indicator>.py

# Run linter on specific file (REQUIRED for all indicators)
python3 trading-view-indicators/tests/pine_script_validator.py path/to/your_indicator.pine

# Run full test suite
bash trading-view-indicators/tests/run_tests.sh
```

### Code Quality Standards
- **Linting**: Pine Script validator MUST pass with zero errors
- **Testing**: Indicator-specific tests MUST be created for complex logic
- **Documentation**: All changes MUST be documented in CLAUDE.md
- **Performance**: Indicators MUST handle 500+ bars efficiently

## Future Improvements

### Potential Enhancements
- Add timezone configuration options
- Implement session labels with customizable text
- Add alert conditions for session transitions
- Create companion overlay indicator for price levels

### Architecture Notes
- Indicator uses bottom pane (overlay=false)
- Draws colored boxes for each time layer
- Historical data processed on last bar only for performance
- Session logic handles all edge cases including midnight crossings

---

**Last Updated**: April 6, 2026
**Status**: Production Ready ✅
**Test Coverage**: Complete ✅