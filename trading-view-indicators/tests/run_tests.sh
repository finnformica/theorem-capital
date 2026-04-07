#!/bin/bash

echo "TradingView Pine Script Indicators - Test Suite"
echo "=============================================="

# Test 1: Sessions Bottom Pane Indicator
echo "1. Testing Sessions Bottom Pane Indicator..."
echo "--------------------------------------------"
python3 test_sessions_bottom_pane.py
if [ $? -eq 0 ]; then
    echo "✅ Sessions Bottom Pane: PASSED"
else
    echo "❌ Sessions Bottom Pane: FAILED"
fi

echo ""

# Test 2: Pine Script Linting (MANDATORY for all indicators)
echo "2. Running Pine Script Linter (MANDATORY)..."
echo "--------------------------------------------"
python3 pine_script_validator.py
if [ $? -eq 0 ]; then
    echo "✅ Pine Script Linting: PASSED"
else
    echo "❌ Pine Script Linting: FAILED - FIX REQUIRED"
fi

echo ""
echo "TEST SUMMARY"
echo "============"
echo "All indicator tests completed."
echo ""
echo "DEPLOYMENT CHECKLIST:"
echo "- [ ] All tests passed above"
echo "- [ ] Pine Script linter shows zero errors (MANDATORY)"
echo "- [ ] Manually tested on TradingView (1M/5M charts)"
echo "- [ ] CLAUDE.md updated with any changes"
echo ""
echo "Next Steps:"
echo "1. If all tests passed, copy Pine Script to TradingView"
echo "2. Test on 1M or 5M charts"
echo "3. Compare with MT4 reference using generated validation data"